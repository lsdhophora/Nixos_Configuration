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

    with nixpkgs.lib;

    let
      system = "x86_64-linux"; # 你可以改成其他架构
      pkgs = nixpkgs.legacyPackages.${system}; # 必须先定义 pkgs
    in
    {
      nixosConfigurations.flowerpot = nixosSystem {
        inherit system pkgs; # 推荐！自动一致
        # system = pkgs.stdenv.hostPlatform.system;     # 也可以，但 inherit 更简洁

        specialArgs = { inherit inputs; };

        modules = [
          ./configuration.nix
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
        ];
      };
    };
}
