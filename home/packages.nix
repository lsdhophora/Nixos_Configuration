{
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    gnomeExtensions.caffeine
    gnomeExtensions.just-perfection
    gnomeExtensions.blur-my-shell
    gnomeExtensions.run-or-raise
    gnome-epub-thumbnailer
    gnome-themes-extra
    lxgw-wenkai
    localsend
    wordbook
    blanket
    celluloid
    opencode
    transmission_4-gtk
    wl-clipboard
  ];
}
