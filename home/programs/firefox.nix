{
  pkgs,
  lib,
  config,
  ...
}:
{
  programs.firefox = {
    enable = true;
    package = pkgs.firefox-patched;
    # Firefox >= 147 honours the XDG Base Directory spec: with no legacy
    # ~/.mozilla, it stores everything under $XDG_CONFIG_HOME/mozilla.
    # home.stateVersion is 25.05, so the module default would still be the
    # legacy .mozilla/firefox path; set the XDG one explicitly.
    configPath = "${config.xdg.configHome}/mozilla/firefox";
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
        # Hide the "Create a New Profile..." entry in the hamburger menu
        # (browser.profiles.enabled gates the app-menu profile section).
        "browser.profiles.enabled" = false;
        "identity.fxaccounts.enabled" = false;
        # Tridactyl (now uninstalled) had set this to its own newtab page
        # (moz-extension://.../static/newtab.html); pin the default instead.
        "browser.startup.homepage" = "about:home";
        # New tab page state (was only in prefs.js, which was wiped at every
        # login): no top sites, no sponsored content, no wallpaper (the
        # empty string means no wallpaper in Firefox's newtab wallpapers).
        "browser.newtabpage.activity-stream.feeds.topsites" = false;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.newtabWallpapers.wallpaper" = "";
        "svg.context-properties.content.enabled" = true;
        "browser.fullscreen.autohide" = false;
        "browser.ml.linkPreview.enabled" = false;
      };
      # CSS files live in assets/, like the GTK themes.
      # home-manager accepts a path and links it as the profile chrome.
      userContent = ./../../assets/firefox/userContent.css;
      userChrome = ./../../assets/firefox/userChrome.css;
    };
  };

  # Firefox enterprise policies (extension force-install, AIControls) live in
  # modules/firefox-policies.nix: the home-manager policies option bakes them
  # into the wrapped package's distribution dir, which the wrapper never reads
  # on this system (the wrapper execs the unwrapped binary, so Firefox's GRE
  # dir has no policies.json).

  # prefs.js (inside the persisted profile) now survives logins, so runtime
  # state configured from the UI -- toolbar layout, status bar, homepage --
  # is kept.  The declarative prefs above are written to user.js and still
  # override prefs.js at every startup for the keys they cover.

  # Native messaging hosts. Firefox 148+ looks them up under
  # $XDG_CONFIG_HOME/mozilla first (then legacy ~/.mozilla). home-manager's
  # mozilla module still hardcodes the legacy .mozilla location, so link the
  # native messaging hosts (Plasma browser integration + firefoxpwa +
  # keepassxc) to the XDG path here and disable the legacy link to keep $HOME free of ~/.mozilla.
  home.file = {
    ".config/mozilla/native-messaging-hosts" = {
      source =
        let
          hosts = pkgs.buildEnv {
            name = "mozilla-native-messaging-hosts";
            paths = [
              pkgs.kdePackages.plasma-browser-integration
              pkgs.firefoxpwa
              pkgs.keepassxc
            ];
            pathsToLink = [ "/lib/mozilla/native-messaging-hosts" ];
          };
        in
        "${hosts}/lib/mozilla/native-messaging-hosts";
      recursive = true;
    };
    ".mozilla/native-messaging-hosts".enable = lib.mkForce false;
  };
}
