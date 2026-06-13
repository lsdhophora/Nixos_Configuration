{ pkgs, ... }:

{
  nix.package = pkgs.lixPackageSets.latest.lix;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "lophophora" ];
    substituters = [
      "https://cache.nixos.org"
      "https://nyx-cache.chaotic.cx/"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk="
    ];
  };
}
