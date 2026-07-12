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

  commonPassthru =
    ff:
    (ff.passthru or { })
    // {
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

  mkPkg =
    extra:
    final.runCommand "firefox-unwrapped-patched-${ff.version}"
      {
        nativeBuildInputs = commonNativeBuildInputs;
        inherit (ff) gtk3 applicationName meta;
        passthru = commonPassthru ff;
      }
      ''
        ${mkBase}
        ${extra}
        ${patch-omni-ja}
      '';
in
{
  inherit tridactyl-native;

  firefox-patched = final.wrapFirefox (mkPkg "") {
    nativeMessagingHosts = [ final.tridactyl-native ];
  };
}
