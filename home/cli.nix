{ pkgs, ... }: {
  home.packages = with pkgs; [
    tmux
    wl-clipboard
    gh
  ];
}
