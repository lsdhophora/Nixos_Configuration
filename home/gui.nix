{ pkgs, ... }: let
  kdenlive-wrapped = pkgs.symlinkJoin {
    name = "kdenlive";
    paths = [ pkgs.kdePackages.kdenlive ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/kdenlive \
        --set QT_SCALE_FACTOR 1.10 \
        --prefix XDG_DATA_DIRS : "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}" \
        --add-flags "--stylesheet ${./../assets/themes/kdenlive.qss}"
    '';
  };
in
{
  home.packages = with pkgs; [
    # GUI
    blanket
    fluffychat
    gnome-themes-extra
    kdenlive-wrapped
    localsend
    lxgw-wenkai
    shortwave
    transmission_4-gtk
    video-trimmer
  ];
}
