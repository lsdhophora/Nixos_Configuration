# NixOS Laptop Configuration

Flake-based config for laptop "flowerpot". Uses Home Manager, Agenix, Chaotic Nyx, custom overlays for patched GNOME.

## Project Structure

```
.
├── flake.nix                 # Flake entry point
├── flake.lock                # Locked deps
├── configuration.nix         # Imports all modules
├── hardware-configuration.nix   # Auto-generated
├── modules/                  # NixOS modules
│   ├── boot.nix              # Plymouth, CachyOS kernel, scx, 32GB swapfile
│   ├── networking.nix        # Hostname, timezone, NetworkManager, firewall
│   ├── user.nix              # User creation, system packages, Zsh
│   ├── nix-config.nix        # Nix settings, flakes, Chaotic cache
│   ├── i18n.nix              # Fonts (CJK, Plex, Maple Mono), IBus Rime
│   ├── desktop/gnome.nix     # GNOME (patched overlays, GDM, purple theme)
│   ├── services/
│   │   ├── cups.nix          # CUPS printing
│   │   ├── dae.nix           # DAE transparent proxy (age secret)
│   │   ├── kmscon.nix        # Kmscon virtual terminal
│   │   └── pipewire.nix      # PipeWire (no suspend)
│   └── security/
│       ├── age.nix           # Agenix secrets
│       └── sudo.nix          # sudo pwfeedback
├── home/                     # Home Manager configs
│   ├── default.nix           # Entry point
│   ├── avatar.nix            # Avatar via AccountsService
│   ├── game.nix              # Cataclysm DDA, Shattered Pixel Dungeon
│   ├── packages.nix          # GNOME extensions, media, IM, Kdenlive
│   ├── dconf.nix             # GNOME dconf (extensions, corners, folders)
│   ├── housekeeping.nix      # Hidden desktop entries
│   ├── shell/
│   │   ├── zsh.nix           # Zsh (aliases, autosuggestions, nix-shell)
│   │   └── elvish.nix        # Legacy reference
│   └── programs/
│       ├── git.nix           # lsdhophora/lsdphophora@proton.me
│       ├── ssh.nix           # GitHub via ssh.github.com:443
│       ├── direnv.nix        # nix-direnv
│       ├── firefox.nix       # Patched, userChrome/userContent
│       ├── ghostty.nix       # Adwaita Dark, IBM Plex Mono
│       ├── kvantum.nix       # KvLibadwaitaDark
│       ├── opencode.nix      # MCP NixOS integration
│       ├── texlive.nix       # CTEX, LuaLaTeX, texlab
│       └── emacs.nix         # PGTK, nix-mode, AUCTeX, magit, corfu, eglot, nov
├── assets/                   # Static assets
│   ├── avatar/face.png
│   ├── icons/Adwaita-purple/ # Purple icon theme (scalable SVG)
│   ├── Kuromi-Wallpapers/    # Wallpapers + GNOME XML
│   └── themes/kdenlive.qss
├── overlays/                 # Nixpkgs overlays
│   ├── default.nix           # Imports firefox, gjs-osk
│   ├── firefox.nix           # omni.ja modification
│   ├── gjs-osk.nix
│   ├── evolution-data-server.nix  # No contacts/calendar backends
│   ├── gnome-calendar.nix    # Remove weather
│   ├── gnome-control-center.nix   # Filter non-25% scales
│   ├── gnome-shell.nix       # a11y, zero-length events, hide details
│   ├── gnome-sound-recorder.nix
│   ├── mutter.nix            # Wayland cursor override
│   └── nautilus.nix          # Rename popover autohide
├── patches/                  # Referenced by overlays
│   ├── evolution-data-server/no-contacts-calendar-backend.patch
│   ├── gnome-calendar-remove-weather.patch
│   ├── gnome-filter-non-25-percent-scales.patch
│   ├── gnome-hide-app-details.patch
│   ├── gnome-shell-fix-a11y-always-show-setting.patch
│   ├── gnome-shell-fix-zero-length-event-time.patch
│   ├── mutter-fix-wayland-overridden-cursor.patch
│   └── nautilus-rename-popover-autohide.patch
├── secrets/                  # Age-encrypted
│   ├── secrets.nix           # Public keys for rekey
│   ├── config.dae.age
│   ├── hashed-password.age
│   └── access-tokens-github.age
├── nix-build-test/           # Build test results (not committed)
└── unused/                   # Empty, kept for reference
```

## Common Commands

```bash
# Verify config (git add new files first)
nixos-rebuild dry-build --flake .#flowerpot

# Commit (keep small and focused)
git add -A && git commit && git push

# Build and switch: agent uses pkexec, user uses sudo
pkexec nixos-rebuild switch --flake /home/lophophora/.config/nixos#flowerpot

# Update flake inputs
cd /home/lophophora/.config/nixos && nix flake update
```

## Workflow

1. Make changes; verify with `nixos-rebuild dry-build --flake .#flowerpot`
2. If dry-build passes, ask user whether to rebuild & commit
3. On confirmation: `pkexec nixos-rebuild switch --flake .#flowerpot`
4. After successful rebuild, commit
5. One logical change per commit; ask whether to push

## Commit Messages

`<type>(<scope>): <subject>` — imperative mood, max 50 chars, no period.
Types: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`
Body (optional): wrap at 72, explain why not how.

## Notes & Lessons

- Hardware config is auto-generated; don't edit directly
- `nixpkgs/` is a local clone for AI reference (excluded from git)
- Dry-build instead of `nixos-rebuild build` (no `result` symlink)
- Package names may differ from expected (e.g. `transmission_4-gtk`)
- Home Manager git uses `settings` not `config`
- Use `force = true` on `home.file` to overwrite existing desktop entries
- Agent uses `pkexec` for root commands; user runs `sudo` when agent asks
- Overlay patches in `overlays/`, patch files in `patches/` with matching names
- 32GB swapfile is in `boot.nix`, not `hardware-configuration.nix`
- Only declare attributes actually used to avoid "unused argument" warnings

## Code Style

- Follow NixOS module conventions; use `lib.mkEnableOption`/`lib.mkOption`
- Overlays: `final: prev: { pkg = prev.pkg.overrideAttrs (...); }`
- Home Manager: `lib.hm.dag.entryAfter` for ordered activation
