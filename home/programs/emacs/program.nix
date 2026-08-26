{
  pkgs,
  inputs,
  repoLib,
  ...
}:
let
  unstableEmacs = repoLib.unstablePkgs inputs pkgs;
in
{
  programs.emacs = {
    enable = true;
    # Emit one separator below a popup menu title instead of two (see
    # patches/emacs-pgtk/popup-title-single-separator.patch).
    package = unstableEmacs.emacs-pgtk.overrideAttrs (oldAttrs: {
      patches = (oldAttrs.patches or [ ]) ++ [
        ./../../../patches/emacs-pgtk/popup-title-single-separator.patch
      ];
    });
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
    '';
  };
}
