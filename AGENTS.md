# NixOS Laptop Configuration

Flake-based config for "flowerpot". Uses flake-parts, Home Manager, sops-nix, Chaotic Nyx, custom overlays, Plasma 6.

## Commands

```bash
nixos-rebuild dry-build --flake .#flowerpot       # verify
pkexec nixos-rebuild switch --flake /home/lophophora/.config/nixos#flowerpot   # rebuild & switch (absolute path — pkexec runs as root)
nix flake update                                   # update inputs
git add -A && git commit -m "type(scope): subject" # commit
git push                                           # push
```

## Workflow

1. Edit → `dry-build` pass
2. Rebuild
3. Commit (if success)
4. Push (if success)

## Code Style

Follow the rules in `docs/code-style.md`:
- STE writing standard
- Required skills: `equational-reasoning`, `hoare-logic`
- Nix/TypeScript style rules and commit message format

## Notes

- Hardware config is auto-generated
- Package attr path may differ from pname (e.g. `transmission_4-gtk`)
- Home Manager: git uses `settings` not `config`
- Overlay patches: file in `patches/<pkg>/`, overlay in `overlays/<pkg>.nix` (auto-discovered)
- Plasma 6: kdePackages from unstable nixpkgs; plasma-desktop patches for UI tweaks
- Granite portal accent color: GNOME returns named strings, Granite expects RGBA tuples — patched via overlay
- Emacs elisp files are `mkOutOfStoreSymlink` targets: edit them in the repo, no rebuild needed
- Enable/disable features by commenting imports in `hosts/flowerpot/default.nix` or `home/default.nix`
