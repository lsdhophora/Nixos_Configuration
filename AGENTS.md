# NixOS Laptop Configuration

Flake-based config for laptop "flowerpot". Uses flake-parts, Home Manager, Agenix, Chaotic Nyx, custom overlays for patched GNOME.

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
│       ├── default.nix       # Host config (imports profiles + logind)
│       └── hardware-configuration.nix   # Auto-generated
├── modules/                  # NixOS modules (by type)
│   ├── profiles/             # Feature bundles (by purpose)
│   │   ├── core.nix          # Core system: boot, networking, user, nix, i18n, security, zram
│   │   ├── desktop.nix       # GNOME + PipeWire
│   │   ├── printing.nix      # CUPS
│   │   ├── proxying.nix      # DAE
│   │   └── kmscon.nix        # Kmscon VT
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
│   │   ├── pipewire.nix      # PipeWire (no suspend)
│   │   └── zram.nix          # Zram swap
│   └── security/
│       ├── age.nix           # Agenix secrets
│       └── sudo.nix          # sudo pwfeedback
├── home/                     # Home Manager configs
│   ├── default.nix           # Entry point
│   ├── profiles/             # Feature bundles
│   │   ├── development.nix   # git, ssh, direnv, opencode, texlive
│   │   ├── gaming.nix        # Cataclysm DDA, Shattered Pixel Dungeon
│   │   └── shell.nix         # Zsh
│   ├── avatar.nix
│   ├── packages.nix          # GNOME extensions, media, IM, Kdenlive
│   ├── dconf.nix             # GNOME dconf (extensions, corners, folders)
│   ├── housekeeping.nix      # Hidden desktop entries
│   ├── programs/
│   │   ├── git.nix           # lsdhophora/lsdphophora@proton.me
│   │   ├── ssh.nix           # GitHub via ssh.github.com:443
│   │   ├── direnv.nix        # nix-direnv
│   │   ├── firefox.nix       # Patched, userChrome/userContent
│   │   ├── ghostty.nix       # Adwaita Dark, IBM Plex Mono
│   │   ├── kvantum.nix       # KvLibadwaitaDark
│   │   ├── opencode.nix      # MCP NixOS integration
│   │   ├── texlive.nix       # CTEX, LuaLaTeX, texlab
│   │   └── emacs.nix         # PGTK, nix-mode, AUCTeX, magit, corfu, eglot, nov
│   └── shell/
│       ├── zsh.nix           # Zsh (aliases, autosuggestions, nix-shell)
│       └── elvish.nix        # Legacy reference
├── assets/                   # Static assets
│   ├── avatar/face.png
│   ├── icons/Adwaita-purple/ # Purple icon theme (scalable SVG)
│   ├── Kuromi-Wallpapers/    # Wallpapers + GNOME XML
│   └── themes/kdenlive.qss
├── overlays/                 # Nixpkgs overlays
│   ├── default.nix           # Imports emoji-copy, firefox
│   ├── emoji-copy.nix        # Patch word-boundary search in sql.js
│   ├── firefox.nix           # omni.ja modification
│   ├── evolution-data-server.nix  # No contacts/calendar backends
│   ├── gnome-calendar.nix    # Remove weather
│   ├── gnome-control-center.nix   # Filter non-25% scales
│   ├── gnome-shell.nix       # a11y, zero-length events, hide details
│   ├── gnome-sound-recorder.nix
│   ├── mutter.nix            # Wayland cursor override
├── patches/                  # Referenced by overlays
│   ├── evolution-data-server/no-contacts-calendar-backend.patch
│   ├── gnome-calendar-remove-weather.patch
│   ├── emoji-copy-word-boundary-search.patch
│   ├── gnome-filter-non-25-percent-scales.patch
│   ├── gnome-hide-app-details.patch
│   ├── gnome-shell-fix-a11y-always-show-setting.patch
│   ├── gnome-shell-fix-zero-length-event-time.patch
│   ├── mutter-fix-wayland-overridden-cursor.patch
├── secrets/                  # Age-encrypted
│   ├── secrets.nix           # Public keys for rekey
│   ├── config.dae.age
│   ├── hashed-password.age
│   └── access-tokens-github.age
└── unused/                   # Empty, kept for reference
```

## Common Commands

```bash
# Verify config (git add new files first)
nixos-rebuild dry-build --flake .#flowerpot

# Commit (keep small and focused)
git add -A && git commit

# Build and switch (agent runs pkexec; user types password when prompted)
pkexec nixos-rebuild switch --flake /home/lophophora/.config/nixos#flowerpot

# Update flake inputs
cd /home/lophophora/.config/nixos && nix flake update
```

## Workflow

⚠ All three asks (rebuild/commit/push) **MUST** use the `question` tool — never plain text.

1. Make changes; verify with `nixos-rebuild dry-build --flake .#flowerpot`
2. If dry-build passes, use `#Questions` with options `["Yes", "No"]` to ask user whether to rebuild
3. On confirmation (label matches "Yes"): run `pkexec nixos-rebuild switch --flake .#flowerpot` — pkexec prompts for password, user enters it interactively
4. After successful rebuild, use `#Questions` with options `["Yes", "No"]` to ask user whether to commit
5. On confirmation (label matches "Yes"): stage and commit
6. Use `#Questions` with options `["Yes", "No"]` to ask user whether to push
7. On confirmation (label matches "Yes"): push

> The commit/push `#Questions` apply to **all** changes, including modifications to AGENTS.md itself.

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
- Agent runs root commands with `pkexec` (password prompt appears, user types it)
- User runs root commands manually in terminal with `sudo` (e.g. on another machine or when agent isn't involved)
- Overlay patches in `overlays/`, patch files in `patches/` with matching names
- 32GB swapfile is in `boot.nix`, not `hardware-configuration.nix`
- Only declare attributes actually used to avoid "unused argument" warnings
- Profiles in `modules/profiles/` and `home/profiles/` group related imports by purpose; the underlying module files stay in their type-based directories
- Always use the `question` tool (not plain text) when asking rebuild/commit/push

## Code Style

- Follow NixOS module conventions; use `lib.mkEnableOption`/`lib.mkOption`
- Overlays: `final: prev: { pkg = prev.pkg.overrideAttrs (...); }`
- Home Manager: `lib.hm.dag.entryAfter` for ordered activation
