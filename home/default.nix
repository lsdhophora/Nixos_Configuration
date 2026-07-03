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
    ./rime.nix
    ./programs/kvantum.nix
    ./programs/firefox.nix
    ./programs/emacs.nix
    ./programs/ghostty.nix
    ./programs/tmux.nix
    ./profiles/development.nix
    ./shell/zsh.nix
  ];

}
