-- Trainfitter - cl_trainfitter.lua
-- Made by SellingVika.

local NET = Trainfitter.Net

Trainfitter.Mounted        = Trainfitter.Mounted or {}
Trainfitter.PersistentList = Trainfitter.PersistentList or {}
Trainfitter.LastMountInfo  = Trainfitter.LastMountInfo or {}
Trainfitter.History        = Trainfitter.History or {}
Trainfitter.ActiveSkin     = Trainfitter.ActiveSkin or nil
Trainfitter.AdminConfig    = Trainfitter.AdminConfig or nil
Trainfitter.MountedSkins   = Trainfitter.MountedSkins or {}

local queue     = {}
local currentDL = nil
local callbacks = {}

local COL_INFO = Color(150, 220, 255)
local COL_OK   = Color(120, 240, 150)
local COL_ERR  = Color(255, 110, 110)

local NOTIFY_INFO = NOTIFY_HINT  or 1
local NOTIFY_OK   = NOTIFY_GENERIC or 0
local NOTIFY_ERR  = NOTIFY_ERROR or 1

local function ShowNotify(text, kind, dur)
    if notification and isfunction(notification.AddLegacy) then
        notification.AddLegacy(tostring(text), kind or NOTIFY_INFO, dur or 5)
        if surface and isfunction(surface.PlaySound) then
            if kind == NOTIFY_ERR then
                surface.PlaySound("buttons/button10.wav")
            else
                surface.PlaySound("ambient/water/drip" .. math.random(1, 4) .. ".wav")
            end
        end
    end
end

function Trainfitter.ChatMsg(text, col)
    local kind = NOTIFY_INFO
    if col == COL_ERR then kind = NOTIFY_ERR
    elseif col == COL_OK then kind = NOTIFY_OK end
    ShowNotify("[Trainfitter] " .. tostring(text), kind, 6)
end

local HISTORY_DIR  = "trainfitter"
local HISTORY_FILE = HISTORY_DIR .. "/client_history.json"
local HISTORY_CAP  = 100

local function SaveHistory()
    if not file.IsDir(HISTORY_DIR, "DATA") then file.CreateDir(HISTORY_DIR) end
    local ok, json = pcall(util.TableToJSON, Trainfitter.History or {}, true)
    if ok and isstring(json) then
        file.Write(HISTORY_FILE, json)
    end
end

local function LoadHistory()
    if not file.Exists(HISTORY_FILE, "DATA") then return end
    local raw = file.Read(HISTORY_FILE, "DATA") or ""
    local ok, data = pcall(util.JSONToTable, raw)
    if not ok or not istable(data) then
        if raw ~= "" then
            pcall(file.Write, HISTORY_FILE .. ".bad", raw)
            MsgC(Color(255, 180, 80),
                "[Trainfitter] client_history.json corrupt - saved a copy as client_history.json.bad, starting fresh\n")
        end
        return
    end
    local clean = {}
    for _, e in ipairs(data) do
        if istable(e) and isstring(e.wsid) and string.match(e.wsid, "^%d+$") then
            table.insert(clean, {
                wsid      = e.wsid,
                title     = isstring(e.title) and e.title or "",
                size      = tonumber(e.size) or 0,
                time      = tonumber(e.time) or 0,
                ok        = e.ok == true,
                apiSource = isstring(e.apiSource) and e.apiSource or "",
            })
        end
    end
    Trainfitter.History = clean
end

local historyDirty = false

local function PushHistory(wsid, title, size, ok, apiSource)
    for i, h in ipairs(Trainfitter.History) do
        if h.wsid == wsid then table.remove(Trainfitter.History, i) break end
    end
    table.insert(Trainfitter.History, 1, {
        wsid      = wsid,
        title     = title or "",
        size      = size or 0,
        time      = os.time(),
        ok        = ok == true,
        apiSource = apiSource or "",
    })
    while #Trainfitter.History > HISTORY_CAP do table.remove(Trainfitter.History) end
    historyDirty = true
end

function Trainfitter.RemoveFromHistory(wsid)
    if not isstring(wsid) then return false end
    for i = #Trainfitter.History, 1, -1 do
        if Trainfitter.History[i].wsid == wsid then
            table.remove(Trainfitter.History, i)
            historyDirty = true
            SaveHistory()
            hook.Run("Trainfitter.HistoryUpdated")
            return true
        end
    end
    return false
end

function Trainfitter.ClearHistory()
    Trainfitter.History = {}
    historyDirty = true
    SaveHistory()
    hook.Run("Trainfitter.HistoryUpdated")
end

timer.Create("Trainfitter.HistoryFlush", 30, 0, function()
    if historyDirty then SaveHistory(); historyDirty = false end
end)

hook.Add("ShutDown", "Trainfitter.HistoryFlush", function()
    if historyDirty then SaveHistory() end
end)

LoadHistory()

local function PurgeDirOfFiles(relDir, mask)
    if not file.IsDir(relDir, "DATA") then return 0 end
    local files = file.Find(relDir .. "/" .. (mask or "*"), "DATA") or {}
    local n = 0
    for _, fname in ipairs(files) do
        if pcall(file.Delete, relDir .. "/" .. fname) then n = n + 1 end
    end
    return n
end

function Trainfitter.PurgeAllClient()
    Trainfitter.History        = {}
    Trainfitter.Mounted        = {}
    Trainfitter.LastMountInfo  = {}
    Trainfitter.MountedSkins   = {}
    Trainfitter.PersistentList = {}
    Trainfitter.ActiveSkin     = nil
    Trainfitter.AdminConfig    = nil

    historyDirty = false
    if file.Exists(HISTORY_FILE, "DATA") then pcall(file.Delete, HISTORY_FILE) end

    local previews = PurgeDirOfFiles("trainfitter/previews", "*.png")
    local gmas     = PurgeDirOfFiles("trainfitter/gmas",     "*.gma")

    hook.Run("Trainfitter.HistoryUpdated")
    hook.Run("Trainfitter.PersistentUpdated", {})
    hook.Run("Trainfitter.ActiveSkinChanged", nil)

    Trainfitter.ChatMsg(Trainfitter.L("purge_client_done", previews, gmas), COL_OK)
    return previews, gmas
end

concommand.Add("trainfitter_client_purge", function()
    Trainfitter.PurgeAllClient()
end)

local function SnapshotMetrostroiTable(t)
    local snap = {}
    if not istable(t) then return snap end
    for category, bucket in pairs(t) do
        if istable(bucket) then
            snap[category] = {}
            for name in pairs(bucket) do snap[category][name] = true end
        end
    end
    return snap
end

local function SnapshotSkins()
    if not Metrostroi then return { skins = {}, masks = {} } end
    return {
        skins = SnapshotMetrostroiTable(Metrostroi.Skins),
        masks = SnapshotMetrostroiTable(Metrostroi.Masks),
    }
end

local function DiffInto(currentTbl, beforeTbl, ownership, kind, log)
    if not istable(currentTbl) then return 0 end
    local total = 0
    for category, bucket in pairs(currentTbl) do
        if istable(bucket) then
            local newOnes = {}
            for name, data in pairs(bucket) do
                if not (beforeTbl[category] and beforeTbl[category][name]) then
                    if istable(data) then
                        local typ = data.typ or ""
                        table.insert(ownership, {
                            kind     = kind,
                            category = category,
                            name     = name,
                            typ      = typ,
                        })
                        local display = data.name or name
                        table.insert(newOnes, string.format("'%s' (typ=%s)", display, typ))
                    end
                end
            end
            if #newOnes > 0 then
                total = total + #newOnes
                MsgC(Color(180, 220, 255),
                    string.format("[Trainfitter] New %s in Metrostroi.%s.%s: %s\n",
                        log, log, category, table.concat(newOnes, ", ")))
            end
        end
    end
    return total
end

function Trainfitter.DiffAndReportSkins(before, wsid)
    if not Metrostroi then return end
    before = before or { skins = {}, masks = {} }

    local ownership = {}
    local totalNew = 0
    totalNew = totalNew + DiffInto(Metrostroi.Skins, before.skins or {}, ownership, "skin", "Skins")
    totalNew = totalNew + DiffInto(Metrostroi.Masks, before.masks or {}, ownership, "mask", "Masks")

    if wsid and #ownership > 0 then
        Trainfitter.MountedSkins[wsid] = ownership
        if #ownership <= 64 then
            net.Start(NET.ReportSkins)
            net.WriteString(wsid)
            net.WriteUInt(#ownership, 8)
            for _, e in ipairs(ownership) do
                net.WriteString(string.sub(e.kind     or "skin", 1, 8))
                net.WriteString(string.sub(e.category or "", 1, 16))
                net.WriteString(string.sub(e.name     or "", 1, 64))
                net.WriteString(string.sub(e.typ      or "", 1, 32))
            end
            net.SendToServer()
        end
    end

    if totalNew > 0 then
        MsgC(Color(120, 220, 150), "[Trainfitter] " .. Trainfitter.L("apply_hint") .. "\n")
    end
end

local function ProcessQueue()
    if currentDL or #queue == 0 then return end

    local wsid = table.remove(queue, 1)
    if Trainfitter.Mounted[wsid] then
        local cbs = callbacks[wsid] or {}
        callbacks[wsid] = nil
        for _, cb in ipairs(cbs) do pcall(cb, true) end
        ProcessQueue()
        return
    end

    currentDL = wsid
    local finished = false

    local progressId = "trainfitter_dl_" .. wsid
    if notification and isfunction(notification.AddProgress) then
        notification.AddProgress(progressId, "[Trainfitter] " .. wsid .. " …")
    end

    local function finish(ok, err, apiSource)
        if finished then return end
        finished = true
        timer.Remove("Trainfitter.DLTimeout." .. wsid)
        if notification and isfunction(notification.Kill) then
            pcall(notification.Kill, progressId)
        end

        currentDL = nil
        if ok then Trainfitter.Mounted[wsid] = true end

        local info = Trainfitter.LastMountInfo[wsid] or {}
        PushHistory(wsid, info.title, info.size, ok, apiSource or "")

        local cbs = callbacks[wsid] or {}
        callbacks[wsid] = nil
        for _, cb in ipairs(cbs) do pcall(cb, ok, err) end
        ProcessQueue()
    end

    timer.Create("Trainfitter.DLTimeout." .. wsid, Trainfitter.Config.MountTimeoutSec, 1,
        function() finish(false, "timeout") end)

    local sharedCache = "trainfitter/gmas/" .. wsid .. ".gma"
    local sharedCachePath = "data/" .. sharedCache
    local function continueWithPath(path, apiSource)
        if finished then return end

        if not path then
            finish(false, "download failed", apiSource)
            return
        end

        local fullLuaForThis = Trainfitter.ShouldAllowFullLua and Trainfitter.ShouldAllowFullLua() or false

        local scanBodies = nil
        if Trainfitter.ShouldScanGMA and Trainfitter.ShouldScanGMA() then
            local callOK, safe, reason, _sf, bodies = pcall(Trainfitter.ScanGMA, path, fullLuaForThis)
            scanBodies = bodies
            if not callOK then
                MsgC(Color(255, 180, 80),
                    "[Trainfitter] scanner crashed on " .. wsid ..
                    ": " .. tostring(safe) .. " - mounting with runtime scan only\n")
            elseif not safe then
                Trainfitter.ChatMsg(Trainfitter.L("refused_mount", wsid, tostring(reason)), COL_ERR)
                finish(false, "scan rejected: " .. tostring(reason), apiSource)
                return
            end
        end

        local ok, files = game.MountGMA(path)
        if not ok then
            finish(false, "mount failed", apiSource)
            return
        end

        local beforeSkins = SnapshotSkins()

        if isbool(files) then files = {} end

        local fullLua = fullLuaForThis

        local function getBody(fpath)
            local c = scanBodies and scanBodies[string.lower(fpath)] or nil
            if not isstring(c) or #c == 0 then
                c = file.Read(fpath, "GAME")
            end
            if isstring(c) and #c > 0 then return c end
            return nil
        end

        local hooksBefore = {}
        do
            local t = hook.GetTable()["InitPostEntity"]
            if istable(t) then for n in pairs(t) do hooksBefore[n] = true end end
        end

        local includedCount, pathMetrostroi, pathAutorun = 0, 0, 0
        for _, fpath in ipairs(files or {}) do
            if isstring(fpath) and string.sub(string.lower(fpath), -4) == ".lua" then
                local low = string.lower(fpath)
                local content = getBody(fpath)
                if content then
                    if string.sub(low, 1, 21) == "lua/metrostroi/skins/" then
                        local preOK, preReason = Trainfitter.ValidateSkinLua(content, fpath)
                        if not preOK then
                            MsgC(Color(255, 120, 120),
                                "[Trainfitter] Refused skin file (preflight): " ..
                                tostring(preReason) .. "\n")
                        else
                            local ok, err = Trainfitter.ExecSandboxed(content, fpath, "skin")
                            if ok then
                                includedCount = includedCount + 1
                                pathMetrostroi = pathMetrostroi + 1
                            else
                                MsgC(Color(255, 180, 80),
                                    "[Trainfitter] sandboxed exec '" .. fpath ..
                                    "' failed: " .. tostring(err) .. "\n")
                            end
                        end
                    elseif fullLua then
                        local rejectBC = Trainfitter.ShouldRejectBytecode
                                         and Trainfitter.ShouldRejectBytecode()
                        if rejectBC and string.byte(content, 1) == 0x1B then
                            MsgC(Color(255, 120, 120),
                                "[Trainfitter] Refused (bytecode, set trainfitter_reject_bytecode 0 to allow): " .. fpath .. "\n")
                        else
                            local fn, compileErr = CompileString(content, fpath, false)
                            if isstring(fn) then
                                MsgC(Color(255, 120, 120),
                                    "[Trainfitter] Compile failed for " .. fpath .. ": " .. fn .. "\n")
                            elseif isfunction(fn) then
                                local ok, runErr = pcall(fn)
                                if ok then
                                    includedCount = includedCount + 1
                                    pathAutorun = pathAutorun + 1
                                else
                                    MsgC(Color(255, 180, 80),
                                        "[Trainfitter] unsandboxed exec '" .. fpath ..
                                        "' failed: " .. tostring(runErr) .. "\n")
                                end
                            end
                        end
                    end
                end
            end
        end

        do
            local t = hook.GetTable()["InitPostEntity"]
            if istable(t) then
                for name, fn in pairs(t) do
                    if not hooksBefore[name] and isfunction(fn) then
                        local ok, err = pcall(fn)
                        if not ok then
                            MsgC(Color(255, 180, 80), string.format(
                                "[Trainfitter] Late-fire InitPostEntity hook '%s' from %s failed: %s\n",
                                tostring(name), tostring(wsid), tostring(err)))
                        end
                    end
                end
            end
        end

        MsgC(Color(150, 220, 255),
            string.format("[Trainfitter] %s: %d scripts executed (metrostroi/skins+masks=%d, autorun=%d, total files=%d)\n",
                tostring(wsid), includedCount, pathMetrostroi, pathAutorun, #(files or {})))

        Trainfitter.DiffAndReportSkins(beforeSkins, wsid)

        Trainfitter.SafeFetchWorkshopInfo(wsid, function(info)
            if info and info.title and info.title ~= "" then
                Trainfitter.LastMountInfo[wsid] = Trainfitter.LastMountInfo[wsid] or {}
                Trainfitter.LastMountInfo[wsid].title = info.title
                Trainfitter.LastMountInfo[wsid].size  = info.size
                Trainfitter.LastMountInfo[wsid].files = files
            else
                Trainfitter.LastMountInfo[wsid] = Trainfitter.LastMountInfo[wsid] or {}
                Trainfitter.LastMountInfo[wsid].files = files
            end
        end)

        finish(true, nil, apiSource)
    end

    if file.Exists(sharedCache, "DATA")
       and (file.Size(sharedCache, "DATA") or 0) > 1000 then
        MsgC(Color(180, 220, 255),
            "[Trainfitter] Using server-shared HTTP cache for " .. wsid .. "\n")
        continueWithPath(sharedCachePath, "shared_cache")
        return
    end

    if not steamworks or not isfunction(steamworks.DownloadUGC) then
        finish(false, "no shared cache and steamworks.DownloadUGC unavailable", "")
        return
    end

    timer.Simple(0, function()
        if finished then return end
        local ok, err = pcall(steamworks.DownloadUGC, wsid, function(path, _file)
            continueWithPath(path, "steamworks_native")
        end)
        if not ok then
            MsgC(Color(255, 120, 120),
                "[Trainfitter] steamworks.DownloadUGC threw on " .. wsid ..
                ": " .. tostring(err) .. "\n")
            finish(false, "DownloadUGC threw: " .. tostring(err), "")
        end
    end)
end

function Trainfitter.ResendOwnership(wsid)
    local ownership = Trainfitter.MountedSkins and Trainfitter.MountedSkins[wsid]
    if not istable(ownership) or #ownership == 0 then return end
    if #ownership > 64 then return end
    net.Start(NET.ReportSkins)
    net.WriteString(wsid)
    net.WriteUInt(#ownership, 8)
    for _, e in ipairs(ownership) do
        net.WriteString(string.sub(e.kind     or "skin", 1, 8))
        net.WriteString(string.sub(e.category or "", 1, 16))
        net.WriteString(string.sub(e.name     or "", 1, 64))
        net.WriteString(string.sub(e.typ      or "", 1, 32))
    end
    net.SendToServer()
end

--# клиентский тумблер: качаем скины или нет (для слабых ПК)
function Trainfitter.SkinsEnabled()
    local cv = GetConVar("trainfitter_skins_enabled")
    return cv == nil or cv:GetBool() ~= false
end

--# снимаем все локально загруженные скины - составы у НАС вернутся к дефолту (других игроков не трогает)
function Trainfitter.UnmountAllLocal()
    if Metrostroi then
        for _, owned in pairs(Trainfitter.MountedSkins or {}) do
            if istable(owned) then
                for _, entry in ipairs(owned) do
                    local rootTbl = (entry.kind == "mask") and Metrostroi.Masks or Metrostroi.Skins
                    if istable(rootTbl) and istable(rootTbl[entry.category]) then
                        rootTbl[entry.category][entry.name] = nil
                    end
                end
            end
        end
    end
    Trainfitter.MountedSkins = {}
    Trainfitter.Mounted = {}
end

--# просим сервер заново прислать ВСЕ текущие скины (persistent + session), чтоб подтянулись без релога
function Trainfitter.ResyncSkins()
    net.Start(NET.ResyncSkins)
    net.SendToServer()
end

cvars.AddChangeCallback("trainfitter_skins_enabled", function(_, _, newVal)
    if tobool(newVal) then
        if Trainfitter.ResyncSkins then Trainfitter.ResyncSkins() end --# включили - подтянем текущие скины
    else
        pcall(Trainfitter.UnmountAllLocal) --# выключили - снимаем локально, дальше не качаем
    end
end, "Trainfitter.SkinsToggle")

function Trainfitter.Enqueue(wsid, cb)
    if not isstring(wsid) or wsid == "" then return end
    if not Trainfitter.SkinsEnabled() then return end --# игрок отключил скины ради оптимизации
    if Trainfitter.Mounted[wsid] then
        Trainfitter.ResendOwnership(wsid)
        if cb then pcall(cb, true) end
        return
    end
    callbacks[wsid] = callbacks[wsid] or {}
    if cb then table.insert(callbacks[wsid], cb) end

    if currentDL == wsid then return end
    for _, q in ipairs(queue) do
        if q == wsid then return end
    end

    table.insert(queue, wsid)
    ProcessQueue()
end

net.Receive(NET.Broadcast, function()
    local wsid         = net.ReadString()
    local initiator    = net.ReadString()
    local title        = net.ReadString()
    local sizeMB       = net.ReadFloat()
    local initiatorSid = net.ReadString()

    Trainfitter.LastMountInfo[wsid] = Trainfitter.LastMountInfo[wsid] or {}
    if title ~= "" then
        Trainfitter.LastMountInfo[wsid].title = title
        if sizeMB and sizeMB > 0 then
            Trainfitter.LastMountInfo[wsid].size = sizeMB * 1024 * 1024
        end
    end
    if initiatorSid ~= "" then
        Trainfitter.LastMountInfo[wsid].initiatorSid = initiatorSid
    end

    --# игрок отключил скины - молча игнорим, метаданные сохранили выше для UI
    if not Trainfitter.SkinsEnabled() then return end

    if Trainfitter.Mounted[wsid] then return end

    local niceTitle = title ~= "" and title or wsid
    if initiator ~= "" then
        Trainfitter.ChatMsg(Trainfitter.L("added_downloading", initiator, niceTitle), COL_INFO)
    else
        Trainfitter.ChatMsg(Trainfitter.L("server_added_dl", niceTitle), COL_INFO)
    end

    Trainfitter.Enqueue(wsid, function(ok, err)
        local info = Trainfitter.LastMountInfo[wsid]
        local nt = (info and info.title) or wsid
        if ok then
            Trainfitter.ChatMsg(Trainfitter.L("ready", nt), COL_OK)
            hook.Run("Trainfitter.AddonMounted", wsid, info, initiatorSid)
        else
            Trainfitter.ChatMsg(Trainfitter.L("download_error", wsid, tostring(err)), COL_ERR)
        end
    end)
end)

net.Receive(NET.ForgetSkin, function()
    local wsid         = net.ReadString()
    local initiatorSid = net.ReadString()
    if not isstring(wsid) or wsid == "" then return end

    Trainfitter.Mounted[wsid] = nil
    Trainfitter.LastMountInfo[wsid] = nil

    local owned = Trainfitter.MountedSkins[wsid]
    local removedCount = 0
    if owned and Metrostroi then
        for _, entry in ipairs(owned) do
            local rootTbl = (entry.kind == "mask") and Metrostroi.Masks or Metrostroi.Skins
            if istable(rootTbl) then
                local bucket = rootTbl[entry.category]
                if istable(bucket) and bucket[entry.name] ~= nil then
                    bucket[entry.name] = nil
                    removedCount = removedCount + 1
                end
            end
        end
    end
    Trainfitter.MountedSkins[wsid] = nil

    if removedCount > 0 then
        MsgC(Color(200, 200, 255),
            string.format("[Trainfitter] Removed %d entries from Metrostroi.Skins/Masks (wsid %s)\n",
                removedCount, wsid))
    end

    local localPath = "trainfitter/previews/" .. wsid .. ".png"
    if file.Exists(localPath, "DATA") then pcall(file.Delete, localPath) end

    for i = #Trainfitter.History, 1, -1 do
        if Trainfitter.History[i].wsid == wsid then
            table.remove(Trainfitter.History, i)
        end
    end

    if steamworks and isfunction(steamworks.Unsubscribe) then
        pcall(steamworks.Unsubscribe, wsid)
    end

    hook.Run("Trainfitter.SkinForgotten", wsid, initiatorSid)
    Trainfitter.ChatMsg(Trainfitter.L("skin_removed", wsid), COL_INFO)
end)

net.Receive(NET.ActiveSkin, function()
    local has = net.ReadBool()
    if not has then
        Trainfitter.ActiveSkin = nil
        hook.Run("Trainfitter.ActiveSkinChanged", nil)
        return
    end
    Trainfitter.ActiveSkin = {
        wsid         = net.ReadString(),
        title        = net.ReadString(),
        initiator    = net.ReadString(),
        sizeMB       = net.ReadFloat(),
        since        = net.ReadUInt(32),
        initiatorSid = net.ReadString(),
    }
    hook.Run("Trainfitter.ActiveSkinChanged", Trainfitter.ActiveSkin)
end)

net.Receive(NET.SyncPersistent, function()
    local n = net.ReadUInt(16)
    local list = {}
    for i = 1, n do list[i] = net.ReadString() end
    Trainfitter.PersistentList = list
    hook.Run("Trainfitter.PersistentUpdated", list)
end)

net.Receive(NET.Notify, function()
    local msg = net.ReadString()
    local col = net.ReadColor()
    local kind = NOTIFY_INFO
    if col and col.r and col.r > 220 and (col.g or 0) < 160 then
        kind = NOTIFY_ERR
    end
    ShowNotify(msg, kind, 6)
end)

net.Receive(NET.AdminConfig, function()
    local canManage   = net.ReadBool()
    local canViewLogs = net.ReadBool() --# порядок чтения = порядок записи на сервере
    local n = net.ReadUInt(8)
    local cvars = {}
    for i = 1, n do
        cvars[i] = {
            name  = net.ReadString(),
            kind  = net.ReadString(),
            value = net.ReadString(),
        }
    end
    Trainfitter.AdminConfig = { canManage = canManage, canViewLogs = canViewLogs, cvars = cvars }
    hook.Run("Trainfitter.AdminConfigUpdated", Trainfitter.AdminConfig)
end)

function Trainfitter.GetLogs(page, perPage)
    net.Start(NET.GetLogs)
    net.WriteUInt(math.max(0, page or 0), 16)
    net.WriteUInt(math.Clamp(perPage or 30, 1, 50), 8)
    net.SendToServer()
end

net.Receive(NET.Logs, function()
    local page  = net.ReadUInt(16)
    local total = net.ReadUInt(16)
    local count = net.ReadUInt(8)
    local entries = {}
    for i = 1, count do
        entries[i] = {
            stamp = net.ReadString(),
            nick  = net.ReadString(),
            sid   = net.ReadString(),
            rest  = net.ReadString(),
        }
    end
    Trainfitter.LogsData = { page = page, total = total, entries = entries }
    hook.Run("Trainfitter.LogsUpdated", Trainfitter.LogsData)
end)

net.Receive(NET.AdminListData, function()
    local lists = {}
    local cnt = net.ReadUInt(8)
    for _ = 1, cnt do
        local name = net.ReadString()
        local n    = net.ReadUInt(16)
        local arr  = {}
        for i = 1, n do arr[i] = net.ReadString() end
        if name ~= "" then lists[name] = arr end
    end
    Trainfitter.AdminLists = lists
    hook.Run("Trainfitter.AdminListsUpdated", lists)
end)

net.Receive(NET.Metrics, function()
    local m = {}
    m.queue      = net.ReadUInt(16)
    m.mounted    = net.ReadUInt(16)
    m.broadcasts = net.ReadUInt(16)
    m.persistent = net.ReadUInt(16)
    m.whitelist  = net.ReadUInt(16)
    m.blacklist  = net.ReadUInt(16)
    m.cache      = net.ReadUInt(16)
    m.steamworks = net.ReadBool()
    local topN = net.ReadUInt(8)
    m.top = {}
    for i = 1, topN do
        m.top[i] = { title = net.ReadString(), count = net.ReadUInt(16) }
    end
    local aN = net.ReadUInt(8)
    m.audit = {}
    for i = 1, aN do m.audit[i] = net.ReadString() end
    Trainfitter.Metrics = m
    hook.Run("Trainfitter.MetricsUpdated", m)
end)

net.Receive(NET.ServerStatus, function()
    local n = net.ReadUInt(4)
    for i = 1, n do
        local severity = net.ReadString()
        local msg      = net.ReadString()
        local kind = (severity == "error") and NOTIFY_ERR or NOTIFY_INFO
        ShowNotify("[Trainfitter] " .. msg, kind, 8)
    end
end)

local subscribeCooldown = subscribeCooldown or {}
local SUBSCRIBE_COOLDOWN_SEC = 60
local SUBSCRIBE_COOLDOWN_CAP = 256

local function PruneSubscribeCooldown()
    local now = SysTime()
    for k, t in pairs(subscribeCooldown) do
        if (now - t) > SUBSCRIBE_COOLDOWN_SEC then
            subscribeCooldown[k] = nil
        end
    end
    local count = 0
    for _ in pairs(subscribeCooldown) do count = count + 1 end
    if count > SUBSCRIBE_COOLDOWN_CAP then
        subscribeCooldown = {}
    end
end

function Trainfitter.Subscribe(wsid)
    if not isstring(wsid) or not string.match(wsid, "^%d+$") then return false end
    if not steamworks or not isfunction(steamworks.Subscribe) then return false end

    local cv = GetConVar("trainfitter_auto_subscribe")
    if cv and not cv:GetBool() then return false end

    if isfunction(game.IsDedicated) and game.IsDedicated() then return false end

    PruneSubscribeCooldown()

    local now = SysTime()
    local last = subscribeCooldown[wsid]
    if last and (now - last) < SUBSCRIBE_COOLDOWN_SEC then return false end
    subscribeCooldown[wsid] = now

    return pcall(steamworks.Subscribe, wsid)
end

function Trainfitter.Request(wsid, makeFavorite)
    if not isstring(wsid) or not string.match(wsid, "^%d+$") then return false end
    Trainfitter.Subscribe(wsid)
    net.Start(NET.Request)
    net.WriteString(wsid)
    net.WriteBool(makeFavorite == true)
    net.SendToServer()
    return true
end

function Trainfitter.RequestCollection(wsid)
    if not isstring(wsid) or not string.match(wsid, "^%d+$") then return false end
    if Trainfitter.AllowCollections and not Trainfitter.AllowCollections() then
        Trainfitter.ChatMsg(Trainfitter.L("collection_disabled"), COL_ERR)
        return false
    end
    --# применяет сервер: он сам тянет детей, режет по cap и обходит кулдаун
    Trainfitter.ChatMsg(Trainfitter.L("collection_reading"), COL_INFO)
    net.Start(NET.RequestCollection)
    net.WriteString(wsid)
    net.SendToServer()
    return true
end

function Trainfitter.RemovePersistent(wsid)
    if not isstring(wsid) or not string.match(wsid, "^%d+$") then return false end
    net.Start(NET.RemovePersistent)
    net.WriteString(wsid)
    net.SendToServer()
    return true
end

function Trainfitter.RequestList()
    net.Start(NET.RequestList)
    net.SendToServer()
end

function Trainfitter.RequestServerStatus()
    net.Start(NET.GetServerStatus)
    net.SendToServer()
end

function Trainfitter.DeleteSkin(wsid)
    if not isstring(wsid) or not string.match(wsid, "^%d+$") then return false end
    net.Start(NET.DeleteSkin)
    net.WriteString(wsid)
    net.SendToServer()
    return true
end

function Trainfitter.AdminGetConfig()
    net.Start(NET.AdminGetConfig)
    net.SendToServer()
end

function Trainfitter.AdminSetConVar(name, value)
    if not isstring(name) or not isstring(value) then return end
    if #name > 64 or #value > 32 then return end
    net.Start(NET.AdminSetConVar)
    net.WriteString(name)
    net.WriteString(value)
    net.SendToServer()
end

function Trainfitter.AdminManageList(listName, action, wsid)
    if not isstring(listName) or not isstring(action) or not isstring(wsid) then return end
    if #listName > 16 or #wsid > 20 then return end
    net.Start(NET.AdminManageList)
    net.WriteString(listName)
    net.WriteString(action)
    net.WriteString(wsid)
    net.SendToServer()
end

function Trainfitter.GetMetrics()
    net.Start(NET.GetMetrics)
    net.SendToServer()
end

local function GetTrainOwnerSid(ent)
    if not IsValid(ent) then return nil end
    local owner
    if isfunction(ent.CPPIGetOwner) then owner = ent:CPPIGetOwner() end
    if not IsValid(owner) and isfunction(ent.GetCreator) then owner = ent:GetCreator() end
    if not IsValid(owner) and IsValid(ent.Owner) then owner = ent.Owner end
    if IsValid(owner) and owner:IsPlayer() then return owner:SteamID64() end
    return nil
end

local function IsLocalPlayerInsideTrain(ent)
    local lp = LocalPlayer()
    if not IsValid(lp) then return false end
    local veh = lp:GetVehicle()
    if not IsValid(veh) then return false end
    local parent = veh:GetParent()
    while IsValid(parent) do
        if parent == ent then return true end
        parent = parent:GetParent()
    end
    return veh == ent
end

local TrainNWKey = Trainfitter.GetTrainNWKey

local function BuildPackSkinSet(wsid)
    local owned = wsid and Trainfitter.MountedSkins and Trainfitter.MountedSkins[wsid]
    if not istable(owned) or #owned == 0 then return nil end
    local set = {}
    for _, e in ipairs(owned) do
        local key = TrainNWKey(e.kind or "skin", e.category)
        if key and e.name and e.name ~= "" then
            set[key] = set[key] or {}
            set[key][e.name] = true
        end
    end
    if not next(set) then return nil end
    return set
end

local function TrainUsesPackSkin(ent, packSet)
    for key, names in pairs(packSet) do
        local cur = ent:GetNW2String(key, "")
        if cur ~= "" and names[cur] then return true end
    end
    return false
end

local function CollectSubwayTrains(ownerFilterSid, wsid)
    local packSet = wsid and BuildPackSkinSet(wsid) or nil
    local out = {}
    for _, ent in ipairs(ents.GetAll()) do
        if not IsValid(ent) then continue end
        local class = ent:GetClass()
        if not class or not string.StartWith(class, "gmod_subway_") then continue end
        if class == "gmod_subway_base" then continue end
        if IsLocalPlayerInsideTrain(ent) then continue end

        if ownerFilterSid and ownerFilterSid ~= "" then
            local sid = GetTrainOwnerSid(ent)
            if sid ~= ownerFilterSid then continue end
        end

        if packSet and not TrainUsesPackSkin(ent, packSet) then continue end

        out[#out + 1] = ent
    end
    return out
end

local RELOAD_BATCH = 4
local reloadBatchId = 0

function Trainfitter.ReloadAllTrains(ownerFilterSid, wsid)
    local trains = CollectSubwayTrains(ownerFilterSid, wsid)
    if #trains == 0 then return end

    reloadBatchId = reloadBatchId + 1
    local timerName = "Trainfitter.ReloadBatch." .. reloadBatchId
    local idx = 0
    local reloaded = 0

    timer.Create(timerName, 0.05, 0, function()
        for _ = 1, RELOAD_BATCH do
            idx = idx + 1
            local ent = trains[idx]
            if not ent then
                timer.Remove(timerName)
                if reloaded > 0 then
                    MsgC(Color(120, 220, 150), string.format(
                        "[Trainfitter] Re-apply skins (batched): %d trains updated\n", reloaded))
                end
                return
            end
            if IsValid(ent) and isfunction(ent.UpdateTextures) then
                ent.Texture      = nil
                ent.PassTexture  = nil
                ent.CabinTexture = nil
                local ok = pcall(ent.UpdateTextures, ent)
                if ok then reloaded = reloaded + 1 end
            end
        end
    end)
end

hook.Add("Trainfitter.AddonMounted", "Trainfitter.ReloadTrains", function(wsid, info, initiatorSid)
    timer.Simple(1.0, function() Trainfitter.ReloadAllTrains(initiatorSid, wsid) end)
end)

hook.Add("Trainfitter.SkinForgotten", "Trainfitter.ReloadTrains", function(wsid, initiatorSid)
    timer.Simple(1.0, function() Trainfitter.ReloadAllTrains(initiatorSid, wsid) end)
end)

hook.Add("InitPostEntity", "Trainfitter.RequestInitial", function()
    timer.Simple(8, function() Trainfitter.RequestList() end)
end)
