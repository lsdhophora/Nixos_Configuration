{ pkgs, inputs, ... }: {
  programs.emacs = {
    enable = true;
    package = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.emacs-pgtk;
    extraPackages =
      _: with inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.emacs-pgtk.pkgs; [
        direnv
        auctex
        nix-mode
        magit
        nov
        nerd-icons
        dashboard
        trashed
        emms
        straight
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
