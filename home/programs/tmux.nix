{ lib, ... }:
let
  palette = (import ../../lib).breezeDark;

  # Generate "bind-key <flags> <key> <cmd>" lines from a key-command table.
  bindKeys =
    flags: binds:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        key: cmd: "bind-key${if flags == "" then "" else " " + flags} ${key} ${cmd}"
      ) binds
    );

  # bindKeys over a key-direction table. It adds the tmux -<dir> suffix.
  # Example: bindDirs "" "select-pane" { h = "L"; } gives "bind-key h select-pane -L"
  bindDirs =
    flags: cmd: dirs:
    bindKeys flags (lib.mapAttrs (key: dir: "${cmd} -${dir}") dirs);
in
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
      # extended-keys: modified Enter keys (needed by e.g. some TUI apps)
      set -g extended-keys on
      # csi-u format: pi (coding agent) works best with this
      set -g extended-keys-format csi-u

      # reload config
      bind-key r source-file ~/.config/tmux/tmux.conf \; display-message "sourced tmux.conf"

      bind-key c copy-mode

      # copy-mode scroll bindings (vi)
      ${bindKeys "-Tcopy-mode-vi" {
        n = "send-keys -X halfpage-down";
        p = "send-keys -X halfpage-up";
      }}
      bind-key -Tcopy-mode-vi v send-keys -X begin-selection
      bind-key -Tcopy-mode-vi y send-keys -X copy-selection
      bind-key -Tcopy-mode-vi Enter send-keys -X copy-selection-and-cancel
      bind-key -Tcopy-mode-vi Escape send-keys -X cancel

      # sessions
      bind-key s choose-session
      bind-key n display-panes
      bind-key : command-prompt

      # panes
      bind-key v split-window -h
      bind-key x split-window -v
      bind-key q kill-pane
      # navigation (h/j/k/l)
      ${bindDirs "" "select-pane" {
        h = "L";
        j = "D";
        k = "U";
        l = "R";
      }}
      # swap (C-h/C-j/C-k/C-l, repeat)
      ${bindDirs "-r" "swap-pane" {
        "C-h" = "D";
        "C-j" = "U";
        "C-k" = "D";
        "C-l" = "U";
      }}
      # resize (i/u/y/o, repeat)
      ${bindDirs "-r" "resize-pane" {
        i = "U 5";
        u = "D 5";
        y = "L 5";
        o = "R 5";
      }}

      # windows (workspace-like)
      bind-key enter new-window
      bind-key -n C-. next-window
      bind-key -n C-, previous-window

      # appearance
      set -g pane-border-style 'fg=${palette.alt}'
      set -g pane-active-border-style 'fg=${palette.accent}'

      # Rename windows automatically to the current program (sway-like)
      setw -g automatic-rename on
      setw -g automatic-rename-format "#{pane_current_command}"

      # status bar
      set -g status-interval 10
      set -g status-right-length 80
      set -g status-style 'bg=${palette.bg},fg=${palette.fg}'

      setw -g window-status-separator ' '
      setw -g window-status-format " #I:#W "
      setw -g window-status-current-format " #I:#W "
      setw -g window-status-style 'fg=${palette.inactive} bg=${palette.alt}'
      setw -g window-status-current-style 'fg=${palette.fg} bg=${palette.accent} bold'
      setw -g window-status-bell-style 'fg=${palette.fg} bg=${palette.red} bold'

      # battery on kmscon or TTY only
      set -g status-right "#(if [ \"\$TERM_SESSION_TYPE\" = kms ] || [ \"\$(tty)\" != \"not a tty\" ]; then read c < /sys/class/power_supply/BAT0/capacity; read s < /sys/class/power_supply/BAT0/status; echo \"\$c%% \$s |\"; fi)%H:%M"
      set -g status-right-style 'fg=${palette.inactive} bg=${palette.bg}'
      set -g status-left "#[bg=${palette.accent},fg=${palette.fg},bold] #S #[default]"
      set -g status-left-style 'bg=${palette.bg}'

      # messages and modes
      set -g message-style 'fg=${palette.fg} bg=${palette.accent}'
      set -g message-command-style 'fg=${palette.fg} bg=${palette.accent}'
      set -g mode-style 'fg=${palette.fg} bg=${palette.accent}'
    '';
  };
}
