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

## Home Manager

Both switch paths share `home/default.nix`; `homeConfigurations` is wired in
`flake-modules/nixos.nix`. Home Manager git uses `settings`, not `config`.

## Enable or disable a module

The import lists are a menu. Comment out an entry in
`hosts/flowerpot/default.nix` for a system module or in `home/default.nix`
for a home module to disable that feature.
