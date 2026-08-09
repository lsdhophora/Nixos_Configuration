{ pkgs, ... }:
let
  t = "${pkgs.tmux}/bin/tmux";
  pi = "${pkgs.pi-coding-agent}/bin/pi";
in
{
  # Restore the hv-farm tmux session automatically on login (and after reboot).
  # It runs a dedicated pi in ~/Projects/HVAuto. pi-scheduler can then
  # restore its cron tasks from ~/Projects/HVAuto/.pi/scheduler.json.
  systemd.user.services.hv-farm = {
    Unit.Description = "Restore hv-farm tmux session (pi + pi-scheduler)";
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      # The desktop session imports TMUX_TMPDIR=/run/user/1000 after this
      # service runs at boot. Without an explicit value, tmux uses /tmp
      # and interactive shells cannot find the socket (`tmux ls` fails).
      # %t is XDG_RUNTIME_DIR (/run/user/1000). It matches the shells.
      Environment = "TMUX_TMPDIR=%t";
      ExecStart = ''
        ${pkgs.bash}/bin/bash -c "${t} has-session -t hv-farm || ${t} new-session -d -s hv-farm 'cd ~/Projects/HVAuto && PI_SESSION=hv-farm exec ${pi}'"
      '';
    };
    Install.WantedBy = [ "default.target" ];
  };
}
