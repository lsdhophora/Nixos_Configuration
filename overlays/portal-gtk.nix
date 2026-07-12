final: prev: {
  xdg-desktop-portal-gtk = prev.xdg-desktop-portal-gtk.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/xdg-desktop-portal-gtk/hide-filter-and-readonly.patch
    ];
    postFixup = (old.postFixup or "") + ''
      substituteInPlace $out/share/xdg-desktop-portal/portals/gtk.portal \
        --replace-fail "UseIn=gnome" "UseIn=sway"
    '';
  });
}
