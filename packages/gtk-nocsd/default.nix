{
  lib,
  stdenv,
  glib,
  libadwaita,
  libhandy,
  pkg-config,
}:
stdenv.mkDerivation {
  pname = "gtk-nocsd";
  version = "4.7";

  # Vendored from https://codeberg.org/MorsMortium/GTK-NoCSD
  # tag 4.7 (commit 0fd0613242a8338bd6ba712d2f45773147fae155).
  src = ./src;

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ glib libadwaita libhandy ];

  # stdenv would shrink away the RUNPATH below (the .so links no GTK libs, only
  # dlopens them at runtime), so patchelf must not touch it.
  dontPatchELF = true;

  # GTK-NoCSD dlopens glib/gio/libadwaita by bare soname at runtime. On NixOS
  # those libs live in /nix/store and are absent from ld.so.cache, so the dlopen
  # fails (e.g. "Could not load library: libgio-2.0.so.0" in pygobject apps
  # where libgio is not yet loaded). RUNPATH on our library makes glibc find
  # them when the dlopen happens from inside it.
  buildPhase = ''
    runHook preBuild

    gcc -fPIC -shared ./Source/GTK-NoCSD.c -o libgtk-nocsd.so.0 \
      -Wl,-soname,libgtk-nocsd.so.0 \
      -Wl,-e,GTKNoCSDMain \
      -Wl,-rpath,${glib.out}/lib \
      -Wl,-rpath,${libadwaita}/lib \
      -Wl,-rpath,${libhandy}/lib \
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
    homepage = "https://codeberg.org/MorsMortium/GTK-NoCSD";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
  };
}
