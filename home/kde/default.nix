{ ... }:
{
  # KDE / Plasma configuration, grouped in one place. Imported from
  # ../default.nix; comment a line out to disable that module.
  #
  # NOTE: kde/persistence-kde.nix is intentionally NOT imported here. It
  # relies on the system-level impermanence module, so it is wired in
  # flake-modules/nixos.nix instead (NixOS path only, not standalone
  # home-manager).
  imports = [
    ./plasma.nix
    ./kwin-myopic-defocus.nix
    ./disable-hot-corners.nix
    ./keyboard-backlight.nix
    ./lid-wake.nix
    ./baloo-purge.nix
  ];
}
