{
  config,
  lib,
  repoLib,
  ...
}:
let
  base = "home/dev/pi-agent";
in
{
  home.file = lib.mkMerge [
    (repoLib.mkRepoLinks config {
      targetPrefix = ".pi/agent/";
      sourcePrefix = "${base}/";
      paths = [
        "AGENTS.md"
        "models.json"
        "lsp.json"
        "skills/exa-search/SKILL.md"
        "skills/ascii-art/SKILL.md"
        "skills/nix/SKILL.md"
      ];
    })
    (repoLib.mkRepoLinks config {
      targetPrefix = ".pi/agent/themes/";
      sourcePrefix = "${base}/themes/";
      paths = [ "breeze-light.json" ];
    })
    (repoLib.mkRepoLinks config {
      targetPrefix = ".pi/agent/extensions/";
      sourcePrefix = "${base}/extensions/";
      paths = [
        "deepseek-balance.ts"
        "exa-gate.ts"
        "exa-pi.ts"
        "exa-prefix.ts"
        "no-cost-footer.ts"
        "plan-mode/index.ts"
        "plan-mode/utils.ts"
        "plan-mode/README.md"
        "root-session/index.ts"
        "root-session/daemon.js"
        "root-session/SKILL.md"
        "pi-scheduler"
        "subagent"
      ];
    })
    (repoLib.mkRepoLinks config {
      targetPrefix = ".pi/agent/agents/";
      sourcePrefix = "${base}/agents/";
      paths = [ "worker.md" ];
    })
    {
      ".pi/agent/settings.json" = {
        text = builtins.toJSON {
          defaultProvider = "deepseek";
          defaultModel = "deepseek-v4-flash";
          theme = "breeze-light";
          packages = [
            "npm:@mistgc/pi-voice-input"
            "npm:pi-lsp"
            "npm:pi-subdir-context"
            "npm:pi-mermaid"
          ];
        };
      };
    }
  ];
}
