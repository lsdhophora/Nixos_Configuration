# NixOS Laptop Configuration

Flake-based config for "flowerpot". Uses flake-parts, Home Manager, Agenix, Chaotic Nyx, custom overlays, Plasma 6.

## Project Structure

```
.
├── flake.nix                 # Flake entry point (flake-parts)
├── flake.lock                # Locked deps
├── flake-modules/            # Flake-parts modules
│   ├── default.nix           # Module aggregator
│   └── nixos.nix             # nixosConfigurations.flowerpot
├── lib/                      # Shared helpers (applyPatches for overlays/modules)
├── hosts/
│   └── flowerpot/            # Machine entry point
│       ├── default.nix       # Host config menu (imports modules directly)
│       └── hardware-configuration.nix
├── modules/                  # NixOS modules (flat, imported by host menu)
│   ├── boot.nix              # Plymouth, CachyOS kernel, scx, swapfile, cleanOnBoot
│   ├── networking.nix
│   ├── i18n.nix
│   ├── nix-config.nix
│   ├── user.nix
│   ├── desktop/
│   │   └── kde.nix           # Plasma 6 desktop, SDDM login, fcitx5
│   ├── security/
│   │   ├── age.nix
│   │   └── sudo.nix
│   └── services/
│       ├── atd.nix
│       ├── cups.nix
│       ├── dae.nix
│       ├── kmscon.nix        # Kmscon VT (disabled in host menu)
│       ├── pipewire.nix
│       ├── tlp.nix
│       └── zram.nix
├── home/                     # Home Manager configs (flat, imported by home menu)
│   ├── default.nix           # Home config menu (username, stateVersion, imports)
│   ├── packages.nix
│   ├── desktop/
│   │   ├── dconf.nix
│   │   ├── gtk.nix
│   │   └── session.nix
│   ├── programs/
│   │   ├── emacs/            # elisp files symlinked out of store (editable directly)
│   │   ├── firefox.nix
│   │   ├── kitty.nix
│   │   ├── mpv.nix
│   │   ├── tmux.nix
│   │   └── zathura.nix
│   ├── dev/
│   │   ├── direnv.nix
│   │   ├── git.nix
│   │   ├── pi-agent/
│   │   ├── ssh.nix
│   │   └── texlive.nix
│   ├── misc/
│   │   ├── avatar.nix
│   │   ├── cli.nix
│   │   ├── gui.nix
│   │   └── housekeeping.nix
│   └── shell/
│       └── zsh.nix
├── assets/                   # Static assets
│   ├── avatar/
│   ├── gtk/
│   └── themes/
├── overlays/                 # Nixpkgs overlays (auto-discovered from this dir)
│   ├── default.nix           # Auto-discovery aggregator
│   ├── firefox.nix           # omni.ja patches
│   └── kitty.nix             # Patched: remove resize text overlay
├── patches/                  # Patch files (grouped by package)
│   ├── ark/
│   ├── kitty/
│   │   ├── kitty-remove-resize-text.patch
│   │   └── kitty-fix-panel-position.patch
│   ├── kscreenlocker/
│   ├── plasma-desktop/
│   │   ├── lookandfeelbox-highlight-border.patch
│   │   └── hide-virtual-keyboard-button.patch
│   └── plasma-workspace/
│       └── jobitem-null-check.patch
├── secrets/                  # Age-encrypted
│   ├── secrets.nix
│   ├── config.dae.age
│   └── hashed-password.age
└── unused/
```

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

## Notes

- Hardware config is auto-generated
- Package attr path may differ from pname (e.g. `transmission_4-gtk`)
- Home Manager: git uses `settings` not `config`
- Overlay patches: file in `patches/<pkg>/`, overlay in `overlays/<pkg>.nix` (auto-discovered)
- Plasma 6: kdePackages from unstable nixpkgs; plasma-desktop patches for UI tweaks
- Granite portal accent color: GNOME returns named strings, Granite expects RGBA tuples — patched via overlay
- Emacs elisp files are `mkOutOfStoreSymlink` targets: edit them in the repo, no rebuild needed
- Enable/disable features by commenting imports in `hosts/flowerpot/default.nix` or `home/default.nix`
