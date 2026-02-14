{
  config,
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
    '';
  };

  environment.sessionVariables = {
    XCOMPOSECACHE = "/tmp/.compose-cache/";
  };
}
