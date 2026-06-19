final: prev: {
  cosmic-osd = prev.cosmic-osd.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ../patches/cosmic-osd/startup-mute-grace-period.patch
    ];
  });
}
