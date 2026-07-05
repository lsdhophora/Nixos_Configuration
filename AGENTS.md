# NixOS Laptop Configuration

Flake-based config for "flowerpot". Uses flake-parts, Home Manager, Agenix, Chaotic Nyx, custom overlays.

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
│       ├── default.nix       # Host config (imports profiles, Sway, TLP)
│       └── hardware-configuration.nix
├── modules/                  # NixOS modules (by type)
│   ├── profiles/             # Feature bundles
│   │   ├── core.nix          # Boot, network, user, nix, i18n, security, zram
│   │   ├── desktop.nix       # PipeWire, Kanata
│   │   ├── printing.nix      # CUPS
│   │   ├── proxying.nix      # DAE
│   │   └── kmscon.nix        # Kmscon VT
│   ├── boot.nix              # Plymouth, CachyOS kernel, scx, swapfile
│   ├── desktop/sway.nix      # Sway WM, pantheon-agent-polkit, fcitx5
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
│   │   ├── firefox.nix
│   │   └── ghostty.nix
│   └── shell/zsh.nix
├── assets/                   # Static assets
│   ├── sway/                 # Sway config, i3blocks, scripts
│   └── icons/Adwaita-purple/
├── overlays/                 # Nixpkgs overlays (final: prev: { ... })
│   ├── default.nix           # Aggregator
│   ├── portal-gtk.nix        # xdg-desktop-portal-gtk: UseIn=sway
│   ├── granite.nix           # granite7: GNOME named accent-color support
│   └── firefox.nix           # omni.ja patches
├── patches/                  # Patch files (grouped by package)
│   ├── granite/
│   │   └── gnome-accent-color.patch
│   └── emoji-copy/
│       ├── word-boundary-search.patch
│       └── ...
├── secrets/                  # Age-encrypted
│   ├── secrets.nix
│   ├── config.dae.age
│   └── hashed-password.age
└── unused/
```

## Commands

```bash
nixos-rebuild dry-build --flake .#flowerpot       # verify
pkexec nixos-rebuild switch --flake .#flowerpot   # rebuild & switch
nix flake update                                   # update inputs
git add -A && git commit -m "type(scope): subject" # commit
git push                                           # push
```

## Workflow

All rebuild/commit/push asks use the `question` tool.

1. Edit → `dry-build` pass
2. `#Questions` → rebuild
3. `#Questions` → commit (if success)
4. `#Questions` → push (if success)

## Notes

- Hardware config is auto-generated
- Packge attr path may differ from pname (e.g. `transmission_4-gtk`)
- Home Manager: git uses `settings` not `config`
- Overlay patches: file in `patches/<pkg>/`, overlay in `overlays/<pkg>.nix`
- Granite portal accent color: GNOME returns named strings, Granite expects RGBA tuples — patched via overlay
