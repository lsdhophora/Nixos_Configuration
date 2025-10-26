{
  description = "A simple NixOS flake";

  nixConfig = {
    trusted-substituters = [ "https://mirrors.ustc.edu.cn/nix-channels/store" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    home-manager = {
      url = "github:nix-community/home-manager";
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
    {
      nixosConfigurations.flowerpot = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          agenix.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.lophophora = {
              imports = [
                ./home.nix
                ./emacs.nix
              ];
            };
          }
          ./configuration.nix
        ];
        specialArgs = { inherit inputs; };
      };
    };
}
