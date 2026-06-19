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

  specialisation.cosmic.configuration = {
    services.desktopManager.cosmic.enable = true;
    services.desktopManager.gnome.enable = lib.mkForce false;
    services.displayManager.gdm.enable = lib.mkForce false;
    services.displayManager.cosmic-greeter.enable = lib.mkForce true;
    i18n.inputMethod = lib.mkForce {
      enable = true;
      type = "fcitx5";
      fcitx5.addons = with pkgs; [
        kdePackages.fcitx5-chinese-addons
        fcitx5-gtk
      ];
      fcitx5.waylandFrontend = true;
    };
    xdg.portal = {
      enable = lib.mkForce true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-cosmic
        xdg-desktop-portal-gtk
      ];
      config = lib.mkForce {
        common = {
          default = [ "cosmic" "gnome" "gtk" ];
          "org.freedesktop.impl.portal.Settings" = [ "gnome" ];
          "org.freedesktop.impl.portal.FileChooser" = [ "cosmic" ];
        };
      };
    };
    xdg.terminal-exec = {
      enable = true;
      settings = {
        default = [ "ghostty.desktop" ];
        cosmic = [ "ghostty.desktop" ];
      };
    };
    environment.systemPackages = with pkgs; [
      loupe
      adw-gtk3
      glib.bin
    ];
    home-manager.users.lophophora = {
      gtk.theme = {
        name = "adw-gtk3-dark";
        package = pkgs.adw-gtk3;
      };
      dconf.settings."org/gnome/desktop/interface"."accent-color" = "purple";
      home.sessionVariables = {
        GSETTINGS_SCHEMA_DIR = "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas";
      };
      programs.firefox.package = lib.mkForce pkgs.firefox-no-gtkwrap;
    };
    boot.loader.grub.configurationName = "COSMIC";
  };
}
