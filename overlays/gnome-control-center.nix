final: prev: {
  gnome-control-center = prev.gnome-control-center.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/gnome-filter-non-25-percent-scales.patch
    ];
  });
}
