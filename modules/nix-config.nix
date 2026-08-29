{ pkgs, ... }:

{
  nix.package = pkgs.lixPackageSets.latest.lix;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    extra-deprecated-features = [
      "or-as-identifier"
      "broken-string-indentation"
    ];
    trusted-users = [
      "root"
      "FeiHsueh"
    ];
    auto-optimise-store = true;
    # Keep the desktop usable during nixos-rebuild: cap parallel builds
    # below the 12 hardware threads (Ryzen 5 5500U) so the compositor and
    # apps keep CPU. 8 jobs also caps the RAM footprint of rustc/gcc:
    # the root filesystem is a 4G tmpfs, so build temp files count too.
    max-jobs = 8;
    cores = 8;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
}
