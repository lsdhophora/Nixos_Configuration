final: prev: {
  cosmic-launcher = prev.cosmic-launcher.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ../patches/cosmic-launcher/strip-source-label.patch
      ../patches/cosmic-launcher/remove-category-icon.patch
      ../patches/cosmic-launcher/mute-icon-to-speaker.patch
    ];
  });
}
