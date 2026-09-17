# Tech Debt

Workarounds to remove after the upstream condition holds.

- **Lid-open screen wake** (`home/kde/lid-wake.nix`) — KWin 6.8 wakes the
  screen natively (kwin commit 0de12027c); the workaround covers
  PowerDevil's no-op `simulateUserActivity` on Wayland. Drop it, and its
  import in `home/kde/default.nix`, when unstable nixpkgs ships kwin 6.8.
- **Herdr client patches** (`patches/herdr/`) — two temporary fixes for the
  terminal client: raw mode before the handshake, and drop input after
  hangup. Drop each one when upstream fixes it.
- **Wider line edit frame** (`assets/plasma/lineedit.svg`, the Klassy
  overlay) — a Plasma QML text field draws its frame from the desktop theme,
  so the copy widens the hover, focus, and focusframe frames of the Klassy
  themes to two logical pixels. Drop the file, the install loop, and the
  comment when Klassy draws that width. Never place this file in a partial
  theme directory below XDG_DATA_HOME: KSvg searches that directory first,
  finds no metadata.json, and falls back to the default theme.
