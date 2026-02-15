{
  config,
  pkgs,
  ...
}:

{
  home.username = "lophophora";
  home.homeDirectory = "/home/lophophora";
  home.stateVersion = "25.11";

  imports = [
    ./desktop-files.nix
    ./packages.nix
    ./dconf.nix
    ./programs/ssh.nix
    ./programs/direnv.nix
    ./programs/librewolf.nix
    ./programs/emacs.nix
  ];
}
