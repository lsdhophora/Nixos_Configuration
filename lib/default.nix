# Shared helper functions and constants.
# Import with: (import ../lib). It resolves to this file.
#
# Modules and home modules receive it as `repoLib` via specialArgs /
# extraSpecialArgs (see flake-modules/nixos.nix). Overlay files receive it
# as `repoLib` from the overlay loader (see overlays/default.nix).

let
  # Add patch files to a package. Keep any existing patches.
  # Example: applyPatches [ ./fix.patch ] pkg
  applyPatches =
    patches: pkg:
    pkg.overrideAttrs (oldAttrs: {
      patches = (oldAttrs.patches or [ ]) ++ patches;
    });

  # Apply a name -> patches map to a package set.
  # Example: applyPatchesToSet kdePatches kdePackages
  applyPatchesToSet =
    patchMap: pkgSet:
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = applyPatches patchMap.${name} pkgSet.${name};
      }) (builtins.attrNames patchMap)
    );

  # Package set from the nixpkgs-unstable input, for the same platform as pkgs.
  # Example: unstablePkgs inputs pkgs
  unstablePkgs =
    inputs: pkgs: inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  # Build home.file entries that symlink repo files into the home directory
  # (out-of-store, so edits in the repo apply without a rebuild).
  # Example:
  #   mkRepoLinks config {
  #     targetPrefix = ".config/emacs/lisp/";
  #     sourcePrefix = "home/programs/emacs/lisp/";
  #     paths = [ "init.el" ];
  #   }
  mkRepoLinks =
    config:
    {
      targetPrefix,
      sourcePrefix,
      paths,
    }:
    builtins.listToAttrs (
      map (path: {
        name = targetPrefix + path;
        value.source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/nixos/${sourcePrefix}${path}";
      }) paths
    );
in
{
  inherit
    applyPatches
    applyPatchesToSet
    unstablePkgs
    mkRepoLinks
    ;

  # Breeze Dark palette (official KDE BreezeDark.colors).
  # Used by tmux and mpv. The desktop keeps one theme (dark).
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

  # Terminal palette (16 colors + fg/bg + selection): Breeze Dark.
  # Values from the WezTerm built-in "Breeze" scheme, the dark KDE Breeze
  # terminal palette. Read them with
  # wezterm.color.get_builtin_schemes()["Breeze"]. Mapped to xterm
  # color0-15 naming. Used by wezterm (ansi/brights).
  # Color0 is the background and Color7 the foreground. Color12 is the
  # Breeze accent (#3daee9).
  weztermPalette = {
    foreground = "#eff0f1";
    background = "#31363b";
    color0 = "#31363b";
    color1 = "#ed1515";
    color2 = "#11d116";
    color3 = "#f67400";
    color4 = "#1d99f3";
    color5 = "#9b59b6";
    color6 = "#1abc9c";
    color7 = "#eff0f1";
    color8 = "#7f8c8d";
    color9 = "#c0392b";
    color10 = "#1cdc9a";
    color11 = "#fdbc4b";
    color12 = "#3daee9";
    color13 = "#8e44ad";
    color14 = "#16a085";
    color15 = "#fcfcfc";
    selection_foreground = "#31363b";
    selection_background = "#eff0f1";
  };
}
