final: prev: {
  gnomeExtensions = prev.gnomeExtensions // {
    paperwm = prev.gnomeExtensions.paperwm.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        ../patches/paperwm/fix-workspace-is-my-window.patch
        ../patches/paperwm/fix-disable-above-cleanup.patch
        ../patches/paperwm/fix-fullscreen-selected-window.patch
        ../patches/paperwm/fix-click-focus-wayland.patch
      ];
    });
  };
}
