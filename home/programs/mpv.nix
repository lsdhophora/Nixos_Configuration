{ pkgs, ... }: {
  home.packages = with pkgs; [
    mpv
    mpvScripts.uosc
  ];

  xdg.configFile."mpv/mpv.conf".text = ''
    # Window
    border=no
    keepaspect-window

    # UI: uosc replaces default OSC
    osc=no
    load-scripts=yes

    # Performance
    profile=gpu-hq
    hwdec=auto-safe
    video-sync=display-resample
    interpolation
    tscale=oversample

    # General
    save-position-on-quit=yes
    keep-open=yes
  '';

  xdg.configFile."mpv/input.conf".text = ''
    # uosc toggle
    TAB script-binding uosc/toggle-ui

    # Navigation
    RIGHT seek  5
    LEFT  seek -5
    UP    add volume 2
    DOWN  add volume -2
    [     add speed 0.1
    ]     add speed -0.1
    \     set speed 1.0

    # Playback
    SPACE cycle pause
    >     playlist-next
    <     playlist-prev
    q     quit
    Q     quit-watch-later
  '';
}
