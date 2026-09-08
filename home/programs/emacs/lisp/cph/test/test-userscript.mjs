// test-userscript.mjs --- DOM-stub harness for cph.user.js (Codeforces only)
// Usage: node test-userscript.mjs
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
    this.readyState = "complete";
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
const commands = {};
const notifications = [];
globalThis.document = new Node("document");
globalThis.location = { hostname: "", href: "" };
globalThis.window = globalThis;
globalThis.GM_registerMenuCommand = (title, fn) => { commands[title] = fn; };
globalThis.GM_notification = (opts) => { notifications.push(opts.text); };
globalThis.GM_xmlhttpRequest = (opts) => {
  captured.push(opts);
  if (opts.onload) opts.onload({ status: 200, responseText: '{"status":"ok"}' });
};
globalThis.alert = () => {};

const body = (globalThis.document.body = new Node("body"));
globalThis.document.appendChild(body);
const reset = () => {
  body.children.length = 0;
  body.byId = {};
  captured.length = 0;
  notifications.length = 0;
};

/* ---------------- Codeforces fixture ---------------- */

function cfPage() {
  return el("div", { class: "problem-statement" },
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
  );
}

/* ---------------- load the userscript on a CF problem page ---------------- */

reset();
body.appendChild(cfPage());
globalThis.location = { hostname: "codeforces.com", href: "https://codeforces.com/problemset/problem/4/A" };

eval(readFileSync(new URL("../cph.user.js", import.meta.url), "utf8"));
const C = globalThis.__CPH_COMPANION__;

assertT("menu command registered", typeof commands["Send problem to Emacs CPH"] === "function");
assertT("no POST at load", captured.length === 0);
assertT("no on-page widget", !body.getElementById("cph-emacs-widget"));

/* ---------------- menu command: manual POST ---------------- */

commands["Send problem to Emacs CPH"]();
assertT("manual POST sent", captured.length === 1 && captured[0].method === "POST");
assertT("manual POST url", captured[0].url === "http://127.0.0.1:27121/");
const sentData = JSON.parse(captured[0].data);
assertT("manual POST payload name", sentData.name === "A. Theatre Square");
assertT("manual POST payload group", sentData.group === "Codeforces");
assertT("manual POST payload url", sentData.url === "https://codeforces.com/problemset/problem/4/A");
assertT("manual POST payload tests", sentData.tests.length === 2);
assertT("manual POST payload timeLimit", sentData.timeLimit === 1000);
assertT("manual POST payload memoryLimit", sentData.memoryLimit === 256);
assertT("manual POST schema fields",
  sentData.testType === "single" && sentData.input.type === "stdin" && sentData.output.type === "stdout");
assertT("success notification", notifications.includes("Sent 2 tests to Emacs CPH"));

/* ---------------- parser (direct) ---------------- */

const cf = C.parseCodeforces();
assertT("cf parsed", !!cf);
assertT("cf name", cf.name === "A. Theatre Square");
assertT("cf 2 tests", cf.tests.length === 2);
assertT("cf test1 input", cf.tests[0].input === "6 6 4");
assertT("cf test1 output", cf.tests[0].output === "4");

/* ---------------- no samples: report, do not POST ---------------- */

reset();
body.appendChild(
  el("div", { class: "problem-statement" },
    el("div", { class: "header" }, el("div", { class: "title" }, txt("C. Empty"))),
  ),
);
globalThis.location = { hostname: "codeforces.com", href: "https://codeforces.com/problemset/problem/1/C" };
C.sendProblem();
assertT("no POST for sample-less page", captured.length === 0);
assertT("no-samples notification", notifications.includes("CPH: no sample tests found on this page"));

/* ---------------- unsupported page ---------------- */

reset();
body.appendChild(el("div", {}, txt("nothing")));
globalThis.location = { hostname: "example.com", href: "https://example.com/" };
assertT("unsupported page parses to null", C.parseCodeforces() === null);
C.sendProblem();
assertT("no POST for unsupported page", captured.length === 0);
assertT("unsupported notification", notifications.includes("CPH: unsupported page"));

/* ---------------- failure does NOT auto-retry ---------------- */

reset();
body.appendChild(cfPage());
globalThis.location = { hostname: "codeforces.com", href: "https://codeforces.com/problemset/problem/4/A" };
globalThis.GM_xmlhttpRequest = (opts) => {
  captured.push(opts);
  opts.onerror(); // server down
};
C.sendProblem();
assertT("failed send posts once", captured.length === 1);
assertT("failure notification", notifications.some((n) => n.includes("Emacs unreachable")));

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

(async () => {
  await sleep(2500);
  assertT("no auto retry after failure", captured.length === 1);
  console.log(failures === 0 ? "ALL USERSCRIPT TESTS PASS" : `USERSCRIPT FAILURES: ${failures}`);
  process.exit(failures === 0 ? 0 : 1);
})();
