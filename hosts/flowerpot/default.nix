{ lib, pkgs, ... }:

{
  # ============================================================
  #  Host configuration menu.
  #  Enable or disable modules here (comment out to disable).
  # ============================================================
  imports = [
    ./hardware-configuration.nix

    # ---- Core (always enabled) ----
    ../../modules/boot.nix
    ../../modules/networking.nix
    ../../modules/i18n.nix
    ../../modules/nix-config.nix
    ../../modules/user.nix

    # ---- Security ----
    ../../modules/security/age.nix
    ../../modules/security/sudo.nix

    # ---- Services ----
    ../../modules/services/zram.nix
    ../../modules/services/atd.nix
    ../../modules/services/pipewire.nix
    ../../modules/services/tlp.nix
    ../../modules/services/cups.nix
    ../../modules/services/dae.nix
    # ../../modules/services/kmscon.nix  # conflicts with plasma-login-manager VT handling

    # ---- Desktop ----
    ../../modules/desktop/kde.nix
  ];

  # ---- Host-specific settings ----
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.logind.settings.Login = {
    HandleLidSwitch = "lock";
    HandleLidSwitchExternalPower = "lock";
    HandleLidSwitchDocked = "lock";
  };

}
