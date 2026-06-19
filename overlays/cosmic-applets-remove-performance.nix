final: prev: {
  cosmic-applets = prev.cosmic-applets.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ../patches/cosmic-applets/remove-performance.patch
    ];
  });
}
