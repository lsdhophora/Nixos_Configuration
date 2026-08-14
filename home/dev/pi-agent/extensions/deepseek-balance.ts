/**
 * DeepSeek Balance
 *
 * Shows the DeepSeek API balance in the footer extension status line.
 * Pure event-driven refresh (no time throttling), matching how
 * DeepSeek-TUI implements it: billing settles when a turn completes, so
 * the balance is fetched once per completed turn instead of following
 * the output stream.
 *
 * Refresh points:
 *   - once per conversation round (agent_end) - the balance only changes
 *     when a request finishes and usage is billed,
 *   - at the start of every turn (turn_start),
 *   - on session start,
 *   - on demand via /balance.
 *
 * Usage:
 *   - Status shows the current balance, updated after each completed turn.
 *   - /balance forces a refresh and shows the value.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const BALANCE_URL = "https://api.deepseek.com/user/balance";
const STATUS_KEY = "ds-balance";

function readDeepseekKey(): string {
  try {
    const auth = JSON.parse(
      readFileSync(join(process.env.HOME || "", ".pi/agent/auth.json"), "utf8"),
    );
    return auth.deepseek?.key || "";
  } catch {
    return "";
  }
}

async function fetchBalance(key: string): Promise<string | null> {
  try {
    const res = await fetch(BALANCE_URL, {
      headers: { Authorization: `Bearer ${key}` },
      signal: AbortSignal.timeout(8000),
    });
    if (!res.ok) return null;
    const data = (await res.json()) as {
      is_available?: boolean;
      balance_infos?: { currency: string; total_balance: string }[];
    };
    const info = data.balance_infos?.[0];
    if (!info) return null;
    return parseFloat(info.total_balance).toFixed(2);
  } catch {
    return null;
  }
}

export default function (pi: ExtensionAPI) {
  let key = readDeepseekKey();
  let balance = "—";
  // Guard against overlapping fetches (concurrency safety, not throttling).
  let refreshing = false;

  async function refresh(ctx: {
    ui: { setStatus(k: string, t: string | undefined): void };
  }) {
    if (refreshing || !key) return;
    refreshing = true;
    try {
      const b = await fetchBalance(key);
      if (b) balance = b;
      ctx.ui.setStatus(STATUS_KEY, `DeepSeek ¥${balance}`);
    } catch {
      /* keep last value */
    } finally {
      refreshing = false;
    }
  }

  pi.on("session_start", async (_event, ctx) => {
    key = readDeepseekKey();
    await refresh(ctx);
  });

  // Catch each model turn start, incl. responses delivered in one shot.
  pi.on("turn_start", async (_event, ctx) => {
    await refresh(ctx);
  });

  // Refresh once per conversation round: usage is billed when the turn
  // ends, so this is the moment the balance actually changes.
  pi.on("agent_end", async (_event, ctx) => {
    await refresh(ctx);
  });

  pi.registerCommand("balance", {
    description: "Refresh DeepSeek balance now",
    handler: async (_args, ctx) => {
      await refresh(ctx);
      ctx.ui.notify(`DeepSeek balance: ¥${balance}`, "info");
    },
  });
}
