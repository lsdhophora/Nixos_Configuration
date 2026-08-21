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
// Duplication guard: an in-place redraw keeps the scrollback, but the
// redrawn rows [pinnedViewportTop, prevViewportTop) are already physically
// in the scrollback (the terminal cannot rewind it). The top rows of the new
// viewport then appear twice - once in the scrollback and once on screen.
// A small shift only duplicates the boundary rows, which is the price for
// keeping the scrollback alive during streaming reflow. A large shift would
// duplicate a whole visible chunk, so it falls back to a full redraw that
// clears the scrollback and rebuilds it from the new buffer.
//
// The same duplication accumulates when streaming oscillates: a small shrink
// (in-place redraw) is followed by a small grow, and the normal append path
// then scrolls, pushing the boundary row into the scrollback where it
// already lives. Every shrink/grow cycle adds another copy. To stop this,
// the patch records that the last frame used the in-place redraw; the next
// frame's small grow then also redraws in place instead of scrolling, so the
// oscillation never pollutes the scrollback.
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

// Track that the last frame used the in-place viewport redraw. The next
// frame's small grow then redraws in place too (see below).
const fieldAnchor = "    previousViewportTop = 0;\n";
const fieldInserted =
  "    previousViewportTop = 0;\n" +
  "    // True when the last frame redrew the viewport in place (shrink\n" +
  "    // fallback). The next frame's small grow then also redraws in place\n" +
  "    // instead of scrolling, so the streaming shrink/grow oscillation does\n" +
  "    // not push boundary rows into the scrollback again and again.\n" +
  "    inPlaceViewportRedraw = false;\n";

if (!src.includes(fieldAnchor)) {
  console.error("pi-tui patch: viewport field anchor not found");
  process.exit(1);
}
src = src.split(fieldAnchor).join(fieldInserted);

// Insert the shrink fallback right after the appendStart computation, before
// the deleted-lines and incremental write paths so both are covered.
const anchor =
  "        const appendStart = appendedLines && firstChanged === this.previousLines.length && firstChanged > 0;\n" +
  "        // No changes - but still need to update hardware cursor position if it moved\n";

const inserted = `        const appendStart = appendedLines && firstChanged === this.previousLines.length && firstChanged > 0;
        // Viewport-top desync: the buffer shrank, so the pinned tail now sits
        // above the tracked viewport top. Terminals cannot scroll backwards,
        // so the incremental diff would keep showing the old (lower) window,
        // desyncing the tracked viewport top and leaving stale cells on screen
        // (e.g. a leftover caret block from an earlier frame). Redraw the
        // visible viewport in place; the scrollback above stays intact.
        // NOTE: never fall back on growth/append - there the incremental path
        // scrolls the terminal forward naturally, preserving every row. An
        // earlier version of this patch also fell back during streaming
        // growth, clearing the screen and rewriting only the trailing rows,
        // which dropped the middle rows of the buffer ("swallowed" lines).
        const pinnedViewportTop = Math.max(0, newLines.length - height);
        if (pinnedViewportTop !== prevViewportTop) {
            const viewportShift = pinnedViewportTop - prevViewportTop;
            // Duplication guard: an in-place redraw keeps the scrollback, but
            // the redrawn rows [pinnedViewportTop, prevViewportTop) already
            // live in the scrollback (it cannot be rewound), so the top rows
            // of the new viewport appear twice - on screen and in history.
            // A small shift only duplicates the boundary rows, which is the
            // price for keeping the scrollback alive during streaming reflow.
            // A large shift would duplicate a whole visible chunk; fall back
            // to a full redraw that also clears the scrollback and rebuilds
            // it from the new buffer (no duplicates at all).
            if (viewportShift < -3) {
                logRedraw("viewport top moved up " + (-viewportShift) + " rows - full redraw");
                this.inPlaceViewportRedraw = false;
                fullRender(true);
                return;
            }
            // After an in-place redraw the next frame usually grows again
            // (streaming continues). The normal append path would then scroll,
            // pushing the boundary row into the scrollback - where it already
            // lives - so every shrink/grow cycle adds another copy. Redraw in
            // place for small follow-up growth as well; the oscillation then
            // never pollutes the scrollback. (Large follow-up growth falls
            // through to the incremental path, which scrolls correctly.)
            const followupGrow = this.inPlaceViewportRedraw && viewportShift > 0 && viewportShift <= 3;
            if (viewportShift < 0 || followupGrow) {
                const startRow = pinnedViewportTop;
                const span = Math.min(height, newLines.length - startRow);
                let redraw = "\\x1b[?2026h";
                redraw += this.deleteKittyImages(this.previousKittyImageIds);
                redraw += "\\x1b[2J\\x1b[H";
                for (let i = 0; i < span; i++) {
                    if (i > 0)
                        redraw += "\\r\\n";
                    const line = newLines[startRow + i];
                    const isImage = isImageLine(line);
                    const imageReservedRows = isImage ? this.getKittyImageReservedRows(newLines, startRow + i) : 1;
                    if (imageReservedRows > 1 && imageReservedRows <= height) {
                        for (let row = 1; row < imageReservedRows; row++)
                            redraw += "\\r\\n";
                        redraw += "\\x1b[" + (imageReservedRows - 1) + "A";
                        redraw += line;
                        redraw += "\\x1b[" + (imageReservedRows - 1) + "B";
                        i += imageReservedRows - 1;
                        continue;
                    }
                    redraw += line;
                }
                redraw += "\\x1b[?2026l";
                this.terminal.write(redraw);
                this.cursorRow = Math.max(0, startRow + span - 1);
                this.hardwareCursorRow = this.cursorRow;
                this.maxLinesRendered = Math.max(this.maxLinesRendered, newLines.length);
                this.previousViewportTop = startRow;
                this.positionHardwareCursor(cursorPos, newLines.length);
                this.previousLines = newLines;
                this.previousKittyImageIds = this.collectKittyImageIds(newLines);
                this.previousWidth = width;
                this.previousHeight = height;
                this.inPlaceViewportRedraw = viewportShift < 0;
                return;
            }
            if (this.inPlaceViewportRedraw && viewportShift > 3) {
                // Large growth right after an in-place redraw: let the
                // incremental path scroll normally from now on.
                this.inPlaceViewportRedraw = false;
            }
        }
        // No changes - but still need to update hardware cursor position if it moved
`;

if (!src.includes(anchor)) {
  console.error("pi-tui patch: viewport fallback anchor not found");
  process.exit(1);
}
src = src.split(anchor).join(inserted);

writeFileSync(mainScreenPath, src);
console.log(`patched ${mainScreenPath}`);
