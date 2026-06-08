final: prev: {
  firefox-patched =
    let
      ff = prev.firefox-unwrapped;
      ff-patched =
        final.runCommand "firefox-unwrapped-patched-${ff.version}"
          {
            nativeBuildInputs = [
              prev.unzip
              prev.zip
            ];
            inherit (ff) gtk3 applicationName meta;
            passthru = (ff.passthru or { }) // {
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
          }
          ''
            cp -a ${ff}/. $out
            chmod -R u+w $out

            rm -f "$out/bin/firefox" "$out/bin/.firefox-wrapped"
            ln -s ../lib/firefox/firefox "$out/bin/firefox"

            # Patch browser/omni.ja
            tmpdir=$(mktemp -d)
            cd "$tmpdir"
            unzip -o ${ff}/lib/firefox/browser/omni.ja 2>/dev/null || true

            echo '#downloadsListBox.allDownloadsListBox { border: none !important; appearance: none !important; }' >> chrome/browser/skin/classic/browser/downloads/allDownloadsView.inc.css

            rm -f "$out/lib/firefox/browser/omni.ja"
            (cd "$tmpdir" && zip -0DXqr "$out/lib/firefox/browser/omni.ja" .)
            rm -rf "$tmpdir"

            # Patch toolkit/omni.ja - widen menupopup border
            cd /
            tmpdir=$(mktemp -d)
            cd "$tmpdir"
            unzip -o ${ff}/lib/firefox/omni.ja 2>/dev/null || true

            echo 'menupopup::part(content) { border-width: 2.5px !important; }' >> chrome/toolkit/skin/classic/global/popup.css

            rm -f "$out/lib/firefox/omni.ja"
            (cd "$tmpdir" && zip -0DXqr "$out/lib/firefox/omni.ja" .)
            rm -rf "$tmpdir"
          '';
    in
    final.wrapFirefox ff-patched { };
}
