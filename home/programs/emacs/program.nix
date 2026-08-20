{ pkgs, inputs, repoLib, ... }:
let
  unstableEmacs = repoLib.unstablePkgs inputs pkgs;
in
{
  programs.emacs = {
    enable = true;
    package = unstableEmacs.emacs-pgtk;
    extraPackages =
      _: with unstableEmacs.emacs-pgtk.pkgs; [
        direnv
        auctex
        nix-mode
        magit
        nov
        nerd-icons
        dashboard
        trashed
        emms
        corfu
        corfu-terminal
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
