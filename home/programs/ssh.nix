{
  ...
}:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "github.com" = {
        HostName = "ssh.github.com";
        User = "git";
        Port = 443;
        IdentityFile = "/home/lophophora/.ssh/lysergic";
      };
    };
  };
}
