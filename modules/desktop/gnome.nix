{
  pkgs,
  lib,
  ...
}:

{
  nixpkgs.overlays = [
    (
      final: prev:
      let
        gtk4-beta = prev.gtk4.overrideAttrs (old: {
          version = "4.21.5";
          src = prev.fetchurl {
            url = "https://download.gnome.org/sources/gtk/4.21/gtk-4.21.5.tar.xz";
            hash = "sha256-ZT2g1VahGj57fTbW77ybFkfLJbjoH0DslAvQh4niSBw=";
          };
        });
      in
      {
        # 可选：全局替换 gtk4（推荐，GNOME 其他程序也能用新版）
        gtk4 = gtk4-beta;

        # Epiphany 用新 gtk4 + 新源码
        epiphany =
          (prev.epiphany.override {
            gtk4 = gtk4-beta; # ← 关键：替换依赖，让 pkg-config 找到新版
          }).overrideAttrs
            (old: {
              version = "50.beta";
              src = prev.fetchFromGitLab {
                domain = "gitlab.gnome.org";
                owner = "GNOME";
                repo = "epiphany";
                rev = "50.beta";
                hash = "sha256-lG70GeAsVnBaXzpfQqkUcjQ4dZqXfh+ug0NhvZWobWY=";
              };

              nativeBuildInputs =
                (old.nativeBuildInputs or [ ])
                ++ (with prev; [
                  shared-mime-info # update-mime-database
                  desktop-file-utils # desktop-file-validate
                  glib # glib-compile-schemas 等
                ]);
            });
      }
    )
  ];

  services.displayManager.gdm.enable = true;
  services.displayManager.gdm.wayland = true;
  services.desktopManager.gnome.enable = true;
  services.desktopManager.gnome.extraGSettingsOverrides = ''
    [org.gnome.mutter]
    experimental-features=['variable-refresh-rate']
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
