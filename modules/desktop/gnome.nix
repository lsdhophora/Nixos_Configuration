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
    experimental-features=['scale-monitor-framebuffer', 'xwayland-native-scaling']
  '';

  nixpkgs.overlays = [
    (final: prev: {
      gnome-sound-recorder = prev.gnome-sound-recorder.overrideAttrs (old: {
        postPatch = ''
          chmod +x build-aux/meson_post_install.py
          substituteInPlace build-aux/meson_post_install.py \
            --replace-fail 'gtk-update-icon-cache' 'gtk4-update-icon-cache'
          patchShebangs build-aux/meson_post_install.py
          substituteInPlace data/ui/row.ui \
            --replace-fail emblem-ok-symbolic object-select-symbolic
        '';
      });
    })
  ];

  environment.gnome.excludePackages = (
    with pkgs;
    [
      atomix
      cheese
      geary
      gedit
      epiphany
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
    ]
  );

  environment.systemPackages = [
    (pkgs.runCommand "Kuromi-cursor" { } ''
      mkdir -p $out/share/icons
      ln -s ${../../assets/icons/Kuromi-cursor} $out/share/icons/Kuromi-cursor
    '')
  ];

  programs.dconf.profiles.gdm.databases = [
    {
      settings."org/gnome/desktop/interface" = {
        cursor-size = lib.gvariant.mkInt32 32;
        cursor-theme = "Kuromi-cursor";
        text-scaling-factor = 1.0;
      };
    }
  ];
}
