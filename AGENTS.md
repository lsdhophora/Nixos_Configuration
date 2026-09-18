# NixOS Laptop Configuration

Flake-based config for "flowerpot". Uses flake-parts, Home Manager, sops-nix, impermanence, plasma-manager, custom overlays, Plasma 6.

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

The `home-manager` CLI is installed via `home/misc/cli.nix`, pinned to the flake input revision (`inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system}.home-manager`), and never run manually with `nix run`.

## Workflow

1. Edit → `dry-build` pass
2. Rebuild and switch
3. Run `just check-fast` before the commit; fix every failure
4. Split the change into semantic commits. Keep each commit at the
   smallest state that still builds and passes the checks
5. `git add -A`, ask the user, then commit on the command line
   (`git commit`) with a GNU-format message
6. Push only if the rebuild, the checks, and the commit succeeded

Home-only changes (everything under `home/`) can skip the full `nixos-rebuild` for a quick check and use `home-manager switch --flake .#FeiHsueh` instead. Both paths share `home/default.nix`; `homeConfigurations` is wired in `flake-modules/nixos.nix`. The standalone switch is not durable: the NixOS `home-manager-FeiHsueh` activation re-links the home files from the NixOS generation on every boot, so run `nixos-rebuild switch` before the change has to survive a reboot.

Exception: declarative Plasma/KDE config (`home/kde/*.nix`, e.g. `plasma.nix` panels) must be followed by a full OS rebuild (`run0 nixos-rebuild switch --flake .#flowerpot`) to take effect; `home-manager switch` alone does not apply it. The regenerated panel layout is only applied at the next Plasma session start.

System changes (hosts, kernel, services, etc.) still require `nixos-rebuild switch`.

## Tests

See `docs/testing.md` for the check list and `flake-modules/checks.nix`
for the definitions.

## Code Style

Follow `docs/code-style.md`.

## Definition of Done

Before you commit: `just check-fast` passes, the change touches only the
intended files, `docs/code-style.md` holds, and AGENTS.md is current —
update it in the same commit when a command, convention, or directory
layout changes.

## Notes

- Hardware config is auto-generated
- Package attr path may differ from pname (e.g. `terminus_font`)
- Home Manager: git uses `settings` not `config`
- Herdr: package from nixpkgs-unstable (`home/misc/cli.nix`), patched by `overlays/herdr.nix`. Config in `home/misc/herdr.nix` with the update checks off. Automatic toasts and sounds are off (`[ui.toast] delivery = "off"`, `[ui.sound] enabled = false`): herdr notifies on every finished agent turn, so a scheduled watchdog would pop "pi finished" on every check. A task that finishes sends one explicit `herdr notification show`; herdr still shows that with delivery off. No `/nix/store` program directory enters the pane PATH, so the Starship `nix_shell` heuristic stays quiet
- Herdr agent states and skill: `home/dev/pi-agent/files.nix` generates the pi integration file with `herdr integration install pi` and links the skill from the herdr package, so both match the installed herdr.
- Overlay patches: file in `patches/<pkg>/`, overlay in `overlays/<pkg>.nix` (auto-discovered)
- Plasma 6: kdePackages from unstable nixpkgs; plasma-desktop patches for UI tweaks
- dae: package from nixpkgs-unstable (`modules/services/dae.nix`). Version 1.0.0 in nixpkgs 26.05 lacks the `sub()`, `node()` and `subnode()` selectors of the DNS request routing. The module sends the host resolution of the subscription and of the nodes to alidns, because the router of 56-606 answers a stale address for `p4.cnt.linuxlh.xin`. The selectors need a parameter: `sub()` does not parse
- Home persistence: `~/.config` is persisted as one directory, never file by file. Never bind-mount a single file that an application rewrites with `rename(2)`: the write fails with EBUSY and is lost without an error. `home-config-prune.service` deletes every other path below `.config` at boot, before the Home Manager activation; see `modules/desktop/home-config-prune.nix`
- Plasma panel/Task Manager settings are declarative via plasma-manager (`home/kde/plasma.nix`); change them in the module, not in the UI
- Plasma panel: the plasma-manager layout script can lose the startup race against plasmashell and then no panel exists. A second startup script in `home/kde/plasma.nix` (priority 3) restarts plasmashell and runs the layout script again
- Plasma Login Manager: the greeter home is `/var/lib/plasmalogin` on tmpfs. `modules/persistence.nix` persists `/var/lib/plasmalogin/.config`, because the Login Screen KCM writes the Plasma settings of the user there. The sync result must survive a reboot.
- Emacs elisp files are `mkOutOfStoreSymlink` targets: edit them in the repo, no rebuild needed
- LibreWolf PDF handler: `handlers.json` is runtime state; an activation script re-applies "save to disk" on every switch (see `docs/librewolf.md`)
- pi `~/.pi/agent/settings.json` is runtime state: persisted in `home/persistence.nix`, and the keys in `piSettings.enforced` are restored on every activation.
- pi notifications: `home/dev/pi-agent/extensions/notify-on-complete.ts` sends one desktop notification (via the `notify-send` from `home.packages`) when the model announces that work is done — a pi-goal marked complete, the agent closing its own scheduled task (`schedule_prompt` `delete`/`clear`), or the `notify_done` tool. Every trigger is model-driven, so a scheduler monitoring round never rings.
- Shell prompt: Starship with a two-line format (`home/shell/starship.nix`). The icons come from the built-in `Symbols Nerd Font Mono` of WezTerm, scaled to 1.2 in `home/programs/wezterm.nix`. `allow_square_glyphs_to_overflow_width = "Always"` lets a square icon render wider than its cell even when the cell after it is not a plain space; the default `WhenFollowedBySpace` collapsed the icon to one cell while it was selected. The OS icon stays unstyled (`os.style = "none"`) and the `nix_shell` icon too (`[$symbol](none)` in its format, with the two spaces inside the symbol).
- asr: transcribes local audio and video files with sherpa-onnx and the FunASR SenseVoice model (`overlays/asr.nix`, `packages/asr/`, skill `home/dev/pi-agent/skills/asr/SKILL.md`). The engine is in the binary cache, so the package installs no pip tree and needs no local build. The first run downloads the model files to `~/.local/share/asr/models`, which `home/persistence.nix` persists. Other machines need the nix files only: the command fetches the models on the first run.
- Enable/disable features by commenting imports in `hosts/flowerpot/default.nix` or `home/default.nix`
