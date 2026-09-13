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
    # Stock emacs-pgtk from nixpkgs-unstable, straight from the binary cache.
    # The previous config overrode it (withNativeCompilation = false plus the
    # popup-title and wayland-cursor patches in patches/emacs-pgtk/), which
    # forced a from-source rebuild of emacs AND every extra package against
    # it. The overrides were dropped to reuse the cache; the patch files are
    # kept in git history.
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
    '';
  };
}
