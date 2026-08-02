{
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  pname = "kwin-renumber-desktops";
  version = "1.0.0";

  src = ./src;

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/kwin/scripts
    cp -r $src $out/share/kwin/scripts/renumber-desktops

    runHook postInstall
  '';

  meta = {
    description = "KWin script that renumbers virtual desktops sequentially from 1";
    homepage = "https://github.com/KDE/kwin";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ ];
  };
}
