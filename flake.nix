{
  description = "My NixOS Laptop flake";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-kdenlive-pinned.url = "github:NixOS/nixpkgs?rev=fea3b367d61c1a6592bc47c72f40a9f3e6a53e96";
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
          pkgs-kdenlive-pinned = import inputs.nixpkgs-kdenlive-pinned {
            system = "x86_64-linux";

          };
        };
        modules = [
          ./configuration.nix
          agenix.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              pkgs-kdenlive-pinned = import inputs.nixpkgs-kdenlive-pinned {
                system = "x86_64-linux";

              };
            };
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
