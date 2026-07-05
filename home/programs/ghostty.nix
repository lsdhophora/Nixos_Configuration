{ pkgs, inputs, ... }: {
  programs.ghostty = {
    enable = true;
    package = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system}.ghostty.overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''
        rm -f $out/share/nautilus-python/extensions/ghostty.py
      '';
    });
    settings = {
      theme = "Adwaita Dark";
      background = "#242424";
      "cursor-style" = "block";
      "shell-integration-features" = "no-cursor,title";
      "font-family" = "IBM Plex Mono";
      "font-size" = "14";
      "link-url" = false;
      "right-click-action" = "ignore";
      "resize-overlay" = "never";
    };
  };
}
