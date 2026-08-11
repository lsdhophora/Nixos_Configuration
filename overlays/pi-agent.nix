# Patch the pi-tui editor to render a "> " input prompt.
# The patch script rewrites the bundled dist file. It fails loudly when a
# pattern does not match, so a pi version bump breaks the build instead of
# silently losing the prompt.
final: prev: {
  pi-coding-agent = prev.pi-coding-agent.overrideAttrs (oldAttrs: {
    postInstall = (oldAttrs.postInstall or "") + ''
      node ${../patches/pi-agent/patch-editor-prompt.mjs} "$out"
    '';
  });
}
