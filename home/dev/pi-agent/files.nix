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

  # The herdr pi integration file comes from the herdr binary itself.
  # Herdr writes the file with `herdr integration install pi`, and this
  # derivation copies it out. The result always matches the installed
  # herdr version, so the file cannot drift.
  herdrPiIntegration =
    pkgs.runCommand "herdr-pi-integration"
      {
        nativeBuildInputs = [ pkgs.herdr ];
      }
      ''
        export HOME=$TMPDIR
        export XDG_CONFIG_HOME=$TMPDIR/.config
        export XDG_STATE_HOME=$TMPDIR/.state
        mkdir -p "$HOME/.pi/agent/extensions"
        herdr integration install pi
        mkdir -p $out
        cp "$HOME/.pi/agent/extensions/herdr-agent-state.ts" $out/
      '';

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
      theme = "breeze-dark";
      packages = [
        "npm:@mistgc/pi-voice-input"
        "npm:pi-lsp"
        "npm:pi-subdir-context"
        "npm:pi-mermaid"
        # The /goal extension with the most GitHub stars (Michaelliv/pi-goal).
        "npm:pi-goal"
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
        ];
      })
      (repoLib.mkRepoLinks config {
        targetPrefix = ".pi/agent/themes/";
        sourcePrefix = "${base}/themes/";
        paths = [ "breeze-dark.json" ];
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
      # Herdr learns the pi agent state (working, blocked, idle) only from
      # the integration file. Herdr generates both that file and the skill
      # file, so take them from the installed herdr package. The copies
      # cannot drift from the running binary that way.
      {
        ".pi/agent/extensions/herdr-agent-state.ts".source = "${herdrPiIntegration}/herdr-agent-state.ts";
        ".pi/agent/skills/herdr/SKILL.md".source = "${pkgs.herdr}/share/herdr/skills/herdr/SKILL.md";
      }
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
