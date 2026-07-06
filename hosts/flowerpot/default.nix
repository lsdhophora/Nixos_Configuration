{ lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/profiles/core.nix
    ../../modules/profiles/desktop.nix
    ../../modules/profiles/printing.nix
    ../../modules/profiles/proxying.nix
    ../../modules/profiles/kmscon.nix
    ../../modules/desktop/sway.nix
    ../../modules/services/tlp.nix
  ];

  services.logind.settings.Login = {
    HandleLidSwitch = "lock";
    HandleLidSwitchExternalPower = "lock";
    HandleLidSwitchDocked = "lock";
  };

}
