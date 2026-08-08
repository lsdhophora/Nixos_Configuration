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
    online-judge-tools
    python3Packages.online-judge-template-generator
    (python3.withPackages (ps: [ ps.selenium ]))
    geckodriver
    time
    clang
    clang-tools
  ];
}
