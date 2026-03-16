{
  pkgs,
  ...
}:

{
  programs.librewolf = {
    enable = true;
    package =
      pkgs.wrapFirefox
        (pkgs.librewolf-unwrapped.overrideAttrs (old: {
          configureFlags = old.configureFlags ++ [
            "--disable-debug"
            "--disable-debug-symbols"
          ];
          separateDebugInfo = false;
        }))
        {
          pname = "librewolf";
          wmClass = "LibreWolf";
        };
    profiles.default = {
      settings = {
        "browser.translations.enable" = false;
        "browser.translations.autoTranslate" = false;
        "browser.translations.panel.shown" = false;
        "browser.chrome.toolbar_tips" = false;
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "browser.tabs.opentabfor.middleclick" = false;
        "browser.tabs.hoverPreview.enabled" = false;
        "middlemouse.openNewWindow" = false;
        "layout.css.devPixelsPerPx" = 1.42;
        "middlemouse.contentLoadURL" = false;
        "middlemouse.paste" = false;
        "layout.spellcheckDefault" = 0;
        "widget.gtk.rounded-bottom-corners.enabled" = true;
        "widget.use-xdg-desktop-portal.file-picker" = 1;
        "browser.formfill.enable" = false;
      };
      userChrome = ''
        menupopup#context-sendimage,
        #context-sendimage {
          display: none !important;
        }
        #spell-check-enabled,
        #spell-add-to-dictionary,
        #spell-suggestions-separator,
        #spell-separator,
        #context-sep-bidi {
          display: none !important;
        }
      '';
    };
  };
}
