# CPH for Emacs + Tampermonkey

A clone of the **Competitive Programming Helper (CPH)** VSCode extension
for Emacs, paired with a Tampermonkey userscript that replaces the
competitive-companion browser extension.

```
browser userscript (cph.user.js)                Emacs (cph.el)
┌────────────────────────────┐                 ┌──────────────────────────────┐
│ Codeforces / AtCoder /     │   POST problem  │ HTTP server on 127.0.0.1:27121│
│ Luogu / LibreOJ problem    │ ──────────────► │                              │
│ pages (LibreOJ via API)    │                 │                              │
│  · parse sample tests      │   problem JSON  │  · create solution file      │
│  · floating status widget  │   (companion    │  · save .cph/.prob metadata  │
│  · auto-send on page load  │    schema)      │  · open judge buffer         │
│                            │                 │                              │
│  cph-submit compatible:    │   GET + header  │  · compile once               │
│  polls for submit state    │ ──────────────► │  · run all sample tests       │
└────────────────────────────┘   cph-submit:true│  · compare (CPH semantics)   │
                                                │  · diff output, timeout kill │
                                                └──────────────────────────────┘
```

## Research summary: how CPH actually works

Reverse-engineered from the installed bundle
(`divyanshuagrawal.competitive-programming-helper-2077.0.0`):

**1. The companion server is plain HTTP, not WebSocket.**
`setupCompanionServer` runs `http.createServer` on port **27121**. The
request body *is* the problem JSON (competitive-companion schema);
the response body is the submit-state JSON (`{"empty":true}` when
idle). There is no `ws` upgrade anywhere.

**2. Problem JSON schema** (competitive-companion):

```json
{ "name": "A. Theatre Square", "group": "Codeforces",
  "url": "https://codeforces.com/problemset/problem/4/A",
  "interactive": false, "memoryLimit": 256, "timeLimit": 1000,
  "tests": [{ "input": "...", "output": "..." }],
  "testType": "single", "input": {"type": "stdin"}, "output": {"type": "stdout"},
  "languages": {} }
```

**3. On receiving a problem** CPH: picks a language (default pref or
quick pick) → derives the file name from the URL (CF `contest+letter`
e.g. `1234A`, AtCoder `contest+task` e.g. `abc123a`, Luogu problem id)
→ writes the template (with `$CURSOR_PLACEHOLDER`) → saves metadata to
`.cph/.<basename>_<md5-of-srcpath>.prob` → opens the file → fills the
judge webview.

**4. Judging**: compile **once** with `-D DEBUG -D CPH` (+ optional
`-D ONLINE_JUDGE`), then for each test: spawn with input on stdin, kill
after timeout, collect stdout/stderr/exit code. Verdict = fail on
non-zero exit, signal, non-empty stderr (default), or wrong output.
Comparison semantics: normalize CRLF → trim whole → split on `\n` →
same line count and every line trimmed-equal. The webview shows an LCS
line diff (match / changed / extra / missing).

**5. Auto-submit (cph-submit)**: CPH stores `S = {empty, url,
problemName, sourceCode, languageId}`; a request with header
`cph-submit: true` gets `S` back, then `S` resets to `{empty:true}` and
the judge view is told `submit-finished`. Because we mirror this
protocol exactly, **the stock cph-submit browser extension also works
against Emacs** (`M-x cph-store-submit-problem` fills `S`).

## Files

| File | Purpose |
|---|---|
| `cph.el` | Emacs side: HTTP server, problem fetch, judge buffer, compiler/runner |
| `cph.user.js` | Tampermonkey userscript: site parsers + status widget + auto-send |
| `test/` | TDD suite: `./run-tests.sh` (97 assertions, self-contained) |

## Usage

### 1. Emacs

On this machine the module `home/programs/emacs/files.nix` already
symlinks `cph.el` into `~/.config/emacs/cph/` (mkOutOfStoreSymlink), so
the repo edits apply without rebuild.  Standalone setup:

```elisp
(add-to-list 'load-path "/home/lophophora/.config/nixos/home/programs/emacs/cph")
(require 'cph)
;; optional: (setq cph-template-file "~/templates/cpp.cpp")
(cph-enable)          ; starts the server + turns on cph-mode
```

No external packages are required (pure elisp + `json.el`). Emacs ≥ 29.

In the judge buffer (`*cph-judge*`):

| Key | Action |
|---|---|
| `g` | run all testcases (compile once) |
| `p` / `RET` | run the testcase at point |
| `k` | stop running testcases |
| `d` | delete testcase at point |
| `n` | new local problem |
| `c` | toggle `ONLINE_JUDGE` define |
| `s` | open the solution file |
| `q` | quit window |

In a solution buffer (`cph-mode`): `C-c C-r` run all, `C-c C-j` show
judge, `C-c C-s` start server, `C-c C-k` stop.

### 2. Browser

Install `cph.user.js` in Tampermonkey (Dashboard → Utilities → Import
from file). Open a problem page on Codeforces, AtCoder, Luogu or LibreOJ.
Codeforces / AtCoder / Luogu are read from the DOM; LibreOJ is a React
SPA with no statement in the DOM, so the script downloads the problem
from its public API (`api.loj.ac`) and sends it when the widget is
clicked (bottom-right; click again to re-send).  Menu commands:
re-send, change port, toggle auto-send.

The userscript uses `GM_xmlhttpRequest`, which bypasses CORS and
mixed-content blocking, so an HTTPS page can reach the local HTTP
server. The `@connect 127.0.0.1` / `@connect localhost` grants are
already in the header.

## Configuration (cph.el)

| Variable | Default | Meaning |
|---|---|---|
| `cph-port` | 27121 | server port (CPH-compatible) |
| `cph-host` | 127.0.0.1 | listen interface |
| `cph-default-language` | nil | e.g. `"cpp"`; nil = infer/ask |
| `cph-template-file` | nil | template with `$CURSOR_PLACEHOLDER` |
| `cph-timeout` | 3000 | per-test timeout in ms |
| `cph-online-judge` | nil | define `ONLINE_JUDGE` at compile |
| `cph-ignore-stderr` | nil | don't fail tests on non-empty stderr |
| `cph-save-location` | "" | `.prob` directory (default: `.cph/` next to source) |
| `cph-keep-binaries` | nil | keep compiled binaries |

## Supported sites & languages

Sites: Codeforces (problemset/contest/gym), AtCoder (tasks), Luogu
(both `.sample` layouts), LibreOJ (`loj.ac/p/<id>`, problem downloaded
from `api.loj.ac` because the page DOM carries no statement).  Extend
`SITES` in the userscript for more.

Languages: c, cpp/cc/cxx, py, rs, java, go, js, rb, hs. Compilers must
be on `PATH`.

## Known differences vs CPH

- No telemetry, no webview — the judge is a text buffer.
- No custom-checker script support yet.
- stdout/stderr are captured separately; the verdict still fails on
  non-empty stderr unless `cph-ignore-stderr`.
- `.prob` metadata is JSON in a `.cph` dir, byte-compatible with CPH's
  file layout (`.<basename>_<md5>.prob`), but only read by cph.el.
- Auto-submit UI is not built in; `cph-store-submit-problem` + the
  stock cph-submit extension cover the flow.

## Testing (TDD)

```bash
cd test
nix shell nixpkgs#emacs nixpkgs#clang --command ./run-tests.sh
```

Covers: HTTP protocol + response format, file naming rules (CF/AtCoder/
Luogu), `.prob` round trip, comparison semantics, compile-once run-all,
pass/fail/timeout verdicts, cph-submit drain protocol, and the
userscript parsers (node DOM-stub harness).
