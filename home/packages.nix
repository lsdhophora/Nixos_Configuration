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
    # Rust toolchain for CPH .rs solutions and rust-analyzer/rustfmt in
    # Emacs (the rust tree-sitter grammar is symlinked separately in
    # home/programs/emacs/files.nix).
    rustc
    cargo
    rustfmt
    rust-analyzer
    mermaid-ascii
  ];
}
