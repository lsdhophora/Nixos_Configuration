{ pkgs, lib, ... }:
let
  # AMO force-install entry. `slug` is the addon id in the download URL.
  mozAddon = slug: {
    install_url = "https://addons.mozilla.org/firefox/downloads/latest/${slug}/addon-${slug}-latest.xpi";
    installation_mode = "force_installed";
  };

  # Tridactyl site bindings for the Pixiv manga-viewer close button.
  # One selector serves both hint variants.
  tridactylSelector = "div.sc-a456a65d-2.ctBYkM.gtm-manga-viewer-close-icon";
  bindurl = key: flags: "bindurl pixiv\\.net ${key} hint ${flags} ${tridactylSelector}";
in
{
  programs.firefox = {
    enable = true;
    package = pkgs.firefox-patched;
    configPath = ".mozilla/firefox";
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
      ExtensionSettings = lib.mapAttrs (id: slug: mozAddon slug) {
        "uBlock0@raymondhill.net" = "ublock-origin";
        "addon@darkreader.org" = "darkreader";
        "{7a7a4a92-a2a0-41d1-9fd7-1e92480d612d}" = "stylus";
        "{aecec67f-0d10-4fa7-b7c7-609a2db280cf}" = "violentmonkey";
      };
    };
  };

  xdg.configFile."tridactyl/tridactylrc" = {
    text = lib.concatLines [
      (bindurl "f" "-C")
      (bindurl "F" "-bC")
    ];
  };
}
