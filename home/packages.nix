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
    gnomeExtensions.customize-ibus
    gnomeExtensions.app-hider
    gnome-epub-thumbnailer
    gnome-themes-extra
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

  home.file.".local/share/applications/config-printer.desktop".text = "";
  home.file.".local/share/applications/cups.desktop".text = "";
  home.file.".local/share/applications/org.gtk.PrintEditor4.desktop".text = "";
}
