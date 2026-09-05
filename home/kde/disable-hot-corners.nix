{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Turn off the Plasma 6 Overview hot corner (top-left edge/corner).
  #
  # KWin stores the corner bindings in the effect config group
  # [Effect-overview], key BorderActivate (IntList of ElectricBorder
  # ids). Default: ElectricTopLeft (8). Writing an EMPTY value disables
  # the trigger (this is what the Screen Edges KCM writes for "No
  # Action"). Do not write "0": the ElectricNone numeric id is not
  # reliable across KWin versions and can remap to another border.
  #
  # Three obstacles make this non-trivial:
  #   1. ~/.config/kwinrc is a single-file bind mount from /persist, so
  #      KConfig's atomic temp-file + rename save fails with EBUSY
  #      (kwriteconfig6 and System Settings cannot write it).
  #   2. KWin itself CAN rewrite the whole file from its in-memory state,
  #      which silently removes hand-appended sections (observed).
  #   3. A plain reconfigure() does not make the Overview effect re-read
  #      BorderActivate once it is loaded.
  # Fix: unload the effect, write the value in place (truncate + write,
  # which works through the bind mount), reload the effect so it reads the
  # new value into KWin memory, then reconfigure. Any later KWin rewrite
  # then keeps the value.
  applyScript = pkgs.writeShellScript "disable-kwin-hot-corners" ''
    dbus-send --session --dest=org.kde.KWin \
      --type=method_call /Effects org.kde.kwin.Effects.unloadEffect \
      string:overview >/dev/null 2>&1 || true
    kwinrc="$HOME/.config/kwinrc"
    if [ -f "$kwinrc" ]; then
      ${pkgs.python3}/bin/python3 - "$kwinrc" <<'PY'
    import sys

    path = sys.argv[1]
    with open(path, encoding="utf-8") as f:
        text = f.read()
    if not text.endswith("\n"):
        text += "\n"

    out = []
    in_overview = False
    for line in text.splitlines(keepends=True):
        body = line.rstrip("\n")
        if body == "[Effect-overview]":
            in_overview = True
            continue
        if in_overview:
            if body.startswith("["):
                in_overview = False
            else:
                continue
        out.append(line)
    while out and not out[-1].strip():
        out.pop()
    out.append("\n[Effect-overview]\nBorderActivate=\n")
    with open(path, "w", encoding="utf-8") as f:
        f.write("".join(out))
    PY
    fi
    # Load the effect again so it reads the updated kwinrc, then make the
    # compositor pick up the new state.
    dbus-send --session --dest=org.kde.KWin \
      --type=method_call /Effects org.kde.kwin.Effects.loadEffect \
      string:overview >/dev/null 2>&1 || true
    /run/current-system/sw/bin/dbus-send --session --dest=org.kde.KWin \
      --type=method_call /KWin org.kde.KWin.reconfigure \
      >/dev/null 2>&1 || true
  '';
in
{
  config = lib.mkIf config.disableHotCorners.enable {
    systemd.user.services.disable-hot-corners = {
      Unit = {
        Description = "Turn off the Overview hot corner";
        After = [ "plasma-kwin_wayland.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = applyScript;
      };
      Install = {
        WantedBy = [ "plasma-workspace.target" ];
      };
    };

    # Also apply during a rebuild while the session is running.
    home.activation.disableHotCorners = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      toString applyScript
    );
  };

  options.disableHotCorners = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Turn off the Overview screen-edge/corner trigger.";
    };
  };
}
