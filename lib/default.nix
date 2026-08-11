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

  # Breeze Dark palette (official KDE BreezeDark.colors).
  # Used by tmux and mpv. The desktop keeps one theme.
  breezeDark = {
    bg = "#202326";
    fg = "#fcfcfc";
    accent = "#3daee9";
    inactive = "#a1a9b1";
    alt = "#292c30";
    red = "#da4453";
    orange = "#f67400";
    green = "#27ae60";
  };

  # Kitty terminal palette (16 colors + fg/bg + selection).
  # Deliberate deviation from Breeze Dark: a terminal needs a full
  # 16-color set, which breezeDark does not provide. This is the
  # single source for kitty.nix.
  kittyPalette = {
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
    selection_foreground = "#ffffff";
    selection_background = "#3a4b6b";
  };
}
