{ config, lib, pkgs, inputs, ... }:
let
  unstable = inputs.nixpkgs-unstable;
in {
  services.desktopManager.plasma6.enable = true;

  environment.systemPackages = [
    pkgs.klassy  # overridden above to add plasma/kcms symlink
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

    # systemsettings sidebar requires KCMs under plasma/kcms/systemsettings/,
    # but klassy installs its KCM to org.kde.kdecoration3.kcm/.
    # Symlink it so systemsettings can discover and launch it from the sidebar.
    # Also remove X-KDE-AliasFor from the desktop file to prevent it from
    # appearing on the Most Used landing page (now redundant with the symlink).
    (final: prev: {
      klassy = unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.klassy.overrideAttrs (oldAttrs: {
        patches = (oldAttrs.patches or []) ++ [
          ./../../patches/klassy/kcm-systemsettings-category.patch
        ];
        postInstall = (oldAttrs.postInstall or "") + ''
          pluginDir="$out/lib/qt-6/plugins"
          mkdir -p "$pluginDir/plasma/kcms/systemsettings"
          ln -sf "../../../org.kde.kdecoration3.kcm/kcm_klassydecoration.so" "$pluginDir/plasma/kcms/systemsettings/kcm_klassydecoration.so"
          sed -i '/^X-KDE-AliasFor=/d' "$out/share/applications/kcm_klassydecoration.desktop"
        '';
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
