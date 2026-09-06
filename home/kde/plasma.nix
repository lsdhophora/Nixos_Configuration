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
  };
}
