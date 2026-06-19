{ self, inputs, ... }: {
  flake.nixosConfigurations.flowerpot = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    pkgs = import inputs.nixpkgs {
      system = "x86_64-linux";
      overlays = (import ../overlays/default.nix) ++ [
        (import ../overlays/cosmic-unstable.nix {
          nixpkgs-unstable = inputs.nixpkgs-unstable;
          system = "x86_64-linux";
          config = { };
        })
        (import ../overlays/cosmic-popup-border.nix)
        (import ../overlays/cosmic-launcher.nix)
        (import ../overlays/cosmic-osd.nix)
        (import ../overlays/pop-launcher.nix)
        (import ../overlays/cosmic-applets-slider.nix)
        (import ../overlays/cosmic-applets-remove-performance.nix)
        (import ../overlays/cosmic-settings-remove-performance.nix)
      ];
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
        home-manager.extraSpecialArgs = {};
        home-manager.users.lophophora = {
          imports = [ ../home/default.nix ];
        };
      }
    ];
  };
}
