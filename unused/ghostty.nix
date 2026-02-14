{
  pkgs,
  ...
}:

{
  programs.ghostty = {
    enable = true;
    package = (
      pkgs.ghostty.overrideAttrs (old: {
        buildInputs =
          old.buildInputs
          ++ (with pkgs.gst_all_1; [
            gstreamer
            gst-plugins-base
            gst-plugins-good
          ]);
        postInstall = (old.postInstall or "") + ''
          rm -f $out/share/nautilus-python/extensions/ghostty.py
        '';
      })
    );
    settings = {
      theme = "Adwaita Dark";
      "cursor-style" = "block";
      "shell-integration-features" = "no-cursor";
      "bell-features" = "no-title,attention,audio";
      "bell-audio-path" = "bell-audio.wav";
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
