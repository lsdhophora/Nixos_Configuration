{
  pkgs,
  inputs,
  repoLib,
  ...
}:
{
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
    # TypeScript/JavaScript runtime with built-in formatter, linter,
    # and language server (`deno lsp`, `deno fmt`, `deno check`).
    deno
    mermaid-ascii
    # LibreOffice, Qt/KF6 variant, from the UNSTABLE channel: the pinned
    # nixos-26.05 revision has no Hydra build for LibreOffice (local
    # from-source compile), while nixos-unstable is continuously cached.
    # On Plasma 6 the Qt backend follows the Breeze theme and uses native
    # KDE dialogs; the plain GTK build looks inconsistent on KDE.
    (repoLib.unstablePkgs inputs pkgs).libreoffice-qt
  ];
}
