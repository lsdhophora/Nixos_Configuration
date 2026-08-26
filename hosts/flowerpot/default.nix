{ pkgs, ... }:

{
  # ============================================================
  #  Host configuration menu.
  #  Enable or disable modules here (comment out to disable).
  # ============================================================
  imports = [
    ./hardware-configuration.nix

    # ---- Core (always enabled) ----
    ../../modules/boot.nix
    ../../modules/persistence.nix
    ../../modules/networking.nix
    ../../modules/i18n.nix
    ../../modules/nix-config.nix
    ../../modules/user.nix

    # ---- Security ----
    ../../modules/security/sops.nix
    ../../modules/security/sudo.nix

    # ---- Services ----
    ../../modules/services/zram.nix
    ../../modules/services/atd.nix
    ../../modules/services/pipewire.nix
    ../../modules/services/tlp.nix
    ../../modules/services/cups.nix
    ../../modules/services/dae.nix
    ../../modules/services/openssh.nix
    ../../modules/services/zerotier.nix

    # ---- Desktop ----
    ../../modules/desktop/kde.nix
  ];

  # ---- X11 support (required for Plasma X11 session) ----
  services.xserver.enable = true;
  services.xserver.excludePackages = [ pkgs.xterm ];

  # Write generated xorg.conf with ModulePath entries to /etc/X11/xorg.conf.
  # plasma-login-manager does not pass -config to the X server, so the X server
  # must find the module paths (libinput, evdev) via this file.
  services.xserver.exportConfiguration = true;

  # ---- Host-specific settings ----
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };

}
