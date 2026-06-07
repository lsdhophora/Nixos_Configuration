# NixOS Laptop Configuration

This is a NixOS flake-based system configuration for a laptop named "flowerpot". It uses Home Manager for user-level configurations and Agenix for secret management.

## Project Structure

```
.
├── flake.nix                 # Main flake entry point
├── flake.lock                # Locked dependencies
├── configuration.nix         # System configuration (imports all modules)
├── hardware-configuration.nix   # Hardware-specific config (auto-generated)
├── modules/                  # NixOS modules
│   ├── boot.nix              # Boot configuration (plymouth, kernel)
│   ├── networking.nix        # Hostname, timezone, NetworkManager, firewall
│   ├── user.nix              # User creation and system packages
│   ├── nix-config.nix        # Nix settings and git config
│   ├── i18n.nix              # Fonts and input method (IBus Rime)
│   ├── desktop/gnome.nix     # GNOME desktop configuration
│   ├── services/
│   │   └── dae.nix           # DAE service (transparent proxy)
│   └── security/
│       └── age.nix            # Agenix secret management
├── home/                     # Home Manager configurations
│   ├── default.nix            # Home Manager entry point
│   ├── packages.nix           # User packages (GNOME extensions, apps)
│   ├── dconf.nix             # GNOME dconf settings
│   ├── housekeeping.nix       # Hidden desktop entries
│   ├── shell/
│   │   ├── zsh.nix            # Zsh shell config (prompt, carapace, history)
│   │   └── elvish.nix         # Elvish shell config (legacy, kept for reference)
│   └── programs/
│       ├── ssh.nix            # SSH configuration (GitHub via SSH over 443)
│       ├── direnv.nix         # Direnv with nix-direnv
│       ├── firefox.nix        # Firefox browser configuration
│       ├── emacs.nix          # Emacs configuration (extensive)
│       └── git.nix            # Git configuration
├── assets/                   # Static assets
│   ├── icons/Kuromi-cursor/  # Custom cursor theme
│   └── Kuromi-Wallpapers/    # Wallpapers with GNOME selector XML
├── secrets/                  # Agenix secrets (age encrypted)
│   ├── config.dae.age        # DAE config secret
│   └── access-tokens-github.age  # GitHub access token
├── patches/                  # Application patches
│   └── celluloid-fix-save-position.patch
└── unused/                   # Deprecated/unused configurations
    ├── ghostty.nix
    ├── zathura.nix
    └── ...
```

## Key Features

### System Configuration
- **Boot**: systemd-boot with Plymouth splash screen, AMDGPU kernel modules
- **Desktop**: GNOME with GDM (Wayland enabled), customized with experimental features
- **Networking**: NetworkManager, hostname "flowerpot", timezone Asia/Shanghai
- **Firewall**: Disabled

### User & Shell
- User: `lophophora` (Chinese: 费雪)
- Shell: Zsh (migrated from Elvish), with nix-shell detection in prompt, carapace completions, autosuggestions, VTE integration
- User packages: tree, ffmpeg, fastfetch, imagemagick, TeX Live (with CTEX), pandoc, texlab, nixfmt, nixd, ghostty

### Desktop Environment
- **GNOME** with extensive customization
- **Accent color**: Purple (#9141AC)
- **Extensions**: Caffeine, Just Perfection, Run or Raise
- **Excluded packages**: Many GNOME defaults removed (cheese, geary, gedit, epiphany, etc.)
- **Nautilus**: Open-in-terminal configured to use Ghostty
- **GDM dconf**: Custom cursor size (28), text scaling factor (1.33)

### Applications
- **Browser**: Firefox with custom settings (sync disabled, no translations, middle-click disabled, etc.)
- **Terminal**: Ghostty (patched with GStreamer support)
- **Editor**: Emacs with extensive configuration:
  - Theme: Modus Vivendi
  - Package managers: GNU ELPA, MELPA
  - Languages: Nix (nix-mode + nixd), Python (pylsp), LaTeX (AUCTeX)
  - Features: direnv, magit, corfu, eglot, dashboard, nov (EPUB reader)
- **Media**: Celluloid (video), Blanket (ambient sounds), GNOME Sound Recorder

### Fonts
- Noto Sans/Serif CJK SC (Chinese)
- IBM Plex (monospace with sans-sc variant)
- Noto Color Emoji
- Charis
- LXGW Wenkai

### Input Method
- IBus with Rime engine (for Chinese input)

### Development Tools
- Git with custom user config (name: lsdhophora, email: lsdphophora@proton.me)
- SSH configured for GitHub (ssh.github.com:443)
- Direnv with nix-direnv
- Nix: flakes + nix-command enabled, nixfmt for formatting, nixd for LSP

### Services
- **DAE**: Transparent proxy service (requires age secret)
- **Secrets**: Managed via Agenix (age encryption)

## Code Style

- Follow standard NixOS module conventions
- Use `lib.mkEnableOption`, `lib.mkOption` for options
- Prefer `with pkgs;` for package lists
- Use `pkgs.writeTextFile` or `pkgs.substituteAll` for generated files
- Keep modules focused and composable
- Only declare attributes that are actually used (e.g., `pkgs`, `config`, `inputs`) to avoid "attribute of argument is not used" warnings

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
- The Emacs config is extensive (~275 lines) with many custom functions
- Some patches in `patches/` are applied via overrideAttrs
- Unused configs in `unused/` directory are kept for reference but not imported
- Shell config migrated from Elvish to Zsh; `home/shell/elvish.nix` kept for reference
- **Important**: After making changes to the configuration, run `tree -L 3 --noreport -I 'result|*.lock'` to update the Project Structure section in this file to keep it in sync with actual modifications. Also update Key Features, Code Style, Common Commands, and Notes sections as needed.
- `nixpkgs/` is a local clone of the NixOS/nixpkgs repository for AI reference only (excluded from git)

## Lessons Learned

- Use `nixos-rebuild dry-build` instead of `nixos-rebuild build` for testing (no `result` symlink created)
- Package names in nixpkgs may differ from expected (e.g., `transmission_4-gtk` not `transmission-gtk`)
- Home Manager uses `settings` instead of `config` for git configuration (`programs.git.settings`)
- Use `force = true` on `home.file` options to forcefully overwrite existing desktop entries
- When hiding desktop entries, search for the exact desktop file name in nix store with `find /nix -name "*.desktop"`
- Always test build with `nixos-rebuild dry-build` before committing
- Use LSP (nixd) in editor to catch attribute errors early
- For **agent-executed** commands requiring root, use `pkexec` instead of `sudo` (e.g., `nixos-rebuild switch`). When manually running commands, use `sudo` as normal.
