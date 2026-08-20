{ pkgs, repoLib, ... }:
let
  palette = repoLib.kittyPalette;
in
{
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
      font_family = "Iosevka";
      # ①-⑳ / ㉑-㉟ 序号用 CJK 字体渲染（Iosevka 内数字太小）
      "symbol_map U+2460-U+24FF" = "Noto Sans Mono CJK SC";
      "symbol_map U+3251-U+32BF" = "Noto Sans Mono CJK SC";
      font_size = 14.0;
      foreground = palette.foreground;
      background = palette.background;
      color0 = palette.color0;
      color1 = palette.color1;
      color2 = palette.color2;
      color3 = palette.color3;
      color4 = palette.color4;
      color5 = palette.color5;
      color6 = palette.color6;
      color7 = palette.color7;
      color8 = palette.color8;
      color9 = palette.color9;
      color10 = palette.color10;
      color11 = palette.color11;
      color12 = palette.color12;
      color13 = palette.color13;
      color14 = palette.color14;
      color15 = palette.color15;
      confirm_os_window_close = 0;
      placement_strategy = "top-left";
      tab_bar_style = "hidden";
      selection_foreground = palette.selection_foreground;
      selection_background = palette.selection_background;
    };
  };
}
