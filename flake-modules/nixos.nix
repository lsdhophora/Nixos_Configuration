{ self, inputs, ... }: {
  flake.nixosConfigurations.flowerpot = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    pkgs = import inputs.nixpkgs {
      system = "x86_64-linux";
      overlays = (import ../overlays/default.nix);
    };
    specialArgs = { inherit inputs; };
    modules = [
      ../hosts/flowerpot/default.nix
      inputs.chaotic.nixosModules.nyx-cache
      inputs.chaotic.nixosModules.nyx-overlay
      inputs.chaotic.nixosModules.nyx-registry
      inputs.agenix.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = { inherit inputs; };
        home-manager.users.lophophora = {
          imports = [ ../home/default.nix ];
        };
      }
    ];
  };
}
