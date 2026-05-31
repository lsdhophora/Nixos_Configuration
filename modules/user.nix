{
  pkgs,
  inputs,
  config,
  ...
}:

{
  programs.zsh.enable = true;

  users.users.lophophora = {
    isNormalUser = true;
    description = "费雪";
    hashedPasswordFile = config.age.secrets.hashedPassword.path;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
    packages = with pkgs; [
      tree
      ffmpeg
      fastfetch
      imagemagick
      pandoc
      nixfmt
      nixd
      unzip
      gnome-sound-recorder
    ];
  };

  environment.systemPackages = with pkgs; [
    nano
    git
    wget
    inputs.agenix.packages.x86_64-linux.default
  ];

  system.stateVersion = "25.05";
}
