{
  ...
}:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        ServerAliveInterval = 60;
        ServerAliveCountMax = 3;
      };
      "github.com" = {
        HostName = "ssh.github.com";
        User = "git";
        Port = 443;
        IdentityFile = "/home/FeiHsueh/.ssh/lysergic";
      };
    };
  };
}
