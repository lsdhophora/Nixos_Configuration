final: prev: {
  gnomeExtensions = prev.gnomeExtensions // {
    emoji-copy = prev.gnomeExtensions.emoji-copy.overrideAttrs (old: {
      patches = (old.patches or []) ++ [
        ../patches/emoji-copy-word-boundary-search.patch
        ../patches/emoji-copy-remove-recents.patch
        ../patches/emoji-copy-select-all-by-group.patch
        ../patches/emoji-copy-gender-filter.patch
        ../patches/emoji-copy-exact-skin-tone.patch
        ../patches/emoji-copy-options-bar.patch
        ../patches/emoji-copy-category-filter.patch
      ];
    });
  };
}
