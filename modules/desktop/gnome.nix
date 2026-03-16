{
  pkgs,
  lib,
  ...
}:

{
  nixpkgs.overlays = [
    (import ../../overlays/gnome-sound-recorder.nix)
    (import ../../overlays/epiphany.nix)
    (import ../../overlays/papers.nix)
  ];

  services.displayManager.gdm.enable = true;
  services.displayManager.gdm.wayland = true;
  services.desktopManager.gnome.enable = true;
  services.desktopManager.gnome.extraGSettingsOverrides = ''
    [org.gnome.mutter]
    experimental-features=['variable-refresh-rate','scale-monitor-framebuffer','xwayland-native-scaling']
  '';

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
    ]
  );

  environment.systemPackages = [
    (pkgs.runCommand "Adwaita-purple-icon-theme" { } ''
      mkdir -p $out/share/icons
      ln -s ${../../assets/icons/Adwaita-purple} $out/share/icons/Adwaita-purple
    '')
    (pkgs.runCommand "Bibata-Modern-Classic-cursor-theme" { } ''
      mkdir -p $out/share/icons
      ln -s ${../../assets/icons/Bibata-Modern-Classic} $out/share/icons/Bibata-Modern-Classic
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
        cursor-theme = "Bibata-Modern-Classic";
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
