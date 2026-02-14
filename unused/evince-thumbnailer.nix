{
  pkgs,
  ...
}:

{
  home.packages = [
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
  ];
}
