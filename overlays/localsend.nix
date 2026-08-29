# Tray icon theme name instead of the bundled relative white logo.
#
# LocalSend hardcodes `assets/img/logo-32-white.png` (a relative path) as
# the Linux tray icon. tray_manager passes it verbatim to
# libayatana-appindicator, which loads only absolute paths as files and
# resolves everything else through the icon theme, so the icon never
# resolves and the tray shows a white placeholder. The bundled asset
# replacement in gui.nix had no effect for the same reason (the file was
# never read). Use the hicolor theme icon `localsend` (the colored logo)
# that the nixpkgs package installs into share/icons/hicolor.
{ repoLib }: final: prev: {
  localsend = repoLib.applyPatches [
    ../patches/localsend/tray-icon-theme-name.patch
  ] prev.localsend;
}
