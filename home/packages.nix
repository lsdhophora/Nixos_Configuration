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
    mosh
    clang
    clang-tools
    mermaid-ascii
  ];
}
