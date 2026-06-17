final: prev: {
  gnome-shell = prev.gnome-shell.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/gnome-shell/fix-a11y-always-show-setting.patch
      ../patches/gnome-shell/hide-app-details.patch
      ../patches/gnome-shell/fix-zero-length-event-time.patch
      ../patches/gnome-shell/ext-app-website-icon-home.patch
    ];
  });
}
