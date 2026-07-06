{ ... }: {
  xdg.configFile."zathura/zathurarc".text = ''
    set completion-bg "#1a1a1a"
    set completion-fg "#cccccc"
    set completion-highlight-bg "#9141ac"
    set completion-highlight-fg "#000000"
    set default-bg "#111111"
    set default-fg "#cccccc"
    set font "IBM Plex Sans 14"
    set highlight-color "#9141ac"
    set highlight-active-color "#b060d0"
    set inputbar-bg "#1a1a1a"
    set inputbar-fg "#cccccc"
    set notification-bg "#1a1a1a"
    set notification-fg "#cccccc"
    set recolor-lightcolor "#111111"
    set recolor-darkcolor "#cccccc"
    set selection-clipboard clipboard
    set statusbar-bg "#1a1a1a"
    set statusbar-fg "#cccccc"
    set zoom-min 10
  '';
}
