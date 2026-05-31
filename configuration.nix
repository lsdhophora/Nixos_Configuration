{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/boot.nix
    ./modules/networking.nix
    ./modules/desktop/gnome.nix
    ./modules/user.nix
    ./modules/i18n.nix
    ./modules/nix-config.nix
    ./modules/services/cups.nix
    ./modules/services/dae.nix
    ./modules/services/kmscon.nix
    ./modules/services/pipewire.nix
    ./modules/security/age.nix
    ./modules/security/sudo.nix
  ];

  services.logind.settings.Login = {
    HandleLidSwitch = "lock";
    HandleLidSwitchExternalPower = "lock";
    HandleLidSwitchDocked = "lock";
  };

}
