// Patch the pi-tui Editor to render a "> " prompt before the input text.
// Usage: node patch-editor-prompt.mjs <package-out>
//
// The script fails loudly when a pattern does not match. A pi version bump
// that changes the bundled code then breaks the build instead of silently
// producing an unpatched editor.
import { readFileSync, writeFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

const root = process.argv[2];
if (!root) {
  console.error("usage: node patch-editor-prompt.mjs <package-out>");
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

// Reserve 2 columns for the prompt in the layout, so wrapping and cursor
// navigation stay aligned. The box width stays unchanged.
const layoutFrom =
  "        const contentWidth = Math.max(1, width - paddingX * 2);\n" +
  "        // Layout width: with padding the cursor can overflow into it,\n" +
  "        // without padding we reserve 1 column for the cursor.\n" +
  "        const layoutWidth = Math.max(1, contentWidth - (paddingX ? 0 : 1));\n" +
  "        // Store for cursor navigation (must match wrapping width)\n" +
  "        this.lastWidth = layoutWidth;\n" +
  "        const horizontal = this.borderColor(\"─\");\n" +
  "        // Layout the text\n" +
  "        const layoutLines = this.layoutText(layoutWidth);";

const layoutTo =
  "        const contentWidth = Math.max(1, width - paddingX * 2);\n" +
  "        // Layout width: with padding the cursor can overflow into it,\n" +
  "        // without padding we reserve 1 column for the cursor.\n" +
  "        // The \"> \" input prompt reserves 2 more columns.\n" +
  "        const PROMPT = \"> \";\n" +
  "        const promptWidth = visibleWidth(PROMPT);\n" +
  "        const layoutWidth = Math.max(1 + promptWidth, contentWidth - (paddingX ? 0 : 1));\n" +
  "        const textLayoutWidth = layoutWidth - promptWidth;\n" +
  "        // Store for cursor navigation (must match wrapping width)\n" +
  "        this.lastWidth = textLayoutWidth;\n" +
  "        const horizontal = this.borderColor(\"─\");\n" +
  "        // Layout the text\n" +
  "        const layoutLines = this.layoutText(textLayoutWidth);";

// Prepend the prompt to the first layout line and offset the cursor.
const lineFrom =
  "        for (const layoutLine of visibleLines) {\n" +
  "            let displayText = layoutLine.text;\n" +
  "            let lineVisibleWidth = visibleWidth(layoutLine.text);\n" +
  "            let cursorInPadding = false;\n" +
  "            // Add cursor if this line has it\n" +
  "            if (layoutLine.hasCursor && layoutLine.cursorPos !== undefined) {\n" +
  "                const before = displayText.slice(0, layoutLine.cursorPos);\n" +
  "                const after = displayText.slice(layoutLine.cursorPos);";

const lineTo =
  "        for (const layoutLine of visibleLines) {\n" +
  "            let displayText = layoutLine.text;\n" +
  "            let lineVisibleWidth = visibleWidth(layoutLine.text);\n" +
  "            let cursorInPadding = false;\n" +
  "            // Input prompt: prepend \"> \" to the first layout line.\n" +
  "            const isFirstLine = layoutLine === layoutLines[0];\n" +
  "            if (isFirstLine) {\n" +
  "                displayText = PROMPT + displayText;\n" +
  "                lineVisibleWidth += promptWidth;\n" +
  "            }\n" +
  "            // Add cursor if this line has it\n" +
  "            if (layoutLine.hasCursor && layoutLine.cursorPos !== undefined) {\n" +
  "                const cursorPos = layoutLine.cursorPos + (isFirstLine ? promptWidth : 0);\n" +
  "                const before = displayText.slice(0, cursorPos);\n" +
  "                const after = displayText.slice(cursorPos);";

for (const [from, to, label] of [
  [layoutFrom, layoutTo, "layout"],
  [lineFrom, lineTo, "render line"],
]) {
  if (!src.includes(from)) {
    console.error(`pi-tui patch: ${label} pattern not found`);
    process.exit(1);
  }
  src = src.split(from).join(to);
}

writeFileSync(editorPath, src);
console.log(`patched ${editorPath}`);
