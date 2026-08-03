{ config, ... }:

{
  sops.defaultSopsFile = ../../secrets/secrets.yaml;

  sops.age.sshKeyPaths = [ "/home/lophophora/.ssh/lysergic" ];

  # hashed-password: needed before user creation
  sops.secrets.hashed-password = {
    neededForUsers = true;
  };

  # GitHub access tokens for nix
  sops.secrets.access-tokens-github = {
    path = "/run/secrets/access-tokens-github";
    mode = "0600";
    owner = "root";
    group = "root";
  };

  nix.extraOptions = ''
    !include ${config.sops.secrets.access-tokens-github.path}
  '';
}
