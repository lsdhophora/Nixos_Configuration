# Build pi-coding-agent from nixpkgs-unstable, pinned to 0.84.2 (the nixpkgs
# input lags behind). 0.84.2 fixes DeepSeek models sending output limits
# through an unsupported field (truncated responses) and adds automatic
# retries for upstream request buffer failures.
#
# The same override also patches the pi-tui editor to render a "> " input
# prompt. The patch scripts rewrite the bundled dist file. They fail loudly
# when a pattern does not match, so a pi version bump breaks the build instead
# of silently losing the prompt.
{ inputs, repoLib }: final: prev: {
  pi-coding-agent = (repoLib.unstablePkgs inputs prev).pi-coding-agent.overrideAttrs (
    old:
    let
      src = prev.fetchFromGitHub {
        owner = "earendil-works";
        repo = "pi";
        tag = "v0.84.2";
        hash = "sha256-d29ft9otYxdHRWYIAX8KMHPpppToX9ME5LbPb1rPcYo=";
      };
    in
    {
      version = "0.84.2";
      inherit src;
      modelData = prev.fetchurl {
        url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-0.84.2.tgz";
        hash = "sha256-AmJ4Wnaw6y7sWWzYp6su4j7vidLvG7EhHE8KGUTaz0E=";
      };
      npmDeps = prev.fetchNpmDeps {
        inherit src;
        hash = "sha256-6J5Efe+6ptCuR3VZojwYPZO8BBnnZsOQ4OAeB64uYOY=";
      };
      postInstall = (old.postInstall or "") + ''
        node ${../patches/pi-agent/patch-editor-prompt.mjs} "$out"
        node ${../patches/pi-agent/patch-editor-cursor.mjs} "$out"
        node ${../patches/pi-agent/patch-main-screen-viewport.mjs} "$out"
        node ${../patches/pi-agent/patch-kitty-fkeys.mjs} "$out"
      '';
    }
  );
}
