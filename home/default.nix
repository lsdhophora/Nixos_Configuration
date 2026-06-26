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
    ./programs/kvantum.nix
    ./programs/firefox.nix
    ./programs/emacs.nix
    ./programs/ghostty.nix
    ./profiles/development.nix
    ./shell/zsh.nix
  ];

  home.packages = with pkgs; [
    tridactyl-native
  ];

}
