# Codebase Review Report — NixOS Configuration (flowerpot)

- Date: 2026-08-11
- Author: pi (code review)
- Status: all review items are applied. Commits: `5f137ce`, `d501762`, `636d676`.

## Summary

This report uses three standards:

1. Programming language (PL) theory.
2. Community best practices (flake-parts official docs, nix-starter-configs, nix.dev, NixOS Discourse).
3. nixpkgs lib abstractions.

The codebase has high quality. The structure is close to the recommended community layout (nix-starter-configs standard version). Most modules use data-driven style (tmux.nix bindKeys, kde.nix kdePatches, firefox.nix mozAddon). The issues below are sorted by priority.

## P0 — Fix Now

### 1. Dead code: tautology in root-session/daemon.js

File: `home/dev/pi-agent/extensions/root-session/daemon.js`

```js
proc.on("error", (err) => {
  const msg = `root-session error: ${err.message}\n`;
  try { conn.write(hasOutput ? msg : msg); } catch { /* connection gone */ }
  if (!hasOutput) conn.end();
});
```

The expression `hasOutput ? msg : msg` has two identical branches. This is a tautology. It is dead code.

Fix: `conn.write(msg);`

### 2. Withdrawn: stateVersion suggestion (old P0-2)

File: `home/default.nix`, `modules/user.nix`

The original report suggested to extract the two stateVersion values into a shared constant. This suggestion was wrong. It is withdrawn.

Reason (based on official docs and community discussion):

- `system.stateVersion` records the first NixOS version installed on this machine. The official option doc says: "Most users should never change this value after the initial install, for any reason".
- The NixOS wiki FAQ (When do I update stateVersion) warns: "system.stateVersion should never be updated". The result of a change can range from no effect to irreversible data loss (original text: "changing the number can lead to irreversible data loss").
- `home.stateVersion` has the same meaning for home-manager. It records the version when the home config was first created (home-manager issue #5794).
- The two values track two separate upgrade histories. They can differ legally (for example system 25.05, home 24.11). A shared constant would bind them together and introduce an error.

Conclusion: the two literals are independent facts that happen to match. They are not duplicated code. Keep them as they are. If needed, add one comment to each location to explain the purpose and the no-change rule.

### 3. Hardcoded architecture and flake input detour: sops package in user.nix

File: `modules/user.nix`

```nix
inputs.sops-nix.packages.x86_64-linux.default
```

Problems:

- `x86_64-linux` is a hardcoded architecture string. The flake fixes the system to x86_64-linux, but a hardcoded string is a code smell.
- `pkgs.sops` exists in nixpkgs (verified). The detour through the sops-nix input is not necessary.

Fix: `pkgs.sops`. Keep sops-nix as a NixOS module, but take the package from nixpkgs directly.

### 4. DRY violation: hardcoded palette values in mpv.nix

File: `home/programs/mpv.nix`

The file already imports the breezeDark palette. The osd colors are still literals:

```nix
osd-color = "#FCFCFC";         # should be palette.fg
osd-border-color = "#202326";  # should be palette.bg
osd-back-color = "#202326";    # should be palette.bg
```

Fix: reference the palette variables in the config (the palette is defined in the scriptOpts let block).

### 5. Imperative heredoc instead of declarative wrapper: localsend in gui.nix

File: `home/misc/gui.nix`

```nix
postBuild = ''
        rm $out/bin/localsend_app
        cat > $out/bin/localsend_app <<'SCRIPT'
  #!/bin/sh
  export GTK_THEME=Breeze:dark
  export GTK_CSD=0
  exec ${pkgs.localsend}/bin/localsend_app "$@"
  SCRIPT
        chmod +x $out/bin/localsend_app
'';
```

Problems:

- The heredoc body has 2-space indentation. The Nix indented string has 8-space common indentation. The Nix common-indent removal makes the result depend on the least-indented line. This is a known footgun. It can fail silently.
- The hand-written shell script is imperative style. The same file uses makeWrapper for kdenlive. Keep the style consistent.

Fix: use wrapProgram declaratively.

```nix
postBuild = ''
  wrapProgram $out/bin/localsend_app \
    --set GTK_THEME "Breeze:dark" \
    --set GTK_CSD 0
'';
```

### 6. Type safety and consistency: no-cost-footer.ts

File: `home/dev/pi-agent/extensions/no-cost-footer.ts`

- `enable(ctx: any)` erases the type with `any`. The other extensions use concrete types. This is a type-safety gap.
- The file uses tabs. The other extensions use 2 spaces. The style is inconsistent.
- The comments are Chinese. The other extensions use English. AGENTS.md requires STE English for technical content.
- `const autoEnabled = true;` is an inferred constant. If the pi default changes, this value becomes wrong. If the API provides a value, read it. Otherwise inline `true` with a comment that states the source.

### 7. Regex instead of predicate: overlays/default.nix

File: `overlays/default.nix`

```nix
builtins.filter (name: name != "default.nix" && builtins.match ".*\\.nix" name != null)
```

`builtins.match` is a regex match. Its semantics are too strong. The intent is only a suffix check. The nixpkgs convention is `lib.hasSuffix` (nix.dev best practices prefer lib over builtins; lib can evolve).

Fix:

```nix
builtins.filter (name: name != "default.nix" && lib.hasSuffix ".nix" name)
```

## P1 — Structural Improvements

### 8. Dead parameter: mkPkg in overlays/firefox.nix

File: `overlays/firefox.nix`

```nix
mkPkg = extra: final.runCommand ... '' ${mkBase} ${extra} ${patch-omni-ja} '';
```

`mkPkg` has only one call: `mkPkg ""`. The `extra` parameter is always an empty string. It is a dead parameter. The abstraction adds no extension point. It only adds indirection.

Fix: remove the `extra` parameter. Inline the build script.

### 9. Empty forwarding layer: flake-modules/default.nix

File: `flake-modules/default.nix`

```nix
{ ... }: {
  imports = [ ./nixos.nix ];
}
```

This is an empty forward to a single child file. flake-parts allows imports directly in the flake attrset. This layer adds no information. Merge it, or keep it as a future extension point (when the modules grow). Low priority. You can keep it.

### 10. Three overlays can merge: kde.nix

File: `modules/desktop/kde.nix`

`nixpkgs.overlays` has 3 entries:

1. kdePackages = unstablePkgs.kdePackages
2. kdePackages = prev.kdePackages // patched
3. dolphin special handling

Note: nixos-26.05 applies `nixpkgs.overlays` via `pkgs.appendOverlays` (see nixpkgs/nixos/modules/misc/nixpkgs.nix:107). The 3 entries are in one module. They trigger one appendOverlays call. There is no repeated nixpkgs import cost. The merge improves readability: entries 1 and 2 operate on the same attribute (kdePackages) in sequence. One overlay function is clearer.

### 11. flake lacks the perSystem convention

File: `flake-modules/nixos.nix`

flake-parts best practice: most build and test work happens in perSystem. This flake has only nixosConfigurations. It lacks:

- `formatter` (nixfmt formats the whole repository)
- `devShells` (development environment with nixd, nixfmt)
- `checks` (for example `nix flake check`)

Suggestion: add one flake-module:

```nix
{ ... }: {
  perSystem = { pkgs, ... }: {
    formatter = pkgs.nixfmt;
    devShells.default = pkgs.mkShell { packages = [ pkgs.nixd pkgs.nixfmt ]; };
  };
}
```

### 12. lib abstraction opportunities

File: `lib/default.nix`

The existing lib (applyPatches, breezeDark) is a good abstraction. Its use is consistent. Possible extensions:

- `system = "x86_64-linux"` constant, to remove the hardcoded strings in flake-modules/nixos.nix and user.nix (stateVersion excluded; see P0-2 withdrawal)
- shared colors for terminals and editors (kitty, vscodium, firefox each write their own colors). Note: kitty uses a different palette from Breeze Dark (Ubuntu-based). The lib comment says "The desktop keeps one theme", but kitty is the exception. If this is intentional, update the comment. If you want to unify, generate it from the palette.

## P2 — Robustness and Future Direction

### 13. Hardcoded battery path in tmux

File: `home/programs/tmux.nix`

The status-right reads `/sys/class/power_supply/BAT0/capacity`. The battery name is hardcoded as BAT0. If the hardware renames the battery (BAT1, BAT2), the status bar silently shows nothing. Use a glob match or shell iteration. Low risk. This machine has BAT0.

### 14. Hash suffix in housekeeping.nix

File: `home/misc/housekeeping.nix`

`userapp-transmission-gtk-33DDK3.desktop` — the desktop environment generates the suffix. It can change with versions. The name is fragile, but no better way exists. Keep it and add a comment.

### 15. vscodium activation script swallows errors

File: `home/programs/vscodium.nix`

`codium --list-extensions > /dev/null 2>&1 || true` — the command runs on every rebuild. The `|| true` swallows failures. Imperative activation inside a declarative config is a known trade-off. Acceptable. Add a comment that explains the need (extensions.json rebuild).

### 16. Future direction: import-tree / dendritic pattern

Reference: <https://iampavel.dev/blog/nixos-module-organization>

Advanced community pattern: each module file registers itself (flake.modules.nixos.<name>), the host imports explicitly. You do not change the import list when you add a module. Host configs are diffable. Use case: 40+ modules, multiple hosts. This repository has 1 machine and about 30 files. The existing import menu (hosts/flowerpot/default.nix) is clear enough. Use this pattern if the machine count grows. Do not do it now.

### 17. Module options (optional)

Reference: <https://flake.parts/best-practices-for-module-writing>

flake-parts official advice: reusable modules declare options; the config assigns values directly. This repository's modules are pure config (import activates them). This matches the nix-starter-configs simple style. It is enough for one machine. Migrate to options style if you want to toggle services between hosts.

## Community Comparison Table

| Practice (source) | Repository status |
|---|---|
| Do not traverse inputs (flake.parts) | Followed; inherit inputs only in nixos.nix |
| Do not assume inputs exist (flake.parts) | Followed |
| Use perSystem (flake.parts) | Missing formatter/devShell (P1-11) |
| Organize modules by function (nix-starter-configs standard) | Followed |
| Data-driven config generation (tmux bindKeys pattern) | In use; promote it |
| Prefer lib over builtins (nix.dev) | Mostly followed; overlays/default.nix exception (P0-7) |
| lib.mkDefault for reusable modules (flake.parts) | pipewire.nix uses mkDefault in pure config; simplify to direct assignment |
| Single source of truth (PL: DRY) | mpv colors, user.nix violate; stateVersion is an independent fact (P0-2 withdrawal) |

## Fix List Summary

Recommended order:

1. daemon.js: dead ternary (P0-1)
2. user.nix: pkgs.sops (P0-3)
3. mpv.nix: osd colors reference palette (P0-4)
4. gui.nix: localsend uses wrapProgram (P0-5)
5. no-cost-footer.ts: types/indentation/comments (P0-6)
6. overlays/default.nix: lib.hasSuffix (P0-7)
7. firefox.nix overlay: remove dead parameter (P1-8)
8. kde.nix: merge the first two overlays (P1-10)
9. flake: add formatter and devShell (P1-11)

The stateVersion suggestion is withdrawn (old P0-2): the two values are independent facts. They cannot be shared.

Items 1, 2, 3, 6, 7 are pure safe fixes. They do not change behavior. Item 4 needs verification of the localsend binary name.
