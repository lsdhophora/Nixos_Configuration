final: prev: {
  pantheon = prev.pantheon // {
    pantheon-agent-polkit = prev.pantheon.pantheon-agent-polkit.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        ../patches/pantheon-agent-polkit/accent-focus.patch
      ];
    });
  };
}
