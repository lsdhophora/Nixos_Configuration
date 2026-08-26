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

  # Kitty terminal palette (16 colors + fg/bg + selection) — Breeze Light.
  # Exact values from the official KDE Breeze Light Konsole color scheme
  # (phabricator D22243, data/color-schemes/BreezeLight.colorscheme),
  # mapped to kitty's color0-15. Background is #EFF0F1 (light grey, not
  # pure white); Color0 is #232627 (dark grey, same as the foreground).
  # Selection colors come from the official BreezeLight.colors.
  kittyPalette = {
    foreground = "#232627";
    background = "#eff0f1";
    color0 = "#232627";
    color1 = "#c0392b";
    color2 = "#55aa00";
    color3 = "#f67400";
    color4 = "#0055ff";
    color5 = "#8e44ad";
    color6 = "#16a085";
    color7 = "#fcfcfc";
    color8 = "#7f8c8d";
    color9 = "#ed1515";
    color10 = "#11d116";
    color11 = "#fdbc4b";
    color12 = "#1d99f3";
    color13 = "#9b59b6";
    color14 = "#1abc9c";
    color15 = "#ffffff";
    selection_foreground = "#ffffff";
    selection_background = "#3daee9";
  };
}
