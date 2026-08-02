final: prev: {
  kwin-renumber-desktops = import ../packages/kwin-renumber-desktops {
    inherit (final) lib stdenvNoCC;
  };
}
