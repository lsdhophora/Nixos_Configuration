# LibreWolf

LibreWolf replaces Firefox on this machine. The module
`home/programs/librewolf.nix` holds the profile settings.

## Profile

The profile lives in `~/.librewolf/default`. Home Manager persists
the whole `~/.librewolf` directory through the bind mount from
`/persist` (see `home/persistence.nix`). History, cookies, logins,
and extension data survive reboots.

## Downloads and PDF handling

LibreWolf saves downloads to the Downloads folder
(`browser.download.useDownloadDir = true`).

The `application/pdf` handler uses action 0 (save to disk). A PDF
link always downloads to the Downloads folder. It does not open in
the browser by itself. The built-in viewer (`pdfjs`) stays enabled.
Use the eye icon in the download panel to preview a saved PDF.

The handler setting lives in `handlers.json` inside the profile.
This file is runtime state: LibreWolf rewrites it in place.
Single-file bind mounts do not work here (a `rename(2)` rewrite on
a bind-mounted file fails with EBUSY), so `home.file` cannot manage
it. Edit the setting in the UI instead
(Settings → General → Applications → Portable Document Format
(PDF) → Save File), or let the activation script below re-apply it.

`home.activation.librewolfPdfSave` runs at every Home Manager
activation. It executes `assets/firefox/patch-pdf-handler.ts` with
Deno. The script merges action 0 into `handlers.json` and keeps all
other entries (schemes, images, and so on). The script is
idempotent, so LibreWolf changes or a skipped activation do not
corrupt the merge.

Restart LibreWolf after a rebuild if it was running during the
activation. The browser holds the old handler in memory and may
write it back at shutdown. The next activation restores the
setting.