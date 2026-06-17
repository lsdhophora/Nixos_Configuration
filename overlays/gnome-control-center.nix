final: prev: {
  gnome-control-center = prev.gnome-control-center.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/gnome-control-center/filter-non-25-percent-scales.patch
      ../patches/gnome-control-center/search-panel-dedup.patch
    ];
  });
}
