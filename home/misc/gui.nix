{ pkgs, ... }:
let
  # Wrap one package with symlinkJoin and postBuild.
  wrapPackage =
    {
      name,
      pkg,
      postBuild,
      buildInputs ? [ ],
    }:
    pkgs.symlinkJoin {
      inherit name postBuild buildInputs;
      paths = [ pkg ];
    };
  kdenlive-wrapped = wrapPackage {
    name = "kdenlive";
    pkg = pkgs.kdePackages.kdenlive;
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/kdenlive \
        --set QT_SCALE_FACTOR 1.10 \
        --prefix XDG_DATA_DIRS : "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}" \
        --add-flags "--stylesheet ${./../../assets/themes/kdenlive.qss}"
    '';
  };
  localsend-wrapped = wrapPackage {
    name = "localsend";
    pkg = pkgs.localsend;
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/localsend_app \
        --set GTK_THEME "Breeze" \
        --set GTK_CSD 0
      # LocalSend forces the white logo as the Linux tray icon
      # (app/lib/util/native/tray_helper.dart -> logo32White), which is
      # invisible on the light Breeze panel. Replace it with the colored
      # logo so the tray icon matches the taskbar icon.
      rm -f $out/app/localsend/data/flutter_assets/assets/img/logo-32-white.png
      cp ${pkgs.localsend}/app/localsend/data/flutter_assets/assets/img/logo-32.png \
        $out/app/localsend/data/flutter_assets/assets/img/logo-32-white.png
    '';
  };
in
{
  home.packages = with pkgs; [
    # GUI
    blanket
    # Element (official Matrix client) replaces fluffychat: fluffychat's
    # Linux OIDC/SSO login is broken against matrix.org MAS
    # (krille-chan/fluffychat#3341, #3380).
    element-desktop
    gnome-themes-extra
    kdenlive-wrapped
    localsend-wrapped
    pkgs.kdePackages.ktorrent
    lxgw-wenkai
    shortwave
    video-trimmer
  ];
}
