{ ... }:
let
  # zsh prompt format. The label shows as a bracket tag when not empty.
  prompt =
    label: if label == "" then "%F{green}%B$%b%f " else "%F{green}%B[${label}]%b %F{green}%B$%b%f ";
in
{
  home.sessionVariables = {
    PI_SKIP_VERSION_CHECK = "1";
  };

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
        PROMPT='${prompt "nix shell"}'
      elif [[ -n $IN_NIX_SHELL ]]; then
        PROMPT='${prompt "nix-shell"}'
      else
        PROMPT='${prompt ""}'
      fi
      RPROMPT=""

      # Set the terminal title to the current directory
      precmd() { print -Pn "\e]0;%~\a" }

      # Start tmux automatically on kmscon or a kernel TTY
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
