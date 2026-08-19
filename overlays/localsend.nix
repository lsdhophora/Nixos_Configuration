# Fix LocalSend title-bar / taskbar icon on Wayland (and X11).
#
# Root cause: Flutter's Linux runner creates a GtkApplication but on Wayland,
# GTK derives the xdg-toplevel app_id from g_get_prgname(), which (after
# nixpkgs makeWrapper double-wrapping) is the argv[0] basename
# ".localsend_app-wrapped_" / "localsend_app". Plasma then can't map the window
# to LocalSend.desktop (stem "localsend") and falls back to the generic icon.
# (The CMake APPLICATION_ID is ignored by GDK for the surface app_id here, so
#  we set both for belt-and-suspenders.)
#
# The patch forces g_set_prgname("localsend") so the app_id matches the desktop
# file name, also sets the window icon explicitly for X11, and postFixup aligns
# StartupWMClass with the new prgname so X11 keeps working too.
let
  applyPatches = (import ../lib).applyPatches;
in
final: prev: {
  localsend = (applyPatches [
    ../patches/localsend/wayland-app-id-window-icon.patch
  ] prev.localsend).overrideAttrs (old: {
    # Run after installPhase so copyDesktopItems has created the desktop file.
    # Two things must line up for the title-bar icon to show on Wayland:
    #
    # 1. KWin looks the icon up via XdgToplevelWindow::updateIcon() ->
    #    iconFromDesktopFile() -> findDesktopFile(m_desktopFileName). KWin sets
    #    desktopFileName to the xdg-toplevel app_id verbatim (see
    #    xdgshellwindow.cpp handleAppIdChanged -> setDesktopFileName(appId)),
    #    and findDesktopFile() does an exact, case-sensitive
    #    QStandardPaths::locate(Applications, desktopFileName + ".desktop").
    #    Our patch sets g_set_prgname("localsend"), so the app_id is
    #    "localsend" and the desktop file MUST be named "localsend.desktop" —
    #    the upstream "LocalSend.desktop" is never matched and KWin then falls
    #    back to the generic "wayland" icon.
    # 2. StartupWMClass must match for X11 (XWayland) to keep working.
    #
    # We rename the desktop file (and fix StartupWMClass) accordingly.
    # Locate the file defensively (name/path can vary between nixpkgs
    # revisions); skip if not present.
    postFixup = (old.postFixup or "") + ''
      d="$out/share/applications"
      f=$(find "$d" -iname '*.desktop' 2>/dev/null | while read -r x; do
            grep -q '^Name=LocalSend$' "$x" && echo "$x"
          done | head -1)
      if [ -n "$f" ]; then
        sed -i 's/^StartupWMClass=.*/StartupWMClass=localsend/' "$f"
        base=$(basename "$f")
        if [ "$base" != "localsend.desktop" ]; then
          mv -f "$f" "$d/localsend.desktop"
        fi
      fi
    '';
  });
}
