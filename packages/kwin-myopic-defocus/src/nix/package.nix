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
  src ? ../.,
  version ? "0.1.0",
}:

stdenv.mkDerivation {
  pname = "kwin-myopic-defocus";
  inherit version src;

  # This is a loadable plugin (.so), not an application: skip Qt wrapping.
  dontWrapQtApps = true;

  nativeBuildInputs = [
    cmake
    extra-cmake-modules
  ];

  buildInputs = [
    qtbase
    kglobalaccel
    kwindowsystem
    kconfig
    kconfigwidgets
    kcoreaddons
    ki18n
    kcmutils
    kwin.dev
    epoxy
  ];

  meta = with lib; {
    description = "KWin (Plasma 6) effect: myopic chromatic aberration — blurs the G and B channels while keeping R sharp";
    homepage = "https://emacs-china.org/t/vibe-coding/30816";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
