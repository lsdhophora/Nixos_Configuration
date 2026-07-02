{ pkgs, ... }: {
  programs.emacs = {
    enable = true;
    package = pkgs.emacs-pgtk;
    extraPackages =
      epkgs: with epkgs; [
        direnv
        auctex
        nix-mode
        magit
        nov
        nerd-icons
        dashboard
        trashed
        emms
      ];
    extraConfig = ''
      (add-to-list 'load-path
        (expand-file-name "lisp" user-emacs-directory))
      (load "~/.config/emacs/lisp/early-init")
      (load "~/.config/emacs/lisp/init")
      (load "~/.config/emacs/lisp/nov-config")
    '';
  };
}
