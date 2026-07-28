{ ... }: {
  imports = [
    ../programs/git.nix
    ../programs/ssh.nix
    ../programs/direnv.nix
    ../programs/opencode.nix
    ../programs/pi-agent.nix
    ../programs/texlive.nix
  ];
}
