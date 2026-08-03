---
name: root-session
description: Run commands as root through the root-session daemon. Load when the user or task needs root privileges.
---

# Root Session

Two tools for session-scoped root execution:

1. **root_activate** — Open the polkit password dialog (pkexec) to start the root daemon.
   Call this first. Authentication is session-scoped.

2. **root** — Run shell commands as root through the daemon.
   The daemon must be active (use root_activate first).

## Rules

- Call `root_activate` first to obtain root privileges.
- The polkit dialog opens once per pi session. Authenticate and the daemon stays alive.
- Use `root` for any command that needs root privileges.
- The daemon exits when the pi session ends. A new pi session needs a new activation.

## Usage

- `root_activate()` — start the daemon (no parameters)
- `root(command: "nixos-rebuild switch --flake ...")` — execute as root

## Status

- `/root-session` shows whether the daemon is up.
