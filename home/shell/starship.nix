{ lib, ... }:
let
  # Two-line prompt. Line 1 shows the context, line 2 shows the input
  # symbol. The icons come from the Symbols Nerd Font Mono of WezTerm
  # (see home/programs/wezterm.nix); the values follow the
  # nerd-font-symbols preset of Starship. The settings below hold only
  # the values that differ from the defaults.
  format = lib.concatStrings [
    "$os"
    "$username"
    "$hostname"
    "$directory"
    "$git_branch"
    "$git_status"
    "$git_state"
    "$git_metrics"
    "$nix_shell"
    "$direnv"
    "$python"
    "$jobs"
    "$cmd_duration"
    "$status"
    "$fill"
    "$time"
    "$line_break"
    "$character"
  ];
in
{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      # Blank line above the prompt. It keeps the first line of the prompt
      # clear of the herdr tab row and of the previous command output.
      add_newline = true;
      inherit format;

      # OS icon. The keys are the os_info type names. The icon carries no
      # style and the format writes an unstyled space after it: WezTerm lets
      # a square icon glyph overflow into the cell after it only when that
      # cell holds a space with the same attributes, and a styled icon is
      # squeezed into one cell instead, which renders it smaller and blurred.
      # The space also leaves room for the width of the larger symbol font.
      # See home/programs/wezterm.nix.
      os = {
        disabled = false;
        style = "none";
        format = "[$symbol]($style) ";
        symbols = {
          NixOS = "";
          Linux = "";
          Macos = "";
        };
      };

      # Show the user and the host name for root and for SSH sessions only.
      # A module that can be absent must not carry the separator, so the
      # user name and the path carry a leading space and the icon does not.
      username = {
        format = " [$user]($style)";
        style_user = "bold green";
      };
      hostname = {
        format = "[@$hostname]($style)";
        style = "bold green";
      };

      # Keep the default path truncation (three elements, up to the
      # repository root); add the ellipsis, the lock, and the separator.
      directory = {
        format = " [$path]($style)[$read_only]($read_only_style) ";
        truncation_symbol = "…/";
        read_only = " 󰌾";
        read_only_style = "bold red";
      };

      git_branch = {
        symbol = " ";
        truncation_length = 32;
      };

      # Show the added and the deleted line counts of the work tree.
      git_metrics.disabled = false;

      # Detect a `nix shell` sub-shell through the /nix/store path entries.
      # The icon keeps the unstyled look of the os icon above: the module
      # style bolds and colours the state, and a bold icon renders heavier
      # than the rest of the prompt. The symbol carries the two spaces, and
      # both stay unstyled, so WezTerm lets the square icon overflow into a
      # space with the same attributes and renders it at the size of the
      # larger symbol font instead of squeezing it into one cell.
      nix_shell = {
        heuristic = true;
        unknown_msg = "nix shell";
        format = "via [$symbol](none)[$state(\\($name\\))]($style) ";
        symbol = "  ";
      };

      direnv = {
        disabled = false;
        format = "via [$symbol$loaded/$allowed]($style) ";
        symbol = " ";
      };

      python.symbol = " ";
      jobs.symbol = " ";

      # Show the duration of the last command after 0.5 seconds.
      cmd_duration = {
        min_time = 500;
        show_milliseconds = true;
        format = "took [ $duration]($style) ";
      };

      # Show the exit code of a failed command.
      status = {
        disabled = false;
        symbol = " ";
        format = "exit [$symbol$status]($style) ";
      };

      # The invisible fill pushes the time to the right edge.
      fill.symbol = " ";
      # The clock icon keeps the colour of the time, so the two read as one
      # unit. The symbol carries two spaces and stays inside the styled
      # span: WezTerm lets the square glyph overflow into a space with the
      # same attributes and renders it at the size of the larger symbol
      # font. One space left the 1.4 scale glyph on top of the time. The
      # style is explicit: the scheme maps the plain "yellow" to an orange
      # (#f67400), so use the bright yellow of the palette (color11,
      # #fdbc4b). The module default "bold yellow" would also bold it.
      time = {
        disabled = false;
        style = "bright-yellow";
        time_format = "%R";
        format = "[  $time]($style) ";
      };
    };
  };
}
