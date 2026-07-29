{ lib, pkgs, ... }: {
  # Don't use gtk.enable - it creates read-only symlinks that prevent
  # KDE's kde-gtk-config from saving GTK settings.
  # Instead, write settings as real files.
  home.file = {
    ".config/gtk-3.0/settings.ini".text = ''
      [Settings]
      gtk-cursor-theme-name=Adwaita
      gtk-cursor-theme-size=24
      gtk-font-name=IBM Plex Sans 14
    '';
    ".config/gtk-3.0/gtk.css".source = ./../assets/gtk/gtk3.css;
    ".config/gtk-4.0/settings.ini".text = ''
      [Settings]
      gtk-cursor-theme-name=Adwaita
      gtk-cursor-theme-size=24
      gtk-font-name=IBM Plex Sans 14
    '';
    ".config/gtk-4.0/gtk.css".source = ./../assets/gtk/gtk4.css;
  };
}
