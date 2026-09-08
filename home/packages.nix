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
    # Interactive debugging of CPH solutions (cph-debug-testcase-at-point
    # in the judge buffer).  lldb matches the clang version above.
    lldb
    # Rust toolchain for rust-analyzer/rustfmt in Emacs (the rust
    # tree-sitter grammar is symlinked separately in
    # home/programs/emacs/files.nix).
    rustc
    cargo
    rustfmt
    rust-analyzer
    mermaid-ascii
  ];
}
