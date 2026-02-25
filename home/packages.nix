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
    refine
    lxgw-wenkai
    localsend
    wordbook
    blanket
    celluloid
    shortwave
    bat
    transmission_4-gtk
    wl-clipboard
  ];
}
