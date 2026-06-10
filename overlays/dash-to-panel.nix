final: prev: {
  gnomeExtensions = prev.gnomeExtensions // {
    dash-to-panel =
      prev.gnomeExtensions.dash-to-panel.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ../patches/dash-to-panel-notrans.patch
          ../patches/dash-to-panel-fix-workspace-indicator.patch
          ../patches/dash-to-panel-label-bg.patch
        ];
      });
  };
}
