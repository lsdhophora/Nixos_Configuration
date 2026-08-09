final: prev: {
  jetbrains-maple-mono = import ../packages/jetbrains-maple-mono {
    inherit (final) lib stdenvNoCC fetchzip;
  };
}
