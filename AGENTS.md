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
│   ├── nix.nix               # Nix settings and git config
│   ├── i18n.nix              # Fonts and input method (IBus Rime)
│   ├── shell/zsh.nix         # Zsh shell configuration
│   ├── services/
│   │   └── dae.nix           # DAE service (transparent proxy)
│   └── security/
│       └── age.nix           # Agenix secret management
├── home/                     # Home Manager configurations
│   ├── default.nix          # Home Manager entry point
│   ├── packages.nix         # User packages (GNOME extensions, apps)
│   ├── dconf.nix             # GNOME dconf settings
│   └── programs/
│       ├── ssh.nix           # SSH configuration (GitHub via SSH over 443)
│       ├── direnv.nix         # Direnv with nix-direnv
│       ├── librewolf.nix      # LibreWolf browser configuration
│       └── emacs.nix          # Emacs configuration (extensive)
├── secrets/                  # Agenix secrets (age encrypted)
│   ├── config.dae.age        # DAE config secret
│   └── access-tokens-github.age  # GitHub access token
├── desktop/                  # Desktop environment configs (empty)
├── services/                 # Additional services (empty)
├── shell/                    # Shell configs (empty)
├── security/                 # Security configs (empty)
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
- Shell: Zsh with custom prompt (shows `[nix-shell]` indicator)
- User packages: tree, ffmpeg, fastfetch, imagemagick, TeX Live (with CTEX), pandoc, texlab, nixfmt, nixd, ghostty

### Desktop Environment
- **GNOME** with extensive customization
- **Extensions**: Caffeine, Just Perfection, Blur My Shell, Run or Raise
- **Excluded packages**: Many GNOME defaults removed (cheese, geary, gedit, epiphany, etc.)
- **Nautilus**: Open-in-terminal configured to use Ghostty
- **GDM dconf**: Custom cursor size (28), text scaling factor (1.33)

### Applications
- **Browser**: LibreWolf with custom settings (no translations, middle-click disabled, etc.)
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

## Common Commands

```bash
# Dry-run build to check for errors before committing
sudo nixos-rebuild build --flake .#flowerpot

# Build system
sudo nixos-rebuild switch --flake .#flowerpot

# Update flake inputs
sudo nixos-rebuild switch --flake .#flowerpot --update-input nixpkgs
```

## Notes

- Hardware config is auto-generated and should not be manually edited
- Secrets in `secrets/` are encrypted with age, decrypted at build time via Agenix
- The Emacs config is extensive (~275 lines) with many custom functions
- Some patches in `patches/` are applied via overrideAttrs
- Unused configs in `unused/` are kept for reference but not imported
- **Important**: After making changes to the configuration, run `tree -L 3 --noreport -I 'result|*.lock'` to update the Project Structure section in this file to keep it in sync with actual modifications. Also update Key Features, Code Style, Common Commands, and Notes sections as needed.
