{
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./gnome/overlays.nix
  ];

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  i18n.inputMethod = {
    enable = true;
    type = "ibus";
    ibus.engines = with pkgs.ibus-engines; [ rime ];
  };
  services.desktopManager.gnome.extraGSettingsOverrides = ''
    [org.gnome.mutter]
    experimental-features=['scale-monitor-framebuffer','xwayland-native-scaling']
  '';

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
    ];
    config = {
      common = {
        default = [ "gnome" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gnome" ];
      };
    };
  };

  environment.gnome.excludePackages = (
    with pkgs;
    [
      atomix
      cheese
      geary
      gedit
      gnome-characters
      gnome-tour
      gnome-photos
      epiphany
      hitori
      iagno
      tali
      totem
      yelp
      gnome-weather
      gnome-software
      showtime
       gnome-console
       gnome-contacts
     ]
  );

  environment.systemPackages = [
    (pkgs.runCommand "Adwaita-purple-icon-theme" { } ''
      mkdir -p $out/share/icons
      ln -s ${../../assets/icons/Adwaita-purple} $out/share/icons/Adwaita-purple
    '')
    (pkgs.runCommand "Cosmic-wallpapers" { } ''
      mkdir -p $out/share/backgrounds/gnome
      mkdir -p $out/share/gnome-background-properties
      cp -r ${../../assets/Cosmic-Wallpapers}/*.jpg $out/share/backgrounds/gnome/
      cp ${../../assets/Cosmic-Wallpapers}/*.xml $out/share/gnome-background-properties/
    '')
  ];

  programs.dconf.profiles.gdm.databases = [
    {
      settings."org/gnome/desktop/interface" = {
        cursor-theme = "Adwaita";
        cursor-size = lib.gvariant.mkInt32 24;
        text-scaling-factor = 1.20;
        accent-color = "purple";
        color-scheme = "prefer-dark";
        icon-theme = "Adwaita-purple";
      };
      settings."org/gnome/desktop/a11y" = {
        always-show-universal-access-status = false;
      };
      settings."org/gnome/mutter" = {
        experimental-features = [
          "scale-monitor-framebuffer"
          "xwayland-native-scaling"
        ];
      };
    }
  ];
}
