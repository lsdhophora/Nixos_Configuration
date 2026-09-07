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
    # withNativeCompilation = false: skip gccemacs native-compiling of every
    # .el file, which dominates the build time and is not needed locally.
    package =
      (unstableEmacs.emacs-pgtk.override { withNativeCompilation = false; }).overrideAttrs
        (oldAttrs: {
          patches = (oldAttrs.patches or [ ]) ++ [
            ./../../../patches/emacs-pgtk/popup-title-single-separator.patch
            # Push the GtkSettings cursor theme/size down to GDK on Wayland:
            # GDK falls back to a hard-coded 24px cursor there (KDE does not
            # provide "gtk-cursor-theme-size" on GDK's settings channel), which
            # makes the pointer inside buffers smaller than the system cursor.
            ./../../../patches/emacs-pgtk/pgtk-wayland-cursor-theme.patch
          ];
        });
    extraPackages =
      _: with unstableEmacs.emacs-pgtk.pkgs; [
        direnv
        auctex
        # nix-log.el calls nix-read-file/nix-read-attr (defined in
        # nix-shell.el) without requiring nix-shell, so the native
        # compiler warns.  Mirror the upstream fix (autoload
        # declarations); see patches/nix-mode/nix-log-autoloads.patch.
        (repoLib.applyPatches [
          ./../../../patches/nix-mode/nix-log-autoloads.patch
        ] nix-mode)
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
