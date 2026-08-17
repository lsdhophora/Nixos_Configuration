// Patch TuiMainScreen so a shrinking buffer never leaves stale rows on screen.
// Usage: node patch-main-screen-viewport.mjs <package-out>
//
// Background: the main-screen renderer tracks the logical line at the top of
// the terminal viewport (prevViewportTop). When the rendered buffer shrinks
// (e.g. markdown reflow collapses lines, or a message is replaced), the
// pinned viewport top must move UP - but terminals cannot scroll backwards.
// The incremental diff then keeps showing the old (lower) window: rows shift
// without a redraw, the tracked viewport top desyncs from the terminal, and
// stale cells remain (for example a leftover caret block from an earlier
// frame sitting in the middle of the output).
//
// The patch detects the desync (pinned viewport top < tracked viewport top)
// and redraws the visible viewport in place after clearing the screen. The
// scrollback above the viewport stays intact.
//
// IMPORTANT: the fallback must NOT fire on growth/append. When the buffer
// grows, the incremental path scrolls the terminal forward naturally, which
// pushes every visible row into the scrollback - nothing is lost. An earlier
// version of this patch also fell back while output was streaming (it keyed
// on "viewport moved" and "writes would scroll"), so it cleared the screen
// and rewrote only the trailing rows every frame, dropping the middle rows
// of the buffer from the visible area ("swallowed" lines).
//
// The script fails loudly when a pattern does not match. A pi version bump
// that changes the bundled code then breaks the build instead of silently
// producing an unpatched renderer.
import { readFileSync, writeFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

const root = process.argv[2];
if (!root) {
  console.error("usage: node patch-main-screen-viewport.mjs <package-out>");
  process.exit(1);
}

// Find the bundled pi-tui main screen renderer.
function findMainScreen(dir, depth = 0) {
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
      const found = findMainScreen(p, depth + 1);
      if (found) return found;
    } else if (name === "tui-main-screen.js" && p.includes(`pi-tui${"/dist"}`)) {
      return p;
    }
  }
  return null;
}

const mainScreenPath = findMainScreen(root);
if (!mainScreenPath) {
  console.error("pi-tui tui-main-screen.js not found under", root);
  process.exit(1);
}

let src = readFileSync(mainScreenPath, "utf8");

// Insert the shrink fallback right after the appendStart computation, before
// the deleted-lines and incremental write paths so both are covered.
const anchor =
  "        const appendStart = appendedLines && firstChanged === this.previousLines.length && firstChanged > 0;\n" +
  "        // No changes - but still need to update hardware cursor position if it moved\n";

const inserted =
  "        const appendStart = appendedLines && firstChanged === this.previousLines.length && firstChanged > 0;\n" +
  "        // Viewport-top desync: the buffer shrank, so the pinned tail now sits\n" +
  "        // above the tracked viewport top. Terminals cannot scroll backwards,\n" +
  "        // so the incremental diff would keep showing the old (lower) window,\n" +
  "        // desyncing the tracked viewport top and leaving stale cells on screen\n" +
  "        // (e.g. a leftover caret block from an earlier frame). Redraw the\n" +
  "        // visible viewport in place; the scrollback above stays intact.\n" +
  "        // NOTE: never fall back on growth/append - there the incremental path\n" +
  "        // scrolls the terminal forward naturally, preserving every row. An\n" +
  "        // earlier version of this patch also fell back during streaming\n" +
  "        // growth, clearing the screen and rewriting only the trailing rows,\n" +
  "        // which dropped the middle rows of the buffer (\"swallowed\" lines).\n" +
  "        const pinnedViewportTop = Math.max(0, newLines.length - height);\n" +
  "        if (pinnedViewportTop < prevViewportTop) {\n" +
  "            logRedraw(\"viewport top moved up (\" + pinnedViewportTop + \" < \" + prevViewportTop + \")\");\n" +
  "            const startRow = pinnedViewportTop;\n" +
  "            const span = Math.min(height, newLines.length - startRow);\n" +
  "            let redraw = \"\\x1b[?2026h\";\n" +
  "            redraw += this.deleteKittyImages(this.previousKittyImageIds);\n" +
  "            redraw += \"\\x1b[2J\\x1b[H\";\n" +
  "            for (let i = 0; i < span; i++) {\n" +
  "                if (i > 0)\n" +
  "                    redraw += \"\\r\\n\";\n" +
  "                const line = newLines[startRow + i];\n" +
  "                const isImage = isImageLine(line);\n" +
  "                const imageReservedRows = isImage ? this.getKittyImageReservedRows(newLines, startRow + i) : 1;\n" +
  "                if (imageReservedRows > 1 && imageReservedRows <= height) {\n" +
  "                    for (let row = 1; row < imageReservedRows; row++)\n" +
  "                        redraw += \"\\r\\n\";\n" +
  "                    redraw += \"\\x1b[\" + (imageReservedRows - 1) + \"A\";\n" +
  "                    redraw += line;\n" +
  "                    redraw += \"\\x1b[\" + (imageReservedRows - 1) + \"B\";\n" +
  "                    i += imageReservedRows - 1;\n" +
  "                    continue;\n" +
  "                }\n" +
  "                redraw += line;\n" +
  "            }\n" +
  "            redraw += \"\\x1b[?2026l\";\n" +
  "            this.terminal.write(redraw);\n" +
  "            this.cursorRow = Math.max(0, startRow + span - 1);\n" +
  "            this.hardwareCursorRow = this.cursorRow;\n" +
  "            this.maxLinesRendered = Math.max(this.maxLinesRendered, newLines.length);\n" +
  "            this.previousViewportTop = startRow;\n" +
  "            this.positionHardwareCursor(cursorPos, newLines.length);\n" +
  "            this.previousLines = newLines;\n" +
  "            this.previousKittyImageIds = this.collectKittyImageIds(newLines);\n" +
  "            this.previousWidth = width;\n" +
  "            this.previousHeight = height;\n" +
  "            return;\n" +
  "        }\n" +
  "        // No changes - but still need to update hardware cursor position if it moved\n";

if (!src.includes(anchor)) {
  console.error("pi-tui patch: viewport fallback anchor not found");
  process.exit(1);
}
src = src.split(anchor).join(inserted);

writeFileSync(mainScreenPath, src);
console.log(`patched ${mainScreenPath}`);
