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
#
# The package carries no wrapper. The toasts of herdr use the "terminal"
# delivery (home/misc/herdr.nix): the client asks the outer terminal, WezTerm,
# to show the notification, and WezTerm shows it in-process over D-Bus. That
# needs no notify-send program, where the older "system" delivery needed one on
# the herdr PATH. A /nix/store program directory in the PATH of every pane also
# made the Starship nix_shell heuristic report "nix shell" in the prompt.
#
# The patch lives in its own derivation. A change to a file under
# patches/herdr/ rebuilds `herdr-patched` with cargo and zig, which takes a
# full build of the package.
{ inputs, repoLib }:
final: prev:
let
  herdr-patched = (repoLib.unstablePkgs inputs prev).herdr.overrideAttrs (old: {
    # Do not set pname or version: the derivation must stay identical to the
    # one whose build the store already holds, or Nix builds it again.
    patches = (old.patches or [ ]) ++ [
      ../patches/herdr/raw-mode-before-handshake.patch
      ../patches/herdr/drop-input-after-hangup.patch
    ];
  });
in
{
  herdr = herdr-patched;
}
