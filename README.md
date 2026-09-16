<img  src="https://github.com/user-attachments/assets/736a79a1-24d4-4426-bed2-98b26744ed18" alt="REAPER Logo">


<br>
<img width="1371" height="984" alt="Screenshot 2026-08-22 015458" src="https://github.com/user-attachments/assets/77722d13-f8cf-49a8-bff3-f8350c00ccf9" />

# Visual Plugin Browser for REAPER (v1.1.0)

[![REAPER](https://img.shields.io/badge/REAPER-v6%20%2F%20v7+-blue.svg)](https://www.reaper.fm/)
[![ReaImGui](https://img.shields.io/badge/GUI-ReaImGui-green.svg)](https://github.com/cfillion/reaimgui)
[![JS_ReaScriptAPI](https://img.shields.io/badge/API-JS__ReaScriptAPI-orange.svg)](https://github.com/juliansander/ReaScriptCSurf)
[![Version](https://img.shields.io/badge/version-1.1.0-brightgreen.svg)]()

A sleek visual FX browser and automated thumbnail generator for **Cockos REAPER**. Browse all your installed instruments and effects visually, search in real-time, and insert plugins onto your tracks with a single click.

---

## ✨ Features

- **Direct Native GUI Capture**: Automatically opens and takes clean PNG screenshots of your plugins using `JS_ReaScriptAPI` — **no external screenshot actions or X-Raym scripts required**.
- **1-Click Track Insertion**: Click any thumbnail card to immediately add that FX to the selected track.
- **Resumable Automated Scanner**: Scans your entire FX collection with one click. Safely pause and resume whenever you want.
- **Format Filtering**: Filter by **VST3, VST3i, VST2, JSFX, CLAP, AU, DX, DXi, LV2**, or show **All**.
- **Instant Search**: Type in real-time to find any plugin instantly.
- **Per-Plugin Customization**:
  - `Replace`: Overwrite an existing thumbnail with your own image file.
  - `Clear`: Delete an existing thumbnail to regenerate later.
  - `Load Image`: Add a custom screenshot or artwork for plugins without a preview.
  - `Skip / Skipped`: Exclude problematic or crash-prone plugins from automated scanning.
- **Orphan Thumbnail Cleanup**: One-click cleanup to delete leftover PNGs for plugins you have uninstalled.

---

## 📋 Requirements

Before running the script, ensure you have **ReaPack** installed along with these two packages:

1. **ReaImGui** (provides the GUI framework)
2. **JS_ReaScriptAPI** (handles native window capture and file dialogs)

### Installing Prerequisites via ReaPack:
1. In REAPER, go to: **Extensions → ReaPack → Browse packages...**
2. Search and install:
   - `ReaImGui`
   - `js_ReaScriptAPI`
3. Click **Apply** in the bottom-right and restart REAPER if prompted.

---

## 🚀 Quick Start

1. **Download the Script**:
   - Download [`MyVisualPluginBrowser_v1.1.0.lua`](file:///c:/Users/Ankur%20Rabha/Documents/Reaper%20Scripts/MyVisualPluginBrowser_v1.1.0.lua) and save it into your REAPER `Scripts` folder (or any folder of your choice).
2. **Load the Script in REAPER**:
   - Press `?` to open the **Action List** (or go to **Actions → Show action list...**).
   - Click **New action... → Load ReaScript...** (bottom-right).
   - Select `MyVisualPluginBrowser_v1.1.0.lua` and click **Open**.
3. **Run the Browser**:
   - In the Action List, search for `My Visual Plugin Browser`.
   - Select it and click **Run** (you can also bind it to a hotkey or toolbar button).
4. **Generate Thumbnails**:
   - Check the plugin formats you want to scan at the top (e.g., `VST3`, `VST2`, `CLAP`, `JS / JSFX`).
   - Click **GENERATE PREVIEWS**.
   - The scanner will load each plugin, capture its interface, and save the image automatically.
   - Click **STOP SCAN** anytime if you need to pause — it remembers your progress!

---

## 🎛️ UI & Controls

| Control | Description |
| :--- | :--- |
| **Search Bar** | Live filter to quickly find plugins by name. |
| **Format Checkboxes** | Toggle visibility for VST3, VST3i, VST2, JSFX, CLAP, AU, DX, DXi, LV2, or All. |
| **GENERATE PREVIEWS** | Runs automated background capture for plugins that are missing previews. |
| **STOP SCAN** | Halts the scanner immediately and cleans up temporary tracks. |
| **REFRESH** | Re-indexes your REAPER plugin database after installing new plugins. |
| **RELOAD IMAGES** | Flushes the in-memory cache and reloads all thumbnails from disk. |
| **Remove orphan thumbnails** | Deletes saved PNG files that no longer match any installed plugin. |
| **Click Thumbnail** | Inserts the plugin directly onto the currently selected track in REAPER. |
| **Replace** | Pick an image file from your computer to replace the current thumbnail. |
| **Clear** | Deletes the thumbnail file for that plugin. |
| **Load Image** | Manually attach a custom image/screenshot to a plugin with no preview. |
| **Skip / Skipped** | Marks a plugin to be bypassed during auto-scan (useful for bridged or slow plugins). Click red `Skipped` to unmark. |

---

## 📁 File Locations

All generated files and cached assets are stored in your REAPER resource directory:

- **Thumbnails Folder**: `%APPDATA%/REAPER/Data/track_icons/FX_Thumbnails/`
- **Skip List**: `%APPDATA%/REAPER/Data/track_icons/FX_Thumbnails/skip_list.txt`

---

## ⚙️ Configuration & Tweaks

You can fine-tune script behavior by opening `MyVisualPluginBrowser_v1.1.0.lua` in any text editor:

- **`OPEN_WAIT_FRAMES`** (default `45`):  
  The number of frames the scanner waits for a plugin window to open and draw before taking the screenshot.  
  *Tip:* If you have heavy plugins (e.g. Kontakt, Omnisphere) that produce black or incomplete screenshots, increase this to `60`–`80`.
- **`MAX_CAPTURE_RETRIES`** (default `3`):  
  How many times the scanner will retry capturing a plugin before moving on.
- **`ITEM_WIDTH` / `ITEM_HEIGHT`** (default `180` / `105`):  
  Dimensions of thumbnail cards in the grid.
- **`MAX_IMAGE_LOADS_PER_FRAME`** (default `2`):  
  Throttles image loading so scrolling and UI interaction remain silky smooth.

---

## ❓ Troubleshooting

### Blank or black screenshots?
Some complex or bridged plugins take longer to paint their GUI.
1. Open the script file in a text editor.
2. Change `local OPEN_WAIT_FRAMES = 45` to `60` or `80`.
3. Save and re-run.

### A plugin hangs or crashes during scan?
1. Click **STOP SCAN**.
2. Find the offending plugin in the browser grid.
3. Click the **`Skip`** button under its card (it will highlight in red as **`Skipped`**).
4. Resume **GENERATE PREVIEWS** — the scanner will safely bypass it.
5. You can take a manual screenshot of that plugin and use **`Load Image`** to set it manually.

### "JS_ReaScriptAPI is required" error on startup?
Open ReaPack (**Extensions → ReaPack → Browse packages...**), ensure `js_ReaScriptAPI` is installed, and restart REAPER.

---

## 💡 Suggestions & Feedback

Have ideas, bug reports, or feature requests? Feel free to open an issue or pull request on GitHub!


