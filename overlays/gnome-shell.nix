final: prev: {
  gnome-shell = prev.gnome-shell.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/gnome-shell/fix-a11y-always-show-setting.patch
      ../patches/gnome-shell/hide-app-details.patch
      ../patches/gnome-shell/fix-zero-length-event-time.patch
      ../patches/gnome-shell/ext-app-website-icon-home.patch
      ../patches/gnome-shell/just-perfection-startup-status.patch
    ];
    postInstall = (old.postInstall or "") + ''
      jp_schema="${prev.gnomeExtensions.just-perfection}/share/gnome-shell/extensions/just-perfection-desktop@just-perfection/schemas"
      schema_dir="$out/share/glib-2.0/schemas"
      if [ -d "$jp_schema" ] && [ -f "$jp_schema/org.gnome.shell.extensions.just-perfection.gschema.xml" ]; then
        cp "$jp_schema/org.gnome.shell.extensions.just-perfection.gschema.xml" "$schema_dir/"
      fi
    '';
  });
}
