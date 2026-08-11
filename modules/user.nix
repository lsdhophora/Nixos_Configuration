{
  pkgs,
  config,
  ...
}:

{
  programs.zsh.enable = true;

  users.users.lophophora = {
    isNormalUser = true;
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
