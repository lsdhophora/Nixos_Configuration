{ pkgs, ... }: {
  home.packages = with pkgs; [
    tree
    ffmpeg
    fastfetch
    imagemagick
    pandoc
    nixfmt
    nixd
    unzip
    gnome-sound-recorder
  ];
}
