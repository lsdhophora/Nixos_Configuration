# Desktop

Plasma 6 and the non-KDE desktop pieces.

## Plasma packages and settings

`modules/desktop/kde.nix` takes kdePackages from nixpkgs-unstable and patches
plasma-desktop for the UI tweaks. The user settings are declarative via
plasma-manager (`home/kde/plasma.nix`): change a setting in the module, not
in the UI.

Declarative Plasma config needs a full OS rebuild, even for a change under
`home/`:

```bash
run0 nixos-rebuild switch --flake .#flowerpot
```

A standalone `home-manager switch` does not apply it. The regenerated layout
appears at the next Plasma session start.

## Panel

The layout is a declarative script (`home/kde/plasma.nix`). The script can
lose the startup race against plasmashell, so a second script (priority 3)
restarts plasmashell and runs it again. `ensurePanel` compares the live
applet types against the declaration and rebuilds the panel when they
differ, not only when the panel is absent.

To restore the layout by hand:

```bash
rm ~/.local/share/plasma-manager/last_run_desktop_script_panels
~/.local/share/plasma-manager/scripts/2_desktop_script_panels.sh
```

## Login screen

`modules/persistence.nix` persists `/var/lib/plasmalogin/.config`, because
the Login Screen KCM writes the user's Plasma settings there.

## Emacs

The elisp files are `mkOutOfStoreSymlink` targets: edit them in the repo, no
rebuild needed.

## LibreWolf

See `docs/librewolf.md`. The PDF handler is runtime state, so an activation
script re-applies "save to disk" on every switch.

## Prompt and fonts

Starship, two lines (`home/shell/starship.nix`). The icons come from the
WezTerm `Symbols Nerd Font Mono`, scaled to 1.2 in
`home/programs/wezterm.nix`; `allow_square_glyphs_to_overflow_width =
"Always"` keeps a square glyph wide while it is selected.
