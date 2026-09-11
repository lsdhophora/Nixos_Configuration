# Patch the herdr client on two shutdown paths.
#
# 1. raw-mode-before-handshake.patch: the client enabled raw mode only after
#    the handshake finished. While the handshake is in flight, the host tty
#    stays in canonical mode. The line discipline then converts Enter to LF.
#    The client reads that LF later and forwards it to the focused pane. A pane
#    application that enables the Kitty keyboard protocol (pi) maps LF to
#    shift+enter, so the composer gains an extra newline.
#
# 2. drop-input-after-hangup.patch: the client main loop checked the quit flag
#    only at the top of the loop. A SIGHUP that arrives while a stdin read is
#    pending sets the flag, but the resumed read still returns the bytes the
#    host terminal wrote during shutdown (WezTerm writes LF and EOT when it
#    closes a pane). The client forwarded them and typed a newline or EOF into
#    the focused pane.
{ inputs, repoLib }: final: prev: {
  herdr = (repoLib.unstablePkgs inputs prev).herdr.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/herdr/raw-mode-before-handshake.patch
      ../patches/herdr/drop-input-after-hangup.patch
    ];
  });
}
