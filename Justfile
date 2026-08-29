# Task runner for this NixOS + Home Manager configuration.
# Run `just` to list all recipes. Requires `just` and `nix`.

# Show all available recipes
default:
    @just --list

# Fast static + eval checks (format, deadnix, statix, sops, invariants, lib-tests), ~1 min
check-fast:
    nix build .#checks.x86_64-linux.format .#checks.x86_64-linux.deadnix .#checks.x86_64-linux.english-comments .#checks.x86_64-linux.statix .#checks.x86_64-linux.sops-integrity .#checks.x86_64-linux.sops-keys .#checks.x86_64-linux.invariants .#checks.x86_64-linux.lib-tests -L

# Full checks: static + system toplevel + home activation (slow)
check:
    nix flake check -L --show-trace

# Evaluate the flake schema without building anything (very fast)
check-no-build:
    nix flake check --no-build

# Format all Nix files with nixfmt (nix fmt itself fails: it passes no file args, nixfmt reads stdin)
fmt:
    nix develop --command bash -c 'nixfmt $$(find . -name "*.nix" -not -path "./result/*" -not -path "./nixpkgs/*" -not -path "./pi/*" -not -path "./opencode/*")'

# Verify the system builds (dry-build, no switch)
build:
    nixos-rebuild dry-build --flake .#flowerpot

# Rebuild and switch the system (needs root)
switch:
    run0 nixos-rebuild switch --flake .#flowerpot

# Rebuild home only (fast, no system closure)
home-switch:
    home-manager switch --flake .#FeiHsueh
