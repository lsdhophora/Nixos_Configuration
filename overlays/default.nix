# Find all overlay files in this directory automatically.
# Add a new .nix file here and it is applied automatically.
#
# Takes the flake output arguments (the flake inputs plus `self`, as the flake
# outputs function receives them). The loader strips `self`, so overlay files
# see the flake inputs only. lib comes from the nixpkgs input.
#
# An overlay file has the plain `final: prev:` signature by default.
# A file that needs the repo helper lib or flake inputs (for example
# nixpkgs-unstable) uses the pattern `{ repoLib, inputs }: final: prev:`
# instead. The loader passes the repo lib and the inputs set to such a file.
args:
let
  inputs = args.nixpkgs.lib.removeAttrs args [ "self" ];
  lib = inputs.nixpkgs.lib;
  repoLib = import ../lib;
  files = builtins.readDir ./.;
  nixFiles = builtins.filter (name: name != "default.nix" && lib.hasSuffix ".nix" name) (
    builtins.attrNames files
  );
  load =
    name:
    let
      overlay = import (./. + "/${name}");
      declared = lib.functionArgs overlay;
      # Only pass the args the overlay declares (set patterns reject extras).
      overlayArgs = builtins.intersectAttrs declared { inherit inputs repoLib; };
    in
    if declared ? inputs || declared ? repoLib then overlay overlayArgs else overlay;
in
map load (builtins.sort (a: b: a < b) nixFiles)
