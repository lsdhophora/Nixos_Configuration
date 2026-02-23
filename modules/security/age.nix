{
  config,
  pkgs,
  ...
}:

{
  age.secrets.hashedPassword = {
    file = ../../secrets/hashed-password.age;
    owner = "root";
    group = "root";
    mode = "600";
  };

  age.secrets.access-tokens-github = {
    file = ../../secrets/access-tokens-github.age;
    path = "/run/agenix/access-tokens-github";
    owner = "root";
    group = "root";
    mode = "600";
  };

  age.identityPaths = [ "/home/lophophora/.ssh/lysergic" ];

  nix.extraOptions = ''
    !include ${config.age.secrets.access-tokens-github.path}
  '';
}
