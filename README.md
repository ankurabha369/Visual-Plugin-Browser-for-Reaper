<img width="399" height="266" alt="image" src="https://github.com/user-attachments/assets/736a79a1-24d4-4426-bed2-98b26744ed18" />

<br>
<img width="1371" height="984" alt="Screenshot 2026-08-22 015458" src="https://github.com/user-attachments/assets/77722d13-f8cf-49a8-bff3-f8350c00ccf9" />

# Visual-Plugin-Browser-for-Reaper

My Visual Plugin Browser — README

Overview

This script provides a visual browser for installed REAPER plugin GUIs and a direct automated thumbnail generator. It uses ReaImGui and JS_ReaScriptAPI to display thumbnails and (when possible) capture plugin windows to PNG images.

Files

- Script: `MyVisualPluginBrowser.lua` (this workspace)
- Thumbnails directory: %APPDATA%/REAPER/Data/track_icons/FX_Thumbnails
- Log file: `scan_log.txt` (in thumbnails folder)
- Progress file: `scan_progress.txt` (in thumbnails folder)
- Skip list: `skip_list.txt` (in thumbnails folder)

Requirements

- REAPER with ReaImGui and JS_ReaScriptAPI installed.
- X‑Raym screenshot script (or alternative) available. Ensure the Command ID at the top of `MyVisualPluginBrowser.lua` matches your installed screenshot action.

Quick Start

1. Put `MyVisualPluginBrowser.lua` in your Reaper Scripts folder and run it via the Action list.
2. The window shows installed plugins in a grid and thumbnails when available.
3. Buttons at the top:
   - `REFRESH`: re-enumerate installed plugins.
   - `RELOAD IMAGES`: clear the image cache so thumbnails are reloaded from disk.
   - `Remove orphan thumbnails`: deletes PNGs in the thumbnails folder that don't match any installed plugin.
   - `Generate Previews (One-shot)`: generate missing thumbnails only, resume from progress.
   - `SCAN & GENERATE`: full automated scan that walks all plugins and attempts to capture each UI.
   - During a scan the top shows progress and a Stop button.

Per-plugin controls (shown under each thumbnail or "NO PREVIEW")

- If a thumbnail exists:
  - `Replace`: choose an image file to overwrite the thumbnail for that plugin.
  - `Clear`: delete the thumbnail file (the scanner can re-generate later).
- If no thumbnail exists:
  - `Load Image`: choose an image file to copy into the thumbnail path (useful to paste your own screenshot).
  - `Skip` / `Skipped`: mark plugin as skipped so automated scanning moves past it. Click "Skipped" to unmark.
  - Clicking the thumbnail (or the NO PREVIEW box) will add the plugin to the selected track in REAPER.

Skip / Manual workflow

- Use `Skip` on problematic plugins (bridged or slow-to-render). They are stored in `skip_list.txt` so scans continue.
- To provide your own thumbnail: capture your screenshot externally, then use `Load Image` (for missing) or `Replace` (for existing) to copy your PNG into the thumbnails folder.

Troubleshooting

- Missing or blank thumbnails:
  - Increase the wait frames in the script: set `OPEN_WAIT_FRAMES` (near top) to 40–60 for slow or bridged plugins.
  - Some bridged plugins open in separate processes; those may not be capturable by the direct capture routine. Use `Skip` and supply a manual thumbnail.
- "Could not find the X‑Raym screenshot script": install the screenshot script or update `SCREENSHOT_COMMAND_ID` at the top of the Lua file to the correct action ID.
- File dialog errors: If the OS file dialog fails, ensure REAPER's JS_ReaScriptAPI provides `GetUserFileNameForRead`. The script uses a safe three-argument call so typical installations should work.
- Logs: see `scan_log.txt` in the thumbnails folder for capture errors and retry info.

Recommendations

- Run `Generate Previews (One-shot)` first — it only creates missing thumbnails and resumes where it left off.
- Use `Remove orphan thumbnails` occasionally to tidy leftover PNGs.
- If a specific plugin fails repeatedly, mark it with `Skip` then capture its image manually and `Replace` the thumbnail.

If you want changes

- I can add an "Open thumbnails folder" button, confirmation dialogs for destructive actions, or drag-and-drop thumbnail replacement.
- Tell me which and I will add it.

