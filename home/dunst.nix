{ ... }: {
  services.dunst = {
    enable = true;
    settings = {
      global = {
        monitor = 0;
        width = 300;
        offset = "10x50";
        origin = "top-right";
        font = "IBM Plex Sans 14";
        corner_radius = 0;
        background = "#1a1a1a";
        foreground = "#cccccc";

        fullscreen = "show";
      };
      urgency_low = {
        timeout = 10;
      };
      urgency_normal = {
        timeout = 5;
      };
      urgency_critical = {
        timeout = 0;
      };
    };
  };
}
