{
  lib,
  pkgs,
  ...
}:
# LibreWolf (Firefox fork with signature checks disabled and unsigned addons
# allowed), replacing Firefox. The profile layout and the download and PDF
# handling are in docs/librewolf.md.
#
# The profile settings, the chrome CSS and the native messaging hosts match
# the former Firefox configuration. The profile moved from
# ~/.config/mozilla/firefox to ~/.librewolf, and the user data was copied
# over by hand once.
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
        # Keep the window open when the last tab closes. The browser quits
        # otherwise, because the window holds the last tab.
        "browser.tabs.closeWindowWithLastTab" = false;
        # Hide the "Create a New Profile..." entry in the hamburger menu.
        "browser.profiles.enabled" = false;
        "identity.fxaccounts.enabled" = false;
        # LibreWolf asks where to save by default (useDownloadDir=false, see
        # the upstream librewolf.cfg DOWNLOADS section). Override it, so a
        # programmatic download (GM_download saveAs:false from the userscripts)
        # lands silently in the download folder and gets its per-artwork
        # subfolder. The browser has no showDirectoryPicker API, so this is the
        # only way to avoid a save dialog per file.
        "browser.download.useDownloadDir" = true;
        "browser.startup.homepage" = "about:home";
        # Restore the previous session on startup. The profile dir
        # (~/.librewolf) is bind-mounted from /persist, so the session data
        # survives reboots; sessionstore backups are written every 15 s, so an
        # unclean poweroff loses at most that window.
        "browser.startup.page" = 3;
        "browser.sessionstore.resume_from_crash" = true;
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
        # Keep the content-process console off the stdout pipe: with
        # devtools.console.stdout.content on, every page console message goes
        # to the parent over IPC. The TypeScript Playground (Monaco plus an
        # in-browser compiler) floods the console while booting, saturates the
        # pipe and starves the main thread, so the page froze with "this page
        # is slowing down" and never loaded.
        "devtools.console.stdout.content" = false;
      };
      # CSS files live in assets/, like the GTK themes.
      userContent = ./../../assets/firefox/userContent.css;
      userChrome = ./../../assets/firefox/userChrome.css;
    };
  };

  # The patched Violentmonkey (unsigned; LibreWolf sets requireSigning = false,
  # so profile-scope unsigned addons load). Ship it as a plain file in the
  # profile extensions dir, not via extensions.packages: the HM buildEnv would
  # turn the dir into a read-only store symlink and block policy downloads.
  home.file.".librewolf/default/extensions/{aecec67f-0d10-4fa7-b7c7-609a2db280cf}.xpi" = {
    source = "${pkgs.violentmonkey-declarative}/share/mozilla/extensions/{aecec67f-0d10-4fa7-b7c7-609a2db280cf}.xpi";
    # LibreWolf replaces the store symlink with a plain file, and the default
    # backup would abort the boot activation ("would be clobbered by backing
    # up"). That abort also skips ~/.zshenv and the panel autostart scripts.
    # Force the link, so the activation overwrites the file without a backup.
    force = true;
  };

  # Native messaging hosts (Plasma browser integration + keepassxc).
  # firefoxpwa is dropped entirely; its PWA launcher never opened.
  mozilla.librewolfNativeMessagingHosts = [
    pkgs.kdePackages.plasma-browser-integration
    pkgs.keepassxc
  ];

  # handlers.json is runtime state (LibreWolf rewrites it in place with
  # rename(2), and the profile dir is bind-mounted from /persist), so home.file
  # cannot manage it. Re-apply the PDF handler at every Home Manager
  # activation: application/pdf saves to disk (action 0) instead of opening in
  # the built-in viewer (action 3). pdfjs stays enabled for explicit previews.
  home.activation.librewolfPdfSave = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.deno}/bin/deno run -q --no-check --no-config --allow-env --allow-read --allow-write ${./../../assets/firefox/patch-pdf-handler.ts}
  '';

  # LibreWolf is the default browser: the per-user mimeapps.list is
  # persisted via persistence-kde.nix (edited there: firefox.desktop ->
  # librewolf.desktop), keeping Plasma's other associations intact.
}
