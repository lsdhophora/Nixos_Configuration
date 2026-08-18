{ pkgs, inputs, ... }: {
  home.packages = with pkgs; [
    wl-clipboard
    gh
    lazygit
    at
    nnn
    # Pin the CLI to the flake input revision.
    inputs.home-manager.packages.${pkgs.system}.home-manager
  ];
}
