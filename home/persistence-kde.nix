{ ... }:
# KDE-specific home persistence (impermanence).
# /home is tmpfs; KDE config files, user resources and state are bind-mounted
# from /persist/home/FeiHsueh. Merged with ./persistence.nix (same key).
{
  home.persistence."/persist" = {
    directories = [
      # ---- KDE config dirs (.config) ----
      ".config/KDE" ".config/kde.org" ".config/kdedefaults"
      ".config/klassy" ".config/panel-colorizer" ".config/plasma-workspace"
      ".config/session"

      # ---- KDE user resources (.local/share) ----
      ".local/share/plasma" ".local/share/aurorae" ".local/share/color-schemes"
      ".local/share/icons" ".local/share/wallpapers" ".local/share/sounds"
      ".local/share/themes" ".local/share/fonts" ".local/share/baloo"
      ".local/share/dolphin" ".local/share/konsole" ".local/share/kactivitymanagerd"
      ".local/share/klipper" ".local/share/kxmlgui5" ".local/share/RecentDocuments"
      ".local/share/kscreen" ".local/share/kwin" ".local/share/knewstuff3"
      ".local/share/plasma_notes" ".local/share/plasma-systemmonitor"
      ".local/share/kded6" ".local/share/khelpcenter" ".local/share/kwrite"
      ".local/share/drkonqi" ".local/share/gwenview" ".local/share/okular"
      ".local/share/ktorrent" ".local/share/kdenlive" ".local/share/Meltytech"
      ".local/share/plasmalogin" ".local/share/containers"
      ".local/share/applications" ".local/share/mime"
      ".local/share/libkunitconversion" ".local/share/icc" ".local/share/backgrounds"
    ];
    files = [
      # ---- KDE rc files (.config, full list) ----
      ".config/arkrc" ".config/baloofileinformationrc" ".config/baloofilerc"
      ".config/bluedevilglobalrc" ".config/breezerc" ".config/darklyrc"
      ".config/dolphinrc" ".config/drkonqirc" ".config/filetypesrc"
      ".config/gtkrc" ".config/gtkrc-2.0" ".config/gwenviewrc"
      ".config/kactivitymanagerdrc" ".config/kactivitymanagerd-statsrc"
      ".config/kcmfonts" ".config/kcminputrc" ".config/kconf_updaterc"
      ".config/kded5rc" ".config/kded6rc" ".config/kdeglobals"
      ".config/kdenlive-layoutsrc" ".config/kdenliverc" ".config/kglobalshortcutsrc"
      ".config/khelpcenterrc" ".config/kiorc" ".config/kmenueditrc"
      ".config/kolfrc" ".config/konsolerc" ".config/konsolesshconfig"
      ".config/kscreenlockerrc" ".config/kservicemenurc" ".config/ksmserverrc"
      ".config/ksplashrc" ".config/ktimezonedrc" ".config/ktorrent_infowidgetrc"
      ".config/ktorrentrc" ".config/ktrashrc" ".config/kwalletrc"
      ".config/kwinoutputconfig.json" ".config/kwinrc" ".config/kwinrulesrc"
      ".config/kwritemetainfos" ".config/kwriterc" ".config/kxkbrc"
      ".config/mimeapps.list" ".config/monitors.xml" ".config/okularpartrc"
      ".config/okularrc" ".config/plasma-localerc" ".config/plasmanotifyrc"
      ".config/plasma-org.kde.plasma.desktop-appletsrc" ".config/plasmarc"
      ".config/plasmashellrc" ".config/powerdevilrc"
      ".config/powermanagementprofilesrc" ".config/QtProject.conf"
      ".config/spectaclerc" ".config/systemmonitorrc" ".config/trashrc"
      ".config/Trolltech.conf" ".config/user-dirs.dirs" ".config/user-dirs.locale"
      ".config/xdg-terminals.list"

      # ---- KDE state files (.local/share) ----
      ".local/share/krunnerstaterc" ".local/share/recently-used.xbel"
      ".local/share/user-places.xbel" ".local/share/user-places.xbel.bak"
      ".local/share/user-places.xbel.bak-lophophora"
      ".local/share/user-places.xbel.tbcache"
    ];
  };
}
