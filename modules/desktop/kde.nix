{
  lib,
  pkgs,
  inputs,
  repoLib,
  ...
}:
let
  applyPatches = repoLib.applyPatches;
  unstablePkgs = repoLib.unstablePkgs inputs pkgs;

  # Patch files per KDE package.
  # Add an entry here to patch the package with applyPatches.
  # applyPatches keeps the existing upstream patches.
  kdePatches = {
    plasma-desktop = [
      ./../../patches/plasma-desktop/lookandfeelbox-highlight-border.patch
      ./../../patches/plasma-desktop/hide-virtual-keyboard-button.patch
      ./../../patches/plasma-desktop/suppress-unlock-failed-on-resume.patch
      ./../../patches/plasma-desktop/defer-failable-labels.patch
      ./../../patches/plasma-desktop/kcm-splash-dedup.patch
      ./../../patches/plasma-desktop/lockscreen-field-colors.patch
    ];
    plasma-workspace = [
      ./../../patches/plasma-workspace/jobitem-null-check.patch
    ];
    ark = [
      ./../../patches/ark/batchextract-desturl.patch
    ];
    # The breeze-gtk build compiles this SCSS fix into the theme CSS:
    # - Give treeview.view.trough the same radius as treeview.view.progressbar.
    breeze-gtk = [
      ./../../patches/breeze-gtk/theme-fixes.patch
    ];
    # xdg-desktop-portal-kde is patched in the kio overlay below. Its file
    # dialog embeds KFileWidget, so it must link the patched kio.
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
      # smartcard auth via pam_p11; PAM_AUTHINFO_UNAVAIL without a token.
      # The first argument IS the PKCS#11 module path (no "module=" prefix;
      # pam_p11 uses argv[0] directly). opensc returns AUTHINFO_UNAVAIL
      # when no reader is present, so the hint stays hidden.
      auth required ${pkgs.pam_p11}/lib/security/pam_p11.so ${pkgs.opensc}/lib/opensc-pkcs11.so
    '';
  };
  services.fprintd.enable = true; # provides pam_fprintd.so and the fprintd service

  environment.systemPackages = [
    pkgs.klassy # overridden in overlay below to remove Type=Application from .desktop
    pkgs.kwin-renumber-desktops # auto-renumbers virtual desktops from 1
    pkgs.kwin-myopic-defocus # myopic chromatic defocus (G/B blur) eye-care effect
  ];

  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    discover
    kate # kwrite lives in kate; we use other editors
  ];

  services.displayManager.sddm.enable = lib.mkForce false;
  services.displayManager.plasma-login-manager.enable = true;

  services.power-profiles-daemon.enable = false;

  nixpkgs.overlays = [
    # Use the unstable kdePackages set as the base for the whole desktop
    # and apply the per-package patch sets from `kdePatches` above.
    # Note: only the listed packages are rebuilt; packages that depend on
    # them (e.g. kwin -> kscreenlocker) keep their stock outputs. This
    # keeps the rebuild small and lets cache.nixos.org serve the rest.
    # (overrideScope was tried but it rebuilds the whole kdePackages set,
    # turning everything into custom builds that miss the binary cache.)
    (final: prev: {
      kdePackages =
        unstablePkgs.kdePackages
        // (repoLib.applyPatchesToSet kdePatches unstablePkgs.kdePackages);
    })
    # Dolphin and the file portal use the patched kio and the location-bar
    # fix. The plasma6 module pulls them from kdePackages, so the override
    # must patch the kdePackages entries (a top-level override does not reach
    # the desktop). The rest of the desktop keeps the stock kio. The rebuild
    # stays small.
    (
      final: prev:
      let
        patchedKio = applyPatches [
          ./../../patches/kio/kurlnavigator-button-border.patch
          ./../../patches/kio/openwith-hide-discover.patch
          ./../../patches/kio/openwith-plain-input.patch
        ] prev.kdePackages.kio;
        patchedKdeSelf = prev.kdePackages // {
          kio = patchedKio;
        };
        mkKdeDerivationForPatchedKio =
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
        # Put the patched kio first in the link inputs. The linker and the
        # dynamic loader then use it instead of the stock kio, which is pulled
        # in transitively.
        withPatchedKio =
          pkg:
          pkg.overrideAttrs (oldAttrs: {
            buildInputs = [ patchedKio ] ++ (oldAttrs.buildInputs or [ ]);
            propagatedBuildInputs = [ patchedKio ] ++ (oldAttrs.propagatedBuildInputs or [ ]);
          });
        patchedDolphin = withPatchedKio (
          applyPatches
            [
              ./../../patches/dolphin/hide-current-dir-path-selector.patch
              # Terminal sync: a currentDirectoryChanged report is only followed
              # if it is neither a duplicate of the terminal's previous directory
              # (stale "previous dir" reports from Konsole's debounce) nor one of
              # Dolphin's own pending programmatic "cd" commands (intermediate
              # targets passed through during fast view navigation). Anything else
              # is a real user "cd" and follows. Leftover commands are dropped
              # when following, so they cannot swallow later user actions.
              ./../../patches/dolphin/terminal-sync-keep-queue-on-mismatch.patch
            ]
            (
              prev.kdePackages.dolphin.override {
                mkKdeDerivation = mkKdeDerivationForPatchedKio;
              }
            )
        );
        # The portal's file dialog embeds KFileWidget, which uses the same
        # KUrlNavigator breadcrumb as Dolphin. Link it against the patched kio
        # so the location-bar border fix applies there too.
        patchedPortal = withPatchedKio (
          applyPatches
            [
              ./../../patches/xdg-desktop-portal-kde/appchooser-hide-discover.patch
              ./../../patches/xdg-desktop-portal-kde/appchooser-plain-input.patch
            ]
            (
              prev.kdePackages.xdg-desktop-portal-kde.override {
                mkKdeDerivation = mkKdeDerivationForPatchedKio;
              }
            )
        );
      in
      {
        kdePackages = prev.kdePackages // {
          dolphin = patchedDolphin;
          xdg-desktop-portal-kde = patchedPortal;
        };
      }
    )
    # Remove Klassy .desktop to prevent KService from indexing it,
    # which causes it to appear on the Most Used page.
    (final: prev: {
      klassy = applyPatches
        [
          ./../../patches/klassy/draw-titlebar-separator-in-tools-area.patch
          ./../../patches/klassy/remove-empty-corners-tooltip.patch
        ]
        (
          unstablePkgs.klassy.overrideAttrs (oldAttrs: {
            postInstall = (oldAttrs.postInstall or "") + ''
              rm -f "$out/share/applications/kcm_klassydecoration.desktop"
            '';
          })
        );
    })
    # kwin-myopic-defocus: myopic chromatic defocus (eye-care) KWin effect.
    # Builds against the same unstable kdePackages (kwin 6.7.x) the desktop
    # uses, so the plugin ABI matches the running compositor.  Source is
    # vendored in packages/kwin-myopic-defocus/src (tests excluded).
    (final: prev: {
      kwin-myopic-defocus = import ../../packages/kwin-myopic-defocus {
        inherit (prev.kdePackages) qtbase kglobalaccel kwindowsystem kconfig kconfigwidgets kcoreaddons ki18n kcmutils kwin extra-cmake-modules;
        inherit (unstablePkgs) lib stdenv cmake;
        epoxy = unstablePkgs.libepoxy;
      };
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
