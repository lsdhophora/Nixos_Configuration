// test-userscript.mjs --- DOM-stub harness for the cph.user.js parsers
// Usage: node test-userscript.mjs (with the script's @match sites stubbed)
import { readFileSync } from "node:fs";

let failures = 0;
function assertT(label, cond) {
  if (cond) console.log(`PASS: ${label}`);
  else { failures++; console.log(`FAIL: ${label}`); }
}

/* ---------------- minimal DOM stub ---------------- */

class Node {
  constructor(tag, attrs = {}, children = []) {
    this.tag = tag;
    this.attrs = attrs;
    this.children = children;
    this.parent = null;
    this.listeners = {};
    this.byId = {};
    this.style = {};
    for (const c of children) {
      if (typeof c !== "string") {
        c.parent = this;
        if (c.attrs.id) this.byId[c.attrs.id] = c;
      }
    }
  }
  get textContent() {
    return this.children.map((c) => (typeof c === "string" ? c : c.textContent)).join("");
  }
  set textContent(s) {
    this.children = [String(s)];
  }
  get id() {
    return this.attrs.id;
  }
  set id(v) {
    this.attrs.id = v;
  }
  appendChild(child) {
    child.parent = this;
    this.children.push(child);
    if (child.attrs.id) this.byId[child.attrs.id] = child;
    return child;
  }
  addEventListener(type, fn) { (this.listeners[type] ||= []).push(fn); }
  getElementById(id) {
    const walk = (n) => {
      if (n.attrs.id === id) return n;
      for (const c of n.children) {
        if (typeof c !== "string") {
          const r = walk(c);
          if (r) return r;
        }
      }
      return null;
    };
    return walk(this);
  }
  createElement(tag) { return new Node(tag); }
  compoundMatch(comp) {
    let rest = comp;
    const tm = rest.match(/^[a-z0-9-]+/i);
    if (tm) {
      if (this.tag !== tm[0]) return false;
      rest = rest.slice(tm[0].length);
    }
    const classes = [...rest.matchAll(/\.([a-zA-Z0-9_-]+)/g)].map((m) => m[1]);
    const idm = rest.match(/#([a-zA-Z0-9_-]+)/);
    const elClasses = (this.attrs.class || "").split(/\s+/).filter(Boolean);
    for (const c of classes) if (!elClasses.includes(c)) return false;
    if (idm && this.attrs.id !== idm[1]) return false;
    return true;
  }
  matchSel(parts) {
    let idx = parts.length - 1;
    if (!this.compoundMatch(parts[idx])) return false;
    idx--;
    let cur = this.parent;
    while (idx >= 0) {
      while (cur && !cur.compoundMatch(parts[idx])) cur = cur.parent;
      if (!cur) return false;
      idx--;
      cur = cur.parent;
    }
    return true;
  }
  querySelectorAll(sel) {
    const out = [];
    // Support comma-separated selector groups, e.g. ".a, .b".
    for (const group of sel.split(",")) {
      const parts = group.trim().split(/\s+/);
      const walk = (n) => {
        if (n.tag && n.matchSel(parts)) out.push(n);
        for (const c of n.children) if (typeof c !== "string") walk(c);
      };
      walk(this);
    }
    return out;
  }
  querySelector(sel) { return this.querySelectorAll(sel)[0] || null; }
}

const el = (tag, attrs = {}, ...children) => new Node(tag, attrs, children);
const txt = (s) => s;

/* ---------------- globals ---------------- */

const captured = [];
globalThis.document = new Node("document");
globalThis.location = { hostname: "", href: "" };
globalThis.GM_getValue = (k, d) => d;
globalThis.GM_setValue = () => {};
globalThis.GM_registerMenuCommand = () => {};
globalThis.GM_xmlhttpRequest = (opts) => {
  captured.push(opts);
  if (opts.onload) opts.onload({ status: 200, responseText: '{"empty":true}' });
};
globalThis.alert = () => {};
globalThis.prompt = () => null;
globalThis.window = globalThis;

const body = (globalThis.document.body = new Node("body"));
globalThis.document.appendChild(body);
const reset = () => {
  body.children.length = 0;
  body.byId = {};
  captured.length = 0;
};

/* ---------------- Codeforces (built before eval: auto-send fires) ---------------- */

body.appendChild(
  el("div", { class: "problem-statement" },
    el("div", { class: "header" },
      el("div", { class: "title" }, txt("A. Theatre Square")),
      el("div", { class: "time-limit" }, txt("time limit per test: 1 second")),
      el("div", { class: "memory-limit" }, txt("memory limit per test: 256 megabytes")),
    ),
    el("div", { class: "sample-tests" },
      el("div", { class: "sample-test" },
        el("div", { class: "input" }, el("pre", {}, txt("\n6 6 4"))),
        el("div", { class: "output" }, el("pre", {}, txt("\n4"))),
      ),
      el("div", { class: "sample-test" },
        el("div", { class: "input" }, el("pre", {}, txt("\n2 2 2"))),
        el("div", { class: "output" }, el("pre", {}, txt("\n1"))),
      ),
    ),
  ),
);
globalThis.location = { hostname: "codeforces.com", href: "https://codeforces.com/problemset/problem/4/A" };

eval(readFileSync(new URL("../cph.user.js", import.meta.url), "utf8"));
const C = globalThis.__CPH_COMPANION__;

// no auto-send at load: the + button must be clicked manually
assertT("no auto POST at load", captured.length === 0);

// clicking the + widget sends the CF problem
const widget = body.getElementById("cph-emacs-widget");
assertT("widget exists", !!widget);
widget.listeners.click[0]();
assertT("manual POST sent", captured.length === 1 && captured[0].method === "POST");
assertT("manual POST url", captured[0].url === "http://127.0.0.1:27121/");
const sentData = JSON.parse(captured[0].data);
assertT("manual POST payload name", sentData.name === "A. Theatre Square");
assertT("manual POST payload tests", sentData.tests.length === 2);
assertT("widget has + button", !!body.getElementById("cph-emacs-plus"));

/* ---------------- Codeforces parser (direct) ---------------- */

const cf = C.parseCodeforces();
assertT("cf parsed", !!cf);
assertT("cf name", cf.name === "A. Theatre Square");
assertT("cf url", cf.url === "https://codeforces.com/problemset/problem/4/A");
assertT("cf timeLimit", cf.timeLimit === 1000);
assertT("cf memoryLimit", cf.memoryLimit === 256);
assertT("cf interactive false", cf.interactive === false);
assertT("cf 2 tests", cf.tests.length === 2);
assertT("cf test1 input", cf.tests[0].input === "6 6 4");
assertT("cf test1 output", cf.tests[0].output === "4");
assertT("cf schema fields", cf.testType === "single" && cf.input.type === "stdin" && cf.output.type === "stdout");

/* ---------------- AtCoder ---------------- */

// Real AtCoder task pages: the title is a .h2 span (no <h1>) with a
// trailing "Editorial" link, and limits use MiB.
reset();
body.appendChild(
  el("div", { id: "main-container" },
    el("div", { class: "contest-title" }, txt("AtCoder Beginners Selection")),
    el("span", { class: "h2" },
      txt("\n\t\t\tA - Welcome to AtCoder\n\t\t\t"),
      el("a", { class: "btn" }, txt("Editorial")),
      txt("\n\t\t"),
    ),
    el("div", { id: "task-statement" },
      el("div", { class: "part" }, el("section", {},
        el("h3", {}, txt("Problem Statement")),
        el("p", {}, txt("Time Limit: 2 sec / Memory Limit: 1024 MiB")),
      )),
      el("div", { class: "part" }, el("section", {},
        el("h3", {}, txt("Sample Input 1")),
        el("pre", {}, txt("\n1 2 3")),
      )),
      el("div", { class: "part" }, el("section", {},
        el("h3", {}, txt("Sample Output 1")),
        el("pre", {}, txt("\n6")),
        el("p", {}, txt("Explanation text after the sample.")),
      )),
    ),
  ),
);
globalThis.location = { hostname: "atcoder.jp", href: "https://atcoder.jp/contests/abs/tasks/abc087_b" };
const ac = C.parseAtCoder();
assertT("atcoder parsed", !!ac);
assertT("atcoder name", ac.name === "A - Welcome to AtCoder");
assertT("atcoder group", ac.group === "AtCoder Beginners Selection");
assertT("atcoder timeLimit", ac.timeLimit === 2000);
assertT("atcoder memoryLimit", ac.memoryLimit === 1024);
assertT("atcoder 1 test", ac.tests.length === 1);
assertT("atcoder test input", ac.tests[0].input === "1 2 3");
assertT("atcoder test output", ac.tests[0].output === "6");

/* ---------------- Luogu (two-pre layout) ---------------- */

reset();
body.appendChild(
  el("div", { id: "app" },
    el("h1", {}, txt("P1001 A+B Problem")),
    el("div", { class: "statistic" },
      txt("时间限制 1s / 内存限制 128MB"),
    ),
    el("div", { class: "sample" },
      el("pre", {}, txt("\n1 2")),
      el("pre", {}, txt("\n3")),
    ),
  ),
);
globalThis.location = { hostname: "www.luogu.com.cn", href: "https://www.luogu.com.cn/problem/P1001" };
const lg = C.parseLuogu();
assertT("luogu parsed", !!lg);
assertT("luogu name", lg.name === "P1001 A+B Problem");
assertT("luogu timeLimit", lg.timeLimit === 1000);
assertT("luogu memoryLimit", lg.memoryLimit === 128);
assertT("luogu 1 test", lg.tests.length === 1);
assertT("luogu test input", lg.tests[0].input === "1 2");
assertT("luogu test output", lg.tests[0].output === "3");

/* ---------------- Luogu (single-pre layout) ---------------- */

reset();
body.appendChild(
  el("div", { id: "app" },
    el("h1", {}, txt("P1001 A+B Problem")),
    el("h3", {}, txt("输入 #1")),
    el("div", { class: "sample" }, el("pre", {}, txt("\n1 2"))),
    el("h3", {}, txt("输出 #1")),
    el("div", { class: "sample" }, el("pre", {}, txt("\n3"))),
    el("h3", {}, txt("输入 #2")),
    el("div", { class: "sample" }, el("pre", {}, txt("\n100 200"))),
    el("h3", {}, txt("输出 #2")),
    el("div", { class: "sample" }, el("pre", {}, txt("\n300"))),
  ),
);
const lg2 = C.parseLuogu();
assertT("luogu2 2 tests", lg2.tests.length === 2);
assertT("luogu2 test2", lg2.tests[1].input === "100 200" && lg2.tests[1].output === "300");

/* ---------------- unsupported / no samples ---------------- */

reset();
body.appendChild(el("div", {}, txt("nothing")));
globalThis.location = { hostname: "example.com", href: "https://example.com/" };
assertT("unsupported site returns null", C.parseCodeforces() === null && C.parseAtCoder() === null && C.parseLuogu() === null);

/* ---------------- manual only: failure does NOT retry ---------------- */

// Rebuild a Codeforces page; a failed click must NOT auto-retry.
reset();
captured.length = 0;
body.appendChild(
  el("div", { class: "problem-statement" },
    el("div", { class: "header" },
      el("div", { class: "title" }, txt("B. Problem")),
      el("div", { class: "time-limit" }, txt("time limit per test: 2 seconds")),
      el("div", { class: "memory-limit" }, txt("memory limit per test: 256 megabytes")),
    ),
    el("div", { class: "sample-tests" },
      el("div", { class: "sample-test" },
        el("div", { class: "input" }, el("pre", {}, txt("\n1"))),
        el("div", { class: "output" }, el("pre", {}, txt("\n1"))),
      ),
    ),
  ),
);
globalThis.location = { hostname: "codeforces.com", href: "https://codeforces.com/problemset/problem/1/B" };

globalThis.GM_xmlhttpRequest = (opts) => {
  captured.push(opts);
  opts.onerror(); // server down: report failure, no retry
};

C.maybeAutoSend(); // prepares the widget, never sends
const w2 = body.getElementById("cph-emacs-widget");
w2.listeners.click[0](); // failed manual click
assertT("failed click sends once", captured.length === 1);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

(async () => {
  // Delayed part of the manual-only flow: nothing may auto-retry.
  await sleep(2500);
  assertT("no auto retry after failure", captured.length === 1);
  const w = body.getElementById("cph-emacs-widget");
  assertT("widget at bottom-left", !!w && /left:12px/.test(w.style.cssText) && !/right:12px/.test(w.style.cssText));

  /* ---------------- LibreOJ: direct API download (SPA, no DOM) ---------- */

  const lojFixture = () => ({
    meta: { id: 1, displayId: 1, type: "Traditional", locales: ["zh_CN", "en_US"], isPublic: true },
    localizedContentsOfLocale: { locale: "zh_CN", title: "A + B 问题" },
    samples: [{ inputData: "1 2", outputData: "3" }],
    judgeInfo: { timeLimit: 2000, memoryLimit: 512, runSamples: true },
    submittable: true,
  });

  let apiCalls = [];
  const routeGM = (apiResponse) => {
    globalThis.GM_xmlhttpRequest = (opts) => {
      if (/api\.loj\.ac/.test(opts.url)) {
        apiCalls.push(opts);
        opts.onload({ status: 200, responseText: JSON.stringify(apiResponse()) });
      } else {
        captured.push(opts);
        opts.onload({ status: 200, responseText: '{"empty":true}' });
      }
    };
  };

  // parseLibreOJ returns a Promise that resolves to the companion schema.
  reset();
  captured.length = 0;
  apiCalls = [];
  globalThis.location = { hostname: "loj.ac", href: "https://loj.ac/p/1", pathname: "/p/1", search: "" };
  routeGM(lojFixture);
  const loj = await C.parseLibreOJ();
  assertT("loj parsed", !!loj);
  assertT("loj api POST", apiCalls.length === 1 && apiCalls[0].method === "POST");
  assertT("loj api url", apiCalls[0].url === "https://api.loj.ac/api/problem/getProblem");
  const lojReq = JSON.parse(apiCalls[0].data);
  assertT("loj api displayId", lojReq.displayId === 1);
  assertT("loj api asks samples+judgeInfo", lojReq.samples === true && lojReq.judgeInfo === true);
  assertT("loj name", loj.name === "A + B 问题");
  assertT("loj group", loj.group === "LibreOJ");
  assertT("loj url", loj.url === "https://loj.ac/p/1");
  assertT("loj limits", loj.timeLimit === 2000 && loj.memoryLimit === 512);
  assertT("loj 1 test", loj.tests.length === 1);
  assertT("loj test io", loj.tests[0].input === "1 2" && loj.tests[0].output === "3");
  assertT("loj no localhost POST from parse", captured.length === 0);

  // Non-problem LibreOJ pages (e.g. the home page) parse to null.
  reset();
  captured.length = 0;
  apiCalls = [];
  globalThis.location = { hostname: "loj.ac", href: "https://loj.ac/", pathname: "/", search: "" };
  assertT("loj home null", (await C.parseLibreOJ()) === null);

  // Full flow: widget click downloads from api.loj.ac, then POSTs to Emacs.
  reset();
  captured.length = 0;
  apiCalls = [];
  globalThis.location = { hostname: "loj.ac", href: "https://loj.ac/p/3", pathname: "/p/3", search: "" };
  routeGM(() => ({ ...lojFixture(), meta: { ...lojFixture().meta, displayId: 3 } }));
  C.maybeAutoSend();
  body.getElementById("cph-emacs-widget").listeners.click[0]();
  await sleep(20);
  assertT("loj click POSTs once to Emacs", captured.length === 1);
  assertT("loj click POST url", captured[0].url === "http://127.0.0.1:27121/");
  const lojSent = JSON.parse(captured[0].data);
  assertT("loj sent name", lojSent.name === "A + B 问题");
  assertT("loj sent group", lojSent.group === "LibreOJ");
  assertT("loj sent 1 test", lojSent.tests.length === 1);

  // API failure (e.g. a non-public problem) reports and sends nothing.
  reset();
  captured.length = 0;
  apiCalls = [];
  globalThis.location = { hostname: "loj.ac", href: "https://loj.ac/p/1000", pathname: "/p/1000", search: "" };
  globalThis.GM_xmlhttpRequest = (opts) => {
    if (/api\.loj\.ac/.test(opts.url)) {
      apiCalls.push(opts);
      opts.onload({ status: 403, responseText: '{"error":"PERMISSION_DENIED"}' });
    } else {
      captured.push(opts);
    }
  };
  C.maybeAutoSend();
  body.getElementById("cph-emacs-widget").listeners.click[0]();
  await sleep(20);
  assertT("loj api error POSTs nothing", captured.length === 0);

  console.log(failures === 0 ? "ALL USERScript TESTS PASS" : `USERScript FAILURES: ${failures}`);
  process.exit(failures === 0 ? 0 : 1);
})();
