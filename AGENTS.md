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

- Hardware config is auto-generated.
- Package attr path may differ from pname (e.g. `terminus_font`).
- Home Manager: git uses `settings`, not `config`.
- Herdr: from nixpkgs-unstable (`home/misc/cli.nix`), patched by
  `overlays/herdr.nix`; config in `home/misc/herdr.nix` with the update
  checks off. Automatic toasts and sounds are off, because a scheduled
  watchdog ends one agent turn per check; a finished task sends one
  explicit `herdr notification show` instead.
- Herdr agent states and skill: `home/dev/pi-agent/files.nix` generates
  the pi integration file with `herdr integration install pi` and links
  the skill from the herdr package, so both match the installed herdr.
- Overlay patches: file in `patches/<pkg>/`, overlay in
  `overlays/<pkg>.nix` (auto-discovered).
- Plasma 6: kdePackages from unstable nixpkgs; plasma-desktop patches for
  UI tweaks.
- dae: from nixpkgs-unstable (`modules/services/dae.nix`). The 1.0.0 in
  nixpkgs 26.05 lacks the `sub()`, `node()` and `subnode()` selectors of
  the DNS request routing, so the module uses the 2.0.0 selectors and
  resolves the subscription and node hosts through alidns.
- dae restart: the unit loads the rendered config through
  `LoadCredential`, and systemd does not watch that file for content. The
  module therefore sets two `restartTriggers`: the template's store file
  (a config-text change) and the secret's `sopsFileHash` (a subscription
  key change, which leaves the text alone). `sopsFileHash` hashes the
  whole sops file, so any key in it triggers the restart, and it is empty
  unless `sops.validateSopsFiles` stays true.
- Home persistence: persist `~/.config` as one directory, never file by
  file. A single-file bind mount breaks an application that rewrites the
  file with `rename(2)`: the write fails with EBUSY and is lost.
  `home-config-prune.service` deletes every other path below `.config` at
  boot; see `modules/desktop/home-config-prune.nix`.
- Plasma settings are declarative via plasma-manager
  (`home/kde/plasma.nix`); change them in the module, not in the UI.
- Plasma panel: the layout script can lose the startup race against
  plasmashell; a second script (priority 3) restarts plasmashell and runs
  it again.
- Plasma Login Manager: `modules/persistence.nix` persists
  `/var/lib/plasmalogin/.config`, because the Login Screen KCM writes the
  user's Plasma settings there.
- Emacs elisp files are `mkOutOfStoreSymlink` targets: edit them in the
  repo, no rebuild needed.
- LibreWolf PDF handler: `handlers.json` is runtime state; an activation
  script re-applies "save to disk" on every switch (see
  `docs/librewolf.md`).
- pi `~/.pi/agent/settings.json` is runtime state: persisted in
  `home/persistence.nix`, and `piSettings.enforced` is restored on every
  activation.
- pi notifications: `home/dev/pi-agent/extensions/notify-on-complete.ts`
  sends one desktop notification when the model reports that work is done
  (a goal marked complete, a closed scheduled task, or `notify_done`); a
  monitoring round never rings.
- Shell prompt: Starship, two lines (`home/shell/starship.nix`). The
  icons come from the WezTerm `Symbols Nerd Font Mono`, scaled to 1.2 in
  `home/programs/wezterm.nix`; `allow_square_glyphs_to_overflow_width =
  "Always"` keeps a square glyph wide while it is selected.
- asr: local audio and video to text, with sherpa-onnx and the FunASR
  SenseVoice model (`overlays/asr.nix`, `packages/asr/`, skill
  `home/dev/pi-agent/skills/asr/SKILL.md`). The engine is in the binary
  cache; the first run downloads the model files to
  `~/.local/share/asr/models`, which `home/persistence.nix` persists.
- Comment out imports in `hosts/flowerpot/default.nix` or
  `home/default.nix` to disable a feature.
