final: prev: {
  cosmic-applets = prev.cosmic-applets.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace cosmic-applet-audio/src/lib.rs \
        --replace-fail '&[100]' '&[98]'
    '';
  });
}
