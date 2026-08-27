{ lib, ... }:
let
  # PWA site list: add one entry to pwas per web app.
  # Each PWA uses one profile. On Wayland, windows with the same profile
  # share app_id and merge into the first PWA taskbar entry (issue #80).
  # ULID has exactly 26 chars: 0123456789ABCDEFGHJKMNPQRSTVWXYZ
  # (I/L/O/U excluded). Site ULIDs are unique.
  pwas = [ ];
in
{
  programs.firefoxpwa = {
    enable = true;
    # The module installs firefoxpwa and writes ~/.local/share/firefoxpwa/config.json.
    # desktopEntry.enable = false: the module entry has no StartupWMClass,
    # so the xdg.desktopEntries below replace it.
    profiles = lib.listToAttrs (
      map (
        p:
        lib.nameValuePair p.profile {
          sites.${p.site} = {
            inherit (p) name url manifestUrl;
            desktopEntry.enable = false;
          };
        }
      ) pwas
    );
  };

  # Custom desktop entries (KDE launcher/taskbar):
  # - StartupWMClass = FFPWA-<siteULID> matches the --class/--name passed
  #   by firefoxpwa launch() (site.rs); taskbar grouping is exact.
  # - env MOZ_ENABLE_WAYLAND=1 equals the extension option "Use Wayland
  #   Display Server" (site.rs runtime_enable_wayland sets it).
  xdg.desktopEntries =
    (lib.listToAttrs (
      map (
        p:
        lib.nameValuePair "FFPWA-${p.site}" {
          name = p.name;
          exec = "env MOZ_ENABLE_WAYLAND=1 firefoxpwa site launch ${p.site} --protocol %u";
          terminal = false;
          icon = p.icon or null;
          categories = p.categories or null;
          settings.StartupWMClass = "FFPWA-${p.site}";
        }
      ) pwas
    ))
    // {
      # Hide the bundled firefoxpwa.desktop (NoDisplay=true).
      # The user entry takes precedence over /share/applications.
      "firefoxpwa" = {
        name = "firefoxpwa";
        noDisplay = true;
      };
    };

  # The firefoxpwa CLI also uses Wayland (Mozilla apps only).
  home.sessionVariables.MOZ_ENABLE_WAYLAND = "1";
}
