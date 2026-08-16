#!/usr/bin/env node
// mermaid-ascii: render Mermaid graph language to ASCII/Unicode text.
// Also renders Markdown tables to aligned ASCII box tables.
//
// Uses beautiful-mermaid (the same renderer pi's pi-mermaid extension uses,
// see ~/.pi/agent/npm/node_modules/pi-mermaid/index.ts). Auto-layout means
// output is always aligned — no manual width math, no post-fix tools.
//
// Usage:
//   mermaid-ascii [options] [FILE|-]        render Mermaid source (stdin if -)
//   mermaid-ascii table [FILE|-]            render Markdown table as ASCII box
//
// Mermaid options:
//   -a, --ascii            pure ASCII output (useAscii: true)
//   -x, --padding-x N      horizontal node spacing (default 5)
//   -y, --padding-y N      vertical node spacing (default 5)
//   -b, --box-padding N    box border padding (default 1)
//   -c, --color MODE       none|auto|ansi16|ansi256|truecolor (default none)
//   -m, --markdown         extract all ```mermaid blocks from the input
//   -h, --help             show this help

import { readFileSync } from "node:fs";
import { renderMermaidASCII } from "./dist/index.js";

// ---- CJK/wide character width (East Asian Wide + Fullwidth + emoji) ----
function charWidth(ch) {
  const c = ch.codePointAt(0);
  if (
    (c >= 0x1100 && c <= 0x115f) || // Hangul Jamo
    (c >= 0x2e80 && c <= 0xa4cf) || // CJK Radicals .. Yi
    (c >= 0xac00 && c <= 0xd7a3) || // Hangul Syllables
    (c >= 0xf900 && c <= 0xfaff) || // CJK Compatibility Ideographs
    (c >= 0xfe30 && c <= 0xfe4f) || // CJK Compatibility Forms
    (c >= 0xff00 && c <= 0xff60) || // Fullwidth Forms
    (c >= 0xffe0 && c <= 0xffe6) || // Fullwidth Signs
    (c >= 0x1f300 && c <= 0x1faff) // Emoji
  ) {
    return 2;
  }
  return 1;
}
function displayWidth(s) {
  let w = 0;
  for (const ch of s) w += charWidth(ch);
  return w;
}
function pad(s, width) {
  const w = displayWidth(s);
  return s + " ".repeat(Math.max(0, width - w));
}

// ---- Markdown table -> ASCII box table ----
function renderTable(md) {
  const rows = md
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter(Boolean)
    .map((l) => l.replace(/^\||\|$/g, "").split("|").map((c) => c.trim()));
  if (rows.length < 2) throw new Error("need at least header + separator rows");
  // skip the separator row (|---|), detect alignment from it
  const sep = rows[1];
  const aligns = sep.map((c) =>
    /^\s*:?-{2,}:?\s*$/.test(c)
      ? c.startsWith(":") && c.endsWith(":") ? "center" : c.startsWith(":") ? "left" : c.endsWith(":") ? "right" : "left"
      : "left"
  );
  const body = [rows[0], ...rows.slice(2)];
  const cols = body[0].length;
  const widths = Array.from({ length: cols }, (_, i) =>
    Math.max(...body.map((r) => displayWidth(r[i] ?? "")))
  );
  const border = "+" + widths.map((w) => "-".repeat(w + 2)).join("+") + "+";
  const line = (cells, alignMode = "left") =>
    "| " +
    cells.map((c, i) => {
      const w = displayWidth(c ?? "");
      const gap = widths[i] - w;
      const l = alignMode === "right" ? gap : alignMode === "center" ? Math.floor(gap / 2) : 0;
      return " ".repeat(l) + c + " ".repeat(gap - l);
    }).join(" | ") +
    " |";
  const out = [border, line(body[0], "center")];
  body.slice(1).forEach((r, ri) => out.push(line(r, aligns[ri] ?? "left")));
  out.push(border);
  return out.join("\n");
}

function usage() {
  console.log(`Usage: mermaid-ascii [options] [FILE|-]
       mermaid-ascii table [FILE|-]

Render Mermaid source to ASCII/Unicode text; or render a Markdown table
as an aligned ASCII box table. Reads stdin when FILE is omitted or '-'.

Mermaid options:
  -a, --ascii           pure ASCII output (useAscii: true)
  -x, --padding-x N     horizontal node spacing (default 5)
  -y, --padding-y N     vertical node spacing (default 5)
  -b, --box-padding N   box border padding (default 1)
  -c, --color MODE      none|auto|ansi16|ansi256|truecolor (default none)
  -m, --markdown        extract all \`\`\`mermaid blocks from the input
  -h, --help            show this help`);
}

const argv = process.argv.slice(2);
if (argv[0] === "-h" || argv[0] === "--help") {
  usage();
  process.exit(0);
}
if (argv[0] === "table") {
  const file = argv[1];
  const input = file && file !== "-" ? readFileSync(file, "utf8") : readFileSync(0, "utf8");
  try {
    console.log(renderTable(input));
  } catch (e) {
    console.error(`table render failed: ${e.message}`);
    process.exit(1);
  }
  process.exit(0);
}

const opts = {
  file: null,
  ascii: false,
  paddingX: 5,
  paddingY: 5,
  boxPadding: 1,
  color: "none",
  markdown: false,
};
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  switch (a) {
    case "-a":
    case "--ascii":
      opts.ascii = true;
      break;
    case "-m":
    case "--markdown":
      opts.markdown = true;
      break;
    case "-x":
    case "--padding-x":
      opts.paddingX = parseInt(argv[++i], 10);
      break;
    case "-y":
    case "--padding-y":
      opts.paddingY = parseInt(argv[++i], 10);
      break;
    case "-b":
    case "--box-padding":
      opts.boxPadding = parseInt(argv[++i], 10);
      break;
    case "-c":
    case "--color":
      opts.color = argv[++i];
      break;
    default:
      opts.file = a;
  }
}

const input =
  opts.file && opts.file !== "-"
    ? readFileSync(opts.file, "utf8")
    : readFileSync(0, "utf8");
const sources = opts.markdown
  ? [...input.matchAll(/```mermaid\s*([\s\S]*?)```/g)]
      .map((m) => m[1].trim())
      .filter(Boolean)
  : [input.trim()];
if (sources.length === 0) {
  console.error("no mermaid source found");
  process.exit(2);
}
for (const src of sources) {
  try {
    console.log(
      renderMermaidASCII(src, {
        useAscii: opts.ascii,
        paddingX: opts.paddingX,
        paddingY: opts.paddingY,
        boxBorderPadding: opts.boxPadding,
        colorMode: opts.color,
      }).trimEnd()
    );
    console.log();
  } catch (e) {
    console.error(`render failed: ${e.message}`);
    process.exit(1);
  }
}
