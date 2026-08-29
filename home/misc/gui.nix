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
      # Tray icon: the white-logo asset swap used to live here, but the
      # icon is passed as a relative path that appindicator never loads;
      # the fix is a source patch in overlays/localsend.nix that switches
      # the tray to the hicolor theme icon.
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
