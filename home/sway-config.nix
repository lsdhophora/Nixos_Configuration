{ pkgs, ... }: {
  xdg.configFile."alacritty/alacritty.toml".source =
    ../assets/sway/alacritty.toml;
  xdg.configFile."sway/toggle-dropdown.sh" = {
    source = ../assets/sway/toggle-dropdown.sh;
    executable = true;
    force = true;
  };
  xdg.configFile."sway/mpv-border.sh" = {
    source = ../assets/sway/mpv-border.sh;
    executable = true;
    force = true;
  };
  xdg.configFile."i3blocks/config".source =
    ../assets/sway/i3blocks/config;
  xdg.configFile."sway/i3blocks/layout".source =
    ../assets/sway/i3blocks/layout;
  xdg.configFile."sway/i3blocks/battery".source =
    ../assets/sway/i3blocks/battery;
  xdg.configFile."sway/i3blocks/brightness".source =
    ../assets/sway/i3blocks/brightness;
  xdg.configFile."sway/i3blocks/datetime".source =
    ../assets/sway/i3blocks/datetime;
  xdg.configFile."sway/i3blocks/volume".source =
    ../assets/sway/i3blocks/volume;
  xdg.configFile."sway/i3blocks/wifi".source =
    ../assets/sway/i3blocks/wifi;
  xdg.configFile."emacs/lisp/nmcli-wifi.el".source =
    ../assets/emacs/nmcli-wifi.el;
}
