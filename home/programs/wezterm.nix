{ repoLib, lib, ... }:
let
  palette = repoLib.weztermPalette;
  # Breeze Light 16 色 (ansi/brights) 从 repoLib 调色板派生，保持单一来源。
  breezeLight = {
    foreground = palette.foreground;
    background = palette.background;
    cursor_bg = palette.foreground;
    cursor_fg = palette.background;
    cursor_border = palette.foreground;
    selection_bg = palette.selection_background;
    selection_fg = palette.selection_foreground;
    ansi = [
      palette.color0
      palette.color1
      palette.color2
      palette.color3
      palette.color4
      palette.color5
      palette.color6
      palette.color7
    ];
    brights = [
      palette.color8
      palette.color9
      palette.color10
      palette.color11
      palette.color12
      palette.color13
      palette.color14
      palette.color15
    ];
  };
in
{
  programs.wezterm = {
    enable = true;
    # 需要时在 wezterm 中运行 wezterm ssh / imgcat 等（注入 wezterm.sh）。
    enableZshIntegration = true;

    # 自定义配色：写入 ~/.config/wezterm/colors/Breeze Light.toml，
    # 由 settings.color_scheme 引用。
    colorSchemes."Breeze Light" = breezeLight;

    settings = {
      color_scheme = "Breeze Light";
      font_size = 14.0;
      # Iosevka 不含 CJK 字形，回退到 Noto Sans Mono CJK SC。
      font = lib.generators.mkLuaInline ''
        wezterm.font_with_fallback({ "Iosevka", "Noto Sans Mono CJK SC" })
      '';
      hide_tab_bar_if_only_one_tab = true;
      window_close_confirmation = "NeverPrompt";

      # 与 kitty 一致的键位（launch hsplit/vsplit、neighboring_window、
      # resize_window、close_window）。
      keys = lib.generators.mkLuaInline ''
        {
          { key = "Enter",     mods = "CTRL|SHIFT", action = wezterm.action.SplitHorizontal { domain = "CurrentPaneDomain" } },
          { key = "\\",        mods = "CTRL|SHIFT", action = wezterm.action.SplitVertical { domain = "CurrentPaneDomain" } },
          { key = "h",         mods = "CTRL|SHIFT", action = wezterm.action.ActivatePaneDirection "Left" },
          { key = "l",         mods = "CTRL|SHIFT", action = wezterm.action.ActivatePaneDirection "Right" },
          { key = "k",         mods = "CTRL|SHIFT", action = wezterm.action.ActivatePaneDirection "Up" },
          { key = "j",         mods = "CTRL|SHIFT", action = wezterm.action.ActivatePaneDirection "Down" },
          { key = "LeftArrow", mods = "CTRL|SHIFT", action = wezterm.action.AdjustPaneSize { "Left", 1 } },
          { key = "RightArrow", mods = "CTRL|SHIFT", action = wezterm.action.AdjustPaneSize { "Right", 1 } },
          { key = "UpArrow",   mods = "CTRL|SHIFT", action = wezterm.action.AdjustPaneSize { "Up", 1 } },
          { key = "DownArrow", mods = "CTRL|SHIFT", action = wezterm.action.AdjustPaneSize { "Down", 1 } },
          { key = "w",         mods = "CTRL|SHIFT", action = wezterm.action.CloseCurrentPane { confirm = false } },
        }
      '';
    };
  };
}
