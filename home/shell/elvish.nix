{ pkgs, ... }:

{
  home.packages = with pkgs; [
    elvish
    carapace
  ];

  home.file.".config/elvish/rc.elv".text = ''
    # Elvish modules
    use github.com/zzamboni/elvish-modules/terminal-title

    # Carapace completions
    eval (carapace _carapace elvish | slurp)

    # Terminal title - show current directory with ~ abbreviation
    set terminal-title:title-during-prompt = { put (tilde-abbr $pwd) }
    set terminal-title:title-during-command = {|cmd| put (tilde-abbr $pwd) }

    # Prompt
    fn prompt {
      if (has-env IN_NIX_SHELL) {
        put (styled (styled "[nix-shell] →" green) bold)
      } else {
        put (styled (styled "→" green) bold)
      }
      put " "
    }

    # Basic settings
    set edit:rprompt = (constantly "")
  '';
}
