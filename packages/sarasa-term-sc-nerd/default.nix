{
  lib,
  stdenvNoCC,
  fetchzip,
}:
stdenvNoCC.mkDerivation {
  pname = "sarasa-term-sc-nerd";
  version = "2.3.1";

  src = fetchzip {
    url = "https://github.com/laishulu/Sarasa-Term-SC-Nerd/releases/download/v2.3.1/SarasaTermSCNerd-Unhinted.ttf.tar.gz";
    sha256 = "0qqsnsvagjjgxgx52iq0c3ybz7qk97qkd1xjn7qd554jxg6pg7c0";
    stripRoot = false; # the archive is a flat list of .ttf files
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/fonts/truetype
    cp *.ttf $out/share/fonts/truetype/
    runHook postInstall
  '';

  meta = {
    description = "Sarasa Term SC with Nerd Font icons (unhinted)";
    homepage = "https://github.com/laishulu/Sarasa-Term-SC-Nerd";
    license = lib.licenses.ofl;
    platforms = lib.platforms.all;
  };
}
