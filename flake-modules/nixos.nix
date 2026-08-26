{ inputs, ... }:
let
  system = "x86_64-linux";
  # Repo helper lib (see ../lib). Passed to modules and overlays as `repoLib`.
  repoLib = import ../lib;
in
{
  # flake-parts convention: formatter for `nix fmt`, devShell for `nix develop`.
  perSystem = { pkgs, ... }: {
    formatter = pkgs.nixfmt;
    devShells.default = pkgs.mkShell {
      packages = [
        pkgs.nixd
        pkgs.nixfmt
      ];
    };
  };

  flake.nixosConfigurations.flowerpot = inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    pkgs = import inputs.nixpkgs {
      inherit system;
      # Auto-discovered overlays from ../overlays (see overlays/default.nix).
      overlays = (import ../overlays/default.nix) inputs;
    };
    specialArgs = { inherit inputs repoLib; };
    modules = [
      ../hosts/flowerpot/default.nix
      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.home-manager
      inputs.impermanence.nixosModules.impermanence
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "bak";
        home-manager.extraSpecialArgs = { inherit inputs repoLib; };
        home-manager.users.FeiHsueh = {
          imports = [ ../home/default.nix ../home/persistence.nix ../home/persistence-kde.nix ];
        };
      }
    ];
  };

  # Standalone entry point for fast home-only rebuilds.
  # Shares the same ../home/default.nix as the NixOS module above.
  flake.homeConfigurations.FeiHsueh = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = import inputs.nixpkgs {
      inherit system;
      overlays = (import ../overlays/default.nix) inputs;
    };
    extraSpecialArgs = { inherit inputs repoLib; };
    modules = [ ../home/default.nix ];
  };
}
