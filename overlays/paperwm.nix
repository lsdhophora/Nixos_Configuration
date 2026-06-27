final: prev: {
  gnomeExtensions = prev.gnomeExtensions // {
    paperwm = prev.gnomeExtensions.paperwm.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        ../patches/paperwm/fix-focus-handler-layout-topbar.patch
      ];
    });
  };
}
