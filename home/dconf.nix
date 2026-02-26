{ pkgs, ... }:

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
      favorite-apps = [
        "librewolf.desktop"
        "emacs.desktop"
        "com.mitchellh.ghostty.desktop"
        "org.gnome.Nautilus.desktop"
      ];
      disable-user-extensions = false;
      last-selected-power-profile = "power-saver";
      welcome-dialog-last-shown-version = "49.4";
    };

    "org/gnome/shell/extensions/blur-my-shell" = {
      settings-version = 2;
    };
    "org/gnome/shell/extensions/blur-my-shell/panel" = {
      pipeline = "pipeline_default";
      static-blur = true;
    };
    "org/gnome/shell/extensions/blur-my-shell/overview" = {
      pipeline = "pipeline_default";
    };
    "org/gnome/shell/extensions/blur-my-shell/dash-to-dock" = {
      pipeline = "pipeline_default_rounded";
    };
    "org/gnome/shell/extensions/blur-my-shell/lockscreen" = {
      pipeline = "pipeline_default";
    };
    "org/gnome/shell/extensions/blur-my-shell/screenshot" = {
      pipeline = "pipeline_default";
    };
    "org/gnome/shell/extensions/blur-my-shell/coverflow-alt-tab" = {
      pipeline = "pipeline_default";
    };

    "org/gnome/shell/extensions/caffeine" = {
      cli-toggle = false;
      indicator-position-max = 1;
      user-enabled = false;
    };

    "org/gnome/shell/extensions/just-perfection" = {
      accessibility-menu = false;
      activities-button = true;
      panel = true;
    };

    "org/gnome/desktop/interface" = {
      font-name = "Adwaita Sans 11";
      document-font-name = "Adwaita Sans 11";
      accent-color = "purple";
      cursor-theme = "Kuromi-cursor";
      cursor-size = 32;
      text-scaling-factor = 1.0;
      color-scheme = "prefer-dark";
      gtk-theme = "Adwaita-dark";
      icon-theme = "Adwaita";
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
        "org.gnome.Papers.desktop"
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
      ];
    };

    "org/gnome/mutter" = {
      experimental-features = [
        "scale-monitor-framebuffer"
        "variable-refresh-rate"
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

    "org/gnome/Console" = {
      font-scale = 1.0;
    };

    "org/gnome/maps" = {
      window-maximized = true;
      transportation-type = "pedestrian";
      zoom-level = 2;
    };

    "org/gnome/papers" = {
      night-mode = false;
    };

    "org/gnome/papers/default" = {
      continuous = true;
      dual-page = false;
      dual-page-odd-left = false;
      enable-spellchecking = true;
      show-sidebar = false;
      sizing-mode = "automatic";
    };

    "org/gnome/control-center" = {
      last-panel = "display";
    };
  };
}
