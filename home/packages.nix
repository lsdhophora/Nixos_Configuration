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
    kitty
    bluetui
    pulsemixer
  ];
}
