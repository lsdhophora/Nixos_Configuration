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
      modernz = {

        accent_color = "#3DAEE9";
        osc_color = "#3DAEE9";
        title_color = "#FCFCFC";
        time_color = "#FCFCFC";
        chapter_title_color = "#FCFCFC";
        cache_info_color = "#A1A9B1";
        side_buttons_color = "#FCFCFC";
        middle_buttons_color = "#FCFCFC";
        playpause_color = "#FCFCFC";
        seekbarfg_color = "#3DAEE9";
        seekbarbg_color = "#292C30";
        seekbar_cache_color = "#3D4044";
        seek_handle_color = "#1D99F3";
        seek_handle_border_color = "#3DAEE9";
        nibble_color = "#3DAEE9";
        nibble_current_color = "#FCFCFC";
        hover_effect_color = "#3DAEE9";
        held_element_color = "#5A5D62";
        thumbnail_box_color = "#202326";
        thumbnail_box_outline = "#3D4044";
        window_title_color = "#FCFCFC";
        window_controls_color = "#FCFCFC";
        windowcontrols_close_hover = "#DA4453";
        windowcontrols_max_hover = "#F67400";
        windowcontrols_min_hover = "#27AE60";
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
