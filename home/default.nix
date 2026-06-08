{
  ...
}:

{
  home.username = "lophophora";
  home.homeDirectory = "/home/lophophora";
  home.stateVersion = "25.05";

  imports = [
    ./avatar.nix
    ./gtk.nix
    ./housekeeping.nix
    ./packages.nix
    ./dconf.nix
    ./programs/kvantum.nix
    ./programs/firefox.nix
    ./programs/emacs.nix
    ./programs/ghostty.nix
    ./profiles/gaming.nix
    ./profiles/development.nix
    ./profiles/shell.nix
  ];
}
