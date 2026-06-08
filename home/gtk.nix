{ ... }:

{
  xdg.configFile."gtk-3.0/gtk.css".text = ''
    decoration {
      box-shadow: none;
    }
  '';
}
