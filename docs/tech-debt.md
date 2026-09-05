# Tech Debt

This file lists workarounds to remove after an upstream condition is met.

## Plasma

### Lid-open screen wake workaround

- Condition: unstable nixpkgs ships Plasma 6.8 (kwin >= 6.8)
- Reason: KWin 6.8 wakes the screen on lid open natively (kwin commit 0de12027c). The workaround exists because PowerDevil's simulateUserActivity call is a no-op on Wayland.
- Steps:
  1. Delete `home/kde/lid-wake.nix`.
  2. Remove its import in `home/kde/default.nix`.
  3. Rebuild.
  4. Commit.
