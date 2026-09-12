{ ... }:
# General home persistence (impermanence).
# /home is tmpfs; only these paths are bind-mounted from /persist/home/FeiHsueh.
# KDE-specific entries live in ./kde/persistence-kde.nix (merged into the same key).
# That file persists the whole .config directory, so no path below .config
# belongs here. The paths below .config that survive a reboot are the list
# in modules/desktop/home-config-prune.nix.
{
  home.persistence."/persist" = {
    directories = [
      # ---- Keys & trust ----
      ".ssh"
      ".gnupg"
      ".pki"

      # ---- Nix state ----
      ".local/state/nix"
      ".local/state/home-manager"

      # ---- App data (.local/share, non-KDE) ----
      ".local/share/keyrings"
      ".local/share/kwalletd"
      ".local/share/Trash" # Trash must persist
      ".local/share/fluffychat"
      ".local/share/localsend_app"
      ".local/share/org.localsend.localsend_app"
      ".local/share/Shortwave"
      ".local/share/emacs"
      ".local/share/fcitx5"
      ".local/share/gh"
      ".local/share/nix"
      ".local/share/direnv"
      ".local/share/systemd"
      ".local/share/uv"

      # ---- zsh -----
      ".local/state/zsh"

      "keepass"
      "Projects"
      "Documents"
      "Downloads"
      "Music"
      "Pictures"
      "Videos"
      "Desktop"
      "Public"
      "Templates"

      # ---- LibreWolf profile (migrated from Firefox) ----
      ".librewolf"

      # ---- pi agent runtime state (config itself is declarative via home/dev/pi-agent) ----
      ".pi/agent/sessions"
      ".pi/agent/npm"
      ".pi/agent/voice-input-models"
    ];
    files = [

      # ---- pi agent runtime files (credentials, fetched model cache, voice config, trust) ----
      ".pi/agent/auth.json"
      ".pi/agent/models-store.json"
      ".pi/agent/voice-input.json"
      ".pi/agent/trust.json"

      # pi-owned settings (model choice, thinking level, ...). The keys
      # in piSettings.enforced are re-applied by
      # home/dev/pi-agent/files.nix on every activation.
      ".pi/agent/settings.json"
    ];
  };
}
