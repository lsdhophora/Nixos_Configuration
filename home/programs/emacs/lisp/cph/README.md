# CPH for Emacs (Codeforces only)

A minimal clone of the **Competitive Programming Helper (CPH)**
VSCode extension for Emacs.  It supports Codeforces only and does
three things: download the problem samples, run them locally, and
debug a sample under lldb.

It borrows the wire design of the VSCode CPH plugin:

* the browser userscript extracts the problem from the page,
* the problem JSON follows the competitive-companion schema,
* the server listens on the CPH default port `127.0.0.1:27121`.

There is no submit flow and no `ONLINE_JUDGE` handling.

## Files

| File | Purpose |
|---|---|
| `cph.el` | Emacs side: HTTP server, solution file, judge buffer |
| `cph.user.js` | Browser userscript: Codeforces parser + send widget |
| `test/` | Test suite: `./run-tests.sh` |

## How it works

```
browser userscript (cph.user.js)           Emacs (cph.el)
  Codeforces problem page                   HTTP server on 127.0.0.1:27121
  Violentmonkey menu command                creates <code>.cpp
  "Send problem to Emacs CPH"  POST JSON --> saves .cph/.prob metadata
                                             opens the source + judge buffer
                                             g: compile once, run samples
```

On a Codeforces problem page, pick "Send problem to Emacs CPH" from
the Violentmonkey menu.  There is no on-page widget, no auto-send and
no retry; a failed send only reports a notification.

## Usage

### 1. Emacs

On this machine `home/programs/emacs/files.nix` symlinks `cph.el`
into `~/.config/emacs/cph/` (out-of-store), so repo edits apply
without a rebuild.  `init.el` loads it and starts the server.

Standalone setup:

```elisp
(add-to-list 'load-path "/path/to/this/dir")
(require 'cph)
(cph-enable)   ; start the problem-fetch server
```

No external packages are required (pure elisp + `json.el`).
Emacs >= 29.

In the judge buffer (`*cph-judge*`):

| Key | Action |
|---|---|
| `g` | run all testcases (compile once) |
| `p` / `RET` | run the testcase at point |
| `d` | debug the testcase at point with lldb |
| `k` | stop running testcases |
| `s` | open the solution file |
| `q` | quit window |

In a solution buffer (`cph-mode`): `C-c C-r` run all, `C-c C-j` show
judge, `C-c C-s` start server, `C-c C-k` stop.

### 2. Browser

On this machine `lib/firefox-policies.nix` injects `cph.user.js`
into the managed Violentmonkey of Firefox and LibreWolf.  An OS
rebuild and a browser restart apply the script.

For any other browser, install `cph.user.js` in Tampermonkey or
Violentmonkey (Dashboard -> Utilities -> Import from file), then open
a Codeforces problem page and pick "Send problem to Emacs CPH" from
the userscript menu.

The userscript uses `GM_xmlhttpRequest`, which bypasses CORS, so the
HTTPS page can reach the local HTTP server.  The `@connect
127.0.0.1` / `@connect localhost` grants are in the header.

## Configuration (cph.el)

| Variable | Default | Meaning |
|---|---|---|
| `cph-port` | 27121 | server port (CPH-compatible) |
| `cph-host` | 127.0.0.1 | listen interface |
| `cph-default-language` | "cpp" | solution language (c, cpp, rs, js) |
| `cph-save-location` | "" | directory for new files; empty = current file dir |
| `cph-template-file` | nil | template with `$CURSOR_PLACEHOLDER` |
| `cph-timeout` | 3000 | per-test timeout in ms |
| `cph-keep-binaries` | nil | keep compiled binaries |

Solution files are named like the CF short code (contest code plus
letter, for example `1234A.cpp`).  Metadata lives in a `.cph`
directory next to the source (`.<basename>_<md5>.prob`), so a problem
can be re-run after Emacs restarts.

## Comparison semantics

Mirror CPH: normalize CRLF, trim the whole output, split on newlines,
then require equal line counts and equal trimmed lines.  A test fails
on timeout, signal, non-zero exit, non-empty stderr, or wrong output.

## Debugging with lldb

Place the cursor on a testcase in the judge buffer and press `d`.
The solution compiles with `-g` (optimization off), the testcase
input is redirected from a temp file, and an interactive lldb session
starts in the `*cph-lldb*` buffer.  lldb stops at `main`; set more
breakpoints, then step and inspect.

lldb comes from `home/packages.nix` and matches the clang version.
Only compiled languages (c, cpp, rs) can be debugged.

## Supported languages

c, cpp (clang++), rs (rustc), js (node).  Compilers must be on PATH.
lldb debugs c, cpp, and rs solutions.

## Testing (TDD)

```bash
cd test
./run-tests.sh    # or: nix shell nixpkgs#emacs nixpkgs#clang --command ./run-tests.sh
```

Covers: HTTP end-to-end fetch, comparison semantics, compile-once
run-all, pass/fail/timeout verdicts, filename rules, `.prob` round
trip, and the userscript (node DOM-stub harness).
