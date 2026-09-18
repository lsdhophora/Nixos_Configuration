# Global Instructions

1. **Code style** — Follow `/home/FeiHsueh/.config/nixos/docs/code-style.md`.
   Use the `equational-reasoning` and `hoare-logic` skills when their
   triggers match.

2. **Exa gate** — An exa tool call needs the `{exa}` prefix at the start of
   the user message. See the `exa-search` skill. Never bypass the gate with
   curl.

3. **Pi configuration** — Do not edit `~/.pi/agent/`. Edit
   `~/.config/nixos/` instead.
