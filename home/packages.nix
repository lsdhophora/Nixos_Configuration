{ pkgs, ... }:

let
  kdenlive-wrapped = pkgs.symlinkJoin {
    name = "kdenlive";
    paths = [ pkgs.kdePackages.kdenlive ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/kdenlive \
        --set QT_QPA_PLATFORM xcb \
        --set QT_SCALE_FACTOR 1.10 \
        --set QT_QPA_PLATFORMTHEME xdgdesktopportal \
        --prefix XDG_DATA_DIRS : "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}" \
        --add-flags "--stylesheet ${./../assets/themes/kdenlive.qss}"
    '';
  };
in
{
  home.packages = with pkgs; [
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
    video-trimmer
    kdenlive-wrapped
  ];
}
