final: prev: {
  pop-launcher = prev.pop-launcher.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      rm -rf $out/share/pop-launcher/scripts/system76-power
    '';
  });
}
