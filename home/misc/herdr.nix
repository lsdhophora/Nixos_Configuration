{ lib, ... }:
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
      name = "one-dark"
      auto_switch = false

      # "dots" shows the compact color marks; "symbols" shows one glyph
      # for each agent state.
      [ui]
      status_indicators = "symbols"

      # Send background notifications to the outer terminal, which asks the
      # desktop notification service. WezTerm does that in-process over D-Bus,
      # so the herdr PATH needs no notify-send. A notify-send from the nix
      # store in that PATH made the nix_shell heuristic of Starship report
      # "nix shell" in the prompt of every pane.
      [ui.toast]
      delivery = "terminal"
    '';
  };

  # Remove any pending release notes left over from a previous update
  # check. Herdr restores "update ready" from this file at startup when
  # its version is newer than the installed one, even with the checks
  # above disabled, so keep it deleted.
  home.activation.herdrClearPendingReleaseNotes = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    rm -f "$HOME/.config/herdr/release-notes.json"
  '';
}
