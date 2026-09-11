{ ... }:
{
  # Declarative herdr configuration. Herdr writes this file during
  # onboarding and on channel changes, so it may diverge between Home
  # Manager activations; the next switch restores this content.
  #
  # NixOS manages herdr itself (home/misc/cli.nix pins the package from
  # nixpkgs-unstable), so the built-in update checks and the update
  # menu entry are disabled.
  home.file.".config/herdr/config.toml" = {
    force = true;
    text = ''
      onboarding = false

      [update]
      channel = "stable"
      version_check = false
      manifest_check = false

      [theme]
      name = "one-light"
      auto_switch = false
    '';
  };
}
