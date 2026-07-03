{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableVteIntegration = true;
    autosuggestion.enable = true;

    history = {
      append = true;
      extended = true;
      ignoreAllDups = true;
      ignoreSpace = true;
      save = 10000;
      size = 10000;
      share = true;
    };

    initContent = ''
      nix() {
        if [[ -n $NIX_GET_COMPLETIONS ]]; then
          command nix "$@"
        elif [[ $1 == "shell" ]]; then
          shift
          command nix shell "$@" --command env "IN_NIX_SHELL=nix3" "$SHELL"
        else
          command nix "$@"
        fi
      }

      if [[ $IN_NIX_SHELL == "nix3" ]]; then
        PROMPT='%F{green}%B[nix shell]%b %F{green}%B$%b%f '
      elif [[ -n $IN_NIX_SHELL ]]; then
        PROMPT='%F{green}%B[nix-shell]%b %F{green}%B$%b%f '
      else
        PROMPT='%F{green}%B$%b%f '
      fi
      RPROMPT=""

      # auto-start tmux on kmscon or kernel TTY
      if [[ -z "$TMUX" ]] && command -v tmux &>/dev/null; then
        if [[ $TERM_SESSION_TYPE == kms ]] || [[ $(tty) == /dev/tty* ]]; then
          tmux new-session -A -s main
          echo "tmux exited with code $?"
        fi
      fi
    '';

    shellAliases = {
      ls = "ls --color=auto";
      ll = "ls -lah";
      open = "xdg-open";
      grep = "grep --color=auto";
    };
  };
}
