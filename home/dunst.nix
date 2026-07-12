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
        frame_color = "#9141ac";
        separator_color = "#9141ac";
        highlight = "#9141ac";
        timeout = 5;
        icon_theme = "Adwaita-purple";
        fullscreen = "show";
      };
    };
  };
}
