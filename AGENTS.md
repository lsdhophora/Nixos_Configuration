# NixOS Laptop Configuration

Flake-based config for "flowerpot". Uses flake-parts, Home Manager,
sops-nix, impermanence, plasma-manager, custom overlays, Plasma 6.

## Commands

```bash
just check-fast                                    # fast static checks (~1 min)
just check                                         # full checks (static + builds)
nixos-rebuild dry-build --flake .#flowerpot       # verify (system + home)
run0 nixos-rebuild switch --flake .#flowerpot   # rebuild & switch (system)
home-manager switch --flake .#FeiHsueh         # home-only rebuild (fast, no system closure)
nix flake update                                   # update inputs
git push                                           # push
```

The `home-manager` CLI is installed via `home/misc/cli.nix`, pinned to the
flake input revision, and never run manually with `nix run`.

## Workflow

1. Edit → `dry-build` pass
2. Rebuild and switch
3. Run `just check-fast` before the commit; fix every failure
4. Split the change into semantic commits. Keep each commit at the
   smallest state that still builds and passes the checks
5. `git add -A`, ask the user, then commit on the command line
   (`git commit`) with a GNU-format message
6. Push only if the rebuild, the checks, and the commit succeeded

A home-only change (everything under `home/`) may use `home-manager switch
--flake .#FeiHsueh` for a quick check. That path is not durable: the NixOS
`home-manager-FeiHsueh` activation re-links the home files from the NixOS
generation on every boot, so run `nixos-rebuild switch` before the change
has to survive a reboot. Declarative Plasma config needs the full rebuild
even for a `home/` change; see `docs/desktop.md`.

## Rules

- **Declarative first.** Change a module, not the live UI or a runtime
  file. Plasma and KDE settings live in `home/kde/*.nix`. A runtime file is
  fair game only when a module re-applies it on every activation.
- **Persist `~/.config` as one directory**, never file by file. A
  single-file bind mount breaks an application that rewrites the file with
  `rename(2)`. See `docs/system.md`.
- **Prefer nixpkgs 26.05.** Take a package from nixpkgs-unstable only when
  26.05 lacks a feature the config needs, and note the reason in the module.
- **Patch a package as** `patches/<pkg>/` plus `overlays/<pkg>.nix`.
  Overlays are auto-discovered from that directory.
- **Disable a feature** by commenting out its import in
  `hosts/flowerpot/default.nix` or `home/default.nix`.

## Tests

See `docs/testing.md` for the check list and `flake-modules/checks.nix` for
the definitions.

## Code Style

Follow `docs/code-style.md`.

## Definition of Done

Before you commit: `just check-fast` passes, the change touches only the
intended files, and `docs/code-style.md` holds. Keep the docs current in the
same commit: AGENTS.md when a command, convention, or directory layout
changes; the matching file under `docs/` when a service, desktop, or system
detail changes.

## Details

- Services (dae, herdr, asr, ZeroTier): `docs/services.md`
- Desktop (Plasma, panel, login, Emacs, LibreWolf, prompt): `docs/desktop.md`
- System (filesystem, persistence, hardware, packages): `docs/system.md`
- pi agent: `docs/pi-agent.md`
- Checks: `docs/testing.md`
- Workarounds to remove later: `docs/tech-debt.md`
