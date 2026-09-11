{
  config,
  lib,
  pkgs,
  ...
}:
# Delete the ephemeral entries in the persistent ~/.config.
#
# ~/.config is one directory mount from /persist (see
# home/kde/persistence-kde.nix). A directory mount is necessary, because
# KConfig saves a file with a temporary file and rename(2), and a rename
# onto a single-file mount point fails with EBUSY. Before this module the
# persisted .config entries were separate bind mounts and everything else
# lived on the tmpfs home directory; this service reproduces that split for
# the rest of ~/.config. The list below is the set of paths that survived a
# reboot then, and the service removes every other path.
#
# The service runs once at boot, before the Home Manager activation
# (`before = home-manager-<user>.service`). That is exactly what the tmpfs
# did: a path that is not in the list is absent after boot, and is
# re-created by the Home Manager activation (its own files) or by the
# application that owns it. It must not run again on `nixos-rebuild
# switch`: a mid-session prune would delete runtime files such as
# plasma-org.kde.plasma.desktop-appletsrc, and the plasma-manager desktop
# script (run once) would not re-create them before the next boot, so the
# panel would fall back to the Plasma default. `restartIfChanged` is
# therefore false, and a change to the list takes effect on the next boot.
let
  user = "FeiHsueh";
  home = config.users.users.${user}.home;

  # The paths below .config that survive a reboot. This is exactly the set
  # that home/kde/persistence-kde.nix and the old per-file .config entries
  # in home/persistence.nix used to bind-mount. Everything else is
  # ephemeral, as it was on the tmpfs home. Home Manager-owned entries are
  # deliberately not added: the boot prune runs before the activation, so
  # the activation re-creates them.
  keep = [
    # ---- Directories ----
    ".mozilla"
    "KDE"
    "clangd"
    "dconf"
    "direnv"
    "Element"
    "emacs"
    "environment.d"
    "fcitx"
    "fcitx5"
    "fontconfig"
    "gh"
    "git"
    "go"
    "herdr"
    "gtk-3.0"
    "gtk-4.0"
    "kdedefaults"
    "kde.org"
    "keepassxc"
    "klassy"
    "lazygit"
    "libaccounts-glib"
    "mozilla"
    "mpv"
    "nix"
    "nixos"
    "nnn"
    "plasma-workspace"
    "session"
    "sops"
    "systemd"
    "tmux"
    "wezterm"
    "xsettingsd"

    # ---- Files ----
    "QtProject.conf"
    "Trolltech.conf"
    "arkrc"
    "baloofileinformationrc"
    "baloofilerc"
    "bluedevilglobalrc"
    "breezerc"
    "darklyrc"
    "dolphinrc"
    "drkonqirc"
    "filetypesrc"
    "gwenviewrc"
    "kactivitymanagerdrc"
    "kactivitymanagerd-statsrc"
    "kcmfonts"
    "kcminputrc"
    "kconf_updaterc"
    "kded5rc"
    "kded6rc"
    "kdeglobals"
    "kdenlive-layoutsrc"
    "kdenliverc"
    "kglobalshortcutsrc"
    "khelpcenterrc"
    "kiorc"
    "kmenueditrc"
    "kolfrc"
    "konsolerc"
    "konsolesshconfig"
    "kscreenlockerrc"
    "kservicemenurc"
    "ksmserverrc"
    "ksplashrc"
    "ktimezonedrc"
    "ktorrent_infowidgetrc"
    "ktorrentrc"
    "ktrashrc"
    "kwalletrc"
    "kwinoutputconfig.json"
    "kwinrc"
    "kwinrulesrc"
    "kwritemetainfos"
    "kwriterc"
    "kxkbrc"
    "mimeapps.list"
    "monitors.xml"
    "okularpartrc"
    "okularrc"
    "plasma-localerc"
    "plasmanotifyrc"
    "plasmarc"
    "powerdevilrc"
    "powermanagementprofilesrc"
    "spectaclerc"
    "systemmonitorrc"
    "trashrc"
    "user-dirs.dirs"
    "user-dirs.locale"
    "xdg-terminals.list"
  ];

  # Build one shell case pattern from the list, for example
  # 'KDE'|'kde.org'|'kwinrc'.
  keepPattern = lib.concatMapStringsSep "|" lib.escapeShellArg keep;
in
{
  systemd.services.home-config-prune = {
    description = "Delete the ephemeral entries in the persistent ~/.config";
    wantedBy = [ "multi-user.target" ];
    before = [ "home-manager-${user}.service" ];
    restartIfChanged = false;
    unitConfig.RequiresMountsFor = "${home}/.config";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "home-config-prune" ''
        set -eu
        if [ ! -d ${home}/.config ]; then
          exit 0
        fi
        cd ${home}/.config
        shopt -s dotglob nullglob
        for entry in *; do
          case "$entry" in
            ${keepPattern}) ;;
            *)
              echo "home-config-prune: remove $entry" >&2
              rm -rf -- "$entry"
              ;;
          esac
        done
      '';
    };
  };
}
