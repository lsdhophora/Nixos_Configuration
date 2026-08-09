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
}
