{
  pkgs,
  config,
  ...
}:

{
  programs.zsh.enable = true;

  users.users.FeiHsueh = {
    isNormalUser = true;
    uid = 1000;
    description = "费雪";
    hashedPasswordFile = config.sops.secrets.hashed-password.path;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
    packages = [ ];
  };

  environment.systemPackages = with pkgs; [
    nano
    git
    wget
    sops
  ];

  system.stateVersion = "25.05";
}
