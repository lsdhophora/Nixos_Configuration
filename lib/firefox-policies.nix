{ lib }:
# Shared Firefox-family enterprise policies, delivered as policies.json
# (see modules/firefox-policies.nix).
#
# - ExtensionSettings: force-install of AMO addons.
# - AIControls: block all AI features.
# - "3rdparty" managed storage for the patched Violentmonkey
#   (violentmonkey-declarative): the extension reads browser.storage.managed
#   at startup and installs the scripts declared here (see
#   patches/violentmonkey/declarative.patch).
#
# Note: the AMO Violentmonkey is deliberately NOT force-installed here; the
# patched build is installed via home-manager extensions.packages instead.
let
  mozAddon = slug: {
    install_url = "https://addons.mozilla.org/firefox/downloads/latest/${slug}/addon-${slug}-latest.xpi";
    installation_mode = "force_installed";
  };
in
{
  ExtensionSettings = lib.mapAttrs (_: mozAddon) {
    "uBlock0@raymondhill.net" = "ublock-origin";
    "{7a7a4a92-a2a0-41d1-9fd7-1e92480d612d}" = "stylus";
    "firefoxpwa@filips.si" = "pwas-for-firefox";
    "keepassxc-browser@keepassxc.org" = "keepassxc-browser";
  };
  AIControls = {
    Default = {
      Value = "blocked";
      Locked = true;
    };
  };
  "3rdparty".Extensions."{aecec67f-0d10-4fa7-b7c7-609a2db280cf}" = {
    options.autoUpdate = 0;
    scripts = map (f: builtins.readFile f) [
      ./../assets/violentmonkey/bilibili-comments-avatar-beautify.js
      ./../assets/violentmonkey/cph.user.js
      ./../assets/violentmonkey/font-weight-min-500.js
      ./../assets/violentmonkey/pixiv-downloader.user.js
      ./../assets/violentmonkey/pixiv-novel-copy.user.js
      ./../assets/violentmonkey/reddit-search-gradient-border-fix.user.js
    ];
  };
}
