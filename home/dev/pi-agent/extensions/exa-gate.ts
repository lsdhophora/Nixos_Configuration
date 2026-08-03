/**
 * Exa Gate — hard constraint for the exa tools.
 *
 * Rule: exa tools are disabled unless the user message starts
 * with the {exa} or {search} prefix. Authorization is one-shot
 * per prompt and expires at agent_end.
 *
 * This makes skill compliance structural: without the prefix,
 * the exa tools never appear in the tool list and calls are blocked.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const EXA_TOOLS = ["exa_search", "exa_get_contents", "exa_find_similar"];
const PREFIX_RE = /^\{exa\}|^\{search\}/;

export default function (pi: ExtensionAPI) {
  let exaAuthorized = false;

  // Keep the active tool list in sync with the authorization state.
  function syncTools() {
    const all = pi.getAllTools();
    const names = all
      .filter((t) => exaAuthorized || !EXA_TOOLS.includes(t.name))
      .map((t) => t.name);
    pi.setActiveTools(names);
  }

  // Default: disabled on every session start.
  pi.on("session_start", async () => {
    exaAuthorized = false;
    syncTools();
  });

  // Grant one-shot authorization when the prompt carries the prefix.
  pi.on("before_agent_start", async (event) => {
    const text = event.prompt?.trim() ?? "";
    exaAuthorized = PREFIX_RE.test(text);
    syncTools();
  });

  // Expire the authorization when the prompt finishes.
  pi.on("agent_end", async () => {
    exaAuthorized = false;
    syncTools();
  });

  // Last line of defense: block exa calls without authorization.
  pi.on("tool_call", async (event) => {
    if (EXA_TOOLS.includes(event.toolName) && !exaAuthorized) {
      return {
        block: true,
        reason: "Exa tools need the {exa} or {search} prefix at the start of the message.",
      };
    }
  });
}
