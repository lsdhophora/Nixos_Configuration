{ pkgs, ... }:

{
  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = [
        "caffeine@patapon.info"
        "just-perfection-desktop@just-perfection"
        "blur-my-shell@aunetx"
        "run-or-raise@edvard.cz"
      ];
      favorite-apps = [
        "librewolf.desktop"
        "emacs.desktop"
        "org.gnome.Console.desktop"
        "org.gnome.Nautilus.desktop"
      ];
      disable-user-extensions = false;
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
      indicator-position-max = 0;
    };

    "org/gnome/shell/extensions/just-perfection" = {
      accessibility-menu = false;
      activities-button = true;
      panel = true;
    };

    "org/gnome/desktop/interface" = {
      font-name = "Adwaita Sans 11";
      accent-color = "purple";
      cursor-theme = "Kuromi-cursor";
      text-scaling-factor = 1.38;
      color-scheme = "prefer-dark";
      gtk-theme = "Adwaita-dark";
      icon-theme = "Adwaita";
      enable-animations = true;
    };

    "org/gnome/desktop/background" = {
      picture-uri = "file:///run/current-system/sw/share/backgrounds/gnome/Kuromi%20Aesthetics.jpg";
      picture-uri-dark = "file:///run/current-system/sw/share/backgrounds/gnome/Kuromi%20Aesthetics.jpg";
      picture-options = "zoom";
      primary-color = "#8B5CF6";
      secondary-color = "#000000";
      color-shading-type = "solid";
    };

    "org/gnome/desktop/screensaver" = {
      picture-uri = "file:///run/current-system/sw/share/backgrounds/gnome/Kuromi%20Aesthetics.jpg";
      picture-options = "zoom";
      primary-color = "#8B5CF6";
      secondary-color = "#000000";
      color-shading-type = "solid";
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
    };

    "org/gnome/desktop/peripherals/touchpad" = {
      two-finger-scrolling-enabled = true;
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
      ];
    };

    "org/gnome/nautilus/preferences" = {
      default-folder-viewer = "icon-view";
    };

    "org/gnome/settings-daemon/plugins/housekeeping" = {
      donation-reminder-enabled = false;
    };

    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-type = "nothing";
    };

    "org/gnome/tweaks" = {
      show-extensions-notice = false;
    };
  };
}
