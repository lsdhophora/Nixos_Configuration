{
  pkgs,
  inputs,
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
    # channel has no herdr package, so overlays/herdr.nix takes it from
    # nixpkgs-unstable and patches the client raw-mode ordering.
    herdr
  ];
}
