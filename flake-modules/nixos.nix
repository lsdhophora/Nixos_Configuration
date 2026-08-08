{ self, inputs, ... }:
let
  system = "x86_64-linux";
in
{
  flake.nixosConfigurations.flowerpot = inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    pkgs = import inputs.nixpkgs {
      inherit system;
      overlays = (import ../overlays/default.nix);
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
