{ pkgs, ... }: {
  programs.mpv = {
    enable = true;
    scripts = [ pkgs.mpvScripts.modernz ];

    config = {
      keepaspect-window = true;
      osc = false;
      osd-bar = false;
      osd-font = "IBM Plex Sans";
      osd-font-size = 16;
      osd-color = "#FCFCFC";
      osd-border-color = "#202326";
      osd-border-size = 3.5;
      osd-back-color = "#202326";
      osd-shadow-offset = 0;
      profile = "gpu-hq";
      hwdec = "auto-safe";
      video-sync = "display-resample";
      interpolation = true;
      tscale = "oversample";
      save-position-on-quit = true;
      keep-open = true;
      pause = true;
      screenshot-directory = "~/Pictures/Screenshots/mpv";
      screenshot-template = "%f-[%T]";
      screenshot-format = "png";
    };

    scriptOpts = {
      modernz =
        let
          # Breeze Dark shared palette + modernz-specific accents.
          palette = (import ../../lib).breezeDark // {
            border = "#3D4044";
            handle = "#1D99F3";
            hover = "#5A5D62";
          };
        in
        {
          accent_color = palette.accent;
          osc_color = palette.accent;
          title_color = palette.fg;
          time_color = palette.fg;
          chapter_title_color = palette.fg;
          cache_info_color = palette.inactive;
          side_buttons_color = palette.fg;
          middle_buttons_color = palette.fg;
          playpause_color = palette.fg;
          seekbarfg_color = palette.accent;
          seekbarbg_color = palette.alt;
          seekbar_cache_color = palette.border;
          seek_handle_color = palette.handle;
          seek_handle_border_color = palette.accent;
          nibble_color = palette.accent;
          nibble_current_color = palette.fg;
          hover_effect_color = palette.accent;
          held_element_color = palette.hover;
          thumbnail_box_color = palette.bg;
          thumbnail_box_outline = palette.border;
          window_title_color = palette.fg;
          window_controls_color = palette.fg;
          windowcontrols_close_hover = palette.red;
          windowcontrols_max_hover = palette.orange;
          windowcontrols_min_hover = palette.green;
          volumebar_match_seek_color = true;

          window_controls = "no";
          title_font_size = 28;
          chapter_title_font_size = 20;
          time_font_size = 20;
          tooltip_font_size = 18;
          speed_font_size = 20;
          cache_info_font_size = 16;
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
