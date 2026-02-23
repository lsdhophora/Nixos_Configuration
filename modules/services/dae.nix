{
  config,
  pkgs,
  ...
}:

{
  age.secrets.daeConfig = {
    file = ../../secrets/config.dae.age;
    mode = "600";
    owner = "root";
    group = "root";
  };

  services.dae = {
    enable = true;
    configFile = config.age.secrets.daeConfig.path;
  };
}
