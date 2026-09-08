{ lib, pkgs, ... }:

{
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      # No cursor-size/cursor-theme here: kde-gtk-config's kded "gtkconfig"
      # daemon owns those on Wayland (writes kcminputrc's cursorSize into
      # GSettings and gtk-3.0/settings.ini).  Pinning them here made GTK
      # cursors drift from the desktop cursor after every home-manager switch.
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

    "org/gtk/Settings/FileChooser" = {
      sort-directories-first = true;
      startup-mode = "cwd";
    };
  };

}
