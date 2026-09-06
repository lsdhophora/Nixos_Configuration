{ ... }:
{
  # Declarative Plasma panel / Task Manager config (plasma-manager).
  #
  # Mechanism: on every Plasma session start, the autostart script:
  #   1. removes plasma-org.kde.plasma.desktop-appletsrc (prevents unbounded growth)
  #   2. rebuilds the panel/widgets from the declarations below with
  #      qdbus evaluateScript
  # Therefore this file regenerates on every start and does not need
  # persistence. It was removed from the files list in
  # persistence-kde.nix (same directory).
  #
  # UI changes (unpin, drag widgets) are overwritten on the next start.
  # To change pins, edit this file + `home-manager switch --flake .#FeiHsueh`.
  programs.plasma = {
    enable = true;

    panels = [
      {
        location = "bottom";
        height = 44;
        # Lock this panel (UserImmutable) right inside the layout script, after
        # the widgets above have been added and in the same evaluateScript run:
        # a separate later lockCorona() raced the layout script and could leave
        # the panel unbuilt.  lockCorona() additionally raises the corona-level
        # immutability -- Applet::immutability() only follows the corona (not
        # the per-containment lock), so without it applets still report Mutable
        # and keep their "Configure..." menu entries.
        extraSettings = "" + "panel.locked = true;" + "\n" + "lockCorona(true);";
        widgets = [
          {
            kickoff = {
              icon = "nix-snowflake";
              settings.General.systemFavorites = "suspend,hibernate,reboot,shutdown";
            };
          }
          # Flexible spacer (expanding = Plasma default; mirrors the live panel).
          # Explicit `expanding = true` avoids the inert `length` leftovers the
          # Plasma UI writes for flexible spacers.
          {
            panelSpacer = {
              expanding = true;
            };
          }
          {
            # Task manager pinned apps
            iconTasks = {
              launchers = [
                "applications:org.wezfurlong.wezterm.desktop"
                "preferred://filemanager"
                "applications:librewolf.desktop"
              ];
              # No hover tooltip/preview popup when hovering task icons
              appearance.showTooltips = false;
              # No speaker indicator on tasks that play audio
              appearance.indicateAudioStreams = false;
              # No media/volume controls inside the hover tooltip
              # (tooltipControls has no typed option in plasma-manager; the
              # generic settings passthrough lands it in [Configuration][General])
              settings.General.tooltipControls = false;
            };
          }
          {
            panelSpacer = {
              expanding = true;
            };
          }
          {
            systemTray = {
              # Icons fill the panel height (same height as taskbar icons)
              icons.scaleToFit = true;
              # extra = restore the original extraItems behavior (main bar does not fill)
              items.extra = [
                "org.kde.plasma.devicenotifier"
                "org.kde.plasma.notifications"
                "org.kde.plasma.cameraindicator"
                "org.kde.plasma.clipboard"
                "org.kde.plasma.volume"
                "org.kde.plasma.keyboardlayout"
                "org.kde.plasma.keyboardindicator"
                "org.kde.plasma.networkmanagement"
                "org.kde.plasma.printmanager"
                "org.kde.kscreen"
                "org.kde.plasma.brightness"
                "org.kde.plasma.battery"
                "org.kde.plasma.bluetooth"
                "org.kde.plasma.mediacontroller"
              ];
            };
          }
          "org.kde.plasma.digitalclock"
          "org.kde.plasma.showdesktop"
          # marginsseparator sits at the far right edge in the live layout
          "org.kde.plasma.marginsseparator"
        ];
      }
    ];

    # Hide per-widget "Configure..." menu entries while the panel is locked.
    # The generic applet configure action stays visible when locked because it
    # is granted through the plasma/allow_configure_when_locked Kiosk action;
    # denying it makes the action (and every menu item bound to it, e.g. the
    # Task Manager's "Configure...") invisible for locked applets.
    configFile."plasmashellrc" = {
      "KDE Action Restrictions"."plasma/allow_configure_when_locked" = false;
    };
  };
}
