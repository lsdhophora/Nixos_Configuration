{ config, lib, repoLib, ... }:

{
  # Elisp files are symlinked to the actual files in this repo (out of store),
  # so editing them in Emacs takes effect immediately, no rebuild needed.
  home.file = lib.mkMerge [
    # early-init.el lives at home/programs/emacs/ (not lisp/), so it needs
    # its own source prefix. The other elisp files are in lisp/.
    (repoLib.mkRepoLinks config {
      targetPrefix = ".config/emacs/lisp/";
      sourcePrefix = "home/programs/emacs/";
      paths = [ "early-init.el" ];
    })
    (repoLib.mkRepoLinks config {
      targetPrefix = ".config/emacs/lisp/";
      sourcePrefix = "home/programs/emacs/lisp/";
      paths = [
        "init.el"
        "nov-config.el"
      ];
    })
    (repoLib.mkRepoLinks config {
      targetPrefix = ".config/emacs/site-lisp/";
      sourcePrefix = "home/programs/emacs/lisp/";
      paths = [ "audio-trimmer.el" ];
    })
    # CPH (competitive programming helper): cph.el is symlinked so
    # edits in the repo apply without rebuild.
    (repoLib.mkRepoLinks config {
      targetPrefix = ".config/emacs/cph/";
      sourcePrefix = "home/programs/emacs/cph/";
      paths = [ "cph.el" ];
    })

    # Placeholders (managed by Emacs itself)
    {
      ".config/emacs/init.el".text = "";
      ".local/share/applications/emacsclient-mail.desktop".text = "";
      ".local/share/applications/emacs-mail.desktop".text = "";
      ".local/share/applications/emacsclient.desktop".text = "";
    }
  ];
}
