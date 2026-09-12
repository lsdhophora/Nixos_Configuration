#!/usr/bin/env -S deno run -q --no-check --no-config --allow-env --allow-read --allow-write

// Make LibreWolf always save application/pdf instead of opening it.
//
// Merges into the profile's handlers.json, flipping the application/pdf
// handler from "handle internally" (action 3, the built-in PDF viewer)
// to "save to disk" (action 0).  pdfjs stays enabled, so the built-in
// reader remains available for explicit previews (download panel eye
// icon, local files); only link-click auto-open is turned off.
//
// handlers.json is runtime state that LibreWolf rewrites in place, so
// this runs at every Home Manager activation to restore the setting
// (idempotent).  All other entries (schemes, mailto, images, ...) are
// preserved.
//
// Zero-dependency Deno script: the flake pins `deno` in home.packages,
// and the activation just runs `deno run` on this file from the store.

// nsIHandlerInfo actions: 0 = saveToDisk, 1 = useHelperApp,
// 3 = handleInternally (built-in viewer), 4 = useSystemDefault.
const ACTION_SAVE_DISK = 0;

type Handler = Record<string, unknown>;

const home = Deno.env.get("HOME");
if (!home) Deno.exit(1);

const dir = `${home}/.librewolf/default`;
const file = `${dir}/handlers.json`;

// Fresh profile (no .librewolf yet): nothing to patch; the script picks
// it up on the next activation once LibreWolf has created the directory.
try {
  await Deno.stat(dir);
} catch {
  Deno.exit(0);
}

let data: Record<string, unknown>;
try {
  data = JSON.parse(await Deno.readTextFile(file)) as Record<string, unknown>;
} catch {
  data = {};
}

const mimeTypes = (data.mimeTypes ??= {}) as Record<string, Handler>;
const pdf = (mimeTypes["application/pdf"] ??= {});
pdf.action = ACTION_SAVE_DISK;
pdf.extensions ??= ["pdf"];

// Same compact format Firefox writes (its own files are 644, so no
// permission fiddling needed either).
await Deno.writeTextFile(file, JSON.stringify(data));
console.log(`patch-pdf-handler: application/pdf -> saveToDisk in ${file}`);