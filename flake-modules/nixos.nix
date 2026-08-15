{ self, inputs, ... }:
let
  system = "x86_64-linux";
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
      overlays =
        [
          # Build pi-coding-agent from nixpkgs-unstable.
          # Must come before the auto-discovered overlays so that
          # overlays/pi-agent.nix applies its editor patches on top of the
          # unstable build.
          (final: prev: {
            pi-coding-agent = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux.pi-coding-agent;
          })
        ]
        ++ (import ../overlays/default.nix) inputs.nixpkgs.lib;
    };
    specialArgs = { inherit inputs; };
    modules = [
      ../hosts/flowerpot/default.nix
      inputs.chaotic.nixosModules.nyx-cache
      inputs.chaotic.nixosModules.nyx-overlay
      inputs.chaotic.nixosModules.nyx-registry
      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "bak";
        home-manager.extraSpecialArgs = { inherit inputs; };
        home-manager.users.lophophora = {
          imports = [ ../home/default.nix ];
        };
      }
    ];
  };
}
