final: prev: {
  gtk-nocsd = import ../packages/gtk-nocsd {
    inherit (final) lib stdenv libadwaita pkg-config;
  };
}
