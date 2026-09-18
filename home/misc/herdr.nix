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

      # Herdr raises a background notification whenever a reported agent
      # turn ends. A scheduled watchdog ends one turn per interval, so a
      # non-off delivery pops "pi finished" on every check. Turn the
      # automatic popups and sounds off; a task that finishes sends one
      # explicit `herdr notification show` instead. Herdr still shows an
      # explicit notification with delivery = "off".
      #
      # This also keeps a /nix/store program directory out of the pane
      # PATH: with the automatic popups off, herdr never runs notify-send
      # behind the user, so the Starship nix_shell heuristic stays quiet
      # (see overlays/herdr.nix). The explicit notification uses the
      # notify-send from the home profile.
      [ui.toast]
      delivery = "off"

      # No sound alerts, for the same reason.
      [ui.sound]
      enabled = false
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
