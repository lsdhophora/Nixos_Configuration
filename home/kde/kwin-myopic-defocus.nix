{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Write the effect state into kwinrc:
  #   [Plugins] myopicdefocusEnabled=true
  #   [Effect-myopicdefocus] GreenBlurRadius / BlueBlurRadius / EffectStrength
  # KWin re-reads kwinrc and re-scans effect plugins on every
  # `org.kde.KWin.reconfigure`, so the DBus call at the end makes the
  # effect come up immediately after a rebuild (no re-login needed).
  # Shared by the login systemd unit and the rebuild activation script.
  applyEffect = pkgs.writeShellScript "apply-kwin-myopic-defocus" ''
    ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
      --file kwinrc --group Plugins --key myopicdefocusEnabled true
    ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
      --file kwinrc --group Effect-myopicdefocus --key GreenBlurRadius \
      ${toString config.kwinMyopicDefocus.greenBlurRadius}
    ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
      --file kwinrc --group Effect-myopicdefocus --key BlueBlurRadius \
      ${toString config.kwinMyopicDefocus.blueBlurRadius}
    ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
      --file kwinrc --group Effect-myopicdefocus --key EffectStrength \
      ${toString config.kwinMyopicDefocus.effectStrength}
    # Ask the running compositor to pick up the new config.
    /run/current-system/sw/bin/dbus-send --session --dest=org.kde.KWin \
      --type=method_call /KWin org.kde.KWin.reconfigure \
      >/dev/null 2>&1 || true
  '';
in
{
  options.kwinMyopicDefocus = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Declaratively enable the kwin-myopic-defocus effect.";
    };
    greenBlurRadius = lib.mkOption {
      type = lib.types.number;
      default = 2.5;
      description = "Gaussian sigma (px) for the green channel.";
    };
    blueBlurRadius = lib.mkOption {
      type = lib.types.number;
      default = 7.0;
      description = "Gaussian sigma (px) for the blue channel.";
    };
    effectStrength = lib.mkOption {
      type = lib.types.number;
      default = 0.30;
      description = "Blend of blurred over original (0..1).";
    };
  };

  config = lib.mkIf config.kwinMyopicDefocus.enable {
    # The systemd unit re-applies it at every login, so even if the
    # effect is disabled in System Settings the next session starts
    # with it enabled again.
    systemd.user.services.kwin-myopic-defocus = {
      Unit = {
        Description = "Declaratively enable the kwin-myopic-defocus effect";
        After = [ "plasma-kwin_wayland.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = applyEffect;
      };
      Install = {
        WantedBy = [ "plasma-workspace.target" ];
      };
    };

    # Also apply during `nixos-rebuild` (while the session is running), so
    # the effect appears right away instead of at the next login.
    home.activation.kwinMyopicDefocus = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      toString applyEffect
    );
  };
}
