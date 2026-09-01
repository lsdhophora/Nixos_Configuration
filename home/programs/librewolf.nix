{ pkgs, ... }:
# LibreWolf (Firefox fork with signature checks disabled and unsigned addons
# allowed), replacing Firefox.
#
# Migrated from home/programs/firefox.nix: profile settings, chrome CSS and
# native messaging hosts are the same as for Firefox.  The profile directory
# moves from ~/.config/mozilla/firefox to ~/.librewolf; user data (history,
# cookies, logins, extension data) was copied over by hand once (see
# docs/migration.md or the migration notes in the git history).
{
  programs.librewolf = {
    enable = true;
    profiles.default = {
      settings = {
        "xpinstall.signatures.required" = false;
        "browser.translations.enable" = false;
        "browser.translations.autoTranslate" = false;
        "browser.translations.panel.shown" = false;
        "browser.chrome.toolbar_tips" = false;
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "browser.tabs.opentabfor.middleclick" = false;
        "browser.tabs.hoverPreview.enabled" = false;
        "middlemouse.openNewWindow" = false;
        "middlemouse.contentLoadURL" = false;
        "middlemouse.paste" = false;
        "layout.spellcheckDefault" = 0;
        "widget.gtk.rounded-bottom-corners.enabled" = true;
        "widget.allow-client-side-decorations" = false;
        "widget.use-xdg-desktop-portal.file-picker" = 1;
        "full-screen-api.warning.timeout" = 1000;
        "browser.formfill.enable" = false;
        "privacy.userContext.enabled" = false;
        "ui.key.menuAccessKey" = 0;
        "browser.tabs.splitView.enabled" = false;
        "browser.tabs.groups.enabled" = false;
        # Hide the "Create a New Profile..." entry in the hamburger menu.
        "browser.profiles.enabled" = false;
        "identity.fxaccounts.enabled" = false;
        # LibreWolf default is to always ask where to save (useDownloadDir=false,
        # see upstream librewolf.cfg DOWNLOADS section).  Override so that
        # programmatic downloads (GM_download saveAs:false from userscripts like
        # Pixiv Downloader) land silently in the default download folder and
        # create per-artwork subfolders; the browser has no showDirectoryPicker
        # API, so this is the only way to avoid a save dialog per file.
        "browser.download.useDownloadDir" = true;
        "browser.startup.homepage" = "about:home";
        # New tab page state: no top sites, no sponsored content, no wallpaper.
        "browser.newtabpage.activity-stream.feeds.topsites" = false;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.newtabWallpapers.wallpaper" = "";
        "svg.context-properties.content.enabled" = true;
        "browser.fullscreen.autohide" = false;
        "browser.ml.linkPreview.enabled" = false;
        # Allow sideloaded addons (the patched Violentmonkey xpi in the
        # profile extensions dir) to enable themselves automatically.
        "extensions.autoDisableScopes" = 0;
      };
      # CSS files live in assets/, like the GTK themes.
      userContent = ./../../assets/firefox/userContent.css;
      userChrome = ./../../assets/firefox/userChrome.css;
    };
  };

  # The patched Violentmonkey (unsigned; LibreWolf is built with
  # requireSigning = false, so profile-scope unsigned addons load fine).
  # Delivered as a plain file in the profile extensions dir instead of
  # extensions.packages: the HM buildEnv would make the whole extensions dir
  # a read-only store symlink, which also blocks policy force-install
  # downloads from landing there.
  home.file.".librewolf/default/extensions/{aecec67f-0d10-4fa7-b7c7-609a2db280cf}.xpi" = {
    source = "${pkgs.violentmonkey-declarative}/share/mozilla/extensions/{aecec67f-0d10-4fa7-b7c7-609a2db280cf}.xpi";
  };

  # Native messaging hosts (Plasma browser integration + keepassxc).
  # firefoxpwa was removed: PWA install is declarative via home/programs/firefoxpwa.nix
  # (no browser extension), so no native messaging host is needed.
  mozilla.librewolfNativeMessagingHosts = [
    pkgs.kdePackages.plasma-browser-integration
    pkgs.keepassxc
  ];

  # LibreWolf is the default browser: the per-user mimeapps.list is
  # persisted via persistence-kde.nix (edited there: firefox.desktop ->
  # librewolf.desktop), keeping Plasma's other associations intact.
}
