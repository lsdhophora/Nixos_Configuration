// Patch the pi-tui Editor caret to use a light grey background instead of
// terminal reverse video.
// Usage: node patch-editor-cursor.mjs <package-out>
//
// The script fails loudly when a pattern does not match. A pi version bump
// that changes the bundled code then breaks the build instead of silently
// producing an unpatched editor.
import { readFileSync, writeFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

const root = process.argv[2];
if (!root) {
  console.error("usage: node patch-editor-cursor.mjs <package-out>");
  process.exit(1);
}

// Find the bundled pi-tui editor component.
function findEditor(dir, depth = 0) {
  if (depth > 8) return null;
  let entries;
  try {
    entries = readdirSync(dir);
  } catch {
    return null;
  }
  for (const name of entries) {
    const p = join(dir, name);
    let stat;
    try {
      stat = statSync(p);
    } catch {
      continue;
    }
    if (stat.isDirectory()) {
      const found = findEditor(p, depth + 1);
      if (found) return found;
    } else if (name === "editor.js" && p.includes(`pi-tui${"/dist/components"}`)) {
      return p;
    }
  }
  return null;
}

const editorPath = findEditor(root);
if (!editorPath) {
  console.error("pi-tui editor.js not found under", root);
  process.exit(1);
}

let src = readFileSync(editorPath, "utf8");

// Light grey caret background (dim #9aa0a6) with dark glyphs.
// 0x30 = black foreground, 0x48;2;r;g;b sets the background.
const charFrom = "const cursor = `\\x1b[7m${firstGrapheme}\\x1b[0m`;";
const charTo =
  "const cursor = `\\x1b[30m\\x1b[48;2;154;160;166m${firstGrapheme}\\x1b[0m`;";
const spaceFrom = 'const cursor = "\\x1b[7m \\x1b[0m";';
const spaceTo = 'const cursor = "\\x1b[30m\\x1b[48;2;154;160;166m \\x1b[0m";';

for (const [from, to, label] of [
  [charFrom, charTo, "caret on grapheme"],
  [spaceFrom, spaceTo, "caret on space"],
]) {
  if (!src.includes(from)) {
    console.error(`pi-tui patch: ${label} pattern not found`);
    process.exit(1);
  }
  src = src.split(from).join(to);
}

writeFileSync(editorPath, src);
console.log(`patched ${editorPath}`);