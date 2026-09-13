# pi-coding-agent comes from nixpkgs-unstable (which now tracks 0.85.1,
# newer than the previously pinned 0.84.2; the old pin existed because the
# nixpkgs input lagged behind, and it has since caught up, so the pin is
# gone).
# This overlay only re-applies our pi-tui editor patches on top of the stock
# derivation:
#   - render a "> " input prompt in the TUI editor
#   - light grey editor caret instead of reverse video
#
# The kitty-protocol F-key patch was dropped: wezterm (our terminal) always
# encodes F1-F4 as legacy SS3 and F5-F12 as legacy CSI ~ sequences even when
# the kitty keyboard protocol is active, so upstream's legacy matching
# already covers it.
#
# The patch scripts rewrite the bundled dist file. They fail loudly when a
# pattern does not match, so a pi version bump breaks the build instead of
# silently losing the patches.
{ inputs, repoLib }: final: prev: {
  pi-coding-agent = (repoLib.unstablePkgs inputs prev).pi-coding-agent.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      node ${../patches/pi-agent/patch-editor-prompt.mjs} "$out"
      node ${../patches/pi-agent/patch-editor-cursor.mjs} "$out"
    '';
  });
}
