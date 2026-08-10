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

  # Patch files per KDE package.
  # Add an entry here to patch the package with applyPatches.
  # applyPatches keeps the existing upstream patches.
  kdePatches = {
    plasma-desktop = [
      ./../../patches/plasma-desktop/lookandfeelbox-highlight-border.patch
      ./../../patches/plasma-desktop/hide-virtual-keyboard-button.patch
      ./../../patches/plasma-desktop/suppress-unlock-failed-on-resume.patch
      ./../../patches/plasma-desktop/kcm-splash-dedup.patch
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

  # kscreenlocker probes kde-fingerprint / kde-smartcard on every lock.
  # Without these files, Linux-PAM falls back to "other" (pam_deny) which
  # returns PAM_AUTH_ERR, so kscreenlocker thinks fingerprint/smartcard are
  # available and shows the "scan your fingerprint/smartcard" hints.
  # With these stacks the modules return PAM_AUTHINFO_UNAVAIL when no device
  # is present, so kscreenlocker marks the authenticators unavailable and
  # hides the hints. Users with hardware get working auth automatically.
  security.pam.services."kde-fingerprint" = {
    text = ''
      # fingerprint auth via fprintd; PAM_AUTHINFO_UNAVAIL without a reader
      auth required ${pkgs.fprintd}/lib/security/pam_fprintd.so
    '';
  };
  security.pam.services."kde-smartcard" = {
    text = ''
      # smartcard auth via pam_p11; PAM_AUTHINFO_UNAVAIL without a token
      auth required ${pkgs.pam_p11}/lib/security/pam_p11.so
    '';
  };
  services.fprintd.enable = true; # provides pam_fprintd.so and the fprintd service

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
    # Note: only the listed packages are rebuilt; packages that depend on
    # them (e.g. kwin -> kscreenlocker) keep their stock outputs. This
    # keeps the rebuild small and lets cache.nixos.org serve the rest.
    # (overrideScope was tried but it rebuilds the whole kdePackages set,
    # turning everything into custom builds that miss the binary cache.)
    (final: prev: {
      kdePackages =
        prev.kdePackages
        // (lib.mapAttrs (name: patches: applyPatches patches prev.kdePackages.${name}) kdePatches);
    })
    # Dolphin uses the patched kio and the location-bar fix.
    # Only Dolphin uses this kio build with the location-bar border fix.
    # The rest of the desktop keeps the stock kio. The rebuild stays small.
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
          # Put the patched kio first in the link inputs.
          # The linker and the dynamic loader then use it instead of the
          # stock kio, which is pulled in transitively.
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
