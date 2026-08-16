// Display width helpers used across the vendored ASCII pipeline.
// CJK / Fullwidth / Wide code points occupy 2 terminal cells while
// JS String#length counts UTF-16 code units, so any layout math that
// assumed `.length === columns` was wrong for non-ASCII text.
//
// Box-drawing chars are EAW=Ambiguous; we render them as single-width
// because every existing layout in the pipeline already assumes 1 cell
// for them (so `ambiguousAsWide: false`).
//
// Editor-font quirk (Iosevka 34.4.0, as configured for VSCodium and the
// terminal): the symbol blocks below are drawn at FULL width (2 cells) —
// arrows (→↔↓), geometric shapes (►◇▼), misc symbols (★☑✓), enclosed
// alphanumerics (①②), em dash (—) etc. — while ASCII, box drawing
// (U+2500-257F) and math operators (±×÷√≤≥) stay 1 cell. Without these
// ranges, any table/figure line containing such a glyph comes out one
// cell short per glyph and the box borders no longer line up.
import { eastAsianWidth } from 'get-east-asian-width';
const SYMBOL_WIDE = [
    [0x2014, 0x2015], // em dash, horizontal bar
    [0x2026, 0x2026], // horizontal ellipsis …
    [0x2030, 0x2030], // per mille ‰
    [0x2190, 0x21ff], // arrows ← ↑ → ↓ ↔ ⇄ ⇒ …
    [0x2211, 0x2211], // n-ary summation ∑
    [0x221e, 0x221e], // infinity ∞
    [0x2460, 0x24ff], // enclosed alphanumerics ① ② … ⑳
    [0x25a0, 0x27bf], // geometric shapes ■ □ ◆ ◇ ▲ ▼ ► … dingbats ✓ ✗ ★
    [0x2b00, 0x2bff], // misc symbols and arrows ⬤ ⬛ ⬜
];
export function isSymbolWide(cp) {
    for (const [lo, hi] of SYMBOL_WIDE) {
        if (cp >= lo && cp <= hi)
            return true;
    }
    return false;
}
export function charWidth(ch) {
    const cp = ch.codePointAt(0);
    if (cp === undefined)
        return 1;
    const w = eastAsianWidth(cp, { ambiguousAsWide: false });
    if (w === 2)
        return 2;
    return isSymbolWide(cp) ? 2 : 1;
}
export function isWide(codePoint) {
    return eastAsianWidth(codePoint, { ambiguousAsWide: false }) === 2 || isSymbolWide(codePoint);
}
/** Terminal display width of a string (CJK chars count as 2). */
export function displayWidth(s) {
    let w = 0;
    for (const ch of s)
        w += charWidth(ch);
    return w;
}
/**
 * Iterate code points with their display widths.
 * Wraps `for…of` so callers can advance their cursors using the cell width.
 */
export function* iterCells(s) {
    for (const ch of s)
        yield { ch, width: charWidth(ch) };
}
//# sourceMappingURL=width.js.map
