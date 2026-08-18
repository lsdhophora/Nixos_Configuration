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

  # firefox-unwrapped does not set every passthru field (it depends on
  # the nixpkgs version). The defaults below fill the gaps uniformly.
  passthruDefaults = {
    binaryName = "firefox";
    libName = "firefox";
    ffmpegSupport = false;
    gssSupport = false;
    alsaSupport = false;
    pipewireSupport = false;
    sndioSupport = false;
    jackSupport = false;
    requireSigning = true;
    allowAddonSideload = false;
  };

  commonPassthru =
    ff:
    (ff.passthru or { }) // (prev.lib.mapAttrs (name: default: ff.${name} or default) passthruDefaults);

  commonNativeBuildInputs = [
    prev.unzip
    prev.zip
  ];

  mkBase = ''
    cp -a ${ff}/. $out
    chmod -R u+w $out
  '';

  mkPkg =
    final.runCommand "firefox-unwrapped-patched-${ff.version}"
      {
        nativeBuildInputs = commonNativeBuildInputs;
        inherit (ff) gtk3 applicationName meta;
        passthru = commonPassthru ff;
      }
      ''
        ${mkBase}
        ${patch-omni-ja}
      '';
in
{
  firefox-patched = final.wrapFirefox mkPkg {
    nativeMessagingHosts = [
      final.kdePackages.plasma-browser-integration
    ];
  };
}
