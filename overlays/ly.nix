final: prev: {
  ly = prev.ly.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/ly/remove-arrows.patch
      ../patches/ly/suppress-startup-messages.patch
    ];
  });
}
