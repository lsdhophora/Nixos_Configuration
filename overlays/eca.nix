final: prev: {
  eca-server = prev.stdenv.mkDerivation {
    pname = "eca-server";
    version = "0.150.1";
    src = prev.fetchurl {
      url = "https://github.com/editor-code-assistant/eca/releases/download/0.150.1/eca-native-static-linux-amd64.zip";
      sha256 = "39d337f2001d56c276a8fcfae0d88caa45c65ba2f84116f8f98aba0ade206df5";
    };
    sourceRoot = ".";
    nativeBuildInputs = [ prev.unzip ];
    installPhase = ''
      mkdir -p $out/bin
      cp eca $out/bin/
    '';
    meta = {
      description = "Editor Code Assistant server binary";
      homepage = "https://github.com/editor-code-assistant/eca";
      sourceProvenance = with prev.lib.sourceTypes; [ binaryNativeCode ];
      license = prev.lib.licenses.asl20;
      platforms = [ "x86_64-linux" ];
    };
  };
}
