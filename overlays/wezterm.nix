# Clamp terminal selection boundaries to full (wide) grapheme cells.
#
# The terminal screen buffer is a cell grid; a wide character (CJK
# ideograph, emoji) occupies two cells: a leading cell holding the text
# and a trailing continuation cell. WezTerm's mouse selection is
# cell-granular, so dragging can leave a selection boundary inside a wide
# character, highlighting (and copying) only half of it.
#
# This patch mirrors kitty's xrange_for_iteration_with_multicells: the
# selection range is clamped to whole cells wherever it is applied
# (rendering the highlight and extracting text), so a wide character is
# always selected as a unit.
#
# Report the Wayland IME cursor rectangle from input paths only (key
# events, preedit changes, focus), mirroring kitty. WezTerm used to
# commit the text-input cursor rectangle on every repaint; a TUI that
# streams output (for example pi) then makes the IME candidate window
# chase the moving cursor and jitter. Input-driven updates keep the
# candidate window at the preedit while output scrolls past it.
{ repoLib }: final: prev: {
  wezterm = repoLib.applyPatches [
    ../patches/wezterm/selection-grapheme-clamp.patch
    ../patches/wezterm/ime-cursor-follows-input.patch
  ] prev.wezterm;
}
