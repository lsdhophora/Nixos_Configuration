// Patch pi-tui's matchesKey() to match function keys (F1-F12) encoded as
// Kitty keyboard-protocol CSI-u sequences.
//
// pi-tui automatically enables the Kitty keyboard protocol when the terminal
// supports it (kitty, ghostty, wezterm, foot, ...). Under that protocol the
// terminal reports function keys with the kitty functional codepoints
// (F2 = ESC[57365u) instead of the legacy sequences (F2 = ESC O Q /
// ESC[12~). The original matchesKey() only checked the legacy sequences, so
// extension shortcuts on F1-F12 (e.g. the pi-voice-input F2 dictation
// hotkey) silently never fired.
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

// 1. Kitty functional codepoints for F1-F12 (per the Kitty keyboard protocol:
//    57364-57375 = F1-F12). Insert after the FUNCTIONAL_CODEPOINTS block.
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

// 2. In matchesKey's F1-F12 case, also try the Kitty CSI-u form.
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
            // sequences (e.g. F2 = ESC[57365u). Match both the legacy
            // sequences and the kitty codepoint so extension shortcuts
            // on F1-F12 work in kitty/ghostty/wezterm/etc.
            return (
                matchesLegacySequence(data, LEGACY_KEY_SEQUENCES[functionKey]) ||
                matchesKittySequence(data, KITTY_FUNCTION_KEY_CODEPOINTS[functionKey], 0)
            );
        }`;

for (const [from, to, label] of [
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
