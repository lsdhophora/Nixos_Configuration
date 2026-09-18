# System

## Filesystem and persistence

The root filesystem is a 4G tmpfs and `/home` is an 8G tmpfs
(`modules/persistence.nix`); `/nix` and `/persist` are bind mounts from
`/mnt/data`. Everything that must survive a reboot is listed under
`environment.persistence."/persist"` (system) or `home.persistence."/persist"`
(home). A path that is in neither list is absent after boot.

`~/.config` is persisted as one directory, never file by file. A directory
mount is necessary: KConfig saves a file with a temporary file and
`rename(2)`, and a rename onto a single-file bind mount fails with EBUSY, so
the write is lost. `home-config-prune.service`
(`modules/desktop/home-config-prune.nix`) then deletes every path below
`.config` that is not in its `keep` list. It runs once at boot, before the
Home Manager activation, and two guards keep a `nixos-rebuild switch` from
running it mid-session.

The persistent journal (`/var/log/journal`, on the data disk) is capped at
1G in `hosts/flowerpot/default.nix`. The default cap is 10% of the file
system, and dae alone writes about 0.5 MB an hour.

## Hardware

`hosts/flowerpot/hardware-configuration.nix` is auto-generated.

## Packages

A package attribute path may differ from its `pname` (for example
`terminus_font`). A package from nixpkgs-unstable comes in through
`repoLib.unstablePkgs`; the reason for the choice belongs in the module, and
in `docs/services.md` when the package backs a service.

Patch a package as a file under `patches/<pkg>/` plus an overlay in
`overlays/<pkg>.nix`. `overlays/default.nix` discovers the files in that
directory automatically.

## Builds

`modules/nix-config.nix` caps the build load at the 12 threads of the Ryzen
5 5500U. `max-jobs` (6) is the number of concurrent derivations and `cores`
(2) is the thread budget of each one, so the two multiply to 12. The setup
also lowers the nix-daemon CPU weight and disk IO class
(`hosts/flowerpot/default.nix`), so Plasma keeps the machine during a
rebuild.

## Home Manager

Both switch paths share `home/default.nix`; `homeConfigurations` is wired in
`flake-modules/nixos.nix`. Home Manager git uses `settings`, not `config`.

## Enable or disable a module

The import lists are a menu. Comment out an entry in
`hosts/flowerpot/default.nix` for a system module or in `home/default.nix`
for a home module to disable that feature.
