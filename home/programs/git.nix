{
  pkgs,
  ...
}:

{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "lsdhophora";
        email = "lsdphophora@proton.me";
      };
      init.defaultBranch = "main";
    };
  };
}
