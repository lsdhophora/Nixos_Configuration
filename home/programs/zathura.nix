{ ... }:
let
  bg = "#111111";
  fg = "#cccccc";
  panel = "#1a1a1a";
in
{
  xdg.configFile."zathura/zathurarc".text = ''
    set completion-bg "${panel}"
    set completion-fg "${fg}"
    set completion-highlight-fg "#000000"
    set default-bg "${bg}"
    set default-fg "${fg}"
    set font "IBM Plex Sans 14"

    set inputbar-bg "${panel}"
    set inputbar-fg "${fg}"
    set notification-bg "${panel}"
    set notification-fg "${fg}"
    set recolor-lightcolor "${bg}"
    set recolor-darkcolor "${fg}"
    set selection-clipboard clipboard
    set statusbar-bg "${panel}"
    set statusbar-fg "${fg}"
    set zoom-min 10
  '';
}
