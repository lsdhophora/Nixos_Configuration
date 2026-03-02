{ pkgs, ... }:

{
  programs.ghostty = {
    enable = true;
    package = (
      pkgs.ghostty.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          rm -f $out/share/nautilus-python/extensions/ghostty.py
        '';
      })
    );
    settings = {
      theme = "Adwaita Dark";
      "cursor-style" = "block";
      "shell-integration-features" = "no-cursor,title";
      "bell-features" = "no-title,attention";
      "font-family" = [ "Maple Mono NF CN" ];
      "link-url" = false;
      "working-directory" = "inherit";
      "right-click-action" = "ignore";
      "resize-overlay" = "never";
    };
  };
}
