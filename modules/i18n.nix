{ pkgs, ... }: {
  # ibm-plex needs a second visibility path besides fontconfig's conf.d
  # <dir> entry: merging it into the system profile exposes it under
  # /run/current-system/sw/share/fonts (an XDG data dir). Without this,
  # Emacs mis-deduplicates ibm-plex's duplicate OTF/TTF faces when only
  # conf.d registers the package, fails to resolve the bold face, and
  # the modeline falls back to another font.
  environment.systemPackages = [ pkgs.ibm-plex ];

  i18n.defaultLocale = "zh_CN.UTF-8";
  i18n.supportedLocales = [
    "zh_CN.UTF-8/UTF-8"
    "en_US.UTF-8/UTF-8"
  ];

  fonts = {
    enableDefaultPackages = true;
    fontDir.enable = true;
    packages = with pkgs; [
      noto-fonts-cjk-sans-static
      noto-fonts-cjk-serif-static
      noto-fonts
      charis
      ibm-plex
      noto-fonts-color-emoji
      iosevka
    ];
    fontconfig = {
      enable = true;
      defaultFonts = {
        sansSerif = [ "Noto Sans CJK SC" ];
        serif = [ "Noto Serif CJK SC" ];
        monospace = [ "Noto Sans Mono CJK SC" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };
}
