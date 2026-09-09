// ==UserScript==
// @name         CPH Companion for Emacs
// @namespace    https://github.com/FeiHsueh
// @version      1.2.0
// @description  Send a Codeforces problem to the Emacs CPH server (127.0.0.1:27121). Minimal clone of the VSCode CPH companion.
// @author       FeiHsueh
// @match        https://codeforces.com/*
// @match        https://*.codeforces.com/*
// @grant        GM_xmlhttpRequest
// @grant        GM_registerMenuCommand
// @grant        GM_notification
// @connect      127.0.0.1
// @connect      localhost
// @run-at       document-idle
// @noframes
// @license      GPL-3.0-or-later
// ==/UserScript==

/*
 * Browser side of the Emacs CPH clone, for Codeforces only.
 *
 * On a Codeforces problem page, pick "Send problem to Emacs CPH" from
 * the Violentmonkey menu.  The script extracts the problem (the same
 * JSON schema as competitive-companion) and POSTs it to the Emacs CPH
 * server.  The default port 27121 matches the VSCode CPH plugin.
 *
 * Sample parsing notes (modern Codeforces DOM):
 *   - every problem title starts with the index, e.g. "A. Vanya and
 *     Fence", "D1. Mocha and Diana (Easy Version)";
 *   - sample lines inside <pre> are separated by <br> tags, NOT by
 *     raw newlines (textContent would join "3 7" and "4 5 14" into
 *     "3 74 5 14");
 *   - all sample tests live in ONE div.sample-test; input/output pre
 *     blocks alternate inside it.  Older pages used one div per test.
 *   The parser handles both layouts by pairing every .input pre with
 *   the .output pre at the same position.
 *
 * GM_xmlhttpRequest bypasses CORS, so the HTTPS page can reach the
 * local HTTP server.
 *
 * There is no on-page widget, no auto-send, no submit flow, and no
 * ONLINE_JUDGE flag.
 */

(function () {
  "use strict";

  const CONFIG = { host: "127.0.0.1", port: 27121 };

  const state = { sending: false };

  function notify(text) {
    try {
      GM_notification({ text, timeout: 3000 });
    } catch (e) {
      console.log("[cph-emacs]", text);
    }
  }

  /* -------------------------------------------------------------- helpers */

  // Extract sample text from a <pre>.  Modern Codeforces separates
  // lines with <br> tags instead of raw newlines, so textContent alone
  // would glue consecutive lines together.  Normalize <br> to "\n" on
  // a deep clone (the page is never mutated).  The <pre> content of
  // older pages starts with a stray newline; drop that one.
  function preToText(pre) {
    const clone = pre.cloneNode(true);
    clone.querySelectorAll("br").forEach((br) => br.replaceWith("\n"));
    return clone.textContent.replace(/^\r?\n/, "");
  }

  function parseTimeLimit(text) {
    const m = text.match(/([\d.]+)\s*second/);
    return m ? Math.round(parseFloat(m[1]) * 1000) : 2000;
  }

  function parseMemoryLimit(text) {
    const m = text.match(/([\d.]+)\s*megabyte/);
    return m ? Math.round(parseFloat(m[1])) : 256;
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

    // Pair every sample input with its output by position.  This works
    // for both DOM layouts: one .sample-test per example (older pages)
    // and one .sample-test holding all examples (modern pages).
    const tests = [];
    const inPres = Array.from(
      statement.querySelectorAll(".sample-test .input pre")
    );
    const outPres = Array.from(
      statement.querySelectorAll(".sample-test .output pre")
    );
    inPres.forEach((inPre, i) => {
      const outPre = outPres[i];
      if (inPre && outPre) {
        tests.push({ input: preToText(inPre), output: preToText(outPre) });
      }
    });

    return {
      name: title.textContent.trim(),
      group,
      url: location.href,
      timeLimit,
      memoryLimit,
      tests,
      testType: "single",
      input: { type: "stdin" },
      output: { type: "stdout" },
      languages: {},
    };
  }

  /* ----------------------------------------------------------------- send */

  function sendProblem() {
    if (state.sending) return;
    let problem = null;
    try {
      problem = parseCodeforces();
    } catch (err) {
      notify("CPH: parse error: " + err.message);
      return;
    }
    if (!problem) {
      notify("CPH: unsupported page");
      return;
    }
    if (!problem.tests.length) {
      notify("CPH: no sample tests found on this page");
      return;
    }
    state.sending = true;
    GM_xmlhttpRequest({
      method: "POST",
      url: "http://" + CONFIG.host + ":" + CONFIG.port + "/",
      headers: { "Content-Type": "application/json" },
      data: JSON.stringify(problem),
      timeout: 5000,
      onload: (r) => {
        state.sending = false;
        if (r.status >= 200 && r.status < 300) {
          notify("Sent " + problem.tests.length + " tests to Emacs CPH");
        } else {
          notify("CPH: server error HTTP " + r.status);
        }
      },
      onerror: () => {
        state.sending = false;
        notify("CPH: Emacs unreachable (" + CONFIG.host + ":" + CONFIG.port + ")");
      },
      ontimeout: () => {
        state.sending = false;
        notify("CPH: timed out");
      },
    });
  }

  /* ----------------------------------------------------------------- menu */

  GM_registerMenuCommand("Send problem to Emacs CPH", () => sendProblem());

  // Expose internals for the node test harness and manual debugging.
  globalThis.__CPH_COMPANION__ = {
    CONFIG,
    parseCodeforces,
    sendProblem,
  };
})();
