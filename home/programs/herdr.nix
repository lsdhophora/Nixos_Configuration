{ ... }:
# Herdr: agent-aware terminal multiplexer (package from nixpkgs-unstable,
# see home/misc/cli.nix). The config is declared here because the package
# self-updates otherwise: on NixOS the update must come from nix, so the
# background version check (and its "update available" menu entry) is off.
# The theme/onboarding settings below mirror what was set in the herdr UI;
# change them here, not in the UI (activation would revert the UI change).
{
  home.file = {
    ".config/herdr/config.toml" = {
      force = true;
      text = ''
        # Declared on NixOS: herdr is a home package from nixpkgs-unstable,
        # so updates come from nix. Disable the self-update UI.
        onboarding = false

        [theme]
        name = "one-light"
        auto_switch = false

        [update]
        version_check = false
      '';
    };
  };
}
