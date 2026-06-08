final: prev: {
  gnomeExtensions = prev.gnomeExtensions // {
    dash-to-panel =
      prev.gnomeExtensions.dash-to-panel.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ../patches/dash-to-panel-notrans.patch
        ];
      });
  };
}
