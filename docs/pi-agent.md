# pi agent

The pi coding agent, `home/dev/pi-agent/`. The `home-manager` CLI and the
package pinning are in `home/misc/cli.nix`.

`~/.pi/agent/settings.json` is runtime state. `home/persistence.nix`
persists it, and `home/dev/pi-agent/files.nix` re-applies the keys in
`piSettings.enforced` on every activation.

`home/dev/pi-agent/extensions/notify-on-complete.ts` sends one desktop
notification when the model reports that work is done: a goal marked
complete, a closed scheduled task, or a `notify_done` call. A monitoring
round never rings.

`home/dev/pi-agent/services.nix` restores the `hv-farm` tmux session at
login. It is disabled, because the cron task it serves is disabled.
