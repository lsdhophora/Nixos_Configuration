final: prev: {
  gnome-shell = prev.gnome-shell.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/gnome-shell-fix-a11y-always-show-setting.patch
      ../patches/gnome-hide-app-details.patch
    ];
  });
}
