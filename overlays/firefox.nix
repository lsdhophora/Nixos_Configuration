final: prev:
let
  ff = prev.firefox-unwrapped;

  patch-omni-ja = ''
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

  tridactyl-native = prev.tridactyl-native.overrideAttrs (old: {
    installPhase = old.installPhase + ''
      sed -i '/"allowed_extensions"/ s/\[/["tridactyl-fixed@lophophora",/' \
        "$out/lib/mozilla/native-messaging-hosts/tridactyl.json"
    '';
  });

  mkBase = ''
    cp -a ${ff}/. $out
    chmod -R u+w $out
  '';

  gtk-wrapper = ''
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
  '';

  mkPkg = extra: final.runCommand "firefox-unwrapped-patched-${ff.version}"
    {
      nativeBuildInputs = commonNativeBuildInputs;
      inherit (ff) gtk3 applicationName meta;
      passthru = commonPassthru ff;
    } ''
    ${mkBase}
    ${extra}
    ${patch-omni-ja}
  '';
in
{
  inherit tridactyl-native;

  firefox-patched = final.wrapFirefox (mkPkg gtk-wrapper) {
    nativeMessagingHosts = [ final.tridactyl-native ];
  };

  firefox-no-gtkwrap = final.wrapFirefox (mkPkg "") { };

  firefox-sway = final.wrapFirefox (mkPkg "") {
    nativeMessagingHosts = [ final.tridactyl-native ];
  };
}
