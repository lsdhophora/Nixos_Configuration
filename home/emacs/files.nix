{ ... }: {
  home.file = {
    ".config/emacs/lisp/early-init.el".source = ./early-init.el;
    ".config/emacs/lisp/init.el".source = ./lisp/init.el;
    ".config/emacs/lisp/nov-config.el".source = ./lisp/nov-config.el;
    ".config/emacs/site-lisp/audio-trimmer.el".source = ./lisp/audio-trimmer.el;
    ".config/emacs/init.el".text = "";
    ".local/share/applications/emacsclient-mail.desktop".text = "";
    ".local/share/applications/emacs-mail.desktop".text = "";
    ".local/share/applications/emacsclient.desktop".text = "";
  };
}
