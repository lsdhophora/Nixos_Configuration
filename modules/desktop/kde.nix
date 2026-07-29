{ config, lib, pkgs, inputs, ... }:
let
  unstable = inputs.nixpkgs-unstable;
in {
  services.desktopManager.plasma6.enable = true;

  # Use Plasma's own login manager instead of SDDM
  services.displayManager.sddm.enable = lib.mkForce false;
  services.displayManager.plasma-login-manager.enable = true;

  # Disable power-profiles-daemon (conflicts with TLP)
  services.power-profiles-daemon.enable = false;

  nixpkgs.overlays = [
    (final: prev: {
      kdePackages = unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.kdePackages;
    })
  ];

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      kdePackages.fcitx5-chinese-addons
      fcitx5-gtk
    ];
    fcitx5.waylandFrontend = true;
  };
}
