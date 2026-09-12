# Tech Debt

Workarounds to remove after the upstream condition holds.

- **Lid-open screen wake** (`home/kde/lid-wake.nix`) — KWin 6.8 wakes the
  screen natively (kwin commit 0de12027c); the workaround covers
  PowerDevil's no-op `simulateUserActivity` on Wayland. Drop it, and its
  import in `home/kde/default.nix`, when unstable nixpkgs ships kwin 6.8.
- **Herdr client patches** (`patches/herdr/`) — two temporary fixes for the
  terminal client: raw mode before the handshake, and drop input after
  hangup. Drop each one when upstream fixes it.
