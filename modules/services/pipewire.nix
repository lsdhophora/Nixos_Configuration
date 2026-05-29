{
  pkgs,
  lib,
  ...
}:

{
  services.pipewire = {
    enable = lib.mkDefault true;
    package = lib.mkDefault pkgs.pipewire;
    wireplumber.enable = lib.mkDefault true;
    pulse.enable = lib.mkDefault true;
  };

  services.pipewire.wireplumber.extraConfig."99-disable-suspend" = {
    "monitor.alsa.rules" = [
      {
        matches = [
          { "node.name" = "~alsa_input.*"; }
          { "node.name" = "~alsa_output.*"; }
        ];
        actions = {
          update-props = {
            "session.suspend-timeout-seconds" = 0;
          };
        };
      }
    ];
  };
}
