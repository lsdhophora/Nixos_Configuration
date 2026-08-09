{
  lib,
  stdenvNoCC,
  fetchzip,
}:
stdenvNoCC.mkDerivation {
  pname = "jetbrains-maple-mono";
  version = "1.2304.79";

  src = fetchzip {
    url = "https://github.com/SpaceTimee/Fusion-JetBrainsMapleMono/releases/download/1.2304.79/JetBrainsMapleMono-NF-XX-XX-HT.zip";
    sha256 = "1615c2brazs5xz6hnrbx0xcsx0l27kpfkjbkx60rgrdh6kr8q9b5";
    stripRoot = false;
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/fonts/truetype
    find "$src" -name "*.ttf" -exec cp {} $out/share/fonts/truetype/ \;
    runHook postInstall
  '';

  meta = {
    description = "JetBrains Mono fused with Maple Mono (Nerd Font, ligatures, hinted)";
    homepage = "https://github.com/SpaceTimee/Fusion-JetBrainsMapleMono";
    license = lib.licenses.ofl;
    platforms = lib.platforms.all;
  };
}
