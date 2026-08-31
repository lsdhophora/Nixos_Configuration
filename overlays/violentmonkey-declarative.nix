final: prev: {
  violentmonkey-declarative = import ../packages/violentmonkey-declarative {
    inherit (final)
      lib
      stdenv
      fetchFromGitHub
      nodejs
      pnpm
      pnpmConfigHook
      zip
      ;
  };
}
