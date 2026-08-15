// Patch pi-tui's matchesKey() to match function keys (F1-F12) under the
// Kitty keyboard protocol.
//
// pi-tui automatically enables the Kitty keyboard protocol when the terminal
// supports it (kitty, ghostty, wezterm, foot, ...). Under that protocol the
// terminal reports function keys in forms that differ from the legacy
// sequences:
//
//   key   legacy (SS3/xterm)         kitty protocol
//   F1    ESC O P / ESC[11~ / ESC[[A  ESC[P           (CSI letter form)
//   F2    ESC O Q / ESC[12~ / ESC[[B  ESC[Q           (CSI letter form)
//   F3    ESC O R / ESC[13~ / ESC[[C  ESC[57366~      (functional # + ~)
//   F4    ESC O S / ESC[14~ / ESC[[D  ESC[S           (CSI letter form)
//   F5+   ESC[15~ ... ESC[24~         same as legacy
//
// (verified empirically: kitty sends ESC[Q for F2 when the protocol is on)
//
// The original matchesKey() only checked the legacy sequences, so extension
// shortcuts on F1-F12 (e.g. the pi-voice-input F2 dictation hotkey) silently
// never fired. This patch:
//   1. adds the kitty CSI-letter forms (ESC[P/Q/S) and F3's functional
//      tilde form to LEGACY_KEY_SEQUENCES,
//   2. adds the kitty functional codepoints (57364-57375) and matches the
//      CSI-u form too, for terminals that encode F-keys that way.
//
// Usage: node patch-kitty-fkeys.mjs <package-out>
//
// The script fails loudly when a pattern does not match. A pi version bump
// that changes the bundled code then breaks the build instead of silently
// producing an unpatched key matcher.
import { readFileSync, writeFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

const root = process.argv[2];
if (!root) {
  console.error("usage: node patch-kitty-fkeys.mjs <package-out>");
  process.exit(1);
}

// Find the bundled pi-tui keys module.
function findKeysJs(dir, depth = 0) {
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
      const found = findKeysJs(p, depth + 1);
      if (found) return found;
    } else if (name === "keys.js" && p.includes(`pi-tui${"/dist"}`)) {
      return p;
    }
  }
  return null;
}

const keysPath = findKeysJs(root);
if (!keysPath) {
  console.error("pi-tui keys.js not found under", root);
  process.exit(1);
}

let src = readFileSync(keysPath, "utf8");

// 1. Add the kitty-protocol forms to LEGACY_KEY_SEQUENCES for F1-F4.
const legacyFrom = `    f1: ["\\x1bOP", "\\x1b[11~", "\\x1b[[A"],
    f2: ["\\x1bOQ", "\\x1b[12~", "\\x1b[[B"],
    f3: ["\\x1bOR", "\\x1b[13~", "\\x1b[[C"],
    f4: ["\\x1bOS", "\\x1b[14~", "\\x1b[[D"],`;
const legacyTo = `    f1: ["\\x1bOP", "\\x1b[11~", "\\x1b[[A", "\\x1b[P"],
    f2: ["\\x1bOQ", "\\x1b[12~", "\\x1b[[B", "\\x1b[Q"],
    f3: ["\\x1bOR", "\\x1b[13~", "\\x1b[[C", "\\x1b[57366~"],
    f4: ["\\x1bOS", "\\x1b[14~", "\\x1b[[D", "\\x1b[S"],`;

// 2. Kitty functional codepoints for F1-F12 (57364-57375). Insert after the
//    FUNCTIONAL_CODEPOINTS block.
const codepointsFrom = `const FUNCTIONAL_CODEPOINTS = {
    delete: -10,
    insert: -11,
    pageUp: -12,
    pageDown: -13,
    home: -14,
    end: -15,
};`;
const codepointsTo = `const FUNCTIONAL_CODEPOINTS = {
    delete: -10,
    insert: -11,
    pageUp: -12,
    pageDown: -13,
    home: -14,
    end: -15,
};
const KITTY_FUNCTION_KEY_CODEPOINTS = {
    f1: 57364,
    f2: 57365,
    f3: 57366,
    f4: 57367,
    f5: 57368,
    f6: 57369,
    f7: 57370,
    f8: 57371,
    f9: 57372,
    f10: 57373,
    f11: 57374,
    f12: 57375,
};`;

// 3. In matchesKey's F1-F12 case, also try the Kitty CSI-u form.
const fkeyFrom = `        case "f12": {
            if (modifier !== 0) {
                return false;
            }
            const functionKey = key;
            return matchesLegacySequence(data, LEGACY_KEY_SEQUENCES[functionKey]);
        }`;
const fkeyTo = `        case "f12": {
            if (modifier !== 0) {
                return false;
            }
            const functionKey = key;
            // Kitty keyboard protocol reports function keys as CSI-u
            // sequences (e.g. F2 = ESC[57365u in some terminals) in
            // addition to the legacy/letter forms. Match both.
            return (
                matchesLegacySequence(data, LEGACY_KEY_SEQUENCES[functionKey]) ||
                matchesKittySequence(data, KITTY_FUNCTION_KEY_CODEPOINTS[functionKey], 0)
            );
        }`;

for (const [from, to, label] of [
  [legacyFrom, legacyTo, "kitty letter forms in LEGACY_KEY_SEQUENCES"],
  [codepointsFrom, codepointsTo, "kitty F-key codepoints"],
  [fkeyFrom, fkeyTo, "matchesKey F1-F12 kitty branch"],
]) {
  if (!src.includes(from)) {
    console.error(`pi-tui patch: ${label} pattern not found`);
    process.exit(1);
  }
  src = src.split(from).join(to);
}

writeFileSync(keysPath, src);
console.log(`patched ${keysPath}`);
