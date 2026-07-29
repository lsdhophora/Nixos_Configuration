{ lib, pkgs, ... }: {
  # Only manage gtk.css (read-only fine, doesn't need modification)
  # settings.ini is intentionally NOT managed here - it must be writable
  # so KDE's kde-gtk-config gtkconfig KDED module can write GTK theme choices.
  home.file = {
    ".config/gtk-3.0/gtk.css".source = ./../assets/gtk/gtk3.css;
    ".config/gtk-4.0/gtk.css".source = ./../assets/gtk/gtk4.css;
  };
}
