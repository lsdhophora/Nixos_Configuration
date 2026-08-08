{ pkgs, ... }:
let
  # Competitive Programming Helper (CPH) —— 从官方 GitHub release 打包
  # 源码: https://github.com/agrawal-d/cph (GPL-3.0-or-later)
  competitiveProgrammingHelper = pkgs.stdenv.mkDerivation {
    pname = "competitive-programming-helper";
    version = "2077.0.0";

    src = pkgs.fetchurl {
      url = "https://github.com/agrawal-d/cph/releases/download/latest-vsix/competitive-programming-helper-2077.0.0.vsix";
      hash = "sha256-P4J+RDnwuqEDRngbJMS5GjmQiF3MZpi9guQzlHpnW2E=";
    };

    nativeBuildInputs = [ pkgs.unzip ];

    dontUnpack = true;

    # VSIX 是 zip，顶层带 [Content_Types].xml / extension/ / extension.vsixmanifest 包装。
    # 只提取 extension/ 里的真实扩展内容到 $out 根目录。
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
      description = "Competitive Programming Helper - compile, run and judge CP problems in VSCodium";
      homepage = "https://github.com/agrawal-d/cph";
      license = pkgs.lib.licenses.gpl3Plus;
    };
  };
in
{
  # 安装到 VSCodium 用户扩展目录（~/.vscode-oss/extensions）
  # 目录 source + 无 recursive => 整体符号链接指向 store，声明式、只读
  home.file.".vscode-oss/extensions/divyanshuagrawal.competitive-programming-helper-2077.0.0" = {
    source = competitiveProgrammingHelper;
    force = true;
  };
}
