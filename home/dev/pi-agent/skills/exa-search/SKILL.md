---
name: exa-search
description: Rules and usage for the Exa web search tools provided by the exa-pi extension. Load when the user requests web research or current sources, or when a message starts with the {search} or {exa} prefix.
---

# Exa Web Search

## Authorization Rule

The `{search}` or `{exa}` prefix authorizes Exa for one round only.

- The prefix must appear at the start of the user message.
- A new prefix is required for each round that needs Exa.
- Do not carry authorization across rounds.
- If a message does not start with `{search}` or `{exa}`, do not use Exa, even if the topic is related.
- When the user requests a web search, use Exa instead of curl.

## Mandatory Verification Before Use

Before you call any exa tool, you MUST verify the current user message with the bash tool. Do not rely on reading the message alone.

1. Take the exact text of the latest user message.
2. Run this command in bash, with `MSG` set to that text:

```bash
MSG='<paste the latest user message here>'
if printf '%s' "$MSG" | grep -qE '^\{search\}|^\{exa\}'; then
  echo "EXA-AUTHORIZED"
else
  echo "EXA-DENIED"
fi
```

3. If the output is `EXA-DENIED`, do not use any exa tool in this round.
4. If the output is `EXA-AUTHORIZED`, you may use the exa tools in this round only.
5. Authorization expires after this round. Run the check again for the next round.

## Tools

The exa-pi extension provides three tools.

### exa_search

Search the live web.

Parameters:
- `query` — search query.
- `numResults` — result count from 1 to 100, default 5.
- `type` — auto, neural, fast, deep-lite, deep, deep-reasoning, or instant.
- `category` — optional category filter.
- `includeDomains` / `excludeDomains` — domain filters.
- `startPublishedDate` / `endPublishedDate` — date filters (YYYY-MM-DD).
- `text`, `highlights`, `summary` — include additional page content.

Prefer `exa_search` for general search.

### exa_get_contents

Fetch cleaned content from known URLs.

Parameters:
- `urls` — URL list.
- `text`, `highlights`, `summary` — include page content formats.

Use `exa_get_contents` when you already have URLs.

### exa_find_similar

Find pages similar to a URL.

Parameters:
- `url` — source URL.
- `numResults` — result count from 1 to 100, default 5.
- `includeDomains` / `excludeDomains` — domain filters.
- `excludeSourceDomain` — exclude the source URL's domain.
- `startPublishedDate` / `endPublishedDate` — date filters (YYYY-MM-DD).
- `text`, `highlights`, `summary` — include additional page content.

## exa-pi Setup

The exa-pi extension adds the Exa tools to pi.

Install:

```bash
pi install https://github.com/Fletcher-Alderton/exa-pi
```

Restart pi or run `/reload` after install.

API key:

1. Create a key at <https://dashboard.exa.ai/api-keys>.
2. Add this entry to `~/.pi/agent/auth.json`:

```json
{
  "exa": {
    "type": "api_key",
    "key": "YOUR_KEY"
  }
}
```

The extension reads the `exa` credential from pi auth storage. The type must be `api_key`. Do not commit API keys.

## Troubleshooting

- Missing API key: add the `exa` entry to `~/.pi/agent/auth.json`, then reload pi.
- Invalid auth entry: type must be `api_key`, key must be a non-empty string.
- Invalid key or API errors: verify the key in the Exa dashboard, check quota and billing.
- Proxy: export `HTTPS_PROXY` or `ALL_PROXY` before starting pi.
