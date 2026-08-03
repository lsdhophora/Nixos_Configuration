// root-session daemon (Node.js): execute commands as root over a unix socket.
// Started once per pi session via pkexec. The pi extension sends commands
// over the socket; this daemon runs them as root and returns stdout+stderr.
//
// Usage: node daemon.js <sid> <runtime_dir>
"use strict";

const net = require("node:net");
const { spawn } = require("node:child_process");
const fs = require("node:fs");

const sid = process.argv[2] || "default";
const runtime = process.argv[3] || "/run/user/0";
const sockPath = `${runtime}/root-session-${sid}.sock`;
const LOG = `${runtime}/root-session-debug.log`;
const IDLE_TIMEOUT = 8 * 3600 * 1000; // 8h without activity -> self-exit
const BASH = "/run/current-system/sw/bin/bash";

function log(msg) {
  try {
    fs.appendFileSync(LOG, `${new Date().toISOString()} ${msg}\n`);
  } catch {
    /* no logging */
  }
}
log(`daemon start sid=${sid} runtime=${runtime} node=${process.version}`);

try {
  fs.unlinkSync(sockPath);
} catch {
  /* no stale socket */
}

let idle = setTimeout(() => {
  server.close();
  process.exit(0);
}, IDLE_TIMEOUT);

const server = net.createServer((conn) => {
  clearTimeout(idle);
  idle = setTimeout(() => {
    server.close();
    process.exit(0);
  }, IDLE_TIMEOUT);

  let buf = "";
  conn.on("data", (d) => {
    buf += d.toString();
    const cmd = buf.trim();
    if (cmd === "__EXIT__") {
      conn.write("OK");
      conn.end();
      server.close();
      process.exit(0);
      return;
    }
    if (cmd === "__PING__") {
      conn.write("PONG");
      conn.end();
      return;
    }
    const proc = spawn(BASH, ["-c", cmd], {
      timeout: 1800000,
      stdio: ["ignore", "pipe", "pipe"],
    });
    let hasOutput = false;
    proc.stdout.on("data", (chunk) => {
      hasOutput = true;
      try { conn.write(chunk); } catch { /* connection gone */ }
    });
    proc.stderr.on("data", (chunk) => {
      hasOutput = true;
      try { conn.write(chunk); } catch { /* connection gone */ }
    });
    proc.on("error", (err) => {
      const msg = `root-session error: ${err.message}\n`;
      try { conn.write(hasOutput ? msg : msg); } catch { /* connection gone */ }
      if (!hasOutput) conn.end();
    });
    proc.on("close", (code) => {
      if (!hasOutput && code !== 0) {
        try { conn.write(`root-session error: exit code ${code}\n`); } catch {}
      }
      conn.end();
    });
  });
});

server.on("error", (e) => {
  log("server error: " + e.message + " (code " + e.code + ")");
  console.error("root-session daemon error:", e.message);
  process.exit(1);
});

process.on("uncaughtException", (e) => {
  log("uncaught: " + (e && e.stack ? e.stack : String(e)));
  process.exit(1);
});

server.listen(sockPath, () => {
  try {
    fs.chmodSync(sockPath, 0o666);
  } catch (e) {
    log("chmod failed: " + e.message);
  }
  log("daemon listening on " + sockPath);
  console.log(`root-session daemon up: ${sockPath}`);
});
