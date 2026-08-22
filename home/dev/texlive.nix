{
  config,
  pkgs,
  lib,
  ...
}:

let
  myTexlive = pkgs.texlive.combine {
    inherit (pkgs.texlive)
      scheme-basic
      ctex
      chinese-jfm
      fontspec
      luatex
      luacode
      graphics
      geometry
      fancyhdr
      titlesec
      hyphen-greek
      hyperref
      postnotes
      eso-pic
      footmisc
      polyglossia
      wrapfig
      capt-of
      unicode-math
      lualatex-math
      selnolig
      everypage
      ;
  };
in
{
  home.packages = [
    myTexlive
    pkgs.texlab
  ];

  # Erase the luaotfload font cache only when the texlive store path
  # changes (upgrade), not on every switch. A stale cache breaks font
  # lookup after an upgrade; clearing unconditionally would force a full
  # cache rebuild after every home-manager switch.
  home.activation.clearLuaotfloadCache = lib.hm.dag.entryAfter [ "entryLast" ] ''
    marker="$HOME/.cache/luaotfload-cleared"
    if [ "$(cat "$marker" 2>/dev/null)" != "${myTexlive}" ]; then
      ${myTexlive}/bin/luaotfload-tool --cache=erase
      mkdir -p "$(dirname "$marker")"
      printf '%s' "${myTexlive}" > "$marker"
    fi
  '';
}
