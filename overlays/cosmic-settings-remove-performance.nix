final: prev: {
  cosmic-settings = prev.cosmic-settings.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ../patches/cosmic-settings/remove-performance.patch
    ];
  });
}
