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
    # Replace kdePackages with unstable
    (final: prev: {
      kdePackages = unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.kdePackages;
    })
    # Patch plasma-workspace: fix accent color radio button border clipping
    (final: prev: {
      kdePackages = prev.kdePackages // {
        plasma-workspace = prev.kdePackages.plasma-workspace.overrideAttrs (oldAttrs: {
          patches = (oldAttrs.patches or []) ++ [
            ./../../patches/plasma-workspace/accent-color-clip.patch
          ];
        });
      };
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
