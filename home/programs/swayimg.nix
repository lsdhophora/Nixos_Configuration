{ pkgs, ... }: {
  home.packages = [ pkgs.swayimg ];

  xdg.configFile."swayimg/config".text = ''
    [info]
    show = no

    [font]
    name = IBM Plex Sans
    size = 14

    [keys.viewer]
    h = step_left 10
    j = step_down 10
    k = step_up 10
    l = step_right 10
    n = next_file
    p = prev_file
  '';
}
