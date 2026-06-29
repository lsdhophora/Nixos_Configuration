final: prev: {
  gnomeExtensions = prev.gnomeExtensions // {
    just-perfection = prev.gnomeExtensions.just-perfection.overrideAttrs (oldAttrs: {
      patches = (oldAttrs.patches or []) ++ [
        ./../patches/just-perfection/session-modes.patch
      ];
    });
  };
}
