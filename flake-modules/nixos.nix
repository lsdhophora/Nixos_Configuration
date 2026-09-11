{ inputs, lib, ... }:
let
  system = "x86_64-linux";
  # Repo helper lib (see ../lib). Passed to modules and overlays as `repoLib`.
  repoLib = import ../lib;
  # Construct pkgs with the repo overlays. Uses legacyPackages + extend
  # instead of `import nixpkgs { inherit system; }`: the latter warns
  # that `system` was renamed to stdenv.hostPlatform.system.
  repoPkgs = inputs.nixpkgs.legacyPackages.${system}.extend (
    inputs.nixpkgs.lib.composeManyExtensions (import ../overlays/default.nix inputs)
  );
in
{
  imports = [ ./checks.nix ];

  # flake-parts convention: formatter for `nix fmt`, devShell for `nix develop`.
  perSystem = { pkgs, ... }: {
    formatter = pkgs.nixfmt;
    devShells.default = pkgs.mkShell {
      packages = [
        pkgs.nixd
        pkgs.nixfmt
        pkgs.deadnix
        pkgs.statix
        pkgs.fd
      ];
    };
  };

  flake.nixosConfigurations.flowerpot = inputs.nixpkgs.lib.nixosSystem {
    pkgs = repoPkgs;
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
          imports = [
            ../home/default.nix
            ../home/persistence.nix
            ../home/kde/persistence-kde.nix
            inputs.plasma-manager.homeModules.plasma-manager
          ];
        };

        # Always re-run the Home Manager activation on switch. With
        # RemainAfterExit the oneshot stays `active (exited)` after its
        # first run, and switch-to-configuration skips restarting it, so
        # home changes are not applied until the next boot. Upstream fix
        # PR #5780 removes this line; the pinned home-manager input still
        # has it, so drop it here.
        systemd.services."home-manager-FeiHsueh".serviceConfig.RemainAfterExit = lib.mkForce false;
      }
    ];
  };

  # Standalone entry point for fast home-only rebuilds.
  # Shares the same ../home/default.nix as the NixOS module above.
  flake.homeConfigurations.FeiHsueh = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = repoPkgs;
    extraSpecialArgs = { inherit inputs repoLib; };
    modules = [
      ../home/default.nix
      inputs.plasma-manager.homeModules.plasma-manager
    ];
  };
}
