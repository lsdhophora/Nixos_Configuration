{ pkgs, ... }: {
  home.packages = with pkgs; [
    ibm-plex
    tree
    ffmpeg
    fastfetch
    imagemagick
    pandoc
    nixfmt
    nixd
    unzip
    kitty
    mosh
    clang
    clang-tools
    ascii-align
    ascii-box-aligner
  ];
}
