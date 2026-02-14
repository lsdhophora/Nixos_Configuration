{
  config,
  pkgs,
  ...
}:

{
  age.secrets.daeConfig = {
    file = ../../secrets/config.dae.age;
    path = "/run/secrets/dae/config.dae";
    mode = "600";
    owner = "root";
    group = "root";
  };

  services.dae = {
    enable = true;
    configFile = config.age.secrets.daeConfig.path;
  };
}
