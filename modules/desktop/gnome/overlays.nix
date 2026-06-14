{ ... }: {
  nixpkgs.overlays = [
    (import ../../../overlays/gnome-sound-recorder.nix)
    (import ../../../overlays/gnome-control-center.nix)
    (import ../../../overlays/gnome-shell.nix)
    (import ../../../overlays/gnome-calendar.nix)
    (import ../../../overlays/evolution-data-server.nix)
    (import ../../../overlays/mutter.nix)
    (final: prev: {
      loupe = prev.loupe.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace src/widgets/image_window.ui \
            --replace-fail "info-outline-symbolic" "view-more-symbolic"
        '';
      });
    })
  ];
}
