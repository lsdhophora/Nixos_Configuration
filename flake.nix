{
  description = "My NixOS Laptop flake";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      nixpkgs,
      agenix,
      home-manager,
      ...
    }@inputs:
    with nixpkgs.lib;
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
      inherit system;
      overlays = import ./overlays/default.nix;
    };
    in
    {
      nixosConfigurations.flowerpot = nixosSystem {
        inherit system pkgs;
        specialArgs = {
          inherit inputs;
        };
        modules = [
          ./configuration.nix
          agenix.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {};
            home-manager.users.lophophora = {
              imports = [
                ./home/default.nix
              ];
            };
          }
        ];
      };
    };
}
