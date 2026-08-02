{ pkgs, ... }: {
  programs.kitty = {
    enable = true;
    package = pkgs.kitty;
    keybindings = {
      # Split panes
      "ctrl+shift+enter" = "launch --location=hsplit";
      "ctrl+shift+backslash" = "launch --location=vsplit";
      # Focus adjacent pane
      "ctrl+shift+h" = "neighboring_window left";
      "ctrl+shift+l" = "neighboring_window right";
      "ctrl+shift+k" = "neighboring_window up";
      "ctrl+shift+j" = "neighboring_window down";
      # Resize panes
      "ctrl+shift+left" = "resize_window narrower";
      "ctrl+shift+right" = "resize_window wider";
      "ctrl+shift+up" = "resize_window taller";
      "ctrl+shift+down" = "resize_window shorter";
      # Close pane
      "ctrl+shift+w" = "close_window";
    };
    settings = {
      enabled_layouts = "splits,stack,tall,fat,grid,horizontal,vertical";
      font_family = "Maple Mono NF CN";
      font_size = 14.0;
      foreground = "#ffffff";
      background = "#1e1e1e";
      color0 = "#171421";
      color1 = "#c01c28";
      color2 = "#26a269";
      color3 = "#a2734c";
      color4 = "#12488b";
      color5 = "#a347ba";
      color6 = "#2aa1b3";
      color7 = "#d0cfcc";
      color8 = "#5e5c64";
      color9 = "#f66151";
      color10 = "#33d17a";
      color11 = "#e9ad0c";
      color12 = "#2a7bde";
      color13 = "#c061cb";
      color14 = "#33c7de";
      color15 = "#ffffff";
      confirm_os_window_close = 0;
      placement_strategy = "top-left";
      tab_bar_style = "hidden";
      selection_foreground = "#ffffff";
      selection_background = "#3a4b6b";
    };
  };
}
