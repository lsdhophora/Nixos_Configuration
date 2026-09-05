{
  inputs,
  pkgs,
  repoLib,
  ...
}:
let
  # Match the desktop's Plasma version (unstable kdePackages, like lid-wake.nix).
  unstable = repoLib.unstablePkgs inputs pkgs;
  baloo = unstable.kdePackages.baloo;
  balooctl6 = "${baloo}/bin/balooctl6";
  balooFile = "${baloo}/libexec/kf6/baloo_file";
in
{
  # /home is tmpfs but the Baloo index (.local/share/baloo) is persisted, so
  # stale entries of deleted tmpfs files (e.g. a removed ~/denial dir) survive
  # reboots and keep showing up in KRunner/launcher file search. Purge the
  # index once per boot; Baloo then reindexes automatically. The marker file
  # lives on tmpfs (~/.local/state/baloo-purge), so it resets every boot.
  #
  # NOTE: balooctl6 disable/enable are NOT used: ~/.config/baloofilerc is a
  # single-file bind mount (impermanence), so KConfig's atomic write (temp +
  # rename) fails with EBUSY there. Instead we stop the indexer process, purge
  # the database, and relaunch baloo_file directly.
  systemd.user.services.baloo-purge-once-per-boot = {
    Unit = {
      Description = "Purge the Baloo index once per boot";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      # Keep the relaunched baloo_file alive when this unit reaches
      # inactive after ExecStart completes.
      KillMode = "process";
      ExecStart = pkgs.writeShellScript "baloo-purge-once-per-boot" ''
        marker="$HOME/.local/state/baloo-purge/ran"
        if [ -f "$marker" ]; then
          exit 0
        fi
        mkdir -p "$(dirname "$marker")"
        : > "$marker"

        # Stop a running indexer (it may have been autostarted already).
        pkill -x baloo_file >/dev/null 2>&1 || true
        for _ in $(seq 1 10); do
          pgrep -x baloo_file >/dev/null 2>&1 || break
          sleep 0.5
        done

        # Purge the index database; retry in case shutdown is still in
        # progress. balooctl6 purge itself writes no config.
        for _ in 1 2 3 4 5; do
          if ${balooctl6} purge >/dev/null 2>&1; then
            break
          fi
          sleep 1
        done

        # Relaunch the indexer so a fresh index builds right away.
        setsid ${balooFile} </dev/null >/dev/null 2>&1 &
      '';
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
