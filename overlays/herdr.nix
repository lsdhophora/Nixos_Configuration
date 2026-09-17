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
# The wrapper adds notify-send to PATH. The `ui.toast.delivery = "system"`
# mode runs notify-send for a desktop notification. The client logs no error
# when that program is absent, so the toast fails without a message.
# nixpkgs does not add this runtime tool to the herdr package.
#
# notify-send reports its own program name as the notification app name.
# The shim below adds --app-name=herdr, so the desktop shows the herdr name.
# Herdr passes its own arguments after the shim arguments. A later app-name
# option from herdr would therefore win.
#
# The patch and the wrapper live in separate derivations. A change to either
# file under patches/herdr/ or to the shim rebuilds `herdr-patched` with
# cargo and zig, which takes a full build of the package. `herdr` itself is
# only a symlinkJoin on top of that, so a change to the wrapper alone costs
# nothing. Keep the wrapper out of `herdr-patched`.
{ inputs, repoLib }:
final: prev:
let
  notifySend = final.writeShellScriptBin "notify-send" ''
    exec ${final.libnotify}/bin/notify-send --app-name=herdr "$@"
  '';

  herdr-patched = (repoLib.unstablePkgs inputs prev).herdr.overrideAttrs (old: {
    # Do not set pname or version: the base derivation must stay identical to
    # the one without a wrapper, or the store already has it built.
    patches = (old.patches or [ ]) ++ [
      ../patches/herdr/raw-mode-before-handshake.patch
      ../patches/herdr/drop-input-after-hangup.patch
    ];
  });
in
{
  herdr = final.symlinkJoin {
    name = "herdr-${herdr-patched.version}";
    paths = [ herdr-patched ];
    nativeBuildInputs = [ final.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/herdr \
        --prefix PATH : ${final.lib.makeBinPath [ notifySend ]}
    '';
    meta = herdr-patched.meta;
  };
}
