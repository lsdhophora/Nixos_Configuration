// Patch TuiMainScreen so incremental diffs never leave stale rows on screen.
// Usage: node patch-main-screen-viewport.mjs <package-out>
//
// Background: the main-screen renderer writes only the changed lines. When
// content grows past the bottom of the viewport the terminal scrolls, and
// when content shrinks the tracked viewport top no longer matches. In both
// cases rows shift on screen without a redraw, so stale cells remain (for
// example a leftover caret block from an earlier frame).
//
// The patch detects both cases and falls back to redrawing the whole
// visible viewport. The terminal scrollback stays intact.
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

// Hoist renderEnd, then add a viewport-consistency fallback before the
// incremental write path. The fallback redraws the visible span when the
// tracked viewport top does not match the end-pinned layout, or when the
// changed span extends below the previous viewport bottom (the writes would
// scroll the terminal and leave the rows above stale).
const blockFrom =
  "        const prevViewportBottom = prevViewportTop + height - 1;\n" +
  "        const moveTargetRow = appendStart ? firstChanged - 1 : firstChanged;\n" +
  "        if (moveTargetRow > prevViewportBottom) {";

const blockTo =
  "        const prevViewportBottom = prevViewportTop + height - 1;\n" +
  "        const renderEnd = Math.min(lastChanged, newLines.length - 1);\n" +
  "        // The viewport is pinned to the end of content. Incremental writes\n" +
  "        // are safe only when they start inside the previous viewport and\n" +
  "        // stay within its bounds. Otherwise rows shift on screen without a\n" +
  "        // redraw and stale cells remain, for example a leftover caret block\n" +
  "        // from an earlier frame. Redraw the visible viewport instead.\n" +
  "        const pinnedViewportTop = Math.max(0, newLines.length - height);\n" +
  "        const viewportMoved = pinnedViewportTop !== prevViewportTop;\n" +
  "        const writesScroll = renderEnd > prevViewportBottom;\n" +
  "        if ((viewportMoved || writesScroll) && !appendStart) {\n" +
  "            const startRow = pinnedViewportTop;\n" +
  "            const span = Math.min(height, newLines.length - startRow);\n" +
  "            let redraw = \"\\x1b[?2026h\";\n" +
  "            redraw += this.deleteKittyImages(this.previousKittyImageIds);\n" +
  "            redraw += \"\\x1b[2J\\x1b[H\";\n" +
  "            for (let i = 0; i < span; i++) {\n" +
  "                if (i > 0)\n" +
  "                    redraw += \"\\r\\n\";\n" +
  "                redraw += newLines[startRow + i];\n" +
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
  "        const moveTargetRow = appendStart ? firstChanged - 1 : firstChanged;\n" +
  "        if (moveTargetRow > prevViewportBottom) {";

// Remove the renderEnd declaration that the block above hoists.
const renderEndFrom =
  "        // Only render changed lines (firstChanged to lastChanged), not all lines to end\n" +
  "        // This reduces flicker when only a single line changes (e.g., spinner animation)\n" +
  "        const renderEnd = Math.min(lastChanged, newLines.length - 1);\n" +
  "        for (let i = firstChanged; i <= renderEnd; i++) {";

const renderEndTo =
  "        // Only render changed lines (firstChanged to lastChanged), not all lines to end\n" +
  "        // This reduces flicker when only a single line changes (e.g., spinner animation)\n" +
  "        for (let i = firstChanged; i <= renderEnd; i++) {";

for (const [from, to, label] of [
  [blockFrom, blockTo, "viewport fallback"],
  [renderEndFrom, renderEndTo, "hoisted renderEnd"],
]) {
  if (!src.includes(from)) {
    console.error(`pi-tui patch: ${label} pattern not found`);
    process.exit(1);
  }
  src = src.split(from).join(to);
}

writeFileSync(mainScreenPath, src);
console.log(`patched ${mainScreenPath}`);
