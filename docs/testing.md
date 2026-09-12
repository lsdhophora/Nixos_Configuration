# Testing

`nix flake check` runs all checks. `just check-fast` runs the fast static
checks. See `flake-modules/checks.nix` for the definitions.

| Check | Type | What it verifies |
|---|---|---|
| `format` | static | All .nix files are formatted with nixfmt |
| `deadnix` | static | No unused let bindings or module args |
| `english-comments` | static | Comments are ASCII English text (STE style), in nix and every `#`-comment file (`.gitignore`, `Justfile`, toml, yaml, sh, hooks/) |
| `statix` | static | No Nix anti-patterns |
| `sops-integrity` | static | Every value in secrets/secrets.yaml is SOPS-encrypted |
| `sops-keys` | static | Every `sops.secrets.<key>` reference exists in the yaml |
| `invariants` | eval | Key services and host facts hold (zram, pipewire, hostname, user, git, zsh) |
| `lib-tests` | eval | Unit tests for the helpers in lib/default.nix (lib.debug.runTests) |
| `system` | build | The full system toplevel builds (includes nested home-manager) |
| `home` | build | The standalone home activation package builds |

`format`, `deadnix`, and `english-comments` enumerate files with `fd`, which
reads `.gitignore`. `statix check .` also respects `.gitignore`.

## Deferred

- **NixOS VM boot test** — needs KVM (absent on this host) and test-only
  overrides for the sops keys and the hardware config. Add it as
  `checks.x86_64-linux.vm-boot` on a KVM host.
- **`gitleaks` secret scan** — add it when CI exists.
