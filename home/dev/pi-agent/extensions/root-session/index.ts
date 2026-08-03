/**
 * root-session: session-scoped root execution for pi.
 *
 * Two tools:
 *   root_activate — open polkit password dialog (pkexec) to start the root daemon
 *   root          — run shell commands as root through the daemon
 *
 * The daemon listens on a unix socket. Authorization is session-scoped:
 * a new pi session needs new authentication.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { spawn } from "node:child_process";
import { randomBytes } from "node:crypto";
import fs from "node:fs";
import net from "node:net";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DAEMON_JS = path.join(__dirname, "daemon.js");
const PING = "__PING__";
const EXIT = "__EXIT__";

function socketPath(sid: string): string {
  const runtime = process.env.XDG_RUNTIME_DIR || `/run/user/${process.getuid()}`;
  return path.join(runtime, `root-session-${sid}.sock`);
}

function request(
  sock: string,
  payload: string,
  timeoutMs: number,
  onData?: (chunk: string) => void,
  signal?: AbortSignal,
): Promise<string> {
  return new Promise((resolve, reject) => {
    const client = net.createConnection(sock);
    const chunks: Buffer[] = [];
    let done = false;

    const finalize = () => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      if (onAbort) signal?.removeEventListener("abort", onAbort);
      client.destroy();
    };

    const timer = setTimeout(() => {
      finalize();
      reject(new Error("root-session: socket timeout"));
    }, timeoutMs);

    const onAbort = () => {
      finalize();
      reject(new Error("Command aborted"));
    };

    if (signal) {
      if (signal.aborted) {
        onAbort();
        return;
      }
      signal.addEventListener("abort", onAbort, { once: true });
    }

    client.on("connect", () => client.write(payload));
    client.on("data", (d) => {
      chunks.push(d);
      if (onData) onData(d.toString());
    });
    client.on("close", () => {
      if (!done) {
        finalize();
        resolve(Buffer.concat(chunks).toString());
      }
    });
    client.on("error", (e) => {
      if (!done) {
        finalize();
        reject(e);
      }
    });
  });
}

export default function (pi: ExtensionAPI) {
  let sid = randomBytes(6).toString("hex");
  const node = process.execPath;

  function sock(): string {
    return socketPath(sid);
  }

  async function alive(): Promise<boolean> {
    try {
      const r = await request(sock(), PING, 2000);
      return r.includes("PONG");
    } catch {
      return false;
    }
  }

  function startDaemon(): Promise<boolean> {
    return new Promise((resolve) => {
      const runtime = process.env.XDG_RUNTIME_DIR || `/run/user/${process.getuid()}`;
      let child;
      try {
        child = spawn("pkexec", [node, DAEMON_JS, sid, runtime], {
          detached: true,
          stdio: "ignore",
        });
        child.unref();
      } catch {
        resolve(false);
        return;
      }

      let settled = false;
      const finish = (ok: boolean) => {
        if (!settled) {
          settled = true;
          resolve(ok);
        }
      };

      child.on("exit", () => {
        setTimeout(async () => finish(await alive()), 800);
      });

      const deadline = Date.now() + 30000;
      const poll = async () => {
        if (await alive()) {
          finish(true);
          return;
        }
        if (Date.now() > deadline) {
          finish(false);
          return;
        }
        setTimeout(poll, 400);
      };
      poll();
    });
  }

  // ── Lifecycle ──────────────────────────────────────────────

  pi.on("session_start", async () => {
    try {
      const runtime = process.env.XDG_RUNTIME_DIR || `/run/user/${process.getuid()}`;
      const stale = await fs.promises.readdir(runtime).catch(() => [] as string[]);
      for (const f of stale) {
        if (f.startsWith("root-session-") && f.endsWith(".sock")) {
          await request(path.join(runtime, f), EXIT, 1500).catch(() => {});
        }
      }
    } catch {
      /* best effort */
    }
    sid = randomBytes(6).toString("hex");
  });

  pi.on("session_shutdown", async () => {
    try {
      await request(sock(), EXIT, 2000);
    } catch {
      /* daemon already gone */
    }
  });

  pi.on("resources_discover", async () => ({
    skillPaths: [__dirname],
  }));

  // ── Tools ──────────────────────────────────────────────────

  // root_activate — start the daemon (opens pkexec dialog)
  pi.registerTool({
    name: "root_activate",
    label: "Root Activate",
    description:
      "Open the polkit password dialog to obtain root privileges for this pi session. " +
      "Call this first before using the root tool. Authentication is session-scoped: " +
      "a new pi session needs a new activation. Returns the daemon status.",
    parameters: Type.Object({}),
    async execute(_toolCallId, _params, _signal, _onUpdate, _ctx) {
      if (await alive()) {
        return {
          content: [{ type: "text", text: "root-session daemon already active.\nRoot privileges are available for this pi session." }],
          details: { active: true },
        };
      }
      const ok = await startDaemon();
      if (ok) {
        return {
          content: [{ type: "text", text: "root-session daemon started successfully.\nThe root tool can now execute commands with root privileges." }],
          details: { active: true },
        };
      }
      return {
        content: [{ type: "text", text: "root-session: authentication failed or daemon did not start.\nThe pkexec dialog may have been cancelled or the password was incorrect.\nTry again with root_activate." }],
        details: { active: false },
      };
    },
  });

  // root — execute commands as root
  pi.registerTool({
    name: "root",
    label: "Root",
    description:
      "Run a shell command as root through the root-session daemon. " +
      "Call root_activate first to obtain root privileges for this session. " +
      "The daemon exits when the pi session ends, so authorization is session-scoped.",
    parameters: Type.Object({
      command: Type.String({ description: "Shell command to run as root" }),
    }),
    async execute(_toolCallId, params, signal, onUpdate, _ctx) {
      if (!(await alive())) {
        return {
          content: [{
            type: "text",
            text: "root-session daemon is not running. Call root_activate first to obtain root privileges.",
          }],
          details: { active: false },
        };
      }
      const cmd = params.command;
      let acc = "";

      // Throttled streaming: mimics pi's built-in bash tool behavior.
      // Fire at most once every THROTTLE_MS to avoid overwhelming the TUI render loop.
      const THROTTLE_MS = 100;
      let updateTimer: ReturnType<typeof setTimeout> | undefined;
      let updateDirty = false;
      let lastUpdateAt = 0;

      const emitUpdate = () => {
        if (!onUpdate || !updateDirty) return;
        updateDirty = false;
        lastUpdateAt = Date.now();
        onUpdate({ content: [{ type: "text", text: `$ ${cmd}\n${acc}` }] });
      };

      const scheduleUpdate = () => {
        if (!onUpdate) return;
        updateDirty = true;
        const delay = THROTTLE_MS - (Date.now() - lastUpdateAt);
        if (delay <= 0) {
          clearTimeout(updateTimer);
          updateTimer = undefined;
          emitUpdate();
        } else {
          updateTimer ??= setTimeout(() => {
            updateTimer = undefined;
            emitUpdate();
          }, delay);
        }
      };

      // Signal to the TUI that streaming updates are coming.
      if (onUpdate) onUpdate({ content: [], details: undefined });

      let out: string;
      try {
        out = await request(sock(), cmd, 1800000, (chunk) => {
          acc += chunk;
          scheduleUpdate();
        }, signal);
      } catch (e) {
        out = "root-session error: " + (e as Error).message;
      }

      // Flush any pending update.
      clearTimeout(updateTimer);
      emitUpdate();

      return {
        content: [{ type: "text", text: `$ ${cmd}\n${out || "(no output)"}` }],
        details: { active: true, command: cmd },
      };
    },
  });

  // ── Command ────────────────────────────────────────────────

  pi.registerCommand("root-session", {
    description: "Show root-session daemon status",
    handler: async (_args, ctx) => {
      const up = await alive();
      ctx.ui.notify(
        up ? `root-session: daemon up (session ${sid})` : "root-session: daemon down",
        up ? "info" : "warning",
      );
    },
  });
}
