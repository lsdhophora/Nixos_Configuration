final: prev: {
  gnomeExtensions = prev.gnomeExtensions // {
    gjs-osk = prev.gnomeExtensions.gjs-osk.overrideAttrs (old: {
      version = "2026-06-05";
      src = final.fetchFromGitHub {
        owner = "Vishram1123";
        repo = "gjs-osk";
        rev = "4191527db5ca206547d48242ad4a08b10a5e3d03";
        hash = "sha256-hTqM0s4jIP59SMnVPn3NSyxhk8LkMYsyzNPN2Vgjrkw=";
      };
      patches = [ ];
      postUnpack = ''
        cd "$sourceRoot/gjsosk@vishram1123.com"
        sourceRoot="$PWD"
      '';
    });
  };
}
