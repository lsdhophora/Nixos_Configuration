final: prev: {
  gnomeExtensions = prev.gnomeExtensions // {
    emoji-copy = prev.gnomeExtensions.emoji-copy.overrideAttrs (old: {
      patches = (old.patches or []) ++ [
        ../patches/emoji-copy-word-boundary-search.patch
      ];
    });
  };
}
