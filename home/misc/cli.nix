{ pkgs, inputs, ... }: {
  home.packages = with pkgs; [
    wl-clipboard
    gh
    lazygit
    at
    nnn
    just
    # Pin the CLI to the flake input revision.
    inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system}.home-manager
  ];
}
