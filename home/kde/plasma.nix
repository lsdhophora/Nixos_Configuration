{
  config,
  lib,
  pkgs,
  ...
}:
let
  # The layout script of plasma-manager and its "already run" marker.  The
  # names come from the panel module of plasma-manager: desktop script
  # "panels" with priority 2.
  panelScript = "${config.xdg.dataHome}/plasma-manager/scripts/2_desktop_script_panels.sh";
  panelMarker = "${config.xdg.dataHome}/plasma-manager/last_run_desktop_script_panels";

  # The applet types of the declared panel, in order. ensurePanel compares
  # the live panel against this list, so a start that rebuilds a default
  # panel (the layout script marker skipped the rebuild) is repaired.
  expectedWidgets = [
    "org.kde.plasma.kickoff"
    "org.kde.plasma.panelspacer"
    "org.kde.plasma.icontasks"
    "org.kde.plasma.panelspacer"
    "org.kde.plasma.systemtray"
    "org.kde.plasma.digitalclock"
    "org.kde.plasma.showdesktop"
    "org.kde.plasma.marginsseparator"
  ];

  # Repair the panel when the layout script loses the startup race.
  #
  # The layout script runs about one second after plasmashell starts, when
  # plasmashell cannot find the org.kde.panel plugin yet. The script then stops
  # at its first addWidget() call and no panel exists; a second run in the same
  # process fails too, because plasmashell keeps the failed plugin lookup.
  # Restart plasmashell and run the layout script again. plasma-manager runs
  # this script after the layout script, because its priority is higher.
  #
  # The same repair covers a different failure: a plasmashell restart (or a
  # start where the layout script's marker already matched) rebuilds the
  # stock Plasma panel. Compare the applet types against the declaration and
  # rebuild when they differ.
  ensurePanel = ''
    set -u
    qdbus="${pkgs.kdePackages.qttools}/bin/qdbus"
    systemctl="${pkgs.systemd}/bin/systemctl"
    rm="${pkgs.coreutils}/bin/rm"
    sleep="${pkgs.coreutils}/bin/sleep"

    expected="${lib.concatStringsSep "," expectedWidgets}"

    # Print the applet types of the first panel, one per line. Print nothing
    # when plasmashell does not answer.
    panel_widgets() {
      "$qdbus" org.kde.plasmashell /PlasmaShell \
        org.kde.PlasmaShell.evaluateScript \
        'var ps = panels(); if (ps.length === 0) { print("NO_PANEL"); } else { print(ps[0].widgets().map(function (w) { return w.type; }).join("\n")); }' 2>/dev/null
    }

    live="$("$(panel_widgets)")"

    if [ -n "$live" ] && [ "$live" = "$expected" ]; then
      exit 0
    fi

    echo "plasma-ensure-panel: rebuilding the panel (live: $(echo "$live" | tr '\n' ' '))" >&2
    "$rm" -f "${panelMarker}"
    "$systemctl" --user restart plasma-plasmashell.service

    # Wait until the restarted plasmashell answers on the session bus.
    i=0
    while [ "$i" -lt 60 ]; do
      if "$qdbus" org.kde.plasmashell /PlasmaShell >/dev/null 2>&1; then
        break
      fi
      "$sleep" 1
      i=$((i + 1))
    done

    # Give the restarted plasmashell time for the containment plugins,
    # then build the panel.
    "$sleep" 5
    "${panelScript}"

    live="$("$(panel_widgets)")"
    if [ "$live" = "$expected" ]; then
      exit 0
    fi
    echo "plasma-ensure-panel: the panel does not match the declaration" >&2
    exit 1
  '';
in
{
  # Declarative Plasma panel / Task Manager config (plasma-manager).
  #
  # On every Plasma session start the autostart script removes
  # plasma-org.kde.plasma.desktop-appletsrc and rebuilds the panel and widgets
  # from the declarations below with qdbus evaluateScript. The file therefore
  # regenerates on every start; the boot prune
  # (modules/desktop/home-config-prune.nix) removes it again. UI changes
  # (unpin, drag widgets) are lost on the next start, so edit this file and run
  # `home-manager switch --flake .#FeiHsueh`.
  programs.plasma = {
    enable = true;

    panels = [
      {
        location = "bottom";
        height = 44;
        # Keep the panel translucent at all times.  The default Adaptive mode
        # switches to the opaque theme background when a window touches the
        # panel.
        opacity = "translucent";
        # Lock the panel (UserImmutable) inside the layout script, after the
        # widgets are added and in the same evaluateScript run: a separate
        # later lockCorona() raced the layout script and could leave the panel
        # unbuilt. lockCorona() also raises the corona-level immutability, so
        # the applets get no "Configure..." entry.
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
                "applications:emacs.desktop"
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

    # Fallback for the layout script of the panel above.  The script runs
    # at every session start (runAlways) and after the layout script
    # (priority 3).
    startup.startupScript."ensure-panel" = {
      priority = 3;
      runAlways = true;
      text = ensurePanel;
    };

    # Hide per-widget "Configure..." menu entries while the panel is locked.
    # The generic applet configure action stays visible when locked because it
    # is granted through the plasma/allow_configure_when_locked Kiosk action;
    # denying it makes the action (and every menu item bound to it, e.g. the
    # Task Manager's "Configure...") invisible for locked applets.
    # The boot prune deletes this file at every boot, so Plasma cannot feed
    # the view state of the last session back (see
    # modules/desktop/home-config-prune.nix).
    configFile."plasmashellrc" = {
      "KDE Action Restrictions"."plasma/allow_configure_when_locked" = false;
    };

    # Default terminal emulator: WezTerm.  KDE consumers (Dolphin/Konsole
    # "Open Terminal Here", KRunner, the desktop context menu, ...) read these
    # keys from ~/.config/kdeglobals (what System Settings -> Default
    # Applications writes).  plasma-manager writes config files in place (no
    # atomic rename), so the declared keys survive while KDE writes its own
    # keys to the same file.
    configFile."kdeglobals" = {
      General.TerminalApplication = "wezterm";
      General.TerminalService = "org.wezfurlong.wezterm.desktop";
    };

    # notify-send carries no desktop entry, so Plasma groups its
    # notifications under the "other" applications, and the default
    # plasmanotifyrc of plasma-workspace keeps those out of the history.
    # Keep them in the history: this covers the pi notification extension
    # and every other command that calls notify-send.
    configFile."plasmanotifyrc" = {
      "Applications/@other".ShowInHistory = true;
    };
  };
}
