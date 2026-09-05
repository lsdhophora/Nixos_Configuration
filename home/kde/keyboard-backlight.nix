{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Raise the keyboard backlight to its maximum at session start, using
  # KDE's own mechanism (PowerDevil / org.kde.Solid.PowerManagement)
  # instead of writing to /sys/class/leds directly. PowerDevil is the
  # component that owns keyboard brightness (see the "Keyboard backlight"
  # entry in System Settings > Power Management) and exposes it over DBus.
  # The max value is queried at runtime so this also works if the laptop
  # is ever swapped for one with more brightness steps.
  setMaxScript = pkgs.writeShellScript "kde-keyboard-backlight-max" ''
    service="org.kde.Solid.PowerManagement"
    object="/org/kde/Solid/PowerManagement/Actions/KeyboardBrightnessControl"
    iface="org.kde.Solid.PowerManagement.Actions.KeyboardBrightnessControl"
    qdbus="${pkgs.kdePackages.qttools}/bin/qdbus"
    max="$($qdbus "$service" "$object" "$iface.keyboardBrightnessMax" 2>/dev/null)"
    if [ -n "$max" ] && [ "$max" -gt 0 ]; then
      $qdbus "$service" "$object" "$iface.setKeyboardBrightness" "$max" \
        >/dev/null 2>&1 || true
    fi
  '';
in
{
  config = lib.mkIf config.keyboardBacklightMax.enable {
    # PowerDevil only runs inside the Plasma session, so apply at login
    # (and again on rebuilds while the session is live).
    systemd.user.services.keyboard-backlight-max = {
      Unit = {
        Description = "Raise keyboard backlight to maximum";
        After = [ "plasma-powerdevil.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = setMaxScript;
      };
      Install = {
        WantedBy = [ "plasma-workspace.target" ];
      };
    };

    home.activation.keyboardBacklightMax = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      toString setMaxScript
    );
  };

  options.keyboardBacklightMax = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Set the keyboard backlight to its maximum via PowerDevil.";
    };
  };
}
