{ lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/profiles/core.nix
    ../../modules/desktop/gnome.nix
    ../../modules/profiles/desktop.nix
    ../../modules/profiles/printing.nix
    ../../modules/profiles/proxying.nix
    ../../modules/profiles/kmscon.nix
  ];

  services.logind.settings.Login = {
    HandleLidSwitch = "lock";
    HandleLidSwitchExternalPower = "lock";
    HandleLidSwitchDocked = "lock";
  };


}
