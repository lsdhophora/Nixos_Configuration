{ config, ... }:

{
  sops.defaultSopsFile = ../../secrets/secrets.yaml;

  sops.age.sshKeyPaths = [ "/home/lophophora/.ssh/lysergic" ];

  # hashed-password: needed before user creation
  sops.secrets.hashed-password = {
    neededForUsers = true;
  };

  # GitHub access token for nix, rendered into the user nix.conf with the
  # sops template pattern (same as the dae config template).
  # NOTE: the secret value must be the bare token (ghp_...), NOT a full
  # nix.conf line — the template adds the "access-tokens = github.com=" part.
  # The nix *client* (running as the user) reads ~/.config/nix/nix.conf
  # itself, so it must be user-readable — a root-only path under
  # /run/secrets.d gives EACCES and access-tokens stays empty.
  sops.secrets.access-tokens-github = { };

  sops.templates."nix-user.conf" = {
    content = ''
      access-tokens = github.com=${config.sops.placeholder.access-tokens-github}
    '';
    path = "/home/lophophora/.config/nix/nix.conf";
    mode = "0600";
    owner = "lophophora";
    group = "users";
  };
}
