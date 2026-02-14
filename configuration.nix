{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/boot.nix
    ./modules/networking.nix
    ./modules/desktop/gnome.nix
    ./modules/user.nix
    ./modules/i18n.nix
    ./modules/nix.nix
    ./modules/shell/zsh.nix
    ./modules/services/dae.nix
    ./modules/security/age.nix
  ];
}
