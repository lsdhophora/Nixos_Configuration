{ ... }:
{
  # Only manage gtk.css (read-only fine, doesn't need modification)
  # settings.ini is intentionally NOT managed here - it must be writable
  # so KDE's kde-gtk-config gtkconfig KDED module can write GTK theme choices.
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
  );
}
