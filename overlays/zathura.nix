final: prev: {
  zathura = prev.zathura.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [
      ../patches/zathura-print-status-changed.patch
    ];
  });
}
