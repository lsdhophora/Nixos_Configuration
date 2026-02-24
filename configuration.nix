{
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
    ./modules/nix-config.nix
    ./modules/services/dae.nix
    ./modules/services/pipewire.nix
    ./modules/shell/elvish.nix
    ./modules/security/age.nix
  ];
}
