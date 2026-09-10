{ ... }:
# KDE-specific home persistence (impermanence).
# /home is tmpfs; KDE config files, user resources and state are bind-mounted
# from /persist/home/FeiHsueh. Merged with ../persistence.nix (same key).
#
# Persist .config as one directory.
# KConfig saves a file with a temporary file and rename(2). A rename onto a
# mount point fails with EBUSY. A single-file bind mount is a mount point,
# so the kernel drops every KConfig write and the application sees no error.
# The GUI then reports success and keeps the old file. Only a directory
# mount keeps the rename inside one file system. A directory mount is
# therefore necessary for the GUI to write mimeapps.list, kwinrc,
# kdeglobals, and the other KDE configuration files.
# The boot service in modules/desktop/home-config-prune.nix keeps the
# paths of the old file list plus the entries Home Manager installs itself,
# and deletes every other path below .config.
{
  home.persistence."/persist" = {
    directories = [
      # ---- KDE config directory (.config) ----
      # The whole directory. The boot prune keeps the paths that must
      # survive a reboot (see modules/desktop/home-config-prune.nix).
      ".config"

      # ---- KDE user resources (.local/share) ----
      ".local/share/plasma"
      ".local/share/aurorae"
      ".local/share/color-schemes"
      ".local/share/icons"
      ".local/share/wallpapers"
      ".local/share/sounds"
      ".local/share/themes"
      ".local/share/fonts"
      ".local/share/baloo"
      ".local/share/dolphin"
      ".local/share/konsole"
      ".local/share/kactivitymanagerd"
      ".local/share/klipper"
      ".local/share/kxmlgui5"
      ".local/share/RecentDocuments"
      ".local/share/kscreen"
      ".local/share/kwin"
      ".local/share/knewstuff3"
      ".local/share/plasma_notes"
      ".local/share/plasma-systemmonitor"
      ".local/share/kded6"
      ".local/share/khelpcenter"
      ".local/share/kwrite"
      ".local/share/drkonqi"
      ".local/share/gwenview"
      ".local/share/okular"
      ".local/share/ktorrent"
      ".local/share/kdenlive"
      ".local/share/Meltytech"
      ".local/share/plasmalogin"
      ".local/share/containers"
      ".local/share/applications"
      ".local/share/mime"
      ".local/share/libkunitconversion"
      ".local/share/icc"
      ".local/share/backgrounds"
    ];
    files = [
      # ---- KDE state files (.local/state) ----
      ".local/state/dolphinstaterc"

      # ---- KDE state files (.local/share) ----
      ".local/share/krunnerstaterc"
      ".local/share/recently-used.xbel"
      ".local/share/user-places.xbel"
      ".local/share/user-places.xbel.bak"
      ".local/share/user-places.xbel.tbcache"
    ];
  };
}
