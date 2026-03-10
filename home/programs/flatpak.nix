{ ... }:

{
  services.flatpak = {
    enable = true;
    packages = [
      "org.gnome.gitlab.YaLTeR.VideoTrimmer"
    ];
    overrides = {
      "org.gnome.gitlab.YaLTeR.VideoTrimmer".Context = {
        filesystems = [ "xdg-config/fontconfig:ro" ];
      };
    };
  };
}
