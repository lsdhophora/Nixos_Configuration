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

  home.activation.clearLuaotfloadCache = lib.hm.dag.entryAfter [ "entryLast" ] ''
    ${myTexlive}/bin/luaotfload-tool --cache=erase
  '';
}
