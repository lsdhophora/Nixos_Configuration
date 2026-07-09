{ ... }: {
  imports = [
    ../boot.nix
    ../networking.nix
    ../user.nix
    ../nix-config.nix
    ../i18n.nix
    ../security/age.nix
    ../security/sudo.nix
    ../services/zram.nix
    ../services/atd.nix
  ];

  boot.tmp.cleanOnBoot = true;
}
