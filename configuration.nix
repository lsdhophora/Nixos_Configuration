{
  inputs,
  lib,
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
    ./modules/services/dae.nix
    ./modules/services/pipewire.nix
    ./modules/security/age.nix
  ];

  nixpkgs.overlays = [
    (import ./overlays/epiphany.nix)
    (import ./overlays/gnome-sound-recorder.nix)
    (import ./overlays/gnome-shell.nix)
  ];

  programs.nix-ld.enable = true;

  services.flatpak.enable = true;

  environment.sessionVariables = {
    XCURSOR_THEME = "Kuromi-cursor";
    XCURSOR_SIZE = "48";
  };

  environment.systemPackages = (
    with pkgs;
    [
      flatpak
    ]
  );
}
