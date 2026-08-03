import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.registerCommand("exa", {
    description: "Replace editor with {exa} prefix for one-shot Exa web search",
    handler: async (args, ctx) => {
      const trimmed = args?.trim();
      const text = trimmed ? `{exa} ${trimmed}` : "{exa} ";
      ctx.ui.setEditorText(text);
    },
  });

  pi.registerCommand("search", {
    description: "Replace editor with {search} prefix for one-shot Exa web search",
    handler: async (args, ctx) => {
      const trimmed = args?.trim();
      const text = trimmed ? `{search} ${trimmed}` : "{search} ";
      ctx.ui.setEditorText(text);
    },
  });
}
