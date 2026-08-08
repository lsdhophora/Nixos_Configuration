let
  applyPatches = (import ../lib).applyPatches;
in
final: prev: {
  kitty = applyPatches [
    ../patches/kitty/kitty-remove-resize-text.patch
    ../patches/kitty/kitty-fix-panel-position.patch
    ../patches/kitty/kitty-remember-maximized-state.patch
  ] prev.kitty;
}
