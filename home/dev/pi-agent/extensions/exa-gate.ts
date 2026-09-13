/**
 * Exa Gate — hard constraint for the exa tools.
 *
 * Rule: exa tools require the {exa} or {search} prefix at the start of
 * the user message. Authorization is one-shot per prompt and expires
 * at agent_end.
 *
 * The old gate filtered exa tools out of the active tool list. It read
 * `before_agent_start` event.prompt. That text already passed skill and
 * template expansion. The re-enable sync could silently fail. An
 * authorized turn then hit "Tool not found" at the dispatcher. That is
 * a dead end.
 *
 * This gate keeps the tools active. Enforcement happens in the
 * tool_call interception, which always runs for an active tool.
 * Authorization comes from the `input` event, which fires with the raw
 * text before any expansion.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const EXA_TOOLS = ["exa_search", "exa_get_contents", "exa_find_similar"];
const PREFIX_RE = /^\{exa\}|^\{search\}/;

export default function (pi: ExtensionAPI) {
  let exaAuthorized = false;

  // Authorize on the raw input text, before any skill or template
  // expansion. The input event fires for every submitted prompt.
  pi.on("input", async (event) => {
    exaAuthorized = PREFIX_RE.test((event.text ?? "").trim());
  });

  // Backstop for flows that bypass the input pipeline (for example RPC
  // submissions).
  pi.on("before_agent_start", async (event) => {
    const text = event.prompt?.trim() ?? "";
    if (PREFIX_RE.test(text)) {
      exaAuthorized = true;
    }
  });

  // Expire the authorization on every session start.
  pi.on("session_start", async () => {
    exaAuthorized = false;
  });

  // Expire the authorization when the prompt finishes.
  pi.on("agent_end", async () => {
    exaAuthorized = false;
  });

  // Hard enforcement: block exa calls without authorization.
  pi.on("tool_call", async (event) => {
    if (EXA_TOOLS.includes(event.toolName) && !exaAuthorized) {
      return {
        block: true,
        reason:
          "Exa web search needs the {exa} or {search} prefix at the start of your message.",
      };
    }
  });
}