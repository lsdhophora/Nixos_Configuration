{ lib, pkgs, ... }:

{
  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = [
        "just-perfection-desktop@just-perfection"
        "hide-cursor@elcste.com"
        "caffeine@patapon.info"
        "customize-ibus@hollowman.ml"
        "app-hider@lynith.dev"
        "color-picker@tuberry"
        "paperwm@paperwm.github.com"
        "touchpad@gpawru"
      ];
      favorite-apps = [
        "firefox.desktop"
        "emacs.desktop"
      ];
      always-show-log-out = true;
      disable-user-extensions = false;
      last-selected-power-profile = "power-saver";
      welcome-dialog-last-shown-version = "49.4";
    };

    "org/gnome/shell/extensions/just-perfection" = {
      accessibility-menu = false;
      activities-button = true;
      panel = true;
    };

    "org/gnome/shell/extensions/customize-ibus" = {
      custom-font = "IBM Plex Sans Medium 14";
      enable-auto-switch = false;
      use-custom-font = true;
      use-input-indicator = false;
    };

    "org/gnome/shell/extensions/app-hider" = {
      hidden-apps = [
        "config-printer.desktop"
        "cups.desktop"
        "org.gtk.PrintEditor4.desktop"
        "kvantummanager.desktop"
        "system-config-printer.desktop"
      ];
    };

    "org/gnome/desktop/background" = {
      picture-uri = "file:///run/current-system/sw/share/backgrounds/gnome/tubes-l.jxl";
      picture-uri-dark = "file:///run/current-system/sw/share/backgrounds/gnome/tubes-d.jxl";
    };

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

    "org/gnome/desktop/wm/preferences" = {
      action-middle-click-titlebar = "none";
      resize-with-right-button = false;
      button-layout = "appmenu:";
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

    "org/gnome/desktop/app-folders" = {
      folder-children = [
        "System"
        "Utilities"
      ];
    };

    "org/gnome/desktop/app-folders/folders/System" = {
      name = "X-GNOME-Shell-System.directory";
      translate = true;
      apps = [
        "org.gnome.baobab.desktop"
        "org.gnome.DiskUtility.desktop"
        "org.gnome.Logs.desktop"
        "org.gnome.SystemMonitor.desktop"
        "org.gnome.Calendar.desktop"
        "org.gnome.TextEditor.desktop"
      ];
    };

    "org/gnome/desktop/app-folders/folders/Utilities" = {
      name = "X-GNOME-Shell-Utilities.directory";
      translate = true;
      apps = [
        "org.gnome.Decibels.desktop"
        "org.gnome.Connections.desktop"
        "org.gnome.font-viewer.desktop"
        "org.gnome.Loupe.desktop"
        "transmission-gtk.desktop"
        "org.gnome.SoundRecorder.desktop"
        "de.haeckerfelix.Shortwave.desktop"
        "org.gnome.seahorse.Application.desktop"
        "LocalSend.desktop"
        "org.gnome.Music.desktop"
        "org.gnome.Calculator.desktop"
        "org.gnome.Extensions.desktop"
        "org.gnome.Snapshot.desktop"
        "com.rafaelmardojai.Blanket.desktop"
        "io.github.celluloid_player.Celluloid.desktop"
        "dev.mufeed.Wordbook.desktop"
        "Fluffychat.desktop"
        "org.gnome.gitlab.YaLTeR.VideoTrimmer.desktop"
        "org.kde.kdenlive.desktop"
        "org.gnome.Papers.desktop"
      ];
    };

    "org/gnome/mutter" = {
      experimental-features = [
        "scale-monitor-framebuffer"
        "variable-refresh-rate"
        "xwayland-native-scaling"
      ];
    };

    "org/gnome/nautilus/preferences" = {
      default-folder-viewer = "icon-view";
      migrated-gtk-settings = true;
    };

    "org/gnome/settings-daemon/plugins/housekeeping" = {
      donation-reminder-enabled = false;
    };

    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-type = "nothing";
    };

    "org/gnome/settings-daemon/plugins/media-keys" = {
      volume-step = 5;
    };

    "org/gnome/settings-daemon/plugins/color" = {
      night-light-schedule-automatic = false;
    };

    "org/gnome/tweaks" = {
      show-extensions-notice = false;
    };

    "org/gnome/Loupe" = {
      show-properties = true;
    };

    "org/gnome/maps" = {
      window-maximized = true;
      transportation-type = "pedestrian";
      zoom-level = 2;
    };

    "org/gnome/control-center" = {
      last-panel = "display";
    };

    "org/gnome/calendar" = {
      weather-settings = lib.gvariant.mkTuple [
        false
        true
        ""
        (lib.gvariant.mkNothing "mv")
      ];
    };
  };

}
