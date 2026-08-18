{ pkgs, ... }:
{
  # Only manage gtk.css (read-only, does not need modification)
  # settings.ini is intentionally not managed here. It must be writable
  # so KDE's kde-gtk-config gtkconfig KDED module can write the GTK theme choices.
  home.file = builtins.listToAttrs (
    map
      (major: {
        name = ".config/gtk-${major}.0/gtk.css";
        value.source = ./../../assets/gtk/gtk${major}.css;
      })
      [
        "3"
        "4"
      ]
  ) // {
    # environment.d is read by the systemd user session (Plasma 6 Wayland) so
    # apps launched from menus/.desktop files also inherit LD_PRELOAD.
    ".config/environment.d/gtk-nocsd.conf".text = ''
      LD_PRELOAD=${pkgs.gtk-nocsd}/lib/libgtk-nocsd.so
    '';
  };

  # GTK-NoCSD: LD_PRELOAD library that disables client-side decorations (CSD)
  # in GTK3/4, LibHandy and LibAdwaita apps, restoring KWin-drawn titlebars
  # (SSD). GTK3 on KDE already gets SSD via the Breeze theme + KDE gtk-modules;
  # this additionally covers GTK4/LibAdwaita apps, which always use CSD.
  home.sessionVariables = {
    LD_PRELOAD = "${pkgs.gtk-nocsd}/lib/libgtk-nocsd.so";
  };
}
