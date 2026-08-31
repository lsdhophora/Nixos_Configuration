{ pkgs, ... }: {
  home.packages = with pkgs; [
    tree
    ffmpeg
    fastfetch
    imagemagick
    keepassxc
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
