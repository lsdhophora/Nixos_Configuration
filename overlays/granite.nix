final: prev: {
  pantheon = prev.pantheon // {
    granite7 = prev.pantheon.granite7.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        ../patches/granite/fallback-accent-color.patch
      ];
    });
  };
}
