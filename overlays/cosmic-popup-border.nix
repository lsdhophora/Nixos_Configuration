final: prev: {
  cosmic-applets = prev.cosmic-applets.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ../patches/cosmic-app-list/thicker-popup-border.patch
    ];
    preBuild = (old.preBuild or "") + ''
      echo "cosmic-popup-border: looking for libcosmic applet/mod.rs..."
      f=$(find /build -maxdepth 5 -path "*/libcosmic*/src/applet/mod.rs" -print -quit 2>/dev/null)
      if [ -n "$f" ]; then
        echo "cosmic-popup-border: patching $f"
        substituteInPlace "$f" --replace-fail 'width: 1.0,' 'width: 2.0,'
      else
        echo "cosmic-popup-border: libcosmic applet/mod.rs not found in /build"
        ls /build/ 2>/dev/null | head -10
      fi
    '';
  });
}
