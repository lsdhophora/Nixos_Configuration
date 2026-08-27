{ repoLib, lib, ... }:
let
  palette = repoLib.weztermPalette;
  # Shared Breeze Light palette (tmux, mpv).
  breeze = repoLib.breezeLight;
  # One tab color pair.
  tabColor = bg_color: fg_color: { inherit bg_color fg_color; };
  # Breeze Light [colors] section, derived from the repoLib palette.
  colors = {
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
    # Light tab bar. WezTerm defaults to a dark bar when the scheme
    # does not set these colors.
    tab_bar = {
      background = breeze.alt;
      active_tab = tabColor breeze.accent "#ffffff";
      inactive_tab = tabColor breeze.alt breeze.fg;
      inactive_tab_hover = tabColor breeze.bg breeze.fg;
      inactive_tab_edge = breeze.alt;
      inactive_tab_edge_hover = breeze.bg;
      new_tab = tabColor breeze.alt breeze.fg;
      new_tab_hover = tabColor breeze.bg breeze.fg;
    };
  };
in
{
  programs.wezterm = {
    enable = true;
    # Enables wezterm ssh / imgcat in the shell (sources wezterm.sh).
    enableZshIntegration = true;

    # Custom colors: ~/.config/wezterm/colors/Breeze Light.toml,
    # selected by settings.color_scheme.
    colorSchemes."Breeze Light" = colors;

    settings = {
      color_scheme = "Breeze Light";
      font_size = 14.0;
      # Iosevka has no CJK glyphs; fall back to Noto Sans Mono CJK SC.
      font = lib.generators.mkLuaInline ''
        wezterm.font_with_fallback({ "Iosevka", "Noto Sans Mono CJK SC" })
      '';
      hide_tab_bar_if_only_one_tab = false;
      window_close_confirmation = "NeverPrompt";

      # Keybindings match kitty: launch hsplit/vsplit, neighboring_window,
      # resize_window, close_window.
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
