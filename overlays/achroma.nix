final: prev: {
  gnomeExtensions = prev.gnomeExtensions // {
    achroma = prev.gnomeExtensions.achroma.overrideAttrs (old: {
      patches = (old.patches or []) ++ [
        ./../patches/achroma/achroma.patch
      ];
    });
  };
}
