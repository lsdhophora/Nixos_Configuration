{ pkgs, ... }:

let
  kvLibadwaita = pkgs.fetchFromGitHub {
    owner = "GabePoel";
    repo = "KvLibadwaita";
    rev = "main";
    hash = "sha256-jCXME6mpqqWd7gWReT04a//2O83VQcOaqIIXa+Frntc=";
  };
in
{
  home.packages = [
    pkgs.kdePackages.qtstyleplugin-kvantum
    pkgs.qadwaitadecorations-qt6
  ];

  xdg.configFile = {
    "Kvantum/KvLibadwaitaDark".source = "${kvLibadwaita}/src/KvLibadwaitaDark";

    "Kvantum/kvantum.kvconfig".text = ''
      [General]
      theme=KvLibadwaitaDark
    '';
  };

  home.sessionVariables = {
    QT_STYLE_OVERRIDE = "kvantum";
    QT_WAYLAND_DECORATION = "adwaita";
  };
}
