{ ... }:
# General home persistence (impermanence).
# /home is tmpfs; only these paths are bind-mounted from /persist/home/FeiHsueh.
# KDE-specific entries live in ./persistence-kde.nix (merged into the same key).
{
  home.persistence."/persist" = {
    directories = [
      # ---- Keys & trust ----
      ".ssh" ".gnupg" ".pki"
      # sops age keys (needed to decrypt secrets at boot)
      ".config/sops"

      # ---- Nix state ----
      ".local/state/nix" ".local/state/home-manager"

      # ---- App data (.local/share, non-KDE) ----
      ".local/share/keyrings" ".local/share/kwalletd" ".local/share/Trash" # Trash must persist
      ".local/share/fluffychat" ".local/share/localsend_app"
      ".local/share/org.localsend.localsend_app" ".local/share/Shortwave"
      ".local/share/emacs" ".local/share/firefoxpwa" ".local/share/fcitx5"
      ".local/share/gh" ".local/share/nix" ".local/share/direnv"
      ".local/share/systemd" ".local/share/uv"

      # ---- User files ----
      "Projects" "Documents" "Downloads" "Music" "Pictures" "Videos"
      "Desktop" "Public" "Templates"

      # ---- Firefox data (under .config) ----
      ".config/.mozilla" ".config/mozilla"

      # ---- Nix config repo ----
      ".config/nixos"

      # ---- pi agent runtime state (config itself is declarative via home/dev/pi-agent) ----
      ".pi/agent/sessions" ".pi/agent/npm" ".pi/agent/voice-input-models"

      # ---- Non-KDE app config (.config) ----
      # Element keeps its key backup (IndexedDB) and session here; must persist
      # across reboots or the Matrix account needs re-login and re-verification.
      ".config/Element"
      ".config/dconf" ".config/direnv" ".config/emacs" ".config/environment.d"
      ".config/fcitx" ".config/fcitx5" ".config/fontconfig" ".config/git"
      ".config/gtk-3.0" ".config/gtk-4.0" ".config/kitty" ".config/mpv"
      ".config/tmux" ".config/systemd"
      ".config/nix" ".config/nnn" ".config/lazygit" ".config/gh"
      ".config/xsettingsd" ".config/libaccounts-glib" ".config/clangd" ".config/go"
    ];
    files = [
      ".bash_history" ".zsh_history"

      # ---- pi agent runtime files (credentials, fetched model cache, voice config, trust) ----
      ".pi/agent/auth.json" ".pi/agent/models-store.json" ".pi/agent/voice-input.json" ".pi/agent/trust.json"
    ];
  };
}
