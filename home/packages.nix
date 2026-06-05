{ pkgs, ... }:
let
  kdenlive-wrapped = pkgs.symlinkJoin {
    name = "kdenlive";
    paths = [ pkgs.kdePackages.kdenlive ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/kdenlive \
        --set QT_SCALE_FACTOR 1.10 \
        --set QT_QPA_PLATFORM xcb \
        --set QT_QPA_PLATFORMTHEME xdgdesktopportal \
        --set QT_STYLE_OVERRIDE breeze \
        --prefix XDG_DATA_DIRS : "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}" \
        --add-flags "--stylesheet ${./../assets/themes/kdenlive.qss}"
    '';
  };
in
{
  home.packages = with pkgs; [
    # CLI
    tmux
    wl-clipboard

    # GUI
    blanket
    celluloid
    fluffychat
    gnome-epub-thumbnailer
    gnomeExtensions.app-hider
    gnomeExtensions.blur-my-shell
    gnomeExtensions.customize-ibus
    gnomeExtensions.just-perfection
    gnomeExtensions.rounded-window-corners-reborn
    gnomeExtensions.run-or-raise
    gnomeExtensions.runcat
    gnome-themes-extra
    kdePackages.breeze
    kdenlive-wrapped
    localsend
    lxgw-wenkai
    shortwave
    transmission_4-gtk
    video-trimmer
    wordbook
  ];
}
