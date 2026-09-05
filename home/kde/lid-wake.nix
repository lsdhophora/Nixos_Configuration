{
  inputs,
  pkgs,
  repoLib,
  ...
}:
let
  # Match the desktop's KWin version (kde.nix uses unstable kdePackages).
  unstable = repoLib.unstablePkgs inputs pkgs;
  kscreenDoctor = "${unstable.kdePackages.libkscreen}/bin/kscreen-doctor";
  gdbus = "${pkgs.glib.bin}/bin/gdbus";
in
{
  # PowerDevil wakes the screen on lid open with
  # KIdleTime::simulateUserActivity(). On Wayland, this function is a
  # no-op. KWin handles the lid switch only from Plasma 6.8 on. Until
  # then, watch the UPower lid property and force the screen on.
  # TODO: remove this module when unstable nixpkgs ships Plasma 6.8.
  systemd.user.services.lid-wake = {
    Unit = {
      Description = "Turn the screen on when the laptop lid opens";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      Type = "simple";
      Restart = "always";
      RestartSec = 2;
      ExecStart = pkgs.writeShellScript "lid-wake" ''
        # UPower emits LidIsClosed=false on the daemon object when the
        # lid opens. kscreen-doctor then forces DPMS on.
        ${gdbus} monitor --system \
          --dest org.freedesktop.UPower \
          --object-path /org/freedesktop/UPower \
          | while IFS= read -r line; do
              case "$line" in
                *"LidIsClosed"*"<false>"*) ${kscreenDoctor} --dpms on || true ;;
              esac
            done
      '';
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
