{ pkgs, inputs, repoLib, ... }:
let
  unstablePkgs = repoLib.unstablePkgs inputs pkgs;

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
    '';
  };
in
{
  home.packages = with pkgs; [
    # GUI
    blanket
    # 2.7.0+ fixed OIDC/SSO login (loopback callback bug, krille-chan/fluffychat#3341);
    # 2.8.0 from nixpkgs-unstable instead of the 2.6.0 in nixpkgs 26.05.
    unstablePkgs.fluffychat
    gnome-themes-extra
    kdenlive-wrapped
    localsend-wrapped
    pkgs.kdePackages.ktorrent
    lxgw-wenkai
    shortwave
    video-trimmer
  ];
}
