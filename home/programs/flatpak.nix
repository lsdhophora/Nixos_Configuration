{ ... }:

{
  services.flatpak = {
    enable = true;
    packages = [
      "org.gnome.gitlab.YaLTeR.VideoTrimmer"
    ];
  };
}
