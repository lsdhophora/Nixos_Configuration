# Global Instructions

1. **Code style** — Follow `/home/FeiHsueh/.config/nixos/docs/code-style.md`. Use the `equational-reasoning` and `hoare-logic` skills when their trigger conditions match.

2. **Exa gate** — An exa tool call requires the `{exa}` prefix at the start of the user message. See the `exa-search` skill for the verification steps. Never bypass the gate, for example with curl.

3. **Pi configuration** — Do not edit `~/.pi/agent/` directly. Edit `~/.config/nixos/` instead.
