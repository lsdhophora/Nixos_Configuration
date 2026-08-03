final: prev: {
  mpvScripts = prev.mpvScripts // {
    modernz = prev.mpvScripts.modernz.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        ../patches/modernz/remove-text-bord.patch
      ];
    });
  };
}
