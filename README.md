<img  src="https://github.com/user-attachments/assets/736a79a1-24d4-4426-bed2-98b26744ed18" alt="REAPER Logo">


<br>
<img width="1365" height="998" alt="image" src="https://github.com/user-attachments/assets/55581c9e-f062-4843-b799-a0359258d192" />


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



