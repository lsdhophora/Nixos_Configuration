{ pkgs, lib, ... }:
let
  # Generic VSIX builder.
  # It downloads a VSIX from a URL, removes the wrapper layer,
  # and puts the extension content into $out.
  # A VSIX is a zip file. The top level has the wrapper
  # [Content_Types].xml, extension/, and extension.vsixmanifest.
  buildVsix =
    {
      publisher,
      name,
      version,
      url,
      hash,
      description,
      homepage,
      license,
    }:
    pkgs.stdenv.mkDerivation {
      pname = name;
      inherit version;

      src = pkgs.fetchurl { inherit url hash; };

      nativeBuildInputs = [ pkgs.unzip ];
      dontUnpack = true;

      # VSCodium installs extensions under <publisher>.<name>-<version>.
      # Derive that dir name here, so it cannot drift from the version.
      passthru = {
        inherit publisher;
        extensionDir = "${publisher}.${name}-${version}";
      };

      installPhase = ''
        runHook preInstall
        mkdir -p "$out" "$TMPDIR/vsix-extract"
        unzip -q "$src" -d "$TMPDIR/vsix-extract"
        if [ -d "$TMPDIR/vsix-extract/extension" ]; then
          shopt -s dotglob
          mv "$TMPDIR/vsix-extract/extension"/* "$out"/
          shopt -u dotglob
        else
          mv "$TMPDIR/vsix-extract"/* "$out"/
        fi
        runHook postInstall
      '';

      meta = {
        inherit description homepage license;
      };
    };

  # Competitive Programming Helper (official GitHub release)
  competitiveProgrammingHelper = buildVsix {
    publisher = "divyanshuagrawal";
    name = "competitive-programming-helper";
    version = "2077.0.0";
    url = "https://github.com/agrawal-d/cph/releases/download/latest-vsix/competitive-programming-helper-2077.0.0.vsix";
    hash = "sha256-P4J+RDnwuqEDRngbJMS5GjmQiF3MZpi9guQzlHpnW2E=";
    description = "Competitive Programming Helper - compile, run and judge CP problems in VSCodium";
    homepage = "https://github.com/agrawal-d/cph";
    license = pkgs.lib.licenses.gpl3Plus;
  };

  # Nix IDE: nixd/nil LSP client (Open VSX)
  nixIde = buildVsix {
    publisher = "jnoortheen";
    name = "nix-ide";
    version = "0.5.13";
    url = "https://open-vsx.org/api/jnoortheen/nix-ide/0.5.13/file/jnoortheen.nix-ide-0.5.13.vsix";
    hash = "sha256-5Jp4slwIFUmbusTZlOw8tDXLEznkVXS7bzZxmRoitY0=";
    description = "Nix language support: nixd/nil LSP, formatting, nixpkgs options completion";
    homepage = "https://github.com/nix-community/vscode-nix-ide";
    license = pkgs.lib.licenses.mit;
  };

  extensions = [
    competitiveProgrammingHelper
    nixIde
  ];
in
{
  # VSCodium (previously installed with nix shell; now declarative)
  home.packages = [ pkgs.vscodium ];

  # VSCodium's profile cleanup deletes extensions that are in the
  # directory but not registered in extensions.json
  # (deleteExtensionsNotInProfiles). After each rebuild, delete the old
  # registry and trigger --list-extensions to rebuild it. The
  # store-linked extensions then register in extensions.json.
  home.activation.regenerateVscodiumExtensions = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run rm -f "$HOME/.vscode-oss/extensions/extensions.json" \
             "$HOME/.vscode-oss/extensions/.init-default-profile-extensions"
    ${pkgs.vscodium}/bin/codium --list-extensions > /dev/null 2>&1 || true
  '';

  # Directory source without recursive: the whole dir links to the store.
  # It is declarative and read-only. The dir name comes from
  # buildVsix.passthru.extensionDir (<publisher>.<name>-<version>).
  home.file = builtins.listToAttrs (
    map (ext: {
      name = ".vscode-oss/extensions/${ext.passthru.extensionDir}";
      value = {
        source = ext;
        force = true;
      };
    }) extensions
  );
}
