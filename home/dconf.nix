{
  ...
}:

{
  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = [
        "caffeine@patapon.info"
        "just-perfection-desktop@just-perfection"
        "blur-my-shell@aunetx"
        "run-or-raise@edvard.cz"
        "rounded-window-corners@fxgn"
      ];
    };
    "org/gnome/desktop/interface" = {
      font-name = "Adwaita Sans 11";
      accent-color = "purple";
      cursor-theme = "Kuromi-cursor";
      text-scaling-factor = 1.38;
    };
    "org/gnome/settings-daemon/plugins/housekeeping" = {
      donation-reminder-enabled = false;
    };
  };
}
