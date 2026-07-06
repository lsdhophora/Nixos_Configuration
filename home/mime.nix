{ ... }: {
  xdg.configFile."sway-mimeapps.list".text = ''
    [Default Applications]
    inode/directory=emacs.desktop
    application/pdf=zathura.desktop
  '';
}
