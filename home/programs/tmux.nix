{ pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    baseIndex = 1;
    keyMode = "vi";
    prefix = "C-b";
    sensibleOnTop = false;
    escapeTime = 0;

    extraConfig = ''
      # reload config
      bind-key r source-file ~/.config/tmux/tmux.conf \; display-message "sourced tmux.conf"

      bind-key c copy-mode
      bind-key -Tcopy-mode-vi n send-keys -X halfpage-down
      bind-key -Tcopy-mode-vi p send-keys -X halfpage-up
      bind-key -Tcopy-mode-vi v send-keys -X begin-selection
      bind-key -Tcopy-mode-vi y send-keys -X copy-selection
      bind-key -Tcopy-mode-vi Enter send-keys -X copy-selection-and-cancel
      bind-key -Tcopy-mode-vi Escape send-keys -X cancel

      bind-key s choose-session
      bind-key n display-panes
      bind-key : command-prompt

      # panes
      bind-key v split-window -h
      bind-key x split-window -v
      bind-key o rotate-window
      bind-key q kill-pane
      bind-key h select-pane -L
      bind-key j select-pane -D
      bind-key k select-pane -U
      bind-key l select-pane -R
      bind-key -r C-h swap-pane -D
      bind-key -r C-j swap-pane -U
      bind-key -r C-k swap-pane -D
      bind-key -r C-l swap-pane -U
      bind-key -r i resize-pane -U 5
      bind-key -r u resize-pane -D 5
      bind-key -r y resize-pane -L 5
      bind-key -r o resize-pane -R 5

      # windows (workspace-like)
      bind-key enter new-window
      bind-key -n C-. next-window
      bind-key -n C-, previous-window

      # appearance
      set -g pane-active-border-style 'fg=red'

      # auto-rename windows to current program (sway-like)
      setw -g automatic-rename on
      setw -g automatic-rename-format "#{pane_current_command}"

      # status bar
      set -g status-interval 10
      set -g status-right-length 80

      setw -g window-status-separator ' '
      setw -g window-status-format " #I:#W "
      setw -g window-status-current-format " #I:#W "
      setw -g window-status-style 'fg=#ffffff bg=#111111'
      setw -g window-status-current-style 'fg=#000000 bg=#9141ac'
      setw -g window-status-bell-style 'fg=yellow bg=red bold'

      # battery on kmscon or TTY only
      set -g status-right "#(if [ \"\$TERM_SESSION_TYPE\" = kms ] || [ \"\$(tty)\" != \"not a tty\" ]; then read c < /sys/class/power_supply/BAT0/capacity; read s < /sys/class/power_supply/BAT0/status; echo \"\$c%% \$s |\"; fi)%H:%M [#S]"
      set -g status-right-style 'fg=#ffffff bg=#111111'
      set -g status-left ""
      set -g status-style 'bg=#111111'
    '';
  };
}
