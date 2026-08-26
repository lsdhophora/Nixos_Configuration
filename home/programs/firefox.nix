{
  pkgs,
  lib,
  config,
  ...
}:
let
  # AMO force-install entry. `slug` is the addon id in the download URL.
  mozAddon = slug: {
    install_url = "https://addons.mozilla.org/firefox/downloads/latest/${slug}/addon-${slug}-latest.xpi";
    installation_mode = "force_installed";
  };
in
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
        "identity.fxaccounts.enabled" = false;
        # Tridactyl (now uninstalled) had set this to its own newtab page
        # (moz-extension://.../static/newtab.html); pin the default instead.
        "browser.startup.homepage" = "about:home";
        "svg.context-properties.content.enabled" = true;
        "browser.fullscreen.autohide" = false;
        "browser.ml.linkPreview.enabled" = false;
      };
      # CSS files live in assets/, like the GTK themes.
      # home-manager accepts a path and links it as the profile chrome.
      userContent = ./../../assets/firefox/userContent.css;
      userChrome = ./../../assets/firefox/userChrome.css;
    };
    policies = {
      ExtensionSettings = lib.mapAttrs (_: mozAddon) {
        "uBlock0@raymondhill.net" = "ublock-origin";
        "addon@darkreader.org" = "darkreader";
        "{7a7a4a92-a2a0-41d1-9fd7-1e92480d612d}" = "stylus";
        "{aecec67f-0d10-4fa7-b7c7-609a2db280cf}" = "violentmonkey";
        "firefoxpwa@filips.si" = "pwas-for-firefox";
      };
    };
  };

  # Native messaging hosts. Firefox 148+ looks them up under
  # $XDG_CONFIG_HOME/mozilla first (then legacy ~/.mozilla). home-manager's
  # mozilla module still hardcodes the legacy .mozilla location, so link the
  # native messaging hosts (Plasma browser integration + firefoxpwa) to the
  # XDG path here and disable the legacy link to keep $HOME free of ~/.mozilla.
  home.file = {
    ".config/mozilla/native-messaging-hosts" = {
      source =
        let
          hosts = pkgs.buildEnv {
            name = "mozilla-native-messaging-hosts";
            paths = [
              pkgs.kdePackages.plasma-browser-integration
              pkgs.firefoxpwa
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
