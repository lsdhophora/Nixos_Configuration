{
  pkgs,
  lib,
  ...
}:

{
  nixpkgs.overlays = [
    (import ../../overlays/gnome-sound-recorder.nix)
    (import ../../overlays/gnome-control-center.nix)
    (import ../../overlays/gnome-shell.nix)
    (import ../../overlays/gnome-calendar.nix)
    (import ../../overlays/evolution-data-server.nix)
    (import ../../overlays/nautilus.nix)
    (import ../../overlays/mutter.nix)
    (final: prev: {
      loupe = prev.loupe.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace src/widgets/image_window.ui \
            --replace-fail "info-outline-symbolic" "view-more-symbolic"
        '';
      });
    })
  ];

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
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
    (pkgs.runCommand "Kuromi-wallpapers" { } ''
      mkdir -p $out/share/backgrounds/gnome
      mkdir -p $out/share/gnome-background-properties
      cp -r ${../../assets/Kuromi-Wallpapers}/* $out/share/backgrounds/gnome/
      cp ${../../assets/Kuromi-Wallpapers}/*.xml $out/share/gnome-background-properties/
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
