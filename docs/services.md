# Services

The system and background services. The modules live under
`modules/services/`.

## dae

Transparent proxy, `modules/services/dae.nix`. The package comes from
nixpkgs-unstable: the 1.0.0 in nixpkgs 26.05 lacks the `sub()`, `node()` and
`subnode()` selectors of the DNS request routing, so the config uses the
2.0.0 selectors and resolves the subscription and node hosts through alidns.

The health check probes a 204 endpoint every 15s, and the group picks the
node with `min_avg10`. The probe target matters: the default
`cp.cloudflare.com` is throttled or polluted through many subscription nodes
and then reads as NOT ALIVE, which drops good nodes.

The unit loads the rendered config through `LoadCredential`, and systemd
does not watch that file for content. The module therefore sets two restart
triggers:

| Trigger | Fires when |
|---|---|
| `sops.templates."dae-config".file` | the config text changes |
| `sops.secrets.dae-subscription.sopsFileHash` | the subscription key changes, which leaves the text alone |

`sopsFileHash` hashes the whole sops file, so any key in it restarts dae. It
is empty unless `sops.validateSopsFiles` stays true.

## Herdr

Terminal multiplexer for agent sessions, from nixpkgs-unstable
(`home/misc/cli.nix`) and patched by `overlays/herdr.nix`. The config is
`home/misc/herdr.nix`, with the update checks off.

Automatic toasts and sounds are off. Herdr raises a background notification
for every finished agent turn, and a scheduled watchdog ends one turn per
interval, so a non-off delivery pops "pi finished" on every check. A task
that finishes sends one explicit `herdr notification show` instead; herdr
still shows an explicit notification with `delivery = "off"`.

The same setting keeps a `/nix/store` program directory out of the pane
PATH, so the Starship `nix_shell` heuristic stays quiet.

`home/dev/pi-agent/files.nix` generates the pi integration file with
`herdr integration install pi` and links the skill from the herdr package,
so both match the installed herdr. The patches live in `patches/herdr/`; see
`docs/tech-debt.md` for their removal condition.

## asr

Local audio and video to text, with sherpa-onnx and the FunASR SenseVoice
model (`overlays/asr.nix`, `packages/asr/`, skill
`home/dev/pi-agent/skills/asr/SKILL.md`). The engine is in the binary cache.
The first run downloads the model files to `~/.local/share/asr/models`,
which `home/persistence.nix` persists.

## ZeroTier

`modules/services/zerotier.nix` holds the network. nixpkgs already opens UDP
9993. `modules/services/dae.nix` routes the control and hole-punching
traffic direct, on both the process name and the port.
