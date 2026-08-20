{ repoLib }: final: prev: {
  kitty = repoLib.applyPatches [
    ../patches/kitty/kitty-remove-resize-text.patch
    ../patches/kitty/kitty-fix-panel-position.patch
    ../patches/kitty/kitty-remember-maximized-state.patch
    ../patches/kitty/kitty-force-circled-double-width.patch
  ] prev.kitty;
}
