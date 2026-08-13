{ pkgs, ... }: {
  home.packages = with pkgs; [
    wl-clipboard
    gh
    lazygit
    at
    nnn
  ];
}
