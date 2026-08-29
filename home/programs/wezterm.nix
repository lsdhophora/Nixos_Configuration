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
      # IME preedit: let fcitx5 render it in its input panel. The default
      # "Builtin" mode makes wezterm draw the preedit too, and the input
      # panel flickers when the terminal repaints during streaming output
      # (for example pi output while composing).
      ime_preedit_rendering = "System";
      # Retro tab bar: cell-based rendering, no fancy button shapes.
      use_fancy_tab_bar = false;
      font_size = 14.0;
      # Iosevka has no CJK glyphs; fall back to Noto Sans Mono CJK SC.
      # NWID=1: Iosevka maps ambiguous-width symbols (dash, arrows,
      # ellipsis, check marks, and so on) to 2-cell WWID glyphs by
      # default, but WezTerm lays them out in 1 cell, so their ink
      # overflows into the next cell and overlaps the following
      # character. The NWID OpenType feature switches those glyphs to the
      # built-in narrow variants (same advance as regular characters).
      # This gives the same result as kitty glyph rescaling. See
      # patches/pi-agent notes.
      font = lib.generators.mkLuaInline ''
        wezterm.font_with_fallback({
          { family = "Iosevka", harfbuzz_features = { "NWID=1" } },
          "Noto Sans Mono CJK SC",
        })
      '';
      hide_tab_bar_if_only_one_tab = false;
      window_close_confirmation = "NeverPrompt";

      # Keybindings match kitty: launch hsplit/vsplit, neighboring_window,
      # resize_window, close_window.
      keys = lib.generators.mkLuaInline ''
        {
          { key = "Enter",     mods = "CTRL|SHIFT", action = wezterm.action.SplitHorizontal { domain = "CurrentPaneDomain" } },
          -- SplitVertical on the physical Backslash key: key = "\\" matches the
          -- shifted char "|" instead, so the binding never fires on US layouts.
          -- "Backslash" matches the physical key regardless of shift state.
          { key = "Backslash", mods = "CTRL|SHIFT", action = wezterm.action.SplitVertical { domain = "CurrentPaneDomain" } },
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
