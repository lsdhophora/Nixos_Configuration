# Global Instructions

## Language and Writing Standard

1. **Code style** — Follow the rules in `/home/FeiHsueh/.config/nixos/docs/code-style.md`. Use the `equational-reasoning` and `hoare-logic` skills when their trigger conditions match.

2. **Reply in the user's language** — If the user writes in a language other than English, first write the response in English following STE rules inside the thinking block (do not output it directly), then translate and output only the final response in the user's language. The English version must stay in the thinking block only.

## Exa Web Search Rules

The exa-gate extension controls the exa tools. The tools are disabled by default. The user must authorize each round with a prefix.

1. **Prefix rule** — The user message must start with `{exa}` or `{search}` to authorize one round. A new prefix is required for each round. Do not carry authorization across rounds.
2. **Verify before use** — Before you call any exa tool, verify the current user message with the bash tool:
   ```bash
   MSG='<paste the latest user message here>'
   if printf '%s' "$MSG" | grep -qE '^\{exa\}|^\{search\}'; then
     echo "EXA-AUTHORIZED"
   else
     echo "EXA-DENIED"
   fi
   ```
   - If the output is `EXA-AUTHORIZED`, you may use the exa tools in this round only.
   - If the output is `EXA-DENIED`, do not use any exa tool in this round.
3. **Do not bypass the gate** — The exa-gate extension blocks exa tool calls without a prefix. Do not attempt workarounds (for example, calling the Exa API directly with bash or curl).
4. **One-shot scope** — Authorization expires at the end of the round. The next round needs a new prefix.
5. **The {search} or {exa} prefix authorizes Exa for one round only.**

## Pi Configuration Management

Do not modify the `~/.pi/agent/` directory directly. Modify `~/.config/nixos/` instead.
