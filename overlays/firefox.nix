final: prev:
let
  ff = prev.firefox-unwrapped;

  patch-omni-ja = ''
    # Patch browser/omni.ja
    tmpdir=$(mktemp -d)
    cd "$tmpdir"
    unzip -o ${ff}/lib/firefox/browser/omni.ja 2>/dev/null || true

    echo '#downloadsListBox.allDownloadsListBox { border: none !important; appearance: none !important; }' >> chrome/browser/skin/classic/browser/downloads/allDownloadsView.inc.css

    rm -f "$out/lib/firefox/browser/omni.ja"
    (cd "$tmpdir" && zip -0DXqr "$out/lib/firefox/browser/omni.ja" .)
    rm -rf "$tmpdir"
  '';

  commonPassthru = ff: (ff.passthru or { }) // {
    binaryName = ff.binaryName or "firefox";
    libName = ff.libName or "firefox";
    ffmpegSupport = ff.ffmpegSupport or false;
    gssSupport = ff.gssSupport or false;
    alsaSupport = ff.alsaSupport or false;
    pipewireSupport = ff.pipewireSupport or false;
    sndioSupport = ff.sndioSupport or false;
    jackSupport = ff.jackSupport or false;
    requireSigning = ff.requireSigning or true;
    allowAddonSideload = ff.allowAddonSideload or false;
  };

  commonNativeBuildInputs = [
    prev.unzip
    prev.zip
  ];
in
{
  firefox-patched =
    let
      ff-patched =
        final.runCommand "firefox-unwrapped-patched-${ff.version}"
          {
            nativeBuildInputs = commonNativeBuildInputs;
            inherit (ff) gtk3 applicationName meta;
            passthru = commonPassthru ff;
          }
          ''
            cp -a ${ff}/. $out
            chmod -R u+w $out

            # Inner wrapper: private ~/.config/gtk-3.0/gtk.css via XDG_CONFIG_HOME
            # wrapFirefox will wrap this (sed-updates paths to its $out)
            rm -f "$out/bin/firefox" "$out/bin/.firefox-wrapped"
            cat > "$out/bin/firefox" << 'FFWRAPPER'
            #!@bash@ -e
            if [ ! -d "/tmp/firefox-gtk-config-''${UID}" ]; then
              REAL_CONFIG="''${XDG_CONFIG_HOME:-$HOME/.config}"
              GTK_D=/tmp/firefox-gtk-config-''${UID}
              mkdir -p "$GTK_D"
              if [ -d "$REAL_CONFIG" ]; then
                for f in "$REAL_CONFIG"/*; do
                  b="$(basename "$f")"
                  [ "$b" = "gtk-3.0" ] && continue
                  ln -sf "$f" "$GTK_D/$b" 2>/dev/null || true
                done
                if [ -d "$REAL_CONFIG/gtk-3.0" ]; then
                  mkdir -p "$GTK_D/gtk-3.0"
                  for f in "$REAL_CONFIG/gtk-3.0"/*; do
                    b="$(basename "$f")"
                    [ "$b" = "gtk.css" ] && continue
                    ln -sf "$f" "$GTK_D/gtk-3.0/$b" 2>/dev/null || true
                  done
                fi
              fi
              echo 'decoration {' > "$GTK_D/gtk-3.0/gtk.css"
              echo '  box-shadow: none;' >> "$GTK_D/gtk-3.0/gtk.css"
              echo '}' >> "$GTK_D/gtk-3.0/gtk.css"
            fi
            export XDG_CONFIG_HOME="/tmp/firefox-gtk-config-''${UID}"
            exec "@out@/lib/firefox/firefox" "$@"
            FFWRAPPER
            sed -i "s|@bash@|${prev.bash}/bin/bash|g" "$out/bin/firefox"
            sed -i "s|@out@|$out|g" "$out/bin/firefox"
            chmod +x "$out/bin/firefox"

            ${patch-omni-ja}
          '';
    in
    final.wrapFirefox ff-patched { };

  firefox-no-gtkwrap =
    let
      ff-patched =
        final.runCommand "firefox-unwrapped-patched-${ff.version}"
          {
            nativeBuildInputs = commonNativeBuildInputs;
            inherit (ff) gtk3 applicationName meta;
            passthru = commonPassthru ff;
          }
          ''
            cp -a ${ff}/. $out
            chmod -R u+w $out

            ${patch-omni-ja}
          '';
    in
    final.wrapFirefox ff-patched { };
}
