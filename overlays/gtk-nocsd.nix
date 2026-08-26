final: prev: {
  gtk-nocsd = import ../packages/gtk-nocsd {
    inherit (final)
      lib
      stdenv
      glib
      libadwaita
      libhandy
      pkg-config
      ;
  };
}
