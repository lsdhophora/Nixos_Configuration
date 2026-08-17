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
            # pi-coding-agent from nixpkgs-unstable, pinned to 0.84.2 (nixpkgs
            # lags behind). 0.84.2 fixes DeepSeek models sending output limits
            # through an unsupported field (truncated responses) and adds
            # automatic retries for upstream request buffer failures.
            pi-coding-agent = (inputs.nixpkgs-unstable.legacyPackages.x86_64-linux.pi-coding-agent).overrideAttrs (old: let
              src = prev.fetchFromGitHub {
                owner = "earendil-works";
                repo = "pi";
                tag = "v0.84.2";
                hash = "sha256-d29ft9otYxdHRWYIAX8KMHPpppToX9ME5LbPb1rPcYo=";
              };
            in {
              version = "0.84.2";
              inherit src;
              modelData = prev.fetchurl {
                url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-0.84.2.tgz";
                hash = "sha256-AmJ4Wnaw6y7sWWzYp6su4j7vidLvG7EhHE8KGUTaz0E=";
              };
              npmDeps = prev.fetchNpmDeps {
                inherit src;
                hash = "sha256-6J5Efe+6ptCuR3VZojwYPZO8BBnnZsOQ4OAeB64uYOY=";
              };
            });
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
