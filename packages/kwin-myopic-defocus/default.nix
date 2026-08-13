{
  lib,
  stdenv,
  cmake,
  extra-cmake-modules,
  qtbase,
  kglobalaccel,
  kwindowsystem,
  kconfig,
  kconfigwidgets,
  kcoreaddons,
  ki18n,
  kcmutils,
  kwin,
  epoxy,
}:

# The build recipe lives in the project's nix/package.nix (single source
# of truth); the project source is vendored into ./src (tests excluded).
(import ./src/nix/package.nix) {
  inherit
    lib
    stdenv
    cmake
    extra-cmake-modules
    qtbase
    kglobalaccel
    kwindowsystem
    kconfig
    kconfigwidgets
    kcoreaddons
    ki18n
    kcmutils
    kwin
    epoxy
    ;
  src = ./src;
}
