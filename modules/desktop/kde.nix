{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  unstable = inputs.nixpkgs-unstable;
in
{
  services.desktopManager.plasma6.enable = true;

  environment.systemPackages = [
    pkgs.klassy # overridden in overlay below to remove Type=Application from .desktop
    pkgs.kwin-renumber-desktops # auto-renumbers virtual desktops from 1
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
          patches = (oldAttrs.patches or [ ]) ++ [
            ./../../patches/plasma-desktop/lookandfeelbox-highlight-border.patch
            ./../../patches/plasma-desktop/hide-virtual-keyboard-button.patch
            ./../../patches/plasma-desktop/suppress-unlock-failed-on-resume.patch
            ./../../patches/plasma-desktop/kcm-splash-dedup.patch
          ];
        });
        kscreenlocker = prev.kdePackages.kscreenlocker.overrideAttrs (oldAttrs: {
          patches = (oldAttrs.patches or [ ]) ++ [
            ./../../patches/kscreenlocker/fix-prepare-for-sleep-cancel-on-wake.patch
          ];
        });
        plasma-workspace = prev.kdePackages.plasma-workspace.overrideAttrs (oldAttrs: {
          patches = (oldAttrs.patches or [ ]) ++ [
            ./../../patches/plasma-workspace/jobitem-null-check.patch
          ];
        });
        ark = prev.kdePackages.ark.overrideAttrs (oldAttrs: {
          patches = (oldAttrs.patches or [ ]) ++ [
            ./../../patches/ark/batchextract-desturl.patch
          ];
        });
        # Hide the current directory in the location-bar jump menu.
        dolphin =
          let
            unstablePkgs = unstable.legacyPackages.${prev.stdenv.hostPlatform.system};
            # Only Dolphin uses this kio build with the location-bar border
            # fix, so the rest of the desktop keeps the stock kio and the
            # rebuild stays small.
            patchedKio = prev.kdePackages.kio.overrideAttrs (oldAttrs: {
              patches = (oldAttrs.patches or [ ]) ++ [
                ./../../patches/kio/kurlnavigator-button-border.patch
              ];
            });
            patchedKdeSelf = prev.kdePackages // { kio = patchedKio; };
            mkKdeDerivationForDolphin =
              (import "${prev.path}/pkgs/kde/lib/mk-kde-derivation.nix" patchedKdeSelf) {
                inherit
                  (unstablePkgs)
                  lib
                  stdenv
                  makeSetupHook
                  cmake
                  ninja
                  qt6
                  python3
                  python3Packages
                  jq
                  ;
              };
          in
          (prev.kdePackages.dolphin.override {
            mkKdeDerivation = mkKdeDerivationForDolphin;
          }).overrideAttrs (oldAttrs: {
            patches = (oldAttrs.patches or [ ]) ++ [
              ./../../patches/dolphin/hide-current-dir-path-selector.patch
            ];
            # Put the patched kio first in the link inputs so that the
            # linker and the dynamic loader resolve to it instead of the
            # stock kio that is pulled in transitively.
            buildInputs = [ patchedKio ] ++ (oldAttrs.buildInputs or [ ]);
            propagatedBuildInputs = [ patchedKio ] ++ (oldAttrs.propagatedBuildInputs or [ ]);
          });
      };
    })

    # Remove Klassy .desktop to prevent KService from indexing it,
    # which causes it to appear on the Most Used page.
    (final: prev: {
      klassy =
        unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.klassy.overrideAttrs
          (oldAttrs: {
            postInstall = (oldAttrs.postInstall or "") + ''
              rm -f "$out/share/applications/kcm_klassydecoration.desktop"
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
      kdePackages.fcitx5-qt
    ];
    fcitx5.waylandFrontend = true;
  };
}
