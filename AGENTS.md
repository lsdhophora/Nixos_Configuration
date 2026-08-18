# NixOS Laptop Configuration

Flake-based config for "flowerpot". Uses flake-parts, Home Manager, sops-nix, Chaotic Nyx, custom overlays, Plasma 6.

## Commands

```bash
nixos-rebuild dry-build --flake .#flowerpot       # verify (system + home)
run0 nixos-rebuild switch --flake .#flowerpot   # rebuild & switch (system)
home-manager switch --flake .#lophophora         # home-only rebuild (fast, no system closure)
nix flake update                                   # update inputs
git add -A && git commit -F -                       # commit (GNU format message via stdin)
git push                                           # push
```

The `home-manager` CLI is installed via `home/misc/cli.nix` and pinned to the flake input revision (`inputs.home-manager.packages.${pkgs.system}.home-manager`).

## Workflow

1. Edit → `dry-build` pass
2. Rebuild
3. Commit (if success)
4. Push (if success)

Home-only changes (everything under `home/`) can skip the full `nixos-rebuild` and use `home-manager switch --flake .#lophophora` instead. Both paths share `home/default.nix`; `homeConfigurations` is wired in `flake-modules/nixos.nix`.

System changes (hosts, kernel, services, etc.) still require `nixos-rebuild switch`.

## Code Style

Follow the rules in `docs/code-style.md`:
- STE writing standard
- Required skills: `equational-reasoning`, `hoare-logic`
- Nix/TypeScript style rules and commit message format

## Notes

- Hardware config is auto-generated
- Package attr path may differ from pname (e.g. `transmission_4-gtk`)
- Home Manager: git uses `settings` not `config`
- home-manager CLI lives in `home/misc/cli.nix`, pinned to the flake input — never `nix run` it manually
- Overlay patches: file in `patches/<pkg>/`, overlay in `overlays/<pkg>.nix` (auto-discovered)
- Plasma 6: kdePackages from unstable nixpkgs; plasma-desktop patches for UI tweaks
- Granite portal accent color: GNOME returns named strings, Granite expects RGBA tuples — patched via overlay
- Emacs elisp files are `mkOutOfStoreSymlink` targets: edit them in the repo, no rebuild needed
- Enable/disable features by commenting imports in `hosts/flowerpot/default.nix` or `home/default.nix`
