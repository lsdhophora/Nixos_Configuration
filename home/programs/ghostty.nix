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
      "bell-features" = "no-title,no-attention,system";
      "font-family" = [
        "IBM Plex Mono"
        "IBM Plex Sans SC"
      ];
      "font-size" = "14";
      "font-style" = "Bold";
      "font-style-bold" = false;
      "link-url" = false;
      "right-click-action" = "ignore";
      "resize-overlay" = "never";
    };
  };
}
