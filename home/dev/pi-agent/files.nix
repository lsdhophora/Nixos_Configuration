{ config, lib, ... }:
let
  repo = "${config.home.homeDirectory}/.config/nixos";
  base = "${repo}/home/dev/pi-agent";

  # Symlink a repo file or dir into ~/.pi/agent.
  mkLink = path: {
    source = config.lib.file.mkOutOfStoreSymlink "${base}/${path}";
  };

  # Turn a list of repo paths into home.file entries.
  # targetPrefix is prepended to the home file name. sourcePrefix is
  # prepended to the repo path. Add a path to a list below to link it.
  mkLinks =
    targetPrefix: sourcePrefix: paths:
    builtins.listToAttrs (
      map (path: {
        name = targetPrefix + path;
        value = mkLink (sourcePrefix + path);
      }) paths
    );
in
{
  home.file = lib.mkMerge [
    (mkLinks ".pi/agent/" "" [
      "AGENTS.md"
      "models.json"
      "skills/exa-search/SKILL.md"
    ])
    (mkLinks ".pi/agent/extensions/" "extensions/" [
      "deepseek-balance.ts"
      "exa-gate.ts"
      "exa-prefix.ts"
      "no-cost-footer.ts"
      "root-session/index.ts"
      "root-session/daemon.js"
      "root-session/SKILL.md"
      "pi-scheduler"
    ])
    {
      ".pi/agent/settings.json" = {
        text = builtins.toJSON {
          defaultProvider = "deepseek";
          defaultModel = "deepseek-v4-flash";
          packages = [
            "git:github.com/Fletcher-Alderton/exa-pi"
          ];
        };
      };
    }
  ];
}
