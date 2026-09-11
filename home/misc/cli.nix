{
  pkgs,
  inputs,
  repoLib,
  ...
}:
{
  home.packages = with pkgs; [
    wl-clipboard
    gh
    lazygit
    at
    nnn
    just
    # Pin the CLI to the flake input revision.
    inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system}.home-manager
    # Agent multiplexer that lives in the terminal. The pinned nixos-26.05
    # channel has no herdr package. Take the package from nixpkgs-unstable.
    (repoLib.unstablePkgs inputs pkgs).herdr
  ];
}
