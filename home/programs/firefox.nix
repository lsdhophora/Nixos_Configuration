{ pkgs, ... }:

{
  programs.firefox = {
    enable = true;
    package = pkgs.firefox-patched;
    configPath = ".mozilla/firefox";
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
        "layout.css.devPixelsPerPx" = "1.40";
        "middlemouse.contentLoadURL" = false;
        "middlemouse.paste" = false;
        "layout.spellcheckDefault" = 0;
        "widget.gtk.rounded-bottom-corners.enabled" = true;
        "widget.use-xdg-desktop-portal.file-picker" = 1;
        "browser.formfill.enable" = false;
        "privacy.userContext.enabled" = false;
        "ui.key.menuAccessKey" = 0;
        "browser.tabs.splitView.enabled" = false;
        "browser.tabs.groups.enabled" = false;
        "identity.fxaccounts.enabled" = false;
        "svg.context-properties.content.enabled" = true;
      };
      userContent = ''
        @-moz-document url(about:home) {
          .personalize-button,
          .open-customization-button {
            display: none !important;
          }
        }
      '';
      userChrome = ''
         menupopup#context-sendimage,
         #context-sendimage {
           display: none !important;
         }
           #context-openlinkinusercontext-menu,
           #context-openlinkincontainertab,
          #spell-check-enabled,
          #spell-add-to-dictionary,
          #spell-suggestions-separator,
          #spell-separator,
           #context-sep-bidi,
           [data-l10n-id="places-open-in-container-tab"] {
             display: none !important;
           }

         /* Override blue group color → purple for drag-to-group highlight */
         :root {
           --tab-group-color-blue: #9141ac !important;
           --tab-group-color-blue-invert: #e8c7f0 !important;
           --tab-group-color-blue-pale: #f3e0f7 !important;
         }

         /* Drag outline for multiselect / group target */
         #tabbrowser-tabs {
           --tab-dragover-outline-color: #9141ac !important;
         }
         #tabbrowser-tabs[movingtab-group] .tab-background[dragover-groupTarget] {
           outline-width: 3px !important;
           outline-offset: -3px !important;
         }
         #tabbrowser-tabs[movingtab-group] tab-split-view-wrapper[dragover-groupTarget] {
           outline-width: 3px !important;
         }
         #tabbrowser-tabs[movingtab-group] .tabbrowser-tab[dragtarget] .tab-background {
           outline-width: 3px !important;
         }

         /* Tab drag drop indicator */
         .tab-drop-indicator {
           background: url("data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMiIgaGVpZ2h0PSIyOSI+PHBhdGggZD0iTTYgMGE1IDUgMCAwMTUgNSA0Ljg1IDQuODUgMCAwMS0zIDQuNDhWMjZhMSAxIDAgMDEtMSAxSDVhMSAxIDAgMDEtMS0xVjkuNDhDMi4wMiA4LjgxIDEuMiA2LjkzIDEgNWE1IDUgMCAwMTUtNXoiIGZpbGw9IiNmZmYiIGZpbHRlcj0iZHJvcC1zaGFkb3coMCAxcHggMC41cHggcmdiYSgwLDAsMCwwLjQ5NikpIi8+PHBhdGggZD0iTTYgMWE0IDQgMCAwMTQgNGMtLjE3IDIuMjUtMS4wNSAzLjAyLTMgMy44NFYyNkg1VjguODRDMy4xMiA4LjI4IDIuMTkgNi44OSAyIDVhNCA0IDAgMDE0LTR6bTAgMmEyIDIgMCAxMDAgNCAyIDIgMCAwMDAtNHoiIGZpbGw9IiM5MTQxYWMiLz48L3N2Zz4=") no-repeat center !important;
         }

         /* History swipe navigation icon colors + scale */
         #historySwipeAnimationPreviousArrow,
         #historySwipeAnimationNextArrow {
           --swipe-nav-icon-primary-color: #9141ac !important;
           --swipe-nav-icon-accent-color: #2e2e32 !important;
           > svg { scale: 1.25 !important; }
         }

         /* Library detail pane spacing between Name and URI textboxes */
         #editBMPanel_namePicker {
           margin-bottom: 8px !important;
         }

        /* Simplify media context */
        #context-media-play,
        #context-media-pause,
        #context-media-mute,
        #context-media-unmute,
        #context-media-playbackrate,
        #context-media-playbackrate-050x,
        #context-media-playbackrate-100x,
        #context-media-playbackrate-125x,
        #context-media-playbackrate-150x,
        #context-media-playbackrate-200x,
        #context-media-loop,
        #context-leave-dom-fullscreen,
        #context-video-fullscreen,
        #context-media-hidecontrols,
        #context-media-showcontrols,
        #context-media-sep-video-commands,
        #context-viewvideo,
        #context-video-pictureinpicture,
        #context-media-sep-commands,
        #context-video-saveimage,
        #context-savevideo,
        #context-saveaudio,
        #context-copyvideourl,
        #context-copyaudiourl,
        #context-sendvideo,
        #context-sendaudio,
        #context-sep-setbackground,
         #context-inspect {
              display: none !important;
          }

          #context-inspect-a11y {
              display: none !important;
          }

          panel[type="arrow"].panel-no-padding {
            transform: translateY(2px) !important;
          }

          #appMenu-empty-profiles-button {
            display: none !important;
          }
       '';
    };
  };
}
