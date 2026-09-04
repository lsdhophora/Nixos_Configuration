{
  config,
  lib,
  pkgs,
  repoLib,
  ...
}:

{
  # Elisp files are symlinked to the actual files in this repo (out of store),
  # so editing them in Emacs takes effect immediately, no rebuild needed.
  home.file = lib.mkMerge [
    # early-init.el and init.el live at home/programs/emacs/ (not lisp/).
    (repoLib.mkRepoLinks config {
      targetPrefix = ".config/emacs/";
      sourcePrefix = "home/programs/emacs/";
      paths = [
        "early-init.el"
        "init.el"
      ];
    })
    # CPH (competitive programming helper): cph.el is symlinked so
    # edits in the repo apply without rebuild.
    (repoLib.mkRepoLinks config {
      targetPrefix = ".config/emacs/cph/";
      sourcePrefix = "home/programs/emacs/lisp/cph/";
      paths = [ "cph.el" ];
    })
    # rust tree-sitter grammar for rust-ts-mode.  Emacs looks for
    # libtree-sitter-rust.so under ~/.config/emacs/tree-sitter/; the
    # nixpkgs grammar ships it as $out/parser (a DSO with the same
    # content), so link it under the name Emacs expects.
    {
      ".config/emacs/tree-sitter/libtree-sitter-rust.so".source =
        "${pkgs.tree-sitter-grammars.tree-sitter-rust}/parser";
    }

    # Placeholders (managed by Emacs itself)
    {
      ".local/share/applications/emacsclient-mail.desktop".text = "";
      ".local/share/applications/emacs-mail.desktop".text = "";
      ".local/share/applications/emacsclient.desktop".text = "";
    }
  ];
}
