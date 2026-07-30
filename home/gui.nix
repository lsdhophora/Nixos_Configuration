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
  localsend-wrapped = pkgs.symlinkJoin {
    name = "localsend";
    paths = [ pkgs.localsend ];
    postBuild = ''
      rm $out/bin/localsend_app
      cat > $out/bin/localsend_app <<'SCRIPT'
#!/bin/sh
export GTK_THEME=Breeze:dark
export GTK_CSD=0
exec ${pkgs.localsend}/bin/localsend_app "$@"
SCRIPT
      chmod +x $out/bin/localsend_app
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
    localsend-wrapped
    pkgs.kdePackages.ktorrent
    lxgw-wenkai
    shortwave
    video-trimmer
  ];
}
