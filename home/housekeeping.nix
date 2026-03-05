{
  ...
}:

{
  home.file.".local/share/applications/userapp-transmission-gtk-33DDK3.desktop" = {
    text = ''
      [Desktop Entry]
      Name=userapp-transmission-gtk-33DDK3
      NoDisplay=true
    '';
    force = true;
  };

  # Hide CUPS printing related apps
  home.file.".local/share/applications/config-printer.desktop".text = "";
  home.file.".local/share/applications/cups.desktop".text = "";
  home.file.".local/share/applications/org.gtk.PrintEditor4.desktop".text = "";
}
