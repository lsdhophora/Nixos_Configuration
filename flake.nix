{
  description = "My NixOS Laptop flake";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    home-manager = {
      url = "github:nix-community/home-manager/";
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
      pkgs = nixpkgs.legacyPackages.${system};
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
