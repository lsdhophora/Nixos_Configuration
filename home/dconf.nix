{ lib, pkgs, ... }:

{
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      cursor-size = 24;
      icon-theme = "Adwaita-purple";
      enable-animations = true;
      font-antialiasing = "rgba";
      font-hinting = "full";
      toolkit-accessibility = false;
    };

    "org/gnome/desktop/input-sources" = {
      sources = [
        (pkgs.lib.gvariant.mkTuple [
          "xkb"
          "us"
        ])
        (pkgs.lib.gvariant.mkTuple [
          "ibus"
          "rime"
        ])
      ];
      xkb-options = [ "terminate:ctrl_alt_bksp" ];
    };

    "org/gnome/desktop/peripherals/touchpad" = {
      two-finger-scrolling-enabled = true;
    };

    "org/gnome/desktop/sound" = {
      event-sounds = true;
      theme-name = "__custom";
    };

    "org/gnome/desktop/notifications" = {
      application-children = [
        "gnome-power-panel"
        "org-gnome-console"
      ];
    };

    "org/gnome/nautilus/preferences" = {
      default-folder-viewer = "icon-view";
      migrated-gtk-settings = true;
    };
  };

}
