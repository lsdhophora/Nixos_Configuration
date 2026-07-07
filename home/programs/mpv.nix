{ pkgs, ... }: {
  programs.mpv = {
    enable = true;
    scripts = [ pkgs.mpvScripts.modernz ];

    config = {
      border = false;
      keepaspect-window = true;
      osc = false;
      osd-bar = false;
      osd-font = "IBM Plex Sans";
      osd-font-size = 12;
      profile = "gpu-hq";
      hwdec = "auto-safe";
      video-sync = "display-resample";
      interpolation = true;
      tscale = "oversample";
      save-position-on-quit = true;
      keep-open = true;
      screenshot-directory = "~/Pictures/Screenshots/mpv";
      screenshot-template = "%f-[%T]";
      screenshot-format = "png";
    };

    scriptOpts = {
      modernz = {
        hover_effect_color = "#9141ac";
        seekbarfg_color = "#9141ac";
        seek_handle_color = "#77358d";
        seek_handle_border_color = "#9141ac";
        nibble_color = "#9141ac";
      };
    };

    bindings = {
      RIGHT = "seek 5";
      LEFT = "seek -5";
      UP = "add volume 2";
      DOWN = "add volume -2";
      "[" = "add speed 0.1";
      "]" = "add speed -0.1";
      "\\" = "set speed 1.0";
      SPACE = "cycle pause";
      ">" = "playlist-next";
      "<" = "playlist-prev";
      q = "quit";
      Q = "quit-watch-later";
    };
  };
}
