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
    (pkgs.evince.overrideAttrs (oldAttrs: {
      mesonFlags = (oldAttrs.mesonFlags or [ ]) ++ [
        "-Dviewer=false"
        "-Dpreviewer=false"
        "-Dthumbnailer=true"
        "-Dintrospection=false"
        "-Ddbus=false"
        "-Dgtk_doc=false"
        "-Duser_doc=false"
        "-Dcomics=disabled"
        "-Ddjvu=disabled"
        "-Ddvi=disabled"
        "-Dps=disabled"
        "-Dtiff=disabled"
        "-Dxps=disabled"
      ];
      outputs = builtins.filter (output: output != "devdoc") oldAttrs.outputs;
    }))
    zathura
  ];
}
