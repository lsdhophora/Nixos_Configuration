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
    gnomeExtensions.rounded-window-corners-reborn
    gnome-epub-thumbnailer
    gnome-themes-extra
    lxgw-wenkai
    localsend
    wordbook
    blanket
    celluloid
    shortwave
    opencode
    transmission_4-gtk
    wl-clipboard
  ];
}
