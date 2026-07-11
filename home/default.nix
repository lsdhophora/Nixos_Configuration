{ pkgs, ... }:

{
  home.username = "lophophora";
  home.homeDirectory = "/home/lophophora";
  home.stateVersion = "25.05";

  imports = [
    ./avatar.nix
    ./housekeeping.nix
    ./gui.nix
    ./cli.nix
    ./dconf.nix
    ./packages.nix
    ./gtk.nix
    ./dunst.nix
    ./mime.nix
    ./sway-config.nix
    ./session.nix
    ./programs/kitty.nix
    ./programs/kvantum.nix
    ./programs/firefox.nix
    ./programs/emacs.nix
    ./programs/tmux.nix
    ./programs/zathura.nix
    ./programs/swayimg.nix
    ./programs/mpv.nix
    ./profiles/development.nix
    ./shell/zsh.nix
  ];

}
