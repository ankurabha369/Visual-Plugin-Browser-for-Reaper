------------------------------------------------------------
-- MY VISUAL PLUGIN BROWSER
-- REAPER + ReaImGui + JS_ReaScriptAPI
--
-- FEATURES
--
-- VST3
-- VST2
-- JS / JSFX
-- CLAP
-- AU
-- DX
-- ALL
--
-- SCANNER:
--
-- Open FX
-- Wait for GUI
-- Directly capture FX window
-- Save PNG
-- Close FX
-- Move to next FX
--
-- No REAPER screenshot action required.
------------------------------------------------------------


------------------------------------------------------------
-- CONTEXT
------------------------------------------------------------

local ctx =
    reaper.ImGui_CreateContext(
        "My Visual Plugin Browser"
    )


------------------------------------------------------------
-- SETTINGS
------------------------------------------------------------

local SCRIPT_NAME =
    "My Visual Plugin Browser"


------------------------------------------------------------
-- THUMBNAIL DIRECTORY
------------------------------------------------------------

local CAPTURE_DIR =
    reaper.GetResourcePath()
    .. "/Data/track_icons/FX_Thumbnails"


------------------------------------------------------------
-- THUMBNAIL DISPLAY SIZE
------------------------------------------------------------

local ITEM_WIDTH  = 180
local ITEM_HEIGHT = 105


------------------------------------------------------------
-- SCANNER SPEED
------------------------------------------------------------

-- Frames to wait after opening an FX.
--
-- 20 frames is roughly:
-- 0.33 sec at 60 FPS
--
-- Increase to 30-40 if some plugins need
-- more time to draw their interface.
------------------------------------------------------------

local OPEN_WAIT_FRAMES = 20


------------------------------------------------------------
-- PLUGIN TYPE FILTERS
------------------------------------------------------------

local type_enabled = {

    VST3 = true,

    VST2 = true,

    JS = true,

    CLAP = false,

    AU = false,

    DX = false,

}


------------------------------------------------------------
-- STATE
------------------------------------------------------------

local plugins = {}

local image_cache = {}

local filter_text = ""

local scanning = false

local scan_index = 1

local temp_track = nil

local current_fx = nil

local scan_stage = "idle"

local wait_frames = 0

local scan_total = 0

local scan_done = 0

local retry_map = {}
local MAX_CAPTURE_RETRIES = 3


------------------------------------------------------------
-- CREATE DIRECTORY
------------------------------------------------------------

reaper.RecursiveCreateDirectory(
    CAPTURE_DIR,
    0
)


------------------------------------------------------------
-- CHECK REQUIRED JS API
------------------------------------------------------------

if not reaper.JS_Window_GetRect
   or not reaper.JS_Window_SetForeground
   or not reaper.JS_Window_SetFocus
   or not reaper.JS_GDI_GetWindowDC
   or not reaper.JS_GDI_ReleaseDC
   or not reaper.JS_GDI_Blit
   or not reaper.JS_LICE_CreateBitmap
   or not reaper.JS_LICE_GetDC
   or not reaper.JS_LICE_WritePNG
   or not reaper.JS_LICE_DestroyBitmap
then

    reaper.ShowMessageBox(
        "JS_ReaScriptAPI is required.\n\n" ..
        "Install or update JS_ReaScriptAPI through ReaPack.",
        SCRIPT_NAME,
        0
    )

    return

end


------------------------------------------------------------
-- FILE EXISTS
------------------------------------------------------------

local function FileExists(path)

    local f =
        io.open(
            path,
            "rb"
        )

    if f then

        f:close()

        return true

    end

    return false

end


------------------------------------------------------------
-- CLEAN PLUGIN NAME
------------------------------------------------------------

local function CleanName(name)

    name =
        tostring(
            name or ""
        )


    --------------------------------------------------------
    -- Remove plugin type prefix
    --------------------------------------------------------

    name =
        name:gsub(
            "^VST3:%s*",
            ""
        )

    name =
        name:gsub(
            "^VST:%s*",
            ""
        )

    name =
        name:gsub(
            "^JS:%s*",
            ""
        )

    name =
        name:gsub(
            "^CLAP:%s*",
            ""
        )

    name =
        name:gsub(
            "^AU:%s*",
            ""
        )

    name =
        name:gsub(
            "^DX:%s*",
            ""
        )


    --------------------------------------------------------
    -- Remove brackets
    --------------------------------------------------------

    name =
        name:gsub(
            "%b[]",
            ""
        )


    --------------------------------------------------------
    -- Windows invalid filename characters
    --------------------------------------------------------

    name =
        name:gsub(
            '[\\/:*?"<>|]',
            "_"
        )


    --------------------------------------------------------
    -- Clean spaces
    --------------------------------------------------------

    name =
        name:gsub(
            "%s+",
            " "
        )

    name =
        name:gsub(
            "^%s+",
            ""
        )

    name =
        name:gsub(
            "%s+$",
            ""
        )


    --------------------------------------------------------
    -- Fallback
    --------------------------------------------------------

    if name == "" then
        name = "Unknown Plugin"
    end


    return name

end


------------------------------------------------------------
-- THUMBNAIL PATH
------------------------------------------------------------

local function GetThumbnailPath(name)

    return CAPTURE_DIR
        .. "/"
        .. CleanName(name)
        .. ".png"

end


------------------------------------------------------------
-- REMOVE ORPHAN THUMBNAILS
------------------------------------------------------------

local function RemoveOrphanThumbnails()
    -- refresh plugin list to be safe
    RefreshPluginDatabase()

    local plugin_map = {}
    for _, name in ipairs(plugins or {}) do
        if name then
            plugin_map[CleanName(name) .. ".png"] = true
        end
    end

    local i = 0
    local removed = 0
    local fname = reaper.EnumerateFiles(CAPTURE_DIR, i)
    while fname and fname ~= "" do
        local low = fname:lower()
        if low:match("%.png$") then
            if not plugin_map[fname] then
                local full = CAPTURE_DIR .. "/" .. fname
                local ok = pcall(function() os.remove(full) end)
                if ok then removed = removed + 1 end
            end
        end
        i = i + 1
        fname = reaper.EnumerateFiles(CAPTURE_DIR, i)
    end

    reaper.ShowMessageBox("Removed " .. tostring(removed) .. " orphan thumbnails.", SCRIPT_NAME, 0)

    image_cache = {}
end


------------------------------------------------------------
-- SKIP LIST (manual handling for problematic plugins)
------------------------------------------------------------

local SKIP_FILE = CAPTURE_DIR .. "/skip_list.txt"
local skip_map = {}

local function LoadSkipMap()
    local m = {}
    local f = io.open(SKIP_FILE, "r")
    if not f then return m end
    for line in f:lines() do
        if line and line ~= "" then
            m[line] = true
        end
    end
    f:close()
    return m
end

local function MarkSkip(name)
    if not name then return end
    local ok = pcall(function()
        local f = io.open(SKIP_FILE, "a")
        if f then f:write(name .. "\n") f:close() end
    end)
    skip_map[name] = true
end

local function UnmarkSkip(name)
    if not name then return end
    local m = LoadSkipMap()
    if not m[name] then return end
    m[name] = nil
    pcall(function()
        local f = io.open(SKIP_FILE, "w")
        if f then
            for k,_ in pairs(m) do f:write(k .. "\n") end
            f:close()
        end
    end)
    skip_map[name] = nil
end

-- load skip map at startup
skip_map = LoadSkipMap()


------------------------------------------------------------
-- GET PLUGIN TYPE
------------------------------------------------------------

local function GetPluginType(name)

    if not name then
        return nil
    end


    local upper =
        name:upper()


    if upper:match("^VST3:") then
        return "VST3"
    end


    if upper:match("^VST:") then
        return "VST2"
    end


    if upper:match("^JS:") then
        return "JS"
    end


    if upper:match("^CLAP:") then
        return "CLAP"
    end


    if upper:match("^AU:") then
        return "AU"
    end


    if upper:match("^DX:") then
        return "DX"
    end


    return nil

end


------------------------------------------------------------
-- CHECK TYPE
------------------------------------------------------------

local function IsTypeEnabled(name)

    local t =
        GetPluginType(name)


    if not t then
        return false
    end


    return type_enabled[t] == true

end


------------------------------------------------------------
-- LOAD INSTALLED PLUGINS
------------------------------------------------------------

local function LoadPlugins()

    local result = {}

    local i = 0


    while true do

        local retval,
              name =
            reaper.EnumInstalledFX(i)


        if not retval then
            break
        end


        if name
           and name ~= ""
           and IsTypeEnabled(name)
        then

            table.insert(
                result,
                name
            )

        end


        i = i + 1

    end


    --------------------------------------------------------
    -- Sort alphabetically
    --------------------------------------------------------

    table.sort(
        result,
        function(a, b)

            return a:lower()
                < b:lower()

        end
    )


    return result

end


------------------------------------------------------------
-- REFRESH PLUGIN DATABASE
------------------------------------------------------------

local function RefreshPluginDatabase()

    plugins =
        LoadPlugins()

end


------------------------------------------------------------
-- TRACK VALIDATION
------------------------------------------------------------

local function IsTrackValid(track)

    return track ~= nil
       and reaper.ValidatePtr2(
            0,
            track,
            "MediaTrack*"
       )

end


------------------------------------------------------------
-- REMOVE OLD SCANNER TRACKS
------------------------------------------------------------

local function RemoveOldScannerTracks()

    for i =
        reaper.GetNumTracks() - 1,
        0,
        -1
    do

        local track =
            reaper.GetTrack(
                0,
                i
            )


        local ok,
              name =
            reaper.GetSetMediaTrackInfo_String(
                track,
                "P_NAME",
                "",
                false
            )


        if ok
           and (
                name ==
                "TEMP_VISUAL_PLUGIN_BROWSER"
           )
        then

            reaper.DeleteTrack(
                track
            )

        end

    end

end


------------------------------------------------------------
-- CREATE TEMP TRACK
------------------------------------------------------------

local function CreateTempTrack()

    if IsTrackValid(temp_track) then
        return true
    end


    local count =
        reaper.GetNumTracks()


    reaper.InsertTrackAtIndex(
        count,
        false
    )


    temp_track =
        reaper.GetTrack(
            0,
            count
        )


    if not IsTrackValid(temp_track) then

        temp_track = nil

        return false

    end


    reaper.GetSetMediaTrackInfo_String(
        temp_track,
        "P_NAME",
        "TEMP_VISUAL_PLUGIN_BROWSER",
        true
    )


    --------------------------------------------------------
    -- Hide from TCP
    --------------------------------------------------------

    reaper.SetMediaTrackInfo_Value(
        temp_track,
        "B_SHOWINTCP",
        0
    )


    --------------------------------------------------------
    -- Hide from mixer
    --------------------------------------------------------

    reaper.SetMediaTrackInfo_Value(
        temp_track,
        "B_SHOWINMIXER",
        0
    )


    reaper.SetOnlyTrackSelected(
        temp_track
    )


    return true

end


------------------------------------------------------------
-- REMOVE CURRENT FX
------------------------------------------------------------

local function RemoveCurrentFX()

    if not IsTrackValid(temp_track) then

        current_fx = nil

        return

    end


    if current_fx ~= nil then

        local count =
            reaper.TrackFX_GetCount(
                temp_track
            )


        if current_fx >= 0
           and current_fx < count
        then

            ------------------------------------------------
            -- Hide FX window FIRST
            ------------------------------------------------

            reaper.TrackFX_Show(
                temp_track,
                current_fx,
                2
            )


            ------------------------------------------------
            -- Small flush
            ------------------------------------------------

            reaper.UpdateArrange()


            ------------------------------------------------
            -- Delete FX
            ------------------------------------------------

            reaper.TrackFX_Delete(
                temp_track,
                current_fx
            )

        end

    end


    current_fx = nil

end


------------------------------------------------------------
-- DELETE TEMP TRACK
------------------------------------------------------------

local function DeleteTempTrack()

    RemoveCurrentFX()


    if IsTrackValid(temp_track) then

        reaper.DeleteTrack(
            temp_track
        )

    end


    temp_track = nil

end


------------------------------------------------------------
-- STOP SCAN
------------------------------------------------------------

local function StopScan()

    scanning = false

    scan_stage = "idle"

    wait_frames = 0

    DeleteTempTrack()

end


------------------------------------------------------------
-- DIRECT FX WINDOW CAPTURE
------------------------------------------------------------

local function CaptureFXWindow(
    track,
    fx_idx,
    filename
)

    --------------------------------------------------------
    -- Get floating FX window
    --------------------------------------------------------

    local hwnd =
        reaper.TrackFX_GetFloatingWindow(
            track,
            fx_idx
        )


    if not hwnd then
        return false
    end


    --------------------------------------------------------
    -- Bring window to foreground
    --------------------------------------------------------

    reaper.JS_Window_SetForeground(
        hwnd
    )

    reaper.JS_Window_SetFocus(
        hwnd
    )


    --------------------------------------------------------
    -- Get window dimensions
    --------------------------------------------------------

    local ok,
          left,
          top,
          right,
          bottom =
        reaper.JS_Window_GetRect(
            hwnd
        )


    if not ok then
        return false
    end


    local width =
        right - left


    local height =
        bottom - top


    if width <= 0
       or height <= 0
    then

        return false

    end


    --------------------------------------------------------
    -- Get source window DC
    --------------------------------------------------------

    local src_dc =
        reaper.JS_GDI_GetWindowDC(
            hwnd
        )


    if not src_dc then
        return false
    end


    --------------------------------------------------------
    -- Create bitmap
    --------------------------------------------------------

    local bitmap =
        reaper.JS_LICE_CreateBitmap(
            true,
            width,
            height
        )


    if not bitmap then

        reaper.JS_GDI_ReleaseDC(
            hwnd,
            src_dc
        )

        return false

    end


    --------------------------------------------------------
    -- Get destination DC
    --------------------------------------------------------

    local dest_dc =
        reaper.JS_LICE_GetDC(
            bitmap
        )


    if not dest_dc then

        reaper.JS_LICE_DestroyBitmap(
            bitmap
        )

        reaper.JS_GDI_ReleaseDC(
            hwnd,
            src_dc
        )

        return false

    end


    --------------------------------------------------------
    -- Copy window
    --------------------------------------------------------

    reaper.JS_GDI_Blit(
        dest_dc,
        0,
        0,
        src_dc,
        0,
        0,
        width,
        height
    )


    --------------------------------------------------------
    -- Save PNG
    --------------------------------------------------------

    local success =
        reaper.JS_LICE_WritePNG(
            filename,
            bitmap,
            false
        )


    --------------------------------------------------------
    -- Cleanup
    --------------------------------------------------------

    reaper.JS_GDI_ReleaseDC(
        hwnd,
        src_dc
    )


    reaper.JS_LICE_DestroyBitmap(
        bitmap
    )


    return success == true

end


------------------------------------------------------------
-- START SCAN
------------------------------------------------------------

local function StartScan()

    if scanning then
        return
    end


    --------------------------------------------------------
    -- Refresh plugin list
    --------------------------------------------------------

    RefreshPluginDatabase()


    if #plugins == 0 then

        reaper.ShowMessageBox(
            "No plugins match your selected types.",
            SCRIPT_NAME,
            0
        )

        return

    end


    --------------------------------------------------------
    -- Remove old scanner
    --------------------------------------------------------

    DeleteTempTrack()


    --------------------------------------------------------
    -- Create scanner track
    --------------------------------------------------------

    if not CreateTempTrack() then

        reaper.ShowMessageBox(
            "Could not create scanner track.",
            SCRIPT_NAME,
            0
        )

        return

    end


    --------------------------------------------------------
    -- Start
    --------------------------------------------------------

    scan_index = 1

    scan_done = 0

    scan_total =
        #plugins

    current_fx = nil

    wait_frames = 0

    scan_stage = "load"

    scanning = true

end


------------------------------------------------------------
-- RUN SCANNER
------------------------------------------------------------

local function RunScanner()

    if not scanning then
        return
    end


    --------------------------------------------------------
    -- FINISHED
    --------------------------------------------------------

    if scan_index > #plugins then

        StopScan()

        return

    end


    --------------------------------------------------------
    -- WAIT
    --------------------------------------------------------

    if wait_frames > 0 then

        wait_frames =
            wait_frames - 1

        return

    end


    --------------------------------------------------------
    -- CURRENT PLUGIN
    --------------------------------------------------------

    local plugin_name =
        plugins[scan_index]

    -- skip if user marked this plugin to be skipped
    if skip_map[plugin_name] then
        scan_index = scan_index + 1
        return
    end


    local thumbnail =
        GetThumbnailPath(
            plugin_name
        )


    --------------------------------------------------------
    -- SKIP EXISTING THUMBNAIL
    --------------------------------------------------------

    if scan_stage == "load"
       and FileExists(thumbnail)
    then

        scan_done =
            scan_done + 1

        scan_index =
            scan_index + 1

        return

    end


    --------------------------------------------------------
    -- LOAD PLUGIN
    --------------------------------------------------------

    if scan_stage == "load" then

        ----------------------------------------------------
        -- Make sure scanner track exists
        ----------------------------------------------------

        if not IsTrackValid(temp_track) then

            if not CreateTempTrack() then

                scan_done =
                    scan_done + 1

                scan_index =
                    scan_index + 1

                return

            end

        end


        reaper.SetOnlyTrackSelected(
            temp_track
        )


        ----------------------------------------------------
        -- Add FX
        ----------------------------------------------------

        local fx =
            reaper.TrackFX_AddByName(
                temp_track,
                plugin_name,
                false,
                -1
            )


        if fx < 0 then

            scan_done =
                scan_done + 1

            scan_index =
                scan_index + 1

            return

        end


        current_fx = fx


        ----------------------------------------------------
        -- OPEN FLOATING WINDOW
        ----------------------------------------------------

        reaper.TrackFX_Show(
            temp_track,
            current_fx,
            3
        )


        ----------------------------------------------------
        -- Wait for GUI
        ----------------------------------------------------

        wait_frames =
            OPEN_WAIT_FRAMES


        scan_stage =
            "capture"


        return

    end


    --------------------------------------------------------
    -- CAPTURE
    --------------------------------------------------------

    if scan_stage == "capture" then

        ----------------------------------------------------
        -- Check FX
        ----------------------------------------------------

        if not IsTrackValid(temp_track)
           or current_fx == nil
        then

            scan_done =
                scan_done + 1

            scan_index =
                scan_index + 1

            scan_stage =
                "load"

            return

        end


        ----------------------------------------------------
        -- Check floating window
        ----------------------------------------------------

        local hwnd =
            reaper.TrackFX_GetFloatingWindow(
                temp_track,
                current_fx
            )


        ----------------------------------------------------
        -- Window hasn't appeared yet
        ----------------------------------------------------

        if not hwnd then

            wait_frames = 5

            return

        end


        ----------------------------------------------------
        -- DIRECT CAPTURE
        ----------------------------------------------------

        local success =
            CaptureFXWindow(
                temp_track,
                current_fx,
                thumbnail
            )


        ----------------------------------------------------
        -- SUCCESS
        ----------------------------------------------------

        if success
           and FileExists(thumbnail)
        then

            ------------------------------------------------
            -- Clear cached image
            ------------------------------------------------

            image_cache[plugin_name] =
                nil


            ------------------------------------------------
            -- Count
            ------------------------------------------------

            scan_done =
                scan_done + 1


            ------------------------------------------------
            -- CLOSE PLUGIN
            ------------------------------------------------

            RemoveCurrentFX()


            ------------------------------------------------
            -- NEXT PLUGIN
            ------------------------------------------------

            scan_index =
                scan_index + 1


            scan_stage =
                "load"


            ------------------------------------------------
            -- Only tiny pause
            ------------------------------------------------

            wait_frames = 2

        else

            ------------------------------------------------
            -- Capture failed.
            -- Retry a few times, then skip this plugin.
            ------------------------------------------------

            retry_map[scan_index] = (retry_map[scan_index] or 0) + 1

            if retry_map[scan_index] >= MAX_CAPTURE_RETRIES then
                Log("Capture failed repeatedly for: " .. tostring(plugin_name) .. "; skipping")
                -- ensure plugin window is closed and delete fx
                RemoveCurrentFX()

                scan_done = scan_done + 1
                scan_index = scan_index + 1
                scan_stage = "load"
                wait_frames = 2
                retry_map[scan_index] = nil
            else
                -- small backoff before retrying
                wait_frames = 10
            end

        end


        return

    end

end


------------------------------------------------------------
-- ADD PLUGIN TO USER TRACK
------------------------------------------------------------

local function AddPlugin(name)

    if not name then
        return
    end


    local track =
        reaper.GetSelectedTrack(
            0,
            0
        )


    if not track then

        reaper.ShowMessageBox(
            "Select a track first.",
            SCRIPT_NAME,
            0
        )

        return

    end


    reaper.TrackFX_AddByName(
        track,
        name,
        false,
        -1
    )

end


------------------------------------------------------------
-- LOAD IMAGE
------------------------------------------------------------

local function GetImage(name)

    --------------------------------------------------------
    -- Cached
    --------------------------------------------------------

    if image_cache[name] ~= nil then

        if image_cache[name] == false then
            return nil
        end

        return image_cache[name]

    end


    --------------------------------------------------------
    -- File
    --------------------------------------------------------

    local path =
        GetThumbnailPath(
            name
        )


    if not FileExists(path) then

        image_cache[name] =
            false

        return nil

    end


    --------------------------------------------------------
    -- Create image
    --------------------------------------------------------

    local img =
        reaper.ImGui_CreateImage(
            path
        )


    if img then

        ----------------------------------------------------
        -- Attach image to context.
        --
        -- This keeps the image valid between defer cycles.
        ----------------------------------------------------

        if reaper.ImGui_Attach then

            reaper.ImGui_Attach(
                ctx,
                img
            )

        end


        image_cache[name] =
            img


        return img

    end


    image_cache[name] =
        false


    return nil

end


------------------------------------------------------------
-- DRAW ASPECT-RATIO THUMBNAIL
------------------------------------------------------------

local function DrawThumbnail(
    name,
    img
)

    --------------------------------------------------------
    -- Starting position
    --------------------------------------------------------

    local start_x,
          start_y =
        reaper.ImGui_GetCursorPos(
            ctx
        )


    --------------------------------------------------------
    -- CORRECT ReaImGui API
    --
    -- IMPORTANT:
    --
    -- ImGui_Image_GetSize(img)
    --
    -- NOT:
    --
    -- ImGui_Image_GetSize(ctx, img)
    --------------------------------------------------------

    local iw,
          ih =
        reaper.ImGui_Image_GetSize(
            img
        )


    --------------------------------------------------------
    -- Invalid image
    --------------------------------------------------------

    if not iw
       or not ih
       or iw <= 0
       or ih <= 0
    then

        return reaper.ImGui_Button(
            ctx,
            "NO PREVIEW",
            ITEM_WIDTH,
            ITEM_HEIGHT
        )

    end


    --------------------------------------------------------
    -- Calculate proportional scale
    --------------------------------------------------------

    local scale =
        math.min(
            ITEM_WIDTH / iw,
            ITEM_HEIGHT / ih
        )


    local draw_w =
        iw * scale


    local draw_h =
        ih * scale


    --------------------------------------------------------
    -- Center image
    --------------------------------------------------------

    local offset_x =
        (ITEM_WIDTH - draw_w) / 2


    local offset_y =
        (ITEM_HEIGHT - draw_h) / 2


    --------------------------------------------------------
    -- Invisible clickable area
    --------------------------------------------------------

    reaper.ImGui_InvisibleButton(
        ctx,
        "##thumbnail_" .. tostring(name),
        ITEM_WIDTH,
        ITEM_HEIGHT
    )


    local clicked =
        reaper.ImGui_IsItemClicked(
            ctx
        )


    --------------------------------------------------------
    -- Draw actual image
    --------------------------------------------------------

    reaper.ImGui_SetCursorPos(
        ctx,
        start_x + offset_x,
        start_y + offset_y
    )


    reaper.ImGui_Image(
        ctx,
        img,
        draw_w,
        draw_h
    )


    --------------------------------------------------------
    -- Restore cursor to bottom of thumbnail
    --------------------------------------------------------

    reaper.ImGui_SetCursorPos(
        ctx,
        start_x,
        start_y + ITEM_HEIGHT
    )


    return clicked

end


------------------------------------------------------------
-- THEME
------------------------------------------------------------

local function PushTheme()

    reaper.ImGui_PushStyleColor(
        ctx,
        reaper.ImGui_Col_WindowBg(),
        0x121212FF
    )


    reaper.ImGui_PushStyleColor(
        ctx,
        reaper.ImGui_Col_ChildBg(),
        0x181818FF
    )


    reaper.ImGui_PushStyleColor(
        ctx,
        reaper.ImGui_Col_Button(),
        0x242424FF
    )


    reaper.ImGui_PushStyleColor(
        ctx,
        reaper.ImGui_Col_ButtonHovered(),
        0x343434FF
    )


    reaper.ImGui_PushStyleColor(
        ctx,
        reaper.ImGui_Col_ButtonActive(),
        0x1DB954FF
    )


    reaper.ImGui_PushStyleColor(
        ctx,
        reaper.ImGui_Col_FrameBg(),
        0x202020FF
    )


    reaper.ImGui_PushStyleColor(
        ctx,
        reaper.ImGui_Col_Text(),
        0xD0D0D0FF
    )


    reaper.ImGui_PushStyleVar(
        ctx,
        reaper.ImGui_StyleVar_WindowRounding(),
        8
    )


    reaper.ImGui_PushStyleVar(
        ctx,
        reaper.ImGui_StyleVar_FrameRounding(),
        6
    )


    reaper.ImGui_PushStyleVar(
        ctx,
        reaper.ImGui_StyleVar_ItemSpacing(),
        10,
        10
    )

end


------------------------------------------------------------
-- POP THEME
------------------------------------------------------------

local function PopTheme()

    reaper.ImGui_PopStyleColor(
        ctx,
        7
    )


    reaper.ImGui_PopStyleVar(
        ctx,
        3
    )

end


------------------------------------------------------------
-- TYPE CHECKBOX
------------------------------------------------------------

local function TypeCheckbox(
    label,
    key
)

    local changed,
          value =
        reaper.ImGui_Checkbox(
            ctx,
            label,
            type_enabled[key]
        )


    if changed then

        type_enabled[key] =
            value


        if not scanning then

            RefreshPluginDatabase()

        end

    end

end


------------------------------------------------------------
-- MAIN LOOP
------------------------------------------------------------

local function Loop()

    --------------------------------------------------------
    -- RUN SCANNER
    --------------------------------------------------------

    RunScanner()


    --------------------------------------------------------
    -- THEME
    --------------------------------------------------------

    PushTheme()


    --------------------------------------------------------
    -- WINDOW SIZE
    --------------------------------------------------------

    reaper.ImGui_SetNextWindowSize(
        ctx,
        950,
        650,
        reaper.ImGui_Cond_FirstUseEver()
    )


    --------------------------------------------------------
    -- BEGIN WINDOW
    --------------------------------------------------------

    local visible,
          open =
        reaper.ImGui_Begin(
            ctx,
            SCRIPT_NAME,
            true
        )


    if visible then

        ----------------------------------------------------
        -- SEARCH
        ----------------------------------------------------

        local width =
            reaper.ImGui_GetContentRegionAvail(
                ctx
            )


        reaper.ImGui_SetNextItemWidth(
            ctx,
            width - 220
        )


        local changed


        changed,
        filter_text =
            reaper.ImGui_InputTextWithHint(
                ctx,
                "##search",
                "Search plugins...",
                filter_text
            )


        reaper.ImGui_SameLine(
            ctx
        )


        ----------------------------------------------------
        -- SCAN BUTTON
        ----------------------------------------------------

        if scanning then

            if reaper.ImGui_Button(
                ctx,
                "STOP SCAN",
                200,
                0
            ) then

                StopScan()

            end

        else

            if reaper.ImGui_Button(
                ctx,
                "GENERATE PREVIEWS",
                200,
                0
            ) then

                StartScan()

            end

        end


        ----------------------------------------------------
        -- PLUGIN TYPES
        ----------------------------------------------------

        reaper.ImGui_Separator(
            ctx
        )


        reaper.ImGui_Text(
            ctx,
            "Generate thumbnails for:"
        )


        TypeCheckbox(
            "VST3",
            "VST3"
        )


        reaper.ImGui_SameLine(
            ctx
        )


        TypeCheckbox(
            "VST2",
            "VST2"
        )


        reaper.ImGui_SameLine(
            ctx
        )


        TypeCheckbox(
            "JS / JSFX",
            "JS"
        )


        reaper.ImGui_SameLine(
            ctx
        )


        TypeCheckbox(
            "CLAP",
            "CLAP"
        )


        reaper.ImGui_SameLine(
            ctx
        )


        TypeCheckbox(
            "AU",
            "AU"
        )


        reaper.ImGui_SameLine(
            ctx
        )


        TypeCheckbox(
            "DX",
            "DX"
        )


        ----------------------------------------------------
        -- STATUS
        ----------------------------------------------------

        reaper.ImGui_Separator(
            ctx
        )


        if scanning then

            local percent = 0


            if scan_total > 0 then

                percent =
                    scan_done /
                    scan_total

            end


            reaper.ImGui_Text(
                ctx,
                string.format(
                    "Scanning: %d / %d",
                    scan_done,
                    scan_total
                )
            )


            reaper.ImGui_ProgressBar(
                ctx,
                percent,
                -1,
                20
            )


            if scan_index <= #plugins then

                reaper.ImGui_Text(
                    ctx,
                    "Current: "
                    .. tostring(
                        plugins[scan_index]
                    )
                )

            end

        else

            reaper.ImGui_Text(
                ctx,
                string.format(
                    "%d plugins available",
                    #plugins
                )
            )

        end


        ----------------------------------------------------
        -- REFRESH BUTTON
        ----------------------------------------------------

        reaper.ImGui_Separator(
            ctx
        )


        if reaper.ImGui_Button(
            ctx,
            "REFRESH",
            120,
            0
        ) then

            RefreshPluginDatabase()

            image_cache = {}

        end


        reaper.ImGui_SameLine(
            ctx
        )


        if reaper.ImGui_Button(
            ctx,
            "RELOAD IMAGES",
            150,
            0
        ) then

            image_cache = {}

        end

        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Remove orphan thumbnails", 220, 0) then
            RemoveOrphanThumbnails()
        end


        ----------------------------------------------------
        -- GRID
        ----------------------------------------------------

        reaper.ImGui_Separator(
            ctx
        )


        local child_visible =
            reaper.ImGui_BeginChild(
                ctx,
                "PluginGrid",
                0,
                0
            )


        if child_visible then

            ------------------------------------------------
            -- Available width
            ------------------------------------------------

            local available =
                reaper.ImGui_GetContentRegionAvail(
                    ctx
                )


            ------------------------------------------------
            -- Number of columns
            ------------------------------------------------

            local columns =
                math.max(
                    1,
                    math.floor(
                        available /
                        (ITEM_WIDTH + 20)
                    )
                )


            ------------------------------------------------
            -- BEGIN TABLE
            ------------------------------------------------

            local table_visible =
                reaper.ImGui_BeginTable(
                    ctx,
                    "PluginTable",
                    columns
                )


            if table_visible then

                ------------------------------------------------
                -- PLUGIN LOOP
                ------------------------------------------------

                for _, name in ipairs(plugins) do

                    local lower_name =
                        name:lower()


                    local lower_filter =
                        filter_text:lower()


                    local match =
                        filter_text == ""
                        or
                        lower_name:find(
                            lower_filter,
                            1,
                            true
                        )


                    if match then

                        ------------------------------------------------
                        -- NEXT COLUMN
                        ------------------------------------------------

                        reaper.ImGui_TableNextColumn(
                            ctx
                        )


                        ------------------------------------------------
                        -- UNIQUE ID
                        ------------------------------------------------

                        reaper.ImGui_PushID(
                            ctx,
                            name
                        )


                        ------------------------------------------------
                        -- IMAGE
                        ------------------------------------------------

                        local img =
                            GetImage(
                                name
                            )


                        local clicked = false


                        if img then

                            clicked =
                                DrawThumbnail(
                                    name,
                                    img
                                )

                            reaper.ImGui_Spacing(ctx)

                            -- Edit controls for existing thumbnail
                            if reaper.ImGui_Button(ctx, "Replace", math.floor(ITEM_WIDTH/2) - 4, 20) then
                                local retval, sel = reaper.GetUserFileNameForRead("", "Select image to replace thumbnail", "")
                                if sel and sel ~= "" then
                                    local src = sel
                                    local dest = GetThumbnailPath(name)
                                    local ok = pcall(function()
                                        local fr = io.open(src, "rb")
                                        if fr then
                                            local data = fr:read("*a")
                                            fr:close()
                                            local fw = io.open(dest, "wb")
                                            if fw then fw:write(data) fw:close() end
                                        end
                                    end)
                                    if ok then
                                        image_cache[name] = nil
                                    else
                                        reaper.ShowMessageBox("Failed to replace thumbnail.", SCRIPT_NAME, 0)
                                    end
                                end
                            end

                            reaper.ImGui_SameLine(ctx)
                            if reaper.ImGui_Button(ctx, "Clear", math.ceil(ITEM_WIDTH/2) - 4, 20) then
                                local dest = GetThumbnailPath(name)
                                local ok = pcall(function()
                                    os.remove(dest)
                                end)
                                if ok then
                                    image_cache[name] = nil
                                else
                                    reaper.ShowMessageBox("Failed to remove thumbnail.", SCRIPT_NAME, 0)
                                end
                            end


                        else

                            if reaper.ImGui_Button(ctx, "NO PREVIEW", ITEM_WIDTH, ITEM_HEIGHT) then
                                clicked = true
                            end

                            reaper.ImGui_Spacing(ctx)

                            -- small action buttons: Load Image and Skip
                            if reaper.ImGui_Button(ctx, "Load Image", math.floor(ITEM_WIDTH/2) - 4, 20) then
                                local retval, sel = reaper.GetUserFileNameForRead("", "Select image to load", "")
                                if sel and sel ~= "" then
                                    local src = sel
                                    local dest = GetThumbnailPath(name)
                                    local ok = pcall(function()
                                        local fr = io.open(src, "rb")
                                        if fr then
                                            local data = fr:read("*a")
                                            fr:close()
                                            local fw = io.open(dest, "wb")
                                            if fw then fw:write(data) fw:close() end
                                        end
                                    end)
                                    if ok then
                                        image_cache[name] = nil
                                        UnmarkSkip(name)
                                    else
                                        reaper.ShowMessageBox("Failed to copy image.", SCRIPT_NAME, 0)
                                    end
                                end
                            end

                            reaper.ImGui_SameLine(ctx)
                            -- show skipped state
                            if skip_map[name] then
                                -- red filled button indicating skipped
                                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0xAAFF5555)
                                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0xCCFF7777)
                                if reaper.ImGui_Button(ctx, "Skipped", math.ceil(ITEM_WIDTH/2) - 4, 20) then
                                    -- clicking toggles unskip
                                    UnmarkSkip(name)
                                end
                                reaper.ImGui_PopStyleColor(ctx)
                                reaper.ImGui_PopStyleColor(ctx)
                            else
                                if reaper.ImGui_Button(ctx, "Skip", math.ceil(ITEM_WIDTH/2) - 4, 20) then
                                    MarkSkip(name)
                                end
                            end

                        end


                        ------------------------------------------------
                        -- CLICK
                        ------------------------------------------------

                        if clicked then

                            AddPlugin(
                                name
                            )

                        end


                        ------------------------------------------------
                        -- NAME
                        ------------------------------------------------

                        reaper.ImGui_TextWrapped(
                            ctx,
                            CleanName(name)
                        )


                        ------------------------------------------------
                        -- TYPE
                        ------------------------------------------------

                        reaper.ImGui_TextDisabled(
                            ctx,
                            GetPluginType(name)
                            or ""
                        )


                        reaper.ImGui_Spacing(
                            ctx
                        )


                        ------------------------------------------------
                        -- POP ID
                        ------------------------------------------------

                        reaper.ImGui_PopID(
                            ctx
                        )

                    end

                end


                ------------------------------------------------
                -- IMPORTANT:
                -- ALWAYS END TABLE
                ------------------------------------------------

                reaper.ImGui_EndTable(
                    ctx
                )

            end


            ------------------------------------------------
            -- END CHILD
            ------------------------------------------------

            reaper.ImGui_EndChild(
                ctx
            )

        end


        ----------------------------------------------------
        -- END WINDOW
        ----------------------------------------------------

        reaper.ImGui_End(
            ctx
        )

    end


    --------------------------------------------------------
    -- POP THEME
    --------------------------------------------------------

    PopTheme()


    --------------------------------------------------------
    -- CONTINUE
    --------------------------------------------------------

    if open then

        reaper.defer(
            Loop
        )

    else

        StopScan()

        ----------------------------------------------------
        -- DO NOT call ImGui_DestroyContext()
        ----------------------------------------------------

    end

end


------------------------------------------------------------
-- INITIALIZE
------------------------------------------------------------

RemoveOldScannerTracks()

RefreshPluginDatabase()


------------------------------------------------------------
-- START
------------------------------------------------------------

reaper.defer(
    Loop
)