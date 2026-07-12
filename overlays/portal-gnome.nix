final: prev: {
  xdg-desktop-portal-gnome = prev.xdg-desktop-portal-gnome.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      substituteInPlace $out/share/xdg-desktop-portal/portals/gnome.portal \
        --replace-fail "UseIn=gnome" "UseIn=sway"
    '';
  });
}
