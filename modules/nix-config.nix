{ pkgs, ... }:

{
  nix.package = pkgs.lixPackageSets.latest.lix;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    extra-deprecated-features = [ "or-as-identifier" "broken-string-indentation" ];
    trusted-users = [ "root" "FeiHsueh" ];
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
}
