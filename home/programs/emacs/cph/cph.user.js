// ==UserScript==
// @name         CPH Companion for Emacs
// @namespace    https://github.com/lophophora
// @version      0.1.0
// @description  Send competitive programming problems (Codeforces, AtCoder, Luogu) to the Emacs CPH server. Clone of competitive-companion.
// @author       lophophora
// @match        https://codeforces.com/*
// @match        https://*.codeforces.com/*
// @match        https://atcoder.jp/*
// @match        https://www.luogu.com.cn/*
// @match        https://luogu.com.cn/*
// @grant        GM_xmlhttpRequest
// @grant        GM_getValue
// @grant        GM_setValue
// @grant        GM_registerMenuCommand
// @connect      127.0.0.1
// @connect      localhost
// @run-at       document-idle
// @noframes
// @license      GPL-3.0-or-later
// ==/UserScript==

/*
 * Browser side of the Emacs CPH clone.
 *
 * It extracts problem data from the current page (same JSON schema as
 * competitive-companion), POSTs it to the Emacs CPH server
 * (default http://127.0.0.1:27121/), and shows a small status widget.
 *
 * The protocol is wire-compatible with the CPH companion server:
 *
 *   POST /            body = problem JSON, response = submit-state JSON
 *   GET  / + header   cph-submit: true  -> response = stored submit state
 *
 * Because GM_xmlhttpRequest bypasses CORS and mixed-content blocking,
 * an HTTPS page can talk to the local HTTP server directly.
 */

(function () {
  "use strict";

  const CONFIG = {
    host: "127.0.0.1",
    port: Number(GM_getValue("cph_port", 27121)),
    autoSend: GM_getValue("cph_autoSend", true) !== false,
  };

  const SITES = [
    { name: "codeforces", match: /codeforces\.com/, parse: parseCodeforces },
    { name: "atcoder", match: /atcoder\.jp/, parse: parseAtCoder },
    { name: "luogu", match: /luogu\.com\.cn/, parse: parseLuogu },
  ];

  const state = {
    site: null,
    sentUrl: null,
    sending: false,
  };

  /* ---------------------------------------------------------------- widget */

  function ensureWidget() {
    if (document.getElementById("cph-emacs-widget")) return;
    const w = document.createElement("div");
    w.id = "cph-emacs-widget";
    w.style.cssText =
      "position:fixed;right:12px;bottom:12px;z-index:2147483647;" +
      "font:13px/1.4 sans-serif;background:#1f2430;color:#ccc;" +
      "border:1px solid #3a4050;border-radius:6px;padding:8px 10px;" +
      "box-shadow:0 2px 8px rgba(0,0,0,.4);cursor:pointer;" +
      "max-width:320px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;" +
      "user-select:none;";
    w.title = "Click to send the problem to Emacs CPH again";
    const dot = document.createElement("span");
    dot.id = "cph-emacs-dot";
    dot.style.cssText =
      "display:inline-block;width:9px;height:9px;border-radius:50%;" +
      "background:#666;margin-right:7px;vertical-align:middle;";
    const label = document.createElement("span");
    label.id = "cph-emacs-label";
    label.textContent = "CPH idle";
    w.appendChild(dot);
    w.appendChild(label);
    w.addEventListener("click", () => sendProblem(true));
    document.body.appendChild(w);
  }

  function setStatus(kind, text) {
    const dot = document.getElementById("cph-emacs-dot");
    const label = document.getElementById("cph-emacs-label");
    if (!dot || !label) return;
    const colors = { idle: "#666", sending: "#e6a23c", ok: "#4caf50", fail: "#e5484d" };
    dot.style.background = colors[kind] || colors.idle;
    label.textContent = text;
  }

  /* -------------------------------------------------------------- helpers */

  // The <pre> content of sample tests usually starts with a newline.
  function normPre(s) {
    return s.replace(/^\r?\n/, "");
  }

  function uniq(arr) {
    return Array.from(new Set(arr));
  }

  /* ---------------------------------------------------------- Codeforces */

  function parseCodeforces() {
    const statement = document.querySelector(".problem-statement");
    if (!statement) return null;
    const title = statement.querySelector(".header .title");
    if (!title) return null;

    let group = "Codeforces";
    const sidebar = document.querySelector("#sidebar .rtable");
    if (sidebar) group = sidebar.textContent.trim().split("\n")[0].trim();

    const timeEl = statement.querySelector(".time-limit");
    const memEl = statement.querySelector(".memory-limit");
    const timeLimit = parseTimeLimit(timeEl ? timeEl.textContent : "");
    const memoryLimit = parseMemoryLimit(memEl ? memEl.textContent : "");

    const tests = [];
    statement.querySelectorAll(".sample-test").forEach((st) => {
      const inPre = st.querySelector(".input pre");
      const outPre = st.querySelector(".output pre");
      if (inPre && outPre) {
        tests.push({ input: normPre(inPre.textContent), output: normPre(outPre.textContent) });
      }
    });

    return buildProblem({
      name: title.textContent.trim(),
      group,
      interactive: /interactive problem/i.test(statement.textContent),
      memoryLimit,
      timeLimit,
      tests,
    });
  }

  function parseTimeLimit(text) {
    const m = text.match(/([\d.]+)\s*second/);
    return m ? Math.round(parseFloat(m[1]) * 1000) : 2000;
  }

  function parseMemoryLimit(text) {
    const m = text.match(/([\d.]+)\s*megabyte/);
    return m ? Math.round(parseFloat(m[1])) : 256;
  }

  /* -------------------------------------------------------------- AtCoder */

  function parseAtCoder() {
    const h1 = document.querySelector("#main-container h1");
    const statement = document.querySelector("#task-statement");
    if (!h1 || !statement) return null;

    const name = h1.textContent.trim();
    const intro = statement.textContent;
    const timeM = intro.match(/Time Limit:\s*([\d.]+)\s*sec/);
    const memM = intro.match(/Memory Limit:\s*([\d.]+)\s*MB/);

    const inputs = [];
    const outputs = [];
    statement.querySelectorAll("section").forEach((sec) => {
      const h3 = sec.querySelector("h3");
      const pre = sec.querySelector("pre");
      if (!h3 || !pre) return;
      const im = h3.textContent.match(/Sample Input\s*(\d+)/);
      const om = h3.textContent.match(/Sample Output\s*(\d+)/);
      if (im) inputs[Number(im[1]) - 1] = normPre(pre.textContent);
      else if (om) outputs[Number(om[1]) - 1] = normPre(pre.textContent);
    });

    const tests = [];
    for (let i = 0; i < Math.max(inputs.length, outputs.length); i++) {
      if (inputs[i] !== undefined && outputs[i] !== undefined) {
        tests.push({ input: inputs[i], output: outputs[i] });
      }
    }

    return buildProblem({
      name,
      group: contestName(),
      interactive: /interactive problem/i.test(intro),
      memoryLimit: memM ? Number(memM[1]) : 1024,
      timeLimit: timeM ? Math.round(Number(timeM[1]) * 1000) : 2000,
      tests,
    });
  }

  function contestName() {
    const el = document.querySelector(".contest-title, .navbar-brand");
    return el ? el.textContent.trim() : "AtCoder";
  }

  /* ---------------------------------------------------------------- Luogu */

  function parseLuogu() {
    const h1 = document.querySelector("h1");
    if (!h1) return null;

    const name = h1.textContent.trim();
    const pageText = document.body.textContent;

    // Luogu renders each sample as a .sample div. Two layouts exist:
    //   (a) one div per sample with two <pre> (input, output)
    //   (b) one div per half with a single <pre>, "输入 #N" / "输出 #N"
    const sampleDivs = Array.from(document.querySelectorAll(".sample"));
    const tests = [];
    if (sampleDivs.every((d) => d.querySelectorAll("pre").length >= 2)) {
      sampleDivs.forEach((d) => {
        const pres = d.querySelectorAll("pre");
        if (pres.length >= 2) {
          tests.push({ input: normPre(pres[0].textContent), output: normPre(pres[1].textContent) });
        }
      });
    } else {
      const pres = sampleDivs.map((d) => d.querySelector("pre")).filter(Boolean);
      for (let i = 0; i + 1 < pres.length; i += 2) {
        tests.push({ input: normPre(pres[i].textContent), output: normPre(pres[i + 1].textContent) });
      }
    }

    const timeM =
      pageText.match(/时间限制[:：]?\s*([\d.]+)\s*(ms|s|秒|分钟|min)/i) ||
      pageText.match(/Time Limit[:：]?\s*([\d.]+)\s*(sec|s)/i);
    const memM =
      pageText.match(/内存限制[:：]?\s*([\d.]+)\s*(MB|MiB|GB|GiB|KB|KiB)/i) ||
      pageText.match(/Memory Limit[:：]?\s*([\d.]+)\s*(MB|MiB|GB|GiB|KB|KiB)/i);

    let timeLimit = 2000;
    let memoryLimit = 128;
    if (timeM) {
      const v = parseFloat(timeM[1]);
      const unit = (timeM[2] || "").toLowerCase();
      timeLimit = unit === "ms" ? Math.round(v) : unit === "min" ? Math.round(v * 60000) : Math.round(v * 1000);
    }
    if (memM) {
      const v = parseFloat(memM[1]);
      const unit = (memM[2] || "").toLowerCase();
      memoryLimit = unit.includes("g") ? Math.round(v * 1024) : unit.includes("k") ? Math.round(v / 1024) : Math.round(v);
    }

    return buildProblem({
      name,
      group: "Luogu",
      interactive: false,
      memoryLimit,
      timeLimit,
      tests,
    });
  }

  /* ---------------------------------------------------------------- common */

  function buildProblem(p) {
    return {
      name: p.name,
      group: p.group,
      url: location.href,
      interactive: p.interactive,
      memoryLimit: p.memoryLimit,
      timeLimit: p.timeLimit,
      tests: p.tests,
      testType: "single",
      input: { type: "stdin" },
      output: { type: "stdout" },
      languages: {},
    };
  }

  /* ----------------------------------------------------------------- send */

  function detectSite() {
    for (const s of SITES) {
      if (s.match.test(location.hostname)) return s;
    }
    return null;
  }

  function sendProblem(manual) {
    const site = state.site || detectSite();
    if (!site) {
      setStatus("fail", "Unsupported site");
      return;
    }
    let problem;
    try {
      problem = site.parse();
    } catch (err) {
      setStatus("fail", "Parse error: " + err.message);
      return;
    }
    if (!problem || !problem.tests.length) {
      setStatus("fail", "No sample tests found on this page");
      return;
    }
    if (state.sending) return;
    state.sending = true;

    setStatus("sending", "Sending to Emacs…");
    GM_xmlhttpRequest({
      method: "POST",
      url: "http://" + CONFIG.host + ":" + CONFIG.port + "/",
      headers: { "Content-Type": "application/json" },
      data: JSON.stringify(problem),
      timeout: 5000,
      onload: (r) => {
        state.sending = false;
        if (r.status >= 200 && r.status < 300) {
          state.sentUrl = location.href;
          let extra = "";
          try {
            const resp = JSON.parse(r.responseText);
            if (resp && !resp.empty) extra = " · submit state ready";
          } catch (e) { /* ignore */ }
          setStatus("ok", "Sent · " + problem.tests.length + " tests" + extra);
        } else {
          setStatus("fail", "Server error HTTP " + r.status);
        }
      },
      onerror: () => {
        state.sending = false;
        setStatus("fail", "Emacs unreachable — start cph-server");
      },
      ontimeout: () => {
        state.sending = false;
        setStatus("fail", "Timed out — is Emacs listening?");
      },
    });
  }

  function maybeAutoSend() {
    const site = detectSite();
    if (!site) return;
    state.site = site;
    ensureWidget();
    if (CONFIG.autoSend && state.sentUrl !== location.href) {
      sendProblem(false);
    } else {
      setStatus("idle", "CPH · click to send");
    }
  }

  /* ---------------------------------------------------------------- menus */

  function setPort() {
    const v = prompt("Emacs CPH server port:", String(CONFIG.port));
    if (v === null) return;
    const n = Number(v);
    if (!Number.isInteger(n) || n <= 0 || n > 65535) {
      alert("Invalid port");
      return;
    }
    CONFIG.port = n;
    GM_setValue("cph_port", n);
    setStatus("idle", "Port " + n);
  }

  function toggleAutoSend() {
    CONFIG.autoSend = !CONFIG.autoSend;
    GM_setValue("cph_autoSend", CONFIG.autoSend);
    setStatus("idle", "Auto-send " + (CONFIG.autoSend ? "on" : "off"));
  }

  GM_registerMenuCommand("Send problem to Emacs", () => sendProblem(true));
  GM_registerMenuCommand("Set Emacs CPH port", setPort);
  GM_registerMenuCommand("Toggle auto-send", toggleAutoSend);

  /* ---------------------------------------------------------------- debug */

  // Expose internals for the node test harness and manual debugging.
  globalThis.__CPH_COMPANION__ = {
    CONFIG,
    detectSite,
    parseCodeforces,
    parseAtCoder,
    parseLuogu,
    buildProblem,
    sendProblem,
  };

  /* ----------------------------------------------------------------- boot */

  if (document.body) {
    maybeAutoSend();
  } else {
    window.addEventListener("DOMContentLoaded", maybeAutoSend);
  }
})();
