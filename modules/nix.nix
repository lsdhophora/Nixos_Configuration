{
  config,
  pkgs,
  ...
}:

{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.trusted-users = [
    "root"
    "lophophora"
  ];

  programs.git = {
    enable = true;
    config = {
      user = {
        name = "lsdhophora";
        email = "lsdphophora@proton.me";
      };
      init.defaultBranch = "main";
    };
  };
}
