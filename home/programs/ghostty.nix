{ pkgs, ... }:

{
  home.packages = with pkgs; [
    nautilus-open-any-terminal
  ];

  dconf.settings."com/github/stunkymonkey/nautilus/open-any-terminal" = {
    terminal = "ghostty";
  };

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
      "shell-integration-features" = "no-cursor";
      "bell-features" = "no-title,attention";
      "font-family" = [
        "Adwaita Mono"
        "Noto Sans CJK SC"
      ];
      "link-url" = false;
      "working-directory" = "inherit";
      "right-click-action" = "ignore";
      "resize-overlay" = "never";
    };
  };
}
