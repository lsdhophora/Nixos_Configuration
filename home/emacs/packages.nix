{ pkgs, ... }: {
  home.packages = with pkgs; [
    vips
    nerd-fonts.hack
    epub-thumbnailer
    (pkgs.mpv.override {
      mpv-unwrapped = pkgs.mpv-unwrapped.overrideAttrs (old: {
        postFixup = (old.postFixup or "") + ''
          rm -f $out/share/applications/mpv.desktop
          rm -f $out/share/applications/umpv.desktop
        '';
      });
    })
    mutagen
  ];
}
