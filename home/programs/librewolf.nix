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
        "middlemouse.openNewWindow" = false;
        "layout.css.devPixelsPerPx" = "-1";
        "middlemouse.contentLoadURL" = false;
        "middlemouse.paste" = false;
        "layout.spellcheckDefault" = 0;
        "widget.gtk.rounded-bottom-corners.enabled" = true;
      };
      userChrome = ''
        menupopup#context-sendimage,
        #context-sendimage {
          display: none !important;
        }
      '';
    };
  };
}
