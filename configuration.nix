{
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/boot.nix
    ./modules/networking.nix
    ./modules/desktop/gnome.nix
    ./modules/user.nix
    ./modules/i18n.nix
    ./modules/nix-config.nix
    ./modules/services/cups.nix
    ./modules/services/dae.nix
    ./modules/services/pipewire.nix
    ./modules/security/age.nix
    ./modules/security/sudo.nix
  ];

  nixpkgs.overlays = [
    (import ./overlays/epiphany.nix)
    (import ./overlays/gnome-sound-recorder.nix)
    (import ./overlays/gnome-shell.nix)
    (import ./overlays/zathura.nix)
  ];

  programs.nix-ld.enable = true;
}
