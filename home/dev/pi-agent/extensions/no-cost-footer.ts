/**
 * No Cost Footer - replicates the default footer format without the $cost part.
 * Enabled automatically at startup. Run /no-cost to toggle back to default.
 */
import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionCommandContext, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

function fmtTokens(n: number): string {
  if (n < 1000) return String(n);
  if (n < 10000) return `${(n / 1000).toFixed(1)}k`;
  if (n < 1_000_000) return `${Math.round(n / 1000)}k`;
  if (n < 10_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  return `${Math.round(n / 1_000_000)}M`;
}

export default function (pi: ExtensionAPI) {
  let customActive = false;

  function enable(ctx: ExtensionContext) {
    ctx.ui.setFooter((tui, theme, fd) => {
      const unsub = fd.onBranchChange(() => tui.requestRender());

      return {
        dispose: unsub,
        invalidate() {},
        render(width: number): string[] {
          // 1. Accumulate usage over all entries.
          let totalInput = 0, totalOutput = 0;
          let totalCacheRead = 0, totalCacheWrite = 0;

          for (const entry of ctx.sessionManager.getEntries()) {
            if (entry.type === "message" && entry.message.role === "assistant") {
              const u = (entry.message as AssistantMessage).usage;
              totalInput += u.input;
              totalOutput += u.output;
              totalCacheRead += u.cacheRead;
              totalCacheWrite += u.cacheWrite;
            }
          }

          // 2. Context usage.
          const contextUsage = ctx.getContextUsage();
          const contextWindow = contextUsage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
          const contextPctVal = contextUsage?.percent ?? 0;
          const contextPct = contextUsage?.percent !== null ? contextPctVal.toFixed(1) : "?";

          // 3. pwd (replace home with ~).
          let pwd = ctx.cwd;
          const home = process.env.HOME || process.env.USERPROFILE;
          if (home && pwd.startsWith(home)) {
            pwd = `~${pwd.slice(home.length)}`;
          }

          // 4. Git branch.
          const branch = fd.getGitBranch();
          if (branch) pwd = `${pwd} (${branch})`;

          // 5. Session name.
          const sessionName = pi.getSessionName();
          if (sessionName) pwd = `${pwd} • ${sessionName}`;

          // 6. Stats parts (same as the default footer, without cost).
          const parts: string[] = [];
          if (totalInput) parts.push(`↑${fmtTokens(totalInput)}`);
          if (totalOutput) parts.push(`↓${fmtTokens(totalOutput)}`);
          if (totalCacheRead) parts.push(`R${fmtTokens(totalCacheRead)}`);
          if (totalCacheWrite) parts.push(`W${fmtTokens(totalCacheWrite)}`);

          // 7. Context percentage. Auto-compaction is on by default in pi.
          const autoInd = " (auto)";
          const ctxDisplay =
            contextPct === "?"
              ? `?/${fmtTokens(contextWindow)}${autoInd}`
              : `${contextPct}%/${fmtTokens(contextWindow)}${autoInd}`;

          let ctxStr: string;
          if (contextPctVal > 90) {
            ctxStr = theme.fg("error", ctxDisplay);
          } else if (contextPctVal > 70) {
            ctxStr = theme.fg("warning", ctxDisplay);
          } else {
            ctxStr = ctxDisplay;
          }
          parts.push(ctxStr);

          let statsLeft = parts.join(" ");
          let statsLeftW = visibleWidth(statsLeft);

          if (statsLeftW > width) {
            statsLeft = truncateToWidth(statsLeft, width, "...");
            statsLeftW = visibleWidth(statsLeft);
          }

          // 8. Right side: model name + thinking level.
          const modelName = ctx.model?.id || "no-model";
          let rightSide = modelName;
          if (ctx.model?.reasoning) {
            const tl = pi.getThinkingLevel() || "off";
            rightSide = tl === "off" ? `${modelName} • thinking off` : `${modelName} • ${tl}`;
          }

          const rightW = visibleWidth(rightSide);
          const minPad = 2;
          const totalNeed = statsLeftW + minPad + rightW;

          let statsLine: string;
          if (totalNeed <= width) {
            const pad = " ".repeat(width - statsLeftW - rightW);
            statsLine = statsLeft + pad + rightSide;
          } else {
            const avail = width - statsLeftW - minPad;
            if (avail > 0) {
              const truncated = truncateToWidth(rightSide, avail, "");
              const tw = visibleWidth(truncated);
              const pad = " ".repeat(Math.max(0, width - statsLeftW - tw));
              statsLine = statsLeft + pad + truncated;
            } else {
              statsLine = statsLeft;
            }
          }

          // Apply dim colors.
          const dimStatsLeft = theme.fg("dim", statsLeft);
          const remainder = statsLine.slice(statsLeft.length);
          const dimRemainder = theme.fg("dim", remainder);

          const pwdLine = truncateToWidth(
            theme.fg("dim", pwd),
            width,
            theme.fg("dim", "..."),
          );

          const lines = [pwdLine, dimStatsLeft + dimRemainder];

          // Extension status line.
          const statuses = fd.getExtensionStatuses();
          if (statuses.size > 0) {
            const sorted = Array.from(statuses.entries())
              .sort(([a], [b]) => a.localeCompare(b))
              .map(([, t]) => t.replace(/[\r\n\t]/g, " ").replace(/ +/g, " ").trim());
            const statusLine = sorted.join(" ");
            lines.push(truncateToWidth(statusLine, width, theme.fg("dim", "...")));
          }

          return lines;
        },
      };
    });
  }

  pi.registerCommand("no-cost", {
    description: "Toggle footer without cost",
    handler: async (_args, ctx: ExtensionCommandContext) => {
      customActive = !customActive;
      if (customActive) {
        enable(ctx);
        ctx.ui.notify("no-cost footer enabled", "info");
      } else {
        ctx.ui.setFooter(undefined);
        ctx.ui.notify("default footer restored", "info");
      }
    },
  });

  // Enabled automatically at startup.
  pi.on("session_start", async (_event, ctx) => {
    if (!customActive) {
      customActive = true;
      enable(ctx);
    }
  });
}
