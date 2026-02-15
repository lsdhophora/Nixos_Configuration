{
  pkgs,
  ...
}:

{
  programs.zsh = {
    enable = true;
    promptInit = ''
      if [[ -n "$IN_NIX_SHELL" ]]; then
        export PS1="%F{green}[nix-shell] →%f "
      else
        export PS1="%F{green}→%f "
      fi
    '';
    interactiveShellInit = ''
      setopt NO_PROMPT_CR
      setopt no_beep

      nixos-assistant() {
        local orig_dir="$(pwd)"
        cd ~/.config/nixos
        opencode -s ses_3a4bcecf7ffemi02sJ5poVS1vw
        cd "$orig_dir"
      }
    '';
  };

  environment.sessionVariables = {
    XCOMPOSECACHE = "/tmp/.compose-cache/";
  };
}
