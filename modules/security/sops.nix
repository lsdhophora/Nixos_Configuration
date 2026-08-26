{ config, ... }:

{
  sops.defaultSopsFile = ../../secrets/secrets.yaml;

  # age key must live under /persist (real file, readable in stage-1 after fstab mounts)
  sops.age.sshKeyPaths = [ "/persist/home/FeiHsueh/.ssh/lysergic" ];

  # hashed-password: needed before user creation
  sops.secrets.hashed-password = {
    neededForUsers = true;
  };

  # GitHub access token for nix. It renders into the user nix.conf
  # with the sops template pattern (same as the dae config template).
  # The secret value must be the bare token (ghp_...), not a full
  # nix.conf line. The template adds the "access-tokens = github.com=" part.
  # The nix client (running as the user) reads ~/.config/nix/nix.conf
  # itself. It must be user-readable. A root-only path under
  # /run/secrets.d gives EACCES and access-tokens stays empty.
  sops.secrets.access-tokens-github = { };

  # ZeroTier network ID, consumed by modules/services/zerotier.nix.
  sops.secrets.zerotier-network-id = { };

  sops.templates."nix-user.conf" = {
    content = ''
      access-tokens = github.com=${config.sops.placeholder.access-tokens-github}
    '';
    path = "/home/FeiHsueh/.config/nix/nix.conf";
    mode = "0600";
    owner = "FeiHsueh";
    group = "users";
  };
}
