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
    # Keep the desktop usable during nixos-rebuild. `max-jobs` is the number
    # of concurrent derivations and `cores` is the thread budget of each one,
    # so the two multiply. Cap the product at the 12 hardware threads of the
    # Ryzen 5 5500U (6 cores, 12 threads): 6 x 2. The 8 x 8 pair before this
    # allowed 64 threads. The low per-job budget also caps the RAM footprint
    # of rustc/gcc: the root filesystem is a 4G tmpfs, so build temp files
    # count too.
    max-jobs = 6;
    cores = 2;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
}
