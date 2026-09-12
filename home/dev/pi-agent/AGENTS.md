# Global Instructions

1. **Code style** — Follow `/home/FeiHsueh/.config/nixos/docs/code-style.md`. Use the `equational-reasoning` and `hoare-logic` skills when their trigger conditions match.

2. **Language** — Reply in the user's language. Write the English STE version in the thinking block only.

3. **Exa gate** — An exa tool call needs a `{exa}` or `{search}` prefix at the start of the current user message. Verify it first with `printf '%s' "$MSG" | grep -qE '^\{exa\}|^\{search\}'`. The prefix authorizes one round only. Never bypass the gate, for example with curl.

4. **Pi configuration** — Do not edit `~/.pi/agent/` directly. Edit `~/.config/nixos/` instead.
