{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs,
  pnpm,
  pnpmConfigHook,
  zip,
}:

let
  pname = "violentmonkey-declarative";
  version = "2.48.0";
  src = fetchFromGitHub {
    owner = "violentmonkey";
    repo = "violentmonkey";
    rev = "v${version}";
    hash = "sha256-IyPOX36rbeKHeZ0iGQtL18dG/dOp83DwsE45YMP1B1U=";
  };
in
stdenv.mkDerivation {
  inherit pname version src;

  # Patch: read userscripts from the "3rdparty" enterprise policy
  # (chrome.storage.managed) with correct id matching and removal semantics.
  # See patches/violentmonkey/declarative.patch.
  patches = [ ../../patches/violentmonkey/declarative.patch ];

  pnpmDeps = pnpm.fetchDeps {
    inherit src pname version;
    fetcherVersion = 3;
    hash = "sha256-OY3LZePUL2dMOE9RTOUBFvkk/2zCBnKR/Gd4ln1H3OY=";
  };

  nativeBuildInputs = [
    pnpmConfigHook
    nodejs
    pnpm
    zip
  ];

  buildPhase = ''
    runHook preBuild
    pnpm build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/mozilla/extensions
    (cd dist && zip -qr $out/share/mozilla/extensions/{aecec67f-0d10-4fa7-b7c7-609a2db280cf}.xpi .)
    runHook postInstall
  '';

  meta = {
    description = "Violentmonkey with declarative (managed-policy) userscripts, patched from upstream v${version}";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
