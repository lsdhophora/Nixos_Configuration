{ ... }:

{
  services.flatpak = {
    enable = true;
    packages = [
      "org.pitivi.Pitivi"
    ];
    overrides = {
      "org.pitivi.Pitivi".Context = {
        filesystems = [ "xdg-config/fontconfig:ro" ];
      };
    };
  };
}
