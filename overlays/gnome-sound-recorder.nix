final: prev:

{
  gnome-sound-recorder = prev.gnome-sound-recorder.overrideAttrs (old: {
    postPatch = ''
      chmod +x build-aux/meson_post_install.py
      substituteInPlace build-aux/meson_post_install.py \
        --replace-fail 'gtk-update-icon-cache' 'gtk4-update-icon-cache'
      patchShebangs build-aux/meson_post_install.py
      substituteInPlace data/ui/row.ui \
        --replace-fail emblem-ok-symbolic object-select-symbolic
    '';
  });
}
