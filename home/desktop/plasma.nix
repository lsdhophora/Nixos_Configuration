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
  # home/persistence-kde.nix.
  #
  # UI changes (unpin, drag widgets) are overwritten on the next start.
  # To change pins, edit this file + `home-manager switch --flake .#FeiHsueh`.
  programs.plasma = {
    enable = true;

    panels = [
      {
        location = "bottom";
        height = 48;
        widgets = [
          {
            kickoff = {
              icon = "nix-snowflake";
              settings.General.systemFavorites = "suspend,hibernate,reboot,shutdown";
            };
          }
          "org.kde.plasma.pager"
          {
            # Task manager pinned apps
            iconTasks = {
              launchers = [
                "applications:org.wezfurlong.wezterm.desktop"
                "preferred://filemanager"
                "preferred://browser"
              ];
            };
          }
          "org.kde.plasma.marginsseparator"
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
        ];
      }
    ];
  };
}
