# NixOS Laptop Configuration

Flake-based config for "flowerpot". Uses flake-parts, Home Manager, sops-nix, Chaotic Nyx, custom overlays, Plasma 6.

## Commands

```bash
just check-fast                                    # fast static checks (~1 min)
just check                                         # full checks (static + builds)
nixos-rebuild dry-build --flake .#flowerpot       # verify (system + home)
run0 nixos-rebuild switch --flake .#flowerpot   # rebuild & switch (system)
home-manager switch --flake .#FeiHsueh         # home-only rebuild (fast, no system closure)
nix flake update                                   # update inputs
git push                                           # push
```

The `home-manager` CLI is installed via `home/misc/cli.nix` and pinned to the flake input revision (`inputs.home-manager.packages.${pkgs.system}.home-manager`).

## Workflow

1. Edit → `dry-build` pass
2. Rebuild
3. `git add -A`, then commit in Magit (`C-x g` → `c c`) with a
   GNU-format message
4. Push (if success)

Home-only changes (everything under `home/`) can skip the full `nixos-rebuild` and use `home-manager switch --flake .#FeiHsueh` instead. Both paths share `home/default.nix`; `homeConfigurations` is wired in `flake-modules/nixos.nix`.

Exception: declarative Plasma/KDE config (`home/kde/*.nix`, e.g. `plasma.nix` panels) must be followed by a full OS rebuild (`run0 nixos-rebuild switch --flake .#flowerpot`) to take effect; `home-manager switch` alone does not apply it. The regenerated panel layout is only applied at the next Plasma session start.

System changes (hosts, kernel, services, etc.) still require `nixos-rebuild switch`.

## Tests

Run `just check-fast` before every commit and `just check` for full
verification. See `docs/testing.md` for the check list and
`flake-modules/checks.nix` for the definitions.

## Code Style

Follow `docs/code-style.md`.

## Definition of Done

Before you commit: `just check-fast` passes, the change touches only the
intended files, `docs/code-style.md` holds, and AGENTS.md is current —
update it in the same commit when a command, convention, or directory
layout changes.

## Notes

- Hardware config is auto-generated
- Package attr path may differ from pname (e.g. `transmission_4-gtk`)
- Home Manager: git uses `settings` not `config`
- home-manager CLI lives in `home/misc/cli.nix`, pinned to the flake input — never `nix run` it manually
- Herdr: package from nixpkgs-unstable (`home/misc/cli.nix`), patched by `overlays/herdr.nix`; config in `home/misc/herdr.nix` with the update checks off
- Overlay patches: file in `patches/<pkg>/`, overlay in `overlays/<pkg>.nix` (auto-discovered)
- Plasma 6: kdePackages from unstable nixpkgs; plasma-desktop patches for UI tweaks
- Home persistence: `~/.config` is persisted as one directory, never file by file. Never bind-mount a single file that an application rewrites with `rename(2)`: the write fails with EBUSY and is lost without an error. `home-config-prune.service` deletes every other path below `.config` at boot, before the Home Manager activation; see `modules/desktop/home-config-prune.nix`
- Plasma panel/Task Manager settings are declarative via plasma-manager (`home/kde/plasma.nix`); change them in the module, not in the UI
- Granite portal accent color: GNOME returns named strings, Granite expects RGBA tuples — patched via overlay
- Emacs elisp files are `mkOutOfStoreSymlink` targets: edit them in the repo, no rebuild needed
- pi `~/.pi/agent/settings.json` is runtime state: persisted in `home/persistence.nix`, and the keys in `piSettings.enforced` are restored on every activation.
- Enable/disable features by commenting imports in `hosts/flowerpot/default.nix` or `home/default.nix`
