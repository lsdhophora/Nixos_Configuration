// Send one desktop notification when the model announces that a unit of
// work is finished. Every trigger is model-driven, so the extension needs
// no tool-count or duration heuristic:
//
//   - the agent marks a goal complete (pi-goal),
//   - the agent closes its own scheduled task (the schedule_prompt tool
//     with action "delete" or "clear"),
//   - the agent calls the notify_done tool.
//
// A scheduler monitoring round only reports progress: it never closes the
// task and never calls the tool, so the watchdog does not ring once per
// check. The notification goes out through notify-send, which lives in the
// home profile and reaches the desktop notification service.
//
// @ts-nocheck
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execFile } from "node:child_process";

// The entry that pi-goal appends for its state.
const GOAL_CUSTOM_TYPE = "pi-goal";

function notify(title: string, body: string): void {
  // Fire and forget: a notification must never slow a turn down, and a
  // failure (no session bus, no daemon) is not actionable here.
  execFile("notify-send", ["--app-name=pi", title, body], () => {});
}

function oneLine(text: string, max = 160): string {
  const flat = String(text).replace(/\s+/g, " ").trim();
  return flat.length > max ? `${flat.slice(0, max - 1)}…` : flat;
}

// The latest goal state, from the newest pi-goal entry in the session.
function latestGoal(ctx: any): any {
  const entries = ctx?.sessionManager?.getBranch?.() ?? ctx?.sessionManager?.getEntries?.() ?? [];
  for (let i = entries.length - 1; i >= 0; i--) {
    const entry = entries[i];
    if (entry?.type === "custom" && entry.customType === GOAL_CUSTOM_TYPE) {
      return entry.data?.goal ?? null;
    }
  }
  return null;
}

export default function notifyOnComplete(pi: ExtensionAPI) {
  // The last goal that already sent a notification, so a settled turn
  // after the goal completed does not send it again.
  let notifiedGoalId: string | undefined;

  pi.registerTool({
    name: "notify_done",
    label: "Notify Done",
    description:
      "Send one desktop notification that the current unit of work is done. " +
      "Use it only when a task is finished and no goal or scheduled task reports it.",
    promptSnippet: "Announce a finished task with one desktop notification",
    promptGuidelines: [
      "Call notify_done only after the requested work is finished and verified.",
      "Do not call it for progress updates, and not when a goal or a scheduled task already covers the work.",
    ],
    parameters: {
      type: "object",
      properties: {
        message: { type: "string", description: "One short line describing what finished." },
      },
      required: ["message"],
      additionalProperties: false,
    } as any,
    async execute(_toolCallId: string, params: any) {
      const message = typeof params?.message === "string" ? params.message.trim() : "";
      notify("任务完成", oneLine(message || "任务已完成"));
      return { content: [{ type: "text", text: "Notification sent." }] };
    },
  });

  // The agent closed its own scheduled task: that is the model saying the
  // task is done. A monitoring round never reaches this branch.
  pi.on("tool_result", async (event: any) => {
    if (event?.toolName !== "schedule_prompt" || event.isError) return;
    const action = event.input?.action ?? event.details?.action;
    if (action !== "delete" && action !== "clear") return;
    if (action === "delete" && event.details?.removed === false) return;
    if (action === "clear" && !event.details?.count) return;
    notify("任务完成", action === "clear" ? "已关闭全部调度任务" : "已关闭调度任务");
  });

  // A goal reached the complete state. Read it from the session and send
  // one notification per goal id.
  pi.on("agent_settled", async (_event: any, ctx: any) => {
    const goal = latestGoal(ctx);
    if (!goal || goal.status !== "complete" || goal.id === notifiedGoalId) return;
    notifiedGoalId = goal.id;
    notify("目标完成", oneLine(goal.objective ?? "目标已完成"));
  });
}
