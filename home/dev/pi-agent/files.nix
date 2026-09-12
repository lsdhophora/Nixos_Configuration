{
  config,
  lib,
  pkgs,
  repoLib,
  ...
}:
let
  base = "home/dev/pi-agent";
  jsonFormat = pkgs.formats.json { };
  jq = lib.getExe pkgs.jq;
  settingsPath = "${config.home.homeDirectory}/.pi/agent/settings.json";

  # Merge the Nix-managed keys into a file that the application owns.
  # This is the form home-manager uses in its own programs.zed-editor
  # module: the static (Nix) side wins, and every other key stays as the
  # application left it.
  # The file is written in place, because rename(2) onto a bind-mounted
  # file fails with EBUSY.
  mergeSettings = staticSettings: ''
    path=${lib.escapeShellArg settingsPath}
    # An earlier generation left a read-only store symlink here. Drop
    # it only when it points into the store: the impermanence symlink
    # into /persist must stay.
    if [[ -L "$path" && "$(readlink -f "$path")" == /nix/store/* ]]; then
      rm -f "$path"
    fi
    mkdir -p "$(dirname "$path")"
    dynamic="$(${jq} -c . "$path" 2>/dev/null || echo '{}')"
    static="$(cat ${lib.escapeShellArg staticSettings})"
    merged="$(${jq} -n '$dynamic * $static' --argjson dynamic "$dynamic" --argjson static "$static")"
    printf '%s\n' "$merged" > "$path"
  '';
in
{
  options.piSettings.enforced = lib.mkOption {
    type = jsonFormat.type;
    default = { };
    description = ''
      Settings that Nix always restores in ~/.pi/agent/settings.json.
      Every other key stays writable by pi, for example the default
      provider and the default model.
    '';
  };

  config = {
    piSettings.enforced = {
      theme = "breeze-light";
      packages = [
        "npm:@mistgc/pi-voice-input"
        "npm:pi-lsp"
        "npm:pi-subdir-context"
        "npm:pi-mermaid"
      ];
    };

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
          "skills/herdr/SKILL.md"
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
          "exa-gate.ts"
          "exa-pi.ts"
          "exa-prefix.ts"
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
    ];

    # ~/.pi/agent/settings.json is runtime state. pi rewrites it whenever
    # the model changes, so it is not a home.file entry. It is persisted
    # (see home/persistence.nix) and the enforced keys are re-applied
    # here on every activation.
    home.activation = lib.mkMerge [
      (lib.mkIf (config.piSettings.enforced != { }) {
        piSettingsMerge = lib.hm.dag.entryAfter [ "linkGeneration" ] (
          mergeSettings (jsonFormat.generate "pi-settings-enforced.json" config.piSettings.enforced)
        );
      })
    ];
  };
}
