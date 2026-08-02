{ config, ... }:
let
  repo = "${config.home.homeDirectory}/.config/nixos";
in
{
  # Elisp files are symlinked to the actual files in this repo (out of store),
  # so editing them in Emacs takes effect immediately, no rebuild needed.
  home.file = {
    ".config/emacs/lisp/early-init.el".source =
      config.lib.file.mkOutOfStoreSymlink "${repo}/home/programs/emacs/early-init.el";
    ".config/emacs/lisp/init.el".source =
      config.lib.file.mkOutOfStoreSymlink "${repo}/home/programs/emacs/lisp/init.el";
    ".config/emacs/lisp/nov-config.el".source =
      config.lib.file.mkOutOfStoreSymlink "${repo}/home/programs/emacs/lisp/nov-config.el";
    ".config/emacs/site-lisp/audio-trimmer.el".source =
      config.lib.file.mkOutOfStoreSymlink "${repo}/home/programs/emacs/lisp/audio-trimmer.el";

    # Placeholders (managed by Emacs itself)
    ".config/emacs/init.el".text = "";
    ".local/share/applications/emacsclient-mail.desktop".text = "";
    ".local/share/applications/emacs-mail.desktop".text = "";
    ".local/share/applications/emacsclient.desktop".text = "";
  };
}
