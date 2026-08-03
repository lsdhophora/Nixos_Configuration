{ config, ... }:
let
  repo = "${config.home.homeDirectory}/.config/nixos";
  base = "${repo}/home/dev/pi-agent";
in
{
  home.file = {
    ".pi/agent/AGENTS.md".source =
      config.lib.file.mkOutOfStoreSymlink "${base}/AGENTS.md";

    ".pi/agent/models.json".source =
      config.lib.file.mkOutOfStoreSymlink "${base}/models.json";

    ".pi/agent/settings.json" = {
      text = builtins.toJSON {
        defaultProvider = "deepseek";
        defaultModel = "deepseek-chat";
        packages = [
          "git:github.com/Fletcher-Alderton/exa-pi"
        ];
      };
    };

    # Extensions
    ".pi/agent/extensions/deepseek-balance.ts".source =
      config.lib.file.mkOutOfStoreSymlink "${base}/extensions/deepseek-balance.ts";
    ".pi/agent/extensions/exa-gate.ts".source =
      config.lib.file.mkOutOfStoreSymlink "${base}/extensions/exa-gate.ts";
    ".pi/agent/extensions/exa-prefix.ts".source =
      config.lib.file.mkOutOfStoreSymlink "${base}/extensions/exa-prefix.ts";
    ".pi/agent/extensions/no-cost-footer.ts".source =
      config.lib.file.mkOutOfStoreSymlink "${base}/extensions/no-cost-footer.ts";
    ".pi/agent/extensions/root-session/index.ts".source =
      config.lib.file.mkOutOfStoreSymlink "${base}/extensions/root-session/index.ts";
    ".pi/agent/extensions/root-session/daemon.js".source =
      config.lib.file.mkOutOfStoreSymlink "${base}/extensions/root-session/daemon.js";
    ".pi/agent/extensions/root-session/SKILL.md".source =
      config.lib.file.mkOutOfStoreSymlink "${base}/extensions/root-session/SKILL.md";

    # Skills
    ".pi/agent/skills/exa-search/SKILL.md".source =
      config.lib.file.mkOutOfStoreSymlink "${base}/skills/exa-search/SKILL.md";
  };
}
