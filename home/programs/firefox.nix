{ pkgs, ... }:

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
      userContent = ''
        @-moz-document url(about:home) {
          .personalize-button,
          .open-customization-button {
            display: none !important;
          }
        }

        /* Bilibili - search bar border */
        @-moz-document domain("bilibili.com") {
          .bili-header .mini-header .center-search-container .center-search__bar #nav-searchform {
            border: 2px solid var(--line_regular) !important;
            background: var(--bg1) !important;
          }

          .bpx-player-top-left-title {
            line-height: 1.4 !important;
          }

          a.title.jumpable {
            line-height: 1.4 !important;
          }

          body, html {
            touch-action: pan-x pan-y pinch-zoom !important;
            overscroll-behavior: auto !important;
          }
        }

        /* DuckDuckGo - result site name line-height */
        @-moz-document domain("duckduckgo.com") {
          article[data-testid="result"] p {
            line-height: 1.4 !important;
          }
        }

        /* Zhihu - search bar, links, global text stroke */
        @-moz-document domain("zhihu.com") {
          [class*="SearchBar-input"] {
            transform: scale(0.9) !important;
            transform-origin: left center !important;
            border: 2px solid var(--MapUIFrame08B) !important;
          }

          [class*="SearchBar-input"]:focus,
          [class*="SearchBar-input"]:focus-within {
            outline: none !important;
            border: 2px solid !important;
          }

          a[href="/creator"] {
            border: 2px solid !important;
          }

          a[href="/question/waiting"] {
            border: 2px solid !important;
          }

          * {
            -webkit-text-stroke: 0.4px currentColor !important;
          }
        }

        span.cleanslate.TridactylStatusIndicator {
          bottom: 8px !important;
          right: 8px !important;
        }

        input#tridactyl-input {
          margin-bottom: 3px;
        }
      '';
      userChrome = ''
        :root { font-size: 12pt !important; }
        menupopup { --panel-border-radius: 8px !important; }
        #contentAreaContextMenu::part(content) { border: 1px solid #3c3c40 !important; }
        menupopup#context-sendimage, #context-sendimage { display: none !important; }
        #context-openlinkinusercontext-menu, #context-openlinkincontainertab,
        #spell-check-enabled, #spell-add-to-dictionary, #spell-suggestions-separator,
        #spell-separator, #context-sep-bidi, #context-sep-selectall,
        [data-l10n-id="places-open-in-container-tab"] { display: none !important; }
        :root { --tab-group-color-blue: #9141ac !important; --tab-group-color-blue-invert: #e8c7f0 !important; --tab-group-color-blue-pale: #f3e0f7 !important; }
        #tabbrowser-tabs { --tab-dragover-outline-color: #9141ac !important; }
        #tabbrowser-tabs[movingtab-group] .tab-background[dragover-groupTarget] { outline-width: 3px !important; outline-offset: -3px !important; }
        #tabbrowser-tabs[movingtab-group] tab-split-view-wrapper[dragover-groupTarget] { outline-width: 3px !important; }
        #tabbrowser-tabs[movingtab-group] .tabbrowser-tab[dragtarget] .tab-background { outline-width: 3px !important; }
        .tab-drop-indicator { background: url("data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIyOSI+PHBhdGggZD0iTTYgMGE1IDUgMCAwMTUgNSA0Ljg1IDQuODUgMCAwMS0zIDQuNDhWMjZhMSAxIDAgMDEtMSAxSDVhMSAxIDAgMDEtMS0xVjkuNDhDMi4wMiA4LjgxIDEuMiA2LjkzIDEgNWE1IDUgMCAwMTUtNXoiIGZpbGw9IiNmZmYiIGZpbHRlcj0iZHJvcC1zaGFkb3coMCAxcHggMC41cHggcmdiYSgwLDAsMCwwLjQ5NikpIi8+PHBhdGggZD0iTTYgMWE0IDQgMCAwMTQgNGMtLjE3IDIuMjUtMS4wNSAzLjAyLTMgMy44NFYyNkg1VjguODRDMy4xMiA4LjI4IDIuMTkgNi44OSAyIDVhNCA0IDAgMDE0LTR6bTAgMmEyIDIgMCAxMDAgNCAyIDIgMCAwMDAtNHoiIGZpbGw9IiM5MTQxYWMiLz48L3N2Zz4=") no-repeat center !important; }
        #historySwipeAnimationPreviousArrow, #historySwipeAnimationNextArrow { --swipe-nav-icon-primary-color: #9141ac !important; --swipe-nav-icon-accent-color: #2e2e32 !important; }
        #historySwipeAnimationPreviousArrow > svg, #historySwipeAnimationNextArrow > svg { scale: 1.25 !important; }
        #editBMPanel_namePicker { margin-bottom: 8px !important; }
        #contentAreaContextMenu menuseparator:last-child, #contentAreaContextMenu menuseparator:only-child { display: none !important; }
        panel[type="arrow"].panel-no-padding { transform: translateY(2px) !important; }
        #appMenu-empty-profiles-button { display: none !important; }
      '';
    };
    policies = {
      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/addon-ublock-origin-latest.xpi";
          installation_mode = "force_installed";
        };
        "addon@darkreader.org" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/darkreader/addon-darkreader-latest.xpi";
          installation_mode = "force_installed";
        };
        "{7a7a4a92-a2a0-41d1-9fd7-1e92480d612d}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/stylus/addon-stylus-latest.xpi";
          installation_mode = "force_installed";
        };
        "{aecec67f-0d10-4fa7-b7c7-609a2db280cf}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/violentmonkey/addon-violentmonkey-latest.xpi";
          installation_mode = "force_installed";
        };
      };
    };
  };

  xdg.configFile."tridactyl/tridactylrc" = {
    text = ''
      bindurl pixiv\.net f hint -C div.sc-a456a65d-2.ctBYkM.gtm-manga-viewer-close-icon
      bindurl pixiv\.net F hint -bC div.sc-a456a65d-2.ctBYkM.gtm-manga-viewer-close-icon
    '';
  };
}
