{
  description = "kwin-myopic-defocus: myopic chromatic defocus effect for KWin (Plasma 6)";

  inputs = {
    # Pinned to the same nixpkgs revision the NixOS flake uses for the
    # unstable kdePackages, so standalone builds reuse the binary cache.
    nixpkgs.url = "github:NixOS/nixpkgs/f13ff45afd1bb73e640eaa08a7066dbed07e3238";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      kd = pkgs.kdePackages;
      pkg = import ./nix/package.nix {
        inherit (kd)
          qtbase
          kglobalaccel
          kwindowsystem
          kconfig
          kconfigwidgets
          kcoreaddons
          ki18n
          kcmutils
          kwin
          extra-cmake-modules
          ;
        inherit (pkgs) lib stdenv cmake;
        epoxy = pkgs.libepoxy;
        src = self;
      };
    in
    {
      packages.${system} = {
        default = pkg;
        kwin-myopic-defocus = pkg;
      };
    };
}
