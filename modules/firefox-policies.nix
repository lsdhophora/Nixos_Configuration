{ lib, ... }:
# Firefox enterprise policies, written system-wide to
# /etc/firefox/policies/policies.json.
#
# Firefox reads this file on every Linux installation regardless of package
# wrapper.  The home-manager `programs.firefox.policies` option bakes the JSON
# into the wrapped package's lib/firefox/distribution/ dir instead, which the
# nixpkgs firefox wrapper never consults here: the wrapper script execs the
# unwrapped package's binary, so Firefox's GRE dir is the unwrapped package
# (no policies.json) and the baked policies are silently ignored.
let
  mozAddon = slug: {
    install_url = "https://addons.mozilla.org/firefox/downloads/latest/${slug}/addon-${slug}-latest.xpi";
    installation_mode = "force_installed";
  };
in
{
  environment.etc."firefox/policies/policies.json" = {
    text = builtins.toJSON {
      policies = {
        ExtensionSettings = lib.mapAttrs (_: mozAddon) {
          "uBlock0@raymondhill.net" = "ublock-origin";
          "{7a7a4a92-a2a0-41d1-9fd7-1e92480d612d}" = "stylus";
          "{aecec67f-0d10-4fa7-b7c7-609a2db280cf}" = "violentmonkey";
          "firefoxpwa@filips.si" = "pwas-for-firefox";
          "keepassxc-browser@keepassxc.org" = "keepassxc-browser";
        };
        AIControls = {
          Default = {
            Value = "blocked";
            Locked = true;
          };
        };
      };
    };
  };
}
