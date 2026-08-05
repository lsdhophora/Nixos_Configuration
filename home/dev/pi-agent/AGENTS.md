# Global Instructions

## Language and Writing Standard

1. **Use Simplified Technical English (STE)** — Write all technical content according to the ASD-STE100 Simplified Technical English specification:
   - Use only approved words with a single meaning (one word, one meaning).
   - Keep sentences short: max 20 words for procedural text, max 25 words for descriptive text.
   - Use the active voice by default. Use passive voice only when permitted by the STE rules.
   - Do not use contractions (e.g., "don't" → "do not").
   - Do not use -ing forms as nouns (gerunds). Use the base form instead.
   - Do not use long noun clusters (max 3 nouns in a row).
   - Write instructions in the imperative mood.
   - Use articles ("a", "an", "the") correctly.
   - Use only the approved verb tenses: simple present, simple past, present perfect.

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

## Documentation Format

1. Write explanatory documents (reports, summaries, check packages, release notes) in org-mode format by default.
2. Use the `*.org` file extension.
3. Use markdown only when the target tool requires it (for example, GitHub README).

## Pi Configuration Management

Do not modify the `~/.pi/agent/` directory directly. Modify `~/.config/nixos/` instead.
