# Testing

This file records the testing setup and decisions for this repository.

## Current checks

`nix flake check` runs all checks. `just check-fast` runs only the fast
static checks. See `flake-modules/checks.nix` for the definitions.

| Check | Type | What it verifies |
|---|---|---|
| `format` | static | All .nix files are formatted with nixfmt |
| `deadnix` | static | No unused let bindings or module args |
| `english-comments` | static | Comments are ASCII English text (STE style) |
| `statix` | static | No Nix anti-patterns |
| `sops-integrity` | static | Every value in secrets/secrets.yaml is SOPS-encrypted |
| `sops-keys` | static | Every `sops.secrets.<key>` reference exists in the yaml |
| `invariants` | eval | Key services and host facts hold (zram, pipewire, hostname, user, git, zsh) |
| `lib-tests` | eval | Unit tests for the helpers in lib/default.nix (lib.debug.runTests) |
| `system` | build | The full system toplevel builds (includes nested home-manager) |
| `home` | build | The standalone home activation package builds |

## Deferred: NixOS VM tests

A full-VM boot smoke test (`pkgs.testers.runNixOSTest`) was considered and
deferred. Reasons:

- The test boots QEMU and needs KVM. This laptop has no usable KVM for the
  test workload, and the build+run cost is high.
- The real host config depends on sops (age key decryption) and
  hardware-configuration.nix (real partitions). Both cannot run in a VM
  without test-only overrides, so a VM test would only cover a subset of
  modules.

How to add it later (on a host with KVM):

1. Create `tests/vm-boot.nix` with `pkgs.testers.runNixOSTest`:
   - node imports only `modules/boot.nix`, `modules/i18n.nix`,
     `modules/networking.nix` (never user.nix, sops.nix, persistence,
     hardware-configuration.nix)
   - disable `systemd.services.nm-wifi-tune` (no "56-606" profile in a VM)
   - set `virtualisation.cores`/`memorySize`
   - `testScript`: `machine.wait_for_unit("multi-user.target")`
2. Expose it as `checks.x86_64-linux.vm-boot` or keep it out of
   `nix flake check` if it must stay optional.
3. Debug with `driverInteractive` (`nix build
   .#checks.x86_64-linux.vm-boot.driverInteractive` then run
   `./result/bin/nixos-test-driver`).
4. `machine.succeed("uptime")` is a trivial smoke assertion; add service
   checks as the config grows.

## Deferred: secret scanning in CI

`gitleaks` scans git history for leaked credentials. This repo stores all
secrets in one SOPS-encrypted file, and `sops-integrity` covers committed
plaintext. Add gitleaks when CI exists (Rabbbba/signalridge-style
workflows run it per push).
