# Unit tests for lib/default.nix helpers.
#
# Returns the raw test attrset ({ expr, expected } per test). The
# `lib-tests` check in flake-modules/checks.nix runs it through
# lib.debug.runTests. Pure evaluation: no derivation is built.
{ pkgs }:
let
  repoLib = import ../lib;
  # Mock for config.lib.file.mkOutOfStoreSymlink (identity function).
  mkSymlink = p: p;
in
{
  testApplyPatchesAppends = {
    expr =
      (repoLib.applyPatches [ ./fixtures/p2.patch ] (
        pkgs.hello.overrideAttrs (o: {
          patches = [ ./fixtures/p1.patch ];
        })
      )).patches;
    expected = [
      ./fixtures/p1.patch
      ./fixtures/p2.patch
    ];
  };

  testApplyPatchesToSet = {
    expr =
      (repoLib.applyPatchesToSet
        {
          hello = [ ./fixtures/p1.patch ];
        }
        {
          hello = pkgs.hello;
        }
      ).hello.patches;
    expected = [ ./fixtures/p1.patch ];
  };

  testUnstablePkgs = {
    expr =
      (repoLib.unstablePkgs
        {
          nixpkgs-unstable = {
            legacyPackages.x86_64-linux.zlib = "stub";
          };
        }
        {
          stdenv.hostPlatform.system = "x86_64-linux";
        }
      ).zlib;
    expected = "stub";
  };

  testMkRepoLinks = {
    expr =
      repoLib.mkRepoLinks
        {
          home.homeDirectory = "/home/x";
          lib.file.mkOutOfStoreSymlink = mkSymlink;
        }
        {
          targetPrefix = "t/";
          sourcePrefix = "s/";
          paths = [
            "a"
            "b"
          ];
        };
    expected = {
      "t/a" = {
        source = "/home/x/.config/nixos/s/a";
      };
      "t/b" = {
        source = "/home/x/.config/nixos/s/b";
      };
    };
  };

  testBreezeLightAccent = {
    expr = repoLib.breezeLight.accent;
    expected = "#3daee9";
  };

  testWeztermPaletteBackground = {
    expr = repoLib.weztermPalette.background;
    expected = "#eff0f1";
  };
}
