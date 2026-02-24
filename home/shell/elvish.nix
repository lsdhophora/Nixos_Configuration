{ pkgs, ... }:

{
  home.packages = with pkgs; [
    elvish
    carapace
  ];

  home.file.".config/elvish/rc.elv".text = ''
    # Carapace completions
    eval (carapace _carapace elvish | slurp)

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
    set edit:completion:binding[tab] = { edit:completion:start }
    set edit:rprompt = (constantly "")
  '';
}
