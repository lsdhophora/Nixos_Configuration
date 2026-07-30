{ config, lib, pkgs, inputs, ... }:
let
  unstable = inputs.nixpkgs-unstable;
in {
  services.desktopManager.plasma6.enable = true;

  environment.systemPackages = [
    pkgs.darkly  # overridden to latest version in overlay below
  ];

  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    discover
  ];

  services.displayManager.sddm.enable = lib.mkForce false;
  services.displayManager.plasma-login-manager.enable = true;

  services.power-profiles-daemon.enable = false;

  nixpkgs.overlays = [
    (final: prev: {
      kdePackages = unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.kdePackages;
    })
    (final: prev: {
      kdePackages = prev.kdePackages // {
        plasma-desktop = prev.kdePackages.plasma-desktop.overrideAttrs (oldAttrs: {
          patches = (oldAttrs.patches or []) ++ [
            ./../../patches/plasma-desktop/lookandfeelbox-highlight-border.patch
            ./../../patches/plasma-desktop/hide-virtual-keyboard-button.patch
            ./../../patches/plasma-desktop/suppress-unlock-failed-on-resume.patch
          ];
        });
        kscreenlocker = prev.kdePackages.kscreenlocker.overrideAttrs (oldAttrs: {
          patches = (oldAttrs.patches or []) ++ [
            ./../../patches/kscreenlocker/fix-prepare-for-sleep-cancel-on-wake.patch
          ];
        });
      };
    })

    # Use latest Darkly (nixpkgs has 0.5.32 but upstream has 0.5.38)
    (final: prev: {
      darkly = prev.darkly.overrideAttrs (oldAttrs: {
        version = "0.5.38";
        src = prev.fetchFromGitHub {
          owner = "Bali10050";
          repo = "Darkly";
          rev = "v0.5.38";
          hash = "sha256-b/spO5sQn+Sk+KrSACfttkDwY/vF57NiHsWHYuQvS7s=";
        };
      });
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
