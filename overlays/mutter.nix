final: prev: {
  mutter = prev.mutter.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/mutter/fix-wayland-overridden-cursor.patch
    ];
  });
}
