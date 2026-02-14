{
  config,
  pkgs,
  ...
}:

{
  fonts = {
    enableDefaultPackages = true;
    fontDir.enable = true;
    packages = with pkgs; [
      noto-fonts-cjk-sans-static
      noto-fonts-cjk-serif-static
      noto-fonts
      charis
      ibm-plex
      (ibm-plex.override { families = [ "sans-sc" ]; })
      noto-fonts-color-emoji
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

  i18n.inputMethod = {
    enable = true;
    type = "ibus";
    ibus.engines = with pkgs.ibus-engines; [
      rime
    ];
  };
}
