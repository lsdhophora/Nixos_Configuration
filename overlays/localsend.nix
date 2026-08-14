# Fix LocalSend taskbar icon on Wayland (and X11).
#
# Root cause: the Flutter Linux runner never sets a window icon, and the Wayland
# app_id / X11 WM_CLASS is derived from argv[0], which after nixpkgs' makeWrapper
# double-wrap becomes the hidden ".localsend_app-wrapped_" name. Plasma then
# cannot map the window to LocalSend.desktop (StartupWMClass=localsend_app), so
# the taskbar falls back to the generic Wayland default icon after the window
# loads (the icon from the launcher startup notification is fine until then).
#
# The patch sets g_set_prgname("localsend_app") so the app_id matches the
# desktop file's StartupWMClass, and sets the window icon explicitly for X11.
let
  applyPatches = (import ../lib).applyPatches;
in
final: prev: {
  localsend = applyPatches [
    ../patches/localsend/wayland-app-id-window-icon.patch
  ] prev.localsend;
}
