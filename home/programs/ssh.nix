{
  ...
}:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "github.com" = {
        hostname = "ssh.github.com";
        user = "git";
        port = 443;
        identityFile = "/home/lophophora/.ssh/lysergic";
      };
    };
  };
}
