# Flake checks: static analysis, evaluation checks, and build verification.
#
#   - Fast static checks (per-edit): format, deadnix, statix,
#     sops-integrity, sops-keys.
#   - Evaluation checks: invariants (key config facts), lib-tests (unit
#     tests for lib/default.nix helpers).
#   - Build checks (pre-commit): system toplevel + home activation.
#
# Run with:
#   just check-fast   # static + eval checks, ~1 min
#   just check        # everything via `nix flake check`, slow
#
# VM boot tests are deliberately absent: see docs/testing.md for the
# record and how to re-enable them on a KVM-capable host.
#
# Note: the static checks pass `src = ../.` as an explicit derivation
# input and enumerate files with `find` at build time. An eval-time
# file list loses its store context, so the sandbox would not contain
# the files.
{ inputs, lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      src = ../.;
    in
    {
      checks = {
        # ---- Fast static checks ----
        # Formatting drift vs the configured formatter (pkgs.nixfmt).
        format =
          pkgs.runCommand "check-nixfmt"
            {
              inherit src;
              nativeBuildInputs = [ pkgs.nixfmt ];
            }
            ''
              files=$(find "$src" -name '*.nix' -not -path "$src/result/*" -not -path "$src/nixpkgs/*" -not -path "$src/.pi/*")
              nixfmt --check $files
              echo "format: OK" > $out
            '';

        # Dead code: unused let bindings and module args. Matches the
        # code-style rule "Remove dead code: no dead parameters".
        # hardware-configuration.nix is auto-generated, so exclude it
        # (community practice, see Rabbbba/nixos-config lint.yml).
        deadnix =
          pkgs.runCommand "check-deadnix"
            {
              inherit src;
              nativeBuildInputs = [ pkgs.deadnix ];
            }
            ''
              files=$(find "$src" -name '*.nix' -not -path "$src/result/*" -not -path "$src/nixpkgs/*" -not -path "$src/.pi/*")
              deadnix --fail --exclude hardware-configuration.nix $files
              echo "deadnix: OK" > $out
            '';

        # Nix anti-patterns (statix). Add .statix.toml to disable noise.
        statix =
          pkgs.runCommand "check-statix"
            {
              inherit src;
              nativeBuildInputs = [ pkgs.statix ];
            }
            ''
              cd "$src"
              statix check .
              echo "statix: OK" > $out
            '';

        # Comments must contain ASCII characters only (STE writing
        # standard). Catches non-ASCII comments, for example Chinese or
        # Unicode dashes. Only comment lines (leading #) are checked;
        # string values are not.
        ascii-comments =
          pkgs.runCommand "check-ascii-comments"
            {
              inherit src;
            }
            ''
              files=$(find "$src" -name '*.nix' -not -path "$src/result/*" -not -path "$src/nixpkgs/*" -not -path "$src/.pi/*")
              status=0
              for f in $files; do
                # hardware-configuration.nix is auto-generated, so exclude it.
                case "$f" in
                  */hardware-configuration.nix) continue ;;
                esac
                if grep -nP '^\s*#.*[^\x00-\x7F]' "$f"; then
                  echo "ERROR: non-ASCII characters in comment: $f" >&2
                  status=1
                fi
              done
              [ $status -eq 0 ] || exit 1
              echo "ascii-comments: OK" > $out
            '';

        # Every value in secrets/secrets.yaml must be SOPS-encrypted
        # (ENC[...]), except the sops: metadata block. Catches a
        # decrypted secret file committed by mistake.
        sops-integrity =
          pkgs.runCommand "check-sops-integrity"
            {
              nativeBuildInputs = [ pkgs.yq-go ];
            }
            ''
              plaintext=$(${pkgs.yq-go}/bin/yq eval 'del(.sops) | .[] | select(test("^ENC\\[") | not)' ${../secrets/secrets.yaml})
              if [ -n "$plaintext" ]; then
                echo "ERROR: plaintext values found in secrets/secrets.yaml:" >&2
                echo "$plaintext" >&2
                exit 1
              fi
              echo "sops-integrity: OK" > $out
            '';

        # Every sops.secrets.<key> referenced in the config must exist
        # as a key in secrets/secrets.yaml. Catches a renamed or removed
        # secret that a module still references.
        sops-keys =
          pkgs.runCommand "check-sops-keys"
            {
              inherit src;
              nativeBuildInputs = [ pkgs.yq-go ];
            }
            ''
              keys=$(${pkgs.yq-go}/bin/yq eval 'keys | map(select(. != "sops")) | .[]' ${../secrets/secrets.yaml})
              refs=$(grep -rhoE 'sops\.secrets\.[A-Za-z0-9_-]+' "$src"/modules "$src"/hosts "$src"/home | sed -E 's/^.*sops\.secrets\.//' | sort -u)
              status=0
              for ref in $refs; do
                if ! printf '%s\n' "$keys" | grep -qxF "$ref"; then
                  echo "ERROR: sops.secrets.$ref is used but missing in secrets/secrets.yaml" >&2
                  status=1
                fi
              done
              [ $status -eq 0 ] || exit 1
              echo "sops-keys: OK" > $out
            '';

        # ---- Evaluation checks ----
        # Key config facts. Assertions fail evaluation if a fact is
        # accidentally toggled off. Cheap: no build, only eval.
        invariants =
          let
            cfg = inputs.self.nixosConfigurations.flowerpot.config;
            homeCfg = inputs.self.homeConfigurations.FeiHsueh.config;
          in
          assert cfg.zramSwap.enable;
          assert cfg.services.pipewire.enable;
          assert cfg.networking.hostName == "flowerpot";
          assert cfg.users.users.FeiHsueh.isNormalUser;
          assert homeCfg.programs.git.enable;
          assert homeCfg.programs.zsh.enable;
          assert homeCfg.programs.wezterm.enable;
          assert homeCfg.programs.wezterm.settings.hide_tab_bar_if_only_one_tab == false;
          pkgs.runCommand "check-invariants" { } "echo 'invariants: OK' > $out";

        # Unit tests for lib/default.nix helpers. Failures abort the
        # evaluation with the failing cases in the message.
        lib-tests =
          let
            failures = lib.runTests (import ../tests/lib-tests.nix { inherit pkgs; });
          in
          if failures == [ ] then
            pkgs.runCommand "check-lib-tests" { } "echo 'lib-tests: OK' > $out"
          else
            throw "lib tests failed: ${builtins.toJSON failures}";

        # ---- Build checks (slow) ----
        # Full system build. Includes the nested home-manager config.
        system = inputs.self.nixosConfigurations.flowerpot.config.system.build.toplevel;
        # Standalone home-manager build (the `home-manager switch` path).
        home = inputs.self.homeConfigurations.FeiHsueh.activationPackage;
      };
    };
}
