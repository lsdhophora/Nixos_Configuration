{ pkgs, ... }:

{
  home.packages = with pkgs; [
    elvish
    carapace
  ];

  home.file.".config/elvish/rc.elv".text = ''
    # Elvish package manager
    use epm

    # Declarative install third-party modules
    epm:install &silent-if-installed github.com/zzamboni/elvish-modules

    # Load terminal-title module
    use github.com/zzamboni/elvish-modules/terminal-title

    # Carapace completions
    eval (carapace _carapace elvish | slurp)

    # Terminal title - show current directory with ~ abbreviation
    set terminal-title:title-during-prompt = { put (tilde-abbr $pwd) }
    set terminal-title:title-during-command = {|cmd| put (tilde-abbr $pwd) }

    # Prompt function
    fn prompt {
      if (has-env IN_NIX_SHELL) {
        put (styled (styled "[nix-shell] →" green) bold)
      } else {
        put (styled (styled "→" green) bold)
      }
      put " "
    }

    # Assign the prompt function
    set edit:prompt = $prompt~

    # Basic settings
    set edit:rprompt = (constantly "")
  '';
}
