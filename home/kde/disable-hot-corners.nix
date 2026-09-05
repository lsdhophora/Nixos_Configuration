{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Turn off the Plasma 6 Overview hot corner (top-left edge/corner).
  #
  # KWin stores the corner bindings inside each effect's own kwinrc group,
  # e.g. [Effect-overview] BorderActivate (IntList of ElectricBorder ids).
  # Default: ElectricTopLeft (8), so the top-left corner opens Overview.
  # Setting it to 0 (ElectricNone) disables the trigger.
  #
  # The script edits ~/.config/kwinrc in place (truncate + write, no
  # rename) because that file is a single-file bind mount from /persist:
  # KConfig's atomic temp-file + rename save fails with EBUSY on such a
  # mount point, which is also why the System Settings "Screen Edges"
  # dialog cannot save anything on this machine. See persistence-kde.nix
  # in this directory for the same limitation on appletsrc.
  applyScript = pkgs.writeShellScript "disable-kwin-hot-corners" ''
    set -e
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
    added = False
    seen_overview = False
    for line in text.splitlines(keepends=True):
        body = line.rstrip("\n")
        if body == "[Effect-overview]":
            in_overview = True
            seen_overview = True
            added = False
            out.append(line)
            continue
        if in_overview and body.startswith("[") and not added:
            out.append("BorderActivate=0\n")
            added = True
        if in_overview and body.startswith("["):
            in_overview = False
        if in_overview and body.startswith("BorderActivate="):
            if not added:
                out.append("BorderActivate=0\n")
                added = True
            continue
        if in_overview and not added and body.strip() and not body.startswith("#"):
            out.append("BorderActivate=0\n")
            added = True
        out.append(line)
    if in_overview and not added:
        out.append("BorderActivate=0\n")
    if not seen_overview:
        out.append("\n[Effect-overview]\nBorderActivate=0\n")
    with open(path, "w", encoding="utf-8") as f:
        f.write("".join(out))
    PY
    fi
    # Ask the running compositor to re-read the effect config.
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
