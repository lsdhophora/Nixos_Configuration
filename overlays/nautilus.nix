final: prev: {
  nautilus = prev.nautilus.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/nautilus-rename-popover-autohide.patch
    ];
  });
}
