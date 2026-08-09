{ ... }:
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
  );
}
