{
  pkgs,
  lib,
  ...
}:

{
  services.displayManager.gdm.enable = true;
  services.displayManager.gdm.wayland = true;
  services.desktopManager.gnome.enable = true;
  services.desktopManager.gnome.extraGSettingsOverrides = ''
    [org.gnome.mutter]
    experimental-features=['variable-refresh-rate']
  '';

  nixpkgs.overlays = [
    (
      self: super:
      import ../../overlays/gnome-sound-recorder.nix {
        final = self;
        prev = super;
      }
    )
    (
      self: super:
      import ../../overlays/epiphany-beta.nix {
        final = self;
        prev = super;
      }
    )
  ];

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
      hitori
      iagno
      tali
      totem
      yelp
      gnome-weather
      gnome-software
      showtime
      gnome-console
    ]
  );

  environment.systemPackages = [
    (pkgs.runCommand "Kuromi-cursor" { } ''
      mkdir -p $out/share/icons
      ln -s ${../../assets/icons/Kuromi-cursor} $out/share/icons/Kuromi-cursor
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
        cursor-size = lib.gvariant.mkInt32 48;
        cursor-theme = "Kuromi-cursor";
        text-scaling-factor = 1.5;
        accent-color = "purple";
        color-scheme = "prefer-dark";
      };
    }
  ];
}
