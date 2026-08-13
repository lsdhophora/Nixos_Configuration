# Shared helper functions and constants.
# Import with: (import ../lib). It resolves to this file.

{
  # Add patch files to a package. Keep any existing patches.
  # Example: applyPatches [ ./fix.patch ] pkg
  applyPatches =
    patches: pkg:
    pkg.overrideAttrs (oldAttrs: {
      patches = (oldAttrs.patches or [ ]) ++ patches;
    });

  # Breeze Light palette (official KDE Breeze.colors, light variant).
  # Used by tmux and mpv. The desktop keeps one theme (light).
  breezeLight = {
    bg = "#ffffff";
    fg = "#232627";
    accent = "#3daee9";
    inactive = "#7f8c8d";
    alt = "#eff0f1";
    red = "#da4453";
    orange = "#f67400";
    green = "#27ae60";
  };

  # Kitty terminal palette (16 colors + fg/bg + selection) — light variant.
  # Deliberate deviation from Breeze Light: a terminal needs a full
  # 16-color set, which breezeLight does not provide. This is the
  # single source for kitty.nix.
  kittyPalette = {
    foreground = "#232627";
    background = "#ffffff";
    color0 = "#f5f6f7";
    color1 = "#da4453";
    color2 = "#27ae60";
    color3 = "#f67400";
    color4 = "#2a7bde";
    color5 = "#9b59b6";
    color6 = "#148f9d";
    color7 = "#7f8c8d";
    color8 = "#bdc3c7";
    color9 = "#e74c3c";
    color10 = "#2ecc71";
    color11 = "#f39c12";
    color12 = "#3daee9";
    color13 = "#af7ac5";
    color14 = "#1abc9c";
    color15 = "#232627";
    selection_foreground = "#ffffff";
    selection_background = "#3daee9";
  };
}
