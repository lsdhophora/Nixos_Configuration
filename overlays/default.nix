# Find all overlay files in this directory automatically.
# Add a new .nix file here and it is applied automatically.
let
  files = builtins.readDir ./.;
  nixFiles = builtins.filter (name: name != "default.nix" && builtins.match ".*\\.nix" name != null) (
    builtins.attrNames files
  );
in
map (name: import (./. + "/${name}")) (builtins.sort (a: b: a < b) nixFiles)
