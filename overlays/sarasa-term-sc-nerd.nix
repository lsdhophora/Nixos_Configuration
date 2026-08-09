final: prev: {
  sarasa-term-sc-nerd = import ../packages/sarasa-term-sc-nerd {
    inherit (final) lib stdenvNoCC fetchzip;
  };
}
