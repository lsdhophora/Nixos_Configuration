# LibreWolf

LibreWolf replaces Firefox on this machine. The module
`home/programs/librewolf.nix` holds the profile settings.

## Profile

The profile lives in `~/.librewolf/default`. Home Manager persists the
whole `~/.librewolf` directory through the bind mount from `/persist`
(see `home/persistence.nix`). History, cookies, logins, and extension
data survive reboots.

## Tabs and windows

Closing the last tab keeps the window open
(`browser.tabs.closeWindowWithLastTab = false`), so LibreWolf does not
quit when every tab is closed. The browser still exits when the window
closes.

## Downloads and PDF handling

LibreWolf saves downloads to the Downloads folder
(`browser.download.useDownloadDir = true`).

The `application/pdf` handler uses action 0 (save to disk). A PDF link
always downloads to the Downloads folder and does not open in the
browser. The built-in viewer (`pdfjs`) stays enabled; use the eye icon in
the download panel to preview a saved PDF.

The handler lives in `handlers.json` in the profile. That file is runtime
state: LibreWolf rewrites it in place. A single-file bind mount does not
work here (a `rename(2)` rewrite on a bind-mounted file fails with
EBUSY), so `home.file` cannot manage it. Edit the setting in the UI
(Settings -> General -> Applications -> Portable Document Format (PDF)
-> Save File), or let the activation script below re-apply it.

`home.activation.librewolfPdfSave` runs at every Home Manager activation.
It runs `assets/firefox/patch-pdf-handler.ts` with Deno. The script
merges action 0 into `handlers.json` and keeps every other entry
(schemes, images, and so on). The script is idempotent, so a LibreWolf
change or a skipped activation does not corrupt the merge.

Restart LibreWolf after a rebuild if it ran during the activation. The
browser holds the old handler in memory and can write it back at
shutdown. The next activation restores the setting.
