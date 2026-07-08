final: prev: {
  kitty = prev.kitty.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/kitty/kitty-remove-resize-text.patch
    ];
  });
}
