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
├── hosts/
│   └── flowerpot/            # Machine entry point
│       ├── default.nix       # Host config (imports profiles, KDE, TLP)
│       └── hardware-configuration.nix
├── modules/                  # NixOS modules (by type)
│   ├── profiles/             # Feature bundles
│   │   ├── core.nix          # Boot, network, user, nix, i18n, security, zram
│   │   ├── desktop.nix       # PipeWire, Kanata
│   │   ├── printing.nix      # CUPS
│   │   ├── proxying.nix      # DAE
│   │   └── kmscon.nix        # Kmscon VT (disabled)
│   ├── boot.nix              # Plymouth, CachyOS kernel, scx, swapfile
│   ├── desktop/
│   │   └── kde.nix           # Plasma 6 desktop, SDDM login, fcitx5
│   └── services/
│       ├── tlp.nix
│       ├── kanata.nix
│       └── dae.nix
├── home/                     # Home Manager configs
│   ├── default.nix
│   ├── profiles/
│   │   ├── development.nix
│   │   └── gaming.nix
│   ├── programs/
│   │   ├── git.nix
│   │   ├── emacs.nix
│   │   └── firefox.nix
│   └── shell/zsh.nix
├── assets/                   # Static assets
│   ├── kitty/                # Kitty terminal config
│   └── icons/Adwaita-purple/
├── overlays/                 # Nixpkgs overlays (final: prev: { ... })
│   ├── default.nix           # Aggregator
│   ├── granite.nix           # granite7: GNOME named accent-color support
│   ├── firefox.nix           # omni.ja patches
│   └── kitty.nix             # Patched: remove resize text overlay
├── patches/                  # Patch files (grouped by package)
│   ├── granite/
│   │   └── fallback-accent-color.patch
│   ├── kitty/
│   │   ├── kitty-remove-resize-text.patch
│   │   └── kitty-fix-panel-position.patch
│   ├── plasma-desktop/
│   │   ├── lookandfeelbox-highlight-border.patch
│   │   └── hide-virtual-keyboard-button.patch
│   └── plasma-workspace/
│       └── accent-color-clip.patch
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
- Overlay patches: file in `patches/<pkg>/`, overlay in `overlays/<pkg>.nix`
- Plasma 6: kdePackages from unstable nixpkgs; plasma-desktop patches for UI tweaks
- Granite portal accent color: GNOME returns named strings, Granite expects RGBA tuples — patched via overlay
