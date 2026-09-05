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

The AI stages, commits, and pushes only when the user asks it to.

Home-only changes (everything under `home/`) can skip the full `nixos-rebuild` and use `home-manager switch --flake .#FeiHsueh` instead. Both paths share `home/default.nix`; `homeConfigurations` is wired in `flake-modules/nixos.nix`.

System changes (hosts, kernel, services, etc.) still require `nixos-rebuild switch`.

## Tests

Run `just check-fast` before every commit. It runs nixfmt, deadnix,
english-comments, statix, sops-integrity, sops-keys, invariants, and
lib-tests. See `docs/testing.md` and `flake-modules/checks.nix` for
the check list and definitions.

Run `just check` (`nix flake check`) for full verification. It also
builds the system toplevel and the home activation package.

VM boot tests are deferred (they need a KVM-capable host). See
`docs/testing.md` for the record and the re-enable recipe.

## Code Style

Follow the rules in `docs/code-style.md`:
- STE writing standard
- Required skills: `equational-reasoning`, `hoare-logic`
- Nix/TypeScript style rules and commit message format

## Definition of Done

Before you commit, check:

1. `just check-fast` passes.
2. The change touches only the intended files.
3. `docs/code-style.md` rules hold (STE, GNU commit format).
4. AGENTS.md stays current. Update it in the same commit when a
   command, convention, or directory layout changes.

## Notes

- Hardware config is auto-generated
- Package attr path may differ from pname (e.g. `transmission_4-gtk`)
- Home Manager: git uses `settings` not `config`
- home-manager CLI lives in `home/misc/cli.nix`, pinned to the flake input — never `nix run` it manually
- Overlay patches: file in `patches/<pkg>/`, overlay in `overlays/<pkg>.nix` (auto-discovered)
- Plasma 6: kdePackages from unstable nixpkgs; plasma-desktop patches for UI tweaks
- Plasma panel/Task Manager pins are declarative via plasma-manager (`home/kde/plasma.nix`): `plasma-org.kde.plasma.desktop-appletsrc` is regenerated on every Plasma startup and NOT persisted (KConfig atomic writes would fail on a single-file bind mount). Change pins by editing the module + `home-manager switch`, not via UI.
- Granite portal accent color: GNOME returns named strings, Granite expects RGBA tuples — patched via overlay
- Emacs elisp files are `mkOutOfStoreSymlink` targets: edit them in the repo, no rebuild needed
- Enable/disable features by commenting imports in `hosts/flowerpot/default.nix` or `home/default.nix`
