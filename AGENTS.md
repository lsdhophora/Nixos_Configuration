# NixOS Laptop Configuration

This is a NixOS flake-based system configuration for a laptop named "flowerpot". It uses Home Manager for user-level configurations, Agenix for secret management, Chaotic Nyx for additional packages, and custom overlays for patched GNOME components.

## Project Structure

```
.
├── flake.nix                 # Main flake entry point
├── flake.lock                # Locked dependencies
├── configuration.nix         # System configuration (imports all modules)
├── hardware-configuration.nix   # Hardware-specific config (auto-generated)
├── modules/                  # NixOS modules
│   ├── boot.nix              # Boot (plymouth, systemd-boot, CachyOS kernel, scx scheduler, 32GB swapfile)
│   ├── networking.nix        # Hostname, timezone, NetworkManager, firewall (enabled)
│   ├── user.nix              # User creation, system packages, Zsh enable
│   ├── nix-config.nix        # Nix settings, flakes, Chaotic cache
│   ├── i18n.nix              # Fonts (CJK, Plex, Maple Mono), IBus Rime
│   ├── desktop/gnome.nix     # GNOME desktop (patched overlays, GDM, purple theme, wallpapers)
│   ├── services/
│   │   ├── cups.nix          # CUPS printing
│   │   ├── dae.nix           # DAE transparent proxy (age secret)
│   │   ├── kmscon.nix        # Kmscon virtual terminal (Maple Mono font)
│   │   └── pipewire.nix      # PipeWire audio (no suspend)
│   └── security/
│       ├── age.nix            # Agenix secrets (password, DAE config, GitHub token)
│       └── sudo.nix           # sudo pwfeedback
├── home/                     # Home Manager configurations
│   ├── default.nix            # Home Manager entry point
│   ├── avatar.nix             # User avatar via AccountsService D-Bus
│   ├── game.nix               # Game packages (Cataclysm DDA, Shattered Pixel Dungeon)
│   ├── packages.nix           # User packages (GNOME extensions, media, IM, Kdenlive)
│   ├── dconf.nix              # GNOME dconf settings (extensions, interface, folders, rounded corners)
│   ├── housekeeping.nix       # Hidden desktop entries (cups, kvantum, etc.)
│   ├── shell/
│   │   ├── zsh.nix            # Zsh shell (prompt, aliases, autosuggestions, VTE, nix-shell detection)
│   │   └── elvish.nix         # Elvish shell config (legacy, kept for reference)
│   └── programs/
│       ├── git.nix            # Git user config (lsdhophora/lsdphophora@proton.me)
│       ├── ssh.nix            # SSH config (GitHub via ssh.github.com:443, key: lysergic)
│       ├── direnv.nix         # Direnv with nix-direnv
│       ├── firefox.nix        # Firefox (patched package, custom userChrome/userContent)
│       ├── ghostty.nix        # Ghostty terminal (Adwaita Dark theme, IBM Plex Mono)
│       ├── kvantum.nix        # Kvantum Qt theme (KvLibadwaitaDark)
│       ├── opencode.nix       # OpenCode AI coding assistant (MCP NixOS)
│       ├── texlive.nix        # TeX Live (CTEX, LuaLaTeX, texlab)
│       └── emacs.nix          # Emacs (PGTK, extensive config: nix-mode, AUCTeX, magit, corfu, eglot, nov, audio-trimmer)
├── assets/                   # Static assets
│   ├── avatar/face.png        # User avatar image
│   ├── icons/Adwaita-purple/  # Custom purple Adwaita icon theme (scalable SVG)
│   ├── Kuromi-Wallpapers/     # Wallpapers with GNOME selector XML
│   └── themes/kdenlive.qss    # Kdenlive Qt stylesheet
├── overlays/                 # Nixpkgs overlays
│   ├── default.nix            # Overlay list (imports firefox, gjs-osk)
│   ├── firefox.nix            # Patched Firefox (omni.ja modification, border removal)
│   ├── gjs-osk.nix            # GJS OSK overlay
│   ├── evolution-data-server.nix  # Patched EDS (no contacts/calendar backends)
│   ├── gnome-calendar.nix     # Patched Calendar (remove weather)
│   ├── gnome-control-center.nix   # Patched Control Center (filter non-25% scales)
│   ├── gnome-shell.nix        # Patched GNOME Shell (a11y, zero-length events, hide details)
│   ├── gnome-sound-recorder.nix    # Patched Sound Recorder
│   ├── mutter.nix             # Patched Mutter (Wayland cursor override)
│   └── nautilus.nix           # Patched Nautilus (rename popover autohide)
├── patches/                  # Application patches
│   ├── evolution-data-server/
│   │   └── no-contacts-calendar-backend.patch
│   ├── gnome-calendar-remove-weather.patch
│   ├── gnome-filter-non-25-percent-scales.patch
│   ├── gnome-hide-app-details.patch
│   ├── gnome-shell-fix-a11y-always-show-setting.patch
│   ├── gnome-shell-fix-zero-length-event-time.patch
│   ├── mutter-fix-wayland-overridden-cursor.patch
│   └── nautilus-rename-popover-autohide.patch
├── secrets/                  # Agenix secrets (age encrypted)
│   ├── secrets.nix            # Public keys for secret rekeying
│   ├── config.dae.age         # DAE config secret
│   ├── hashed-password.age    # User hashed password
│   └── access-tokens-github.age  # GitHub access token
├── nix-build-test/           # Build test results (not committed)
└── unused/                   # Empty (kept for legacy reference)
```

## Key Features

### System Configuration
- **NixOS**: 25.05 channel with flakes + nix-command
- **Kernel**: CachyOS kernel via `linuxPackages_cachyos`
- **Boot**: systemd-boot with Plymouth splash screen (bgrt theme), AMDGPU kernel modules, early KMS
- **Scheduler**: `scx_rustland` (sched_ext)
- **Desktop**: GNOME with GDM (Wayland enabled), mutter experimental features (scale-monitor-framebuffer, xwayland-native-scaling, VRR)
- **Networking**: NetworkManager, hostname "flowerpot", timezone Asia/Shanghai
- **Firewall**: Enabled (LocalSend TCP/UDP 53317, port 9090)
- **Swap**: 32GB swapfile at `/var/lib/swapfile`
- **Services**: PipeWire (no suspend), CUPS printing, Kmscon virtual terminal, DAE transparent proxy
- **Secrets**: Managed via Agenix (age encryption), identity key: `/home/lophophora/.ssh/lysergic`

### User & Shell
- User: `lophophora` (Chinese: 费雪)
- Shell: Zsh (migrated from Elvish), with nix-shell detection in prompt, autosuggestions, VTE integration
- Aliases: `ls`→`ls --color=auto`, `ll`→`ls -lah`, `grep`→`grep --color=auto`
- Custom function: `update-flake` (update flake.lock + auto-commit)
- System packages: tree, ffmpeg, fastfetch, imagemagick, pandoc, nixfmt, nixd, unzip, gnome-sound-recorder, nano, git, wget, agenix

### Desktop Environment
- **GNOME** with extensive customization
- **Accent color**: Purple (#9141AC)
- **Window corners**: Rounded (15px) via extension, per-app overrides for Kdenlive and Firefox
- **Extensions**: App Hider, Blur My Shell, Customize IBus, Dash to Panel, Just Perfection, Rounded Window Corners, Run or Raise, RunCat, GJS OSK
- **Excluded packages**: Many GNOME defaults removed (cheese, geary, gedit, epiphany, totem, etc.)
- **Nautilus**: Open-in-terminal configured to use Ghostty, icon view default
- **GDM dconf**: Purple accent, dark scheme, custom cursor size (24), text scaling (1.20)
- **Favorite apps**: Firefox, Emacs, Ghostty, Nautilus

### Overlays & Patches
- **Overlays** are applied via `nixpkgs.overlays` in `gnome.nix` and `overlays/default.nix`
- **Patching pattern**: `final: prev: { pkg = prev.pkg.overrideAttrs (...) }` for GNOME components
- **Patched packages**: Firefox (omni.ja mods), GNOME Shell + Calendar + Control Center + Sound Recorder, Evolution Data Server, Mutter, Nautilus, GJS OSK
- **GNOME patches** fix: a11y setting, zero-length event times, app detail hiding, calendar weather removal, scale filtering, Wayland cursor override, rename popover autohide

### Applications
- **Browser**: Firefox (patched, sync disabled, no translations, purple tab group colors, simplified context menus)
- **Terminal**: Ghostty (Adwaita Dark, IBM Plex Mono, block cursor, shell integration)
- **Editor**: Emacs with extensive configuration:
  - Theme: Modus Vivendi, font: IBM Plex Mono + Noto Sans CJK SC
  - Package managers: GNU ELPA, MELPA
  - Languages: Nix (nix-mode + nixd), Python (pylsp), LaTeX (AUCTeX + LuaLaTeX)
  - Features: direnv, magit, corfu (auto-complete), eglot (LSP), dashboard, nov (EPUB reader), emms (music player)
  - Custom: audio-trimmer (Elisp), image centering, tab-bar image optimization, LaTeX viewer via Papers
- **Media**: Celluloid (video), Blanket (ambient sounds), GNOME Sound Recorder, Shortwave (internet radio), Mpv (Emacs backend)
- **IM**: Fluffychat (Matrix client)
- **Office**: TeX Live (CTEX, LuaLaTeX, texlab), Wordbook
- **Qt Apps**: Kdenlive (video editor, wrapped with Breeze theme), Kvantum (KvLibadwaitaDark)
- **Games**: Cataclysm DDA, Shattered Pixel Dungeon

### Fonts
- Noto Sans/Serif CJK SC (Chinese)
- IBM Plex (monospace)
- Noto Color Emoji
- Maple Mono NF CN (monospace with Nerd Font + Chinese)
- LXGW Wenkai (Chinese calligraphy)

### Input Method
- IBus with Rime engine (for Chinese input)
- Customize IBus extension: custom font (Adwaita Sans 13), no switch indicator

### Development Tools
- Git: user `lsdhophora` / `lsdphophora@proton.me`
- SSH: configured for GitHub (ssh.github.com:443), key: `lysergic`
- Direnv with nix-direnv
- Nix: flakes + nix-command, nixfmt for formatting, nixd for LSP
- OpenCode AI assistant: MCP NixOS integration (`mcp-nixos`)

## Code Style

- Follow standard NixOS module conventions
- Use `lib.mkEnableOption`, `lib.mkOption` for options
- Prefer `with pkgs;` for package lists
- Use `pkgs.writeTextFile` or `pkgs.substituteAll` for generated files
- Keep modules focused and composable
- Only declare attributes that are actually used (e.g., `pkgs`, `config`, `inputs`) to avoid "attribute of argument is not used" warnings
- Overlays use `final: prev: { ... }` pattern with `overrideAttrs` for patching
- Home Manager modules use `lib.hm.dag.entryAfter` for ordered activation

## Common Commands

```bash
# Always run this AFTER making any modification to verify config is valid
# IMPORTANT: If you add new files, run 'git add <files>' BEFORE dry-build
nixos-rebuild dry-build --flake .#flowerpot

# Commit after successful dry-build (keep commits small and focused)
git add -A && git commit && git push

# Build and switch to new system
pkexec nixos-rebuild switch --flake /home/lophophora/.config/nixos#flowerpot

# Update flake inputs
cd /home/lophophora/.config/nixos && nix flake update
```

## Workflow

1. Make changes to the configuration
2. Run `nixos-rebuild dry-build --flake .#flowerpot` to verify; fix any errors
3. When dry-build passes, ask the user whether the result is correct and whether to rebuild & commit
4. On confirmation, rebuild: `pkexec nixos-rebuild switch --flake .#flowerpot`
5. After successful rebuild, commit
6. Each commit must be a minimal, independently working unit that solves exactly one problem
7. After commit, ask whether to push

## Commit Messages

Format: `<type>(<scope>): <subject>`

- **Subject**: imperative mood, max 50 chars, capitalize first word, no period
- **Types**: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`
- **Body (optional)**: wrap at 72 chars, explain why, not how
- **One logical change per commit**. If you need "and", split it
- **Footer (optional)**: `Fixes #123`, `Refs #456`, or `BREAKING CHANGE: ...`

## Notes

- Hardware config is auto-generated and should not be manually edited
- Secrets in `secrets/` are encrypted with age, decrypted at build time via Agenix
- The Emacs config is extensive (~570 lines) with many custom functions (audio-trimmer, image centering, EPUB chapter display toggle)
- Some patches in `patches/` are applied via overrideAttrs in overlays
- Unused configs in `unused/` directory are kept for reference but currently empty
- Shell config migrated from Elvish to Zsh; `home/shell/elvish.nix` kept for reference
- **Important**: After making changes to the configuration, run `tree -L 3 --noreport -I 'result|*.lock'` to update the Project Structure section in this file to keep it in sync with actual modifications. Also update Key Features, Code Style, Common Commands, and Notes sections as needed.
- `nixpkgs/` is a local clone of the NixOS/nixpkgs repository for AI reference only (excluded from git)
- Patches in `patches/` are referenced by overlays in `overlays/`; the GNOME desktop module imports overlays directly, while the main overlay list (`overlays/default.nix`) covers Firefox and GJS OSK

## Lessons Learned

- Use `nixos-rebuild dry-build` instead of `nixos-rebuild build` for testing (no `result` symlink created)
- Package names in nixpkgs may differ from expected (e.g., `transmission_4-gtk` not `transmission-gtk`)
- Home Manager uses `settings` instead of `config` for git configuration (`programs.git.settings`)
- Use `force = true` on `home.file` options to forcefully overwrite existing desktop entries
- When hiding desktop entries, search for the exact desktop file name in nix store with `find /nix -name "*.desktop"`
- Always test build with `nixos-rebuild dry-build` before committing
- Use LSP (nixd) in editor to catch attribute errors early
- For **agent-executed** commands requiring root, use `pkexec` instead of `sudo` (e.g., `nixos-rebuild switch`). When manually running commands, use `sudo` as normal.
- Overlay patches go in `overlays/`; patch files go in `patches/` with matching names
- The 32GB swapfile is defined in `boot.nix` (not `hardware-configuration.nix`)
