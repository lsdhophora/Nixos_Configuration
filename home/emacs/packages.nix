{ pkgs, ... }: {
  home.packages = with pkgs; [
    vips
    nerd-fonts.hack
    epub-thumbnailer
    mutagen
  ];
}
