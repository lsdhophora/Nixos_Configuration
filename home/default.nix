{ ... }:

{
  home.username = "FeiHsueh";
  home.homeDirectory = "/home/FeiHsueh";
  home.stateVersion = "25.05";

  # ============================================================
  #  Home configuration menu.
  #  Enable or disable modules here (comment out to disable).
  # ============================================================
  imports = [
    # ---- Misc ----
    ./misc/avatar.nix
    ./misc/cli.nix
    ./misc/clangd.nix
    ./misc/gui.nix
    ./packages.nix

    # ---- KDE / Plasma (per-module toggles in ./kde/default.nix) ----
    ./kde

    # ---- Desktop (non-KDE) ----
    ./desktop/dconf.nix
    ./desktop/gtk.nix
    ./desktop/session.nix

    # ---- Programs ----
    ./programs/emacs
    ./programs/librewolf.nix
    ./programs/mpv.nix
    ./programs/tmux.nix
    ./programs/wezterm.nix

    # ---- Dev ----
    ./dev/direnv.nix
    ./dev/git.nix
    ./dev/pi-agent
    ./dev/ssh.nix
    ./dev/texlive.nix

    # ---- Shell ----
    ./shell/zsh.nix
  ];

}
