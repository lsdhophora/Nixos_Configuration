{ pkgs, lib, ... }:
let
  # 通用 VSIX 打包器：从 URL 拉取 VSIX，剥离包装层，输出扩展内容到 $out 根目录。
  # VSIX 是 zip，顶层带 [Content_Types].xml / extension/ / extension.vsixmanifest 包装。
  buildVsix = { name, version, url, hash, description, homepage, license }:
    pkgs.stdenv.mkDerivation {
      pname = name;
      inherit version;

      src = pkgs.fetchurl { inherit url hash; };

      nativeBuildInputs = [ pkgs.unzip ];
      dontUnpack = true;

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

  # Competitive Programming Helper —— 官方 GitHub release
  competitiveProgrammingHelper = buildVsix {
    name = "competitive-programming-helper";
    version = "2077.0.0";
    url = "https://github.com/agrawal-d/cph/releases/download/latest-vsix/competitive-programming-helper-2077.0.0.vsix";
    hash = "sha256-P4J+RDnwuqEDRngbJMS5GjmQiF3MZpi9guQzlHpnW2E=";
    description = "Competitive Programming Helper - compile, run and judge CP problems in VSCodium";
    homepage = "https://github.com/agrawal-d/cph";
    license = pkgs.lib.licenses.gpl3Plus;
  };

  # Nix IDE —— nixd/nil LSP 客户端（Open VSX）
  nixIde = buildVsix {
    name = "nix-ide";
    version = "0.5.13";
    url = "https://open-vsx.org/api/jnoortheen/nix-ide/0.5.13/file/jnoortheen.nix-ide-0.5.13.vsix";
    hash = "sha256-5Jp4slwIFUmbusTZlOw8tDXLEznkVXS7bzZxmRoitY0=";
    description = "Nix language support: nixd/nil LSP, formatting, nixpkgs options completion";
    homepage = "https://github.com/nix-community/vscode-nix-ide";
    license = pkgs.lib.licenses.mit;
  };
in
{
  # VSCodium 本体（原先用 nix shell 临时安装，改为声明式）
  home.packages = [ pkgs.vscodium ];

  # VSCodium 的 profile 清理机制会把"目录里有但 extensions.json 没登记"的扩展
  # 当作残留自动删除（deleteExtensionsNotInProfiles）。
  # 因此每次重建后：删掉旧注册表 + 触发 --list-extensions 全量重建，
  # 让 store 符号链接扩展被登记进 extensions.json。
  home.activation.regenerateVscodiumExtensions = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run rm -f "$HOME/.vscode-oss/extensions/extensions.json" \
             "$HOME/.vscode-oss/extensions/.init-default-profile-extensions"
    ${pkgs.vscodium}/bin/codium --list-extensions > /dev/null 2>&1 || true
  '';

  # 目录 source + 无 recursive => 整体符号链接指向 store，声明式、只读
  home.file.".vscode-oss/extensions/divyanshuagrawal.competitive-programming-helper-2077.0.0" = {
    source = competitiveProgrammingHelper;
    force = true;
  };
  home.file.".vscode-oss/extensions/jnoortheen.nix-ide-0.5.13" = {
    source = nixIde;
    force = true;
  };
}
