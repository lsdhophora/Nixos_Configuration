{
  lib,
  stdenv,
  libadwaita,
  pkg-config,
}:
stdenv.mkDerivation {
  pname = "gtk-nocsd";
  version = "2026-06-09";

  # Vendored from https://codeberg.org/ffoss/GTK-NoCSD
  # commit 8275f5814fbc5d4d9fcffdef0f1db61ae5daaddd (2026-06-09).
  src = ./src;

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ libadwaita ];

  buildPhase = ''
    runHook preBuild

    gcc -fPIC -shared ./Source/GTK-NoCSD.c -o libgtk-nocsd.so.0 \
      -Wl,-soname,libgtk-nocsd.so.0 \
      -Wl,-e,GTKNoCSDMain \
      $(pkg-config --cflags libadwaita-1 gobject-2.0 gio-2.0)

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib
    install -m 755 libgtk-nocsd.so.0 $out/lib/libgtk-nocsd.so.0
    ln -s libgtk-nocsd.so.0 $out/lib/libgtk-nocsd.so

    runHook postInstall
  '';

  meta = {
    description = "LD_PRELOAD library to disable CSD in GTK3/4, LibHandy, and LibAdwaita apps";
    homepage = "https://codeberg.org/ffoss/GTK-NoCSD";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
  };
}
