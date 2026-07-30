{ config, lib, pkgs, inputs, ... }:
let
  unstable = inputs.nixpkgs-unstable;
in {
  services.desktopManager.plasma6.enable = true;

  environment.systemPackages = [
    pkgs.klassy  # overridden to git master in overlay below
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

    # Use Klassy git master (newer than nixpkgs v6.5.3)
    (final: prev: {
      klassy = prev.klassy.overrideAttrs (oldAttrs: {
        version = "6.5.3-git";
        src = prev.fetchFromGitHub {
          owner = "paulmcauley";
          repo = "klassy";
          rev = "3fe6e7e39a9330dcb5803bb5d622eb31b19b215f";
          hash = "sha256-0nzb/oUMj6Toe8ZSdfZfuE/yPAHGHUE9gShXGMS7v9k=";
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
