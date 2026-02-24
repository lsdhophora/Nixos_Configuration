{
  ...
}:

{
  home.username = "lophophora";
  home.homeDirectory = "/home/lophophora";
  home.stateVersion = "25.05";

  imports = [
    ./avatar.nix
    ./housekeeping.nix
    ./packages.nix
    ./dconf.nix
    ./programs/git.nix
    ./programs/ssh.nix
    ./programs/direnv.nix
    ./programs/librewolf.nix
    ./programs/emacs.nix
    ./shell/elvish.nix
  ];
}
