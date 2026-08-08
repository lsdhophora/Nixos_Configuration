{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  applyPatches = (import ../../lib).applyPatches;
  unstable = inputs.nixpkgs-unstable;
  unstablePkgs = unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  # Patches per KDE package. Add an entry here and the package is patched
  # via applyPatches (keeping any existing upstream patches).
  kdePatches = {
    plasma-desktop = [
      ./../../patches/plasma-desktop/lookandfeelbox-highlight-border.patch
      ./../../patches/plasma-desktop/hide-virtual-keyboard-button.patch
      ./../../patches/plasma-desktop/suppress-unlock-failed-on-resume.patch
      ./../../patches/plasma-desktop/kcm-splash-dedup.patch
    ];
    kscreenlocker = [
      ./../../patches/kscreenlocker/fix-prepare-for-sleep-cancel-on-wake.patch
    ];
    plasma-workspace = [
      ./../../patches/plasma-workspace/jobitem-null-check.patch
    ];
    ark = [
      ./../../patches/ark/batchextract-desturl.patch
    ];
    xdg-desktop-portal-kde = [
      ./../../patches/xdg-desktop-portal-kde/appchooser-hide-discover.patch
      ./../../patches/xdg-desktop-portal-kde/appchooser-plain-input.patch
    ];
  };
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
    # Use the unstable kdePackages set as the base for the whole desktop.
    (final: prev: {
      kdePackages = unstablePkgs.kdePackages;
    })
    # Apply the per-package patch sets from `kdePatches` above.
    (final: prev: {
      kdePackages =
        prev.kdePackages
        // (lib.mapAttrs (name: patches: applyPatches patches prev.kdePackages.${name}) kdePatches);
    })
    # Dolphin: patched kio + location-bar fix. Only Dolphin uses this kio
    # build with the location-bar border fix, so the rest of the desktop
    # keeps the stock kio and the rebuild stays small.
    (final: prev: {
      dolphin =
        let
          patchedKio = applyPatches [
            ./../../patches/kio/kurlnavigator-button-border.patch
            ./../../patches/kio/openwith-hide-discover.patch
            ./../../patches/kio/openwith-plain-input.patch
          ] prev.kdePackages.kio;
          patchedKdeSelf = prev.kdePackages // {
            kio = patchedKio;
          };
          mkKdeDerivationForDolphin =
            (import "${prev.path}/pkgs/kde/lib/mk-kde-derivation.nix" patchedKdeSelf)
              {
                inherit (unstablePkgs)
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
          patchedDolphin =
            applyPatches
              [
                ./../../patches/dolphin/hide-current-dir-path-selector.patch
              ]
              (
                prev.kdePackages.dolphin.override {
                  mkKdeDerivation = mkKdeDerivationForDolphin;
                }
              );
        in
        patchedDolphin.overrideAttrs (oldAttrs: {
          # Put the patched kio first in the link inputs so that the linker
          # and the dynamic loader resolve to it instead of the stock kio
          # that is pulled in transitively.
          buildInputs = [ patchedKio ] ++ (oldAttrs.buildInputs or [ ]);
          propagatedBuildInputs = [ patchedKio ] ++ (oldAttrs.propagatedBuildInputs or [ ]);
        });
    })
    # Remove Klassy .desktop to prevent KService from indexing it,
    # which causes it to appear on the Most Used page.
    (final: prev: {
      klassy = unstablePkgs.klassy.overrideAttrs (oldAttrs: {
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
