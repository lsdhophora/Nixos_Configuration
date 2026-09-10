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
# onto a single-file mount point fails with EBUSY. This module restores the
# old behavior for the rest of ~/.config: the list below holds the paths
# that survive until the next prune (boot or rebuild), and the service
# removes every other path.
#
# The service runs at boot (multi-user.target) and on every rebuild that
# changes the unit (switch-to-configuration restarts it). It must therefore
# never remove a path that Home Manager installs itself: Home Manager only
# re-creates its links when its own activation runs, so a pruned
# Home-Manager-owned entry would stay missing until the next boot (this is
# how ~/.config/zsh, and with it every new zsh, was lost). Everything Home
# Manager puts below .config is added to the keep list automatically;
# keepInConfig only carries the user data that Home Manager does not own.
# The service runs before the Home Manager activation, so Home Manager
# recreates the files that it owns from the current generation.
let
  user = "FeiHsueh";
  home = config.users.users.${user}.home;

  keepInConfig = [
    # ---- Directories ----
    # Most of these are Home Manager-owned, but they cannot be dropped from
    # this list: only entries that Home Manager installs through home.file /
    # xdg.configFile appear in the automatic set below, while the rest (dconf,
    # git, mpv, tmux, wezterm, autostart, ...) are written by Home Manager's
    # activation and are invisible to it at evaluation time.
    ".mozilla"
    "KDE"
    "autostart"
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
    "zsh"

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

  # Top-level entries below .config that Home Manager itself installs. The
  # prune must keep all of them, otherwise it deletes them on a rebuild where
  # the Home Manager activation does not run afterwards.
  hmConfigEntries = lib.unique (
    # home.file entries whose path is below .config
    (map (parts: lib.elemAt parts 1) (
      map (lib.splitString "/") (
        builtins.filter (path: lib.hasPrefix ".config/" path) (
          lib.attrNames config.home-manager.users.${user}.home.file
        )
      )
    ))
    # xdg.configFile entries are relative to .config already
    ++ (map (parts: lib.elemAt parts 0) (
      map (lib.splitString "/") (lib.attrNames config.home-manager.users.${user}.xdg.configFile)
    ))
  );

  keep = keepInConfig ++ hmConfigEntries;

  # Build one shell case pattern from the list, for example
  # 'KDE'|'kde.org'|'kwinrc'.
  keepPattern = lib.concatMapStringsSep "|" lib.escapeShellArg keep;
in
{
  systemd.services.home-config-prune = {
    description = "Delete the ephemeral entries in the persistent ~/.config";
    wantedBy = [ "multi-user.target" ];
    before = [ "home-manager-${user}.service" ];
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
