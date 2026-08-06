{ pkgs, ... }:
let
  t = "${pkgs.tmux}/bin/tmux";
  pi = "${pkgs.pi-coding-agent}/bin/pi";
in {
  # Auto-restore the hv-farm tmux session on login (and after reboot).
  # Runs a dedicated pi in ~/Projects/HVAuto so pi-scheduler can restore
  # its cron tasks from ~/Projects/HVAuto/.pi/scheduler.json.
  systemd.user.services.hv-farm = {
    Unit.Description = "Restore hv-farm tmux session (pi + pi-scheduler)";
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = ''
        ${pkgs.bash}/bin/bash -c "${t} has-session -t hv-farm || ${t} new-session -d -s hv-farm 'cd ~/Projects/HVAuto && exec ${pi}'"
      '';
    };
    Install.WantedBy = [ "default.target" ];
  };
}
