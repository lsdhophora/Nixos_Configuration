# Find all overlay files in this directory automatically.
# Add a new .nix file here and it is applied automatically.
# Takes nixpkgs lib for the suffix predicate.
lib:
let
  files = builtins.readDir ./.;
  nixFiles = builtins.filter (name: name != "default.nix" && lib.hasSuffix ".nix" name) (
    builtins.attrNames files
  );
in
map (name: import (./. + "/${name}")) (builtins.sort (a: b: a < b) nixFiles)
