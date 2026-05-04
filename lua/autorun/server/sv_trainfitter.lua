-- Trainfitter — sv_trainfitter.lua
-- Made by SellingVika.

if not steamworks or not isfunction(steamworks.DownloadUGC) then
    local hasModule = isfunction(util.IsBinaryModuleInstalled)
                  and util.IsBinaryModuleInstalled("workshop")
    if hasModule then
        local ok, err = pcall(require, "workshop")
        if ok and steamworks and isfunction(steamworks.DownloadUGC) then
            MsgC(Color(120, 220, 150),
                "[Trainfitter] gmsv_workshop loaded — server has native steamworks.DownloadUGC.\n")
        elseif ok then
            MsgC(Color(255, 180, 80),
                "[Trainfitter] gmsv_workshop loaded but steamworks.DownloadUGC still nil — falling back to HTTP fetch.\n")
        else
            MsgC(Color(255, 180, 80),
                "[Trainfitter] require('workshop') failed: " .. tostring(err)
                .. " — falling back to HTTP fetch.\n")
        end
    else
        MsgC(Color(255, 180, 80),
            "[Trainfitter] gmsv_workshop binary not installed — using HTTP fetch.\n" ..
            "[Trainfitter] For dedicated x32 srcds put gmsv_workshop_<platform>.dll into garrysmod/lua/bin/\n" ..
            "[Trainfitter] (faster + more stable). For listen-server / x64 — HTTP is the right choice anyway.\n")
    end
end

local NET = Trainfitter.Net

for _, name in pairs(NET) do util.AddNetworkString(name) end

Trainfitter.Persistent        = Trainfitter.Persistent or {}
Trainfitter.Whitelist         = Trainfitter.Whitelist or {}
Trainfitter.Blacklist         = Trainfitter.Blacklist or {}
Trainfitter.Stats             = Trainfitter.Stats or {}
Trainfitter.SessionBroadcast  = Trainfitter.SessionBroadcast or {}
Trainfitter.MountedServer     = Trainfitter.MountedServer or {}
Trainfitter.NickCache         = Trainfitter.NickCache or {}
Trainfitter.SkinOwnership     = Trainfitter.SkinOwnership or {}
Trainfitter.PendingRequest    = Trainfitter.PendingRequest or {}
Trainfitter.ActiveSkin        = Trainfitter.ActiveSkin

local PERSIST_DIR     = "trainfitter"
local PERSIST_FILE    = PERSIST_DIR .. "/persistent.json"
local WHITELIST_FILE  = PERSIST_DIR .. "/whitelist.json"
local BLACKLIST_FILE  = PERSIST_DIR .. "/blacklist.json"
local STATS_FILE      = PERSIST_DIR .. "/stats.json"
local NICKS_FILE      = PERSIST_DIR .. "/nicks.json"
local AUDIT_FILE      = PERSIST_DIR .. "/audit.log"
local AUDIT_FILE_OLD  = PERSIST_DIR .. "/audit.log.old"

local lastRequest = {}
local lastListReq = {}

local function IsValidWSID(s)
    if not isstring(s) then return false end
    if #s < 4 or #s > Trainfitter.WSID_MAX_LEN then return false end
    return string.match(s, "^%d+$") ~= nil
end

local function EnsureDir()
    if not file.IsDir(PERSIST_DIR, "DATA") then file.CreateDir(PERSIST_DIR) end
end

local function ReadJSON(path, default)
    if not file.Exists(path, "DATA") then return default end
    local raw = file.Read(path, "DATA") or ""
    local ok, data = pcall(util.JSONToTable, raw)
    if ok and istable(data) then return data end
    return default
end

local function WriteJSON(path, data)
    EnsureDir()
    file.Write(path, util.TableToJSON(data, true))
end

local function Notify(ply, msg, color)
    if not IsValid(ply) then return end
    net.Start(NET.Notify)
    net.WriteString(msg)
    net.WriteColor(color or Color(255, 200, 100))
    net.Send(ply)
end

local function Sanitize(s, maxLen)
    if not isstring(s) then s = tostring(s or "") end
    s = string.gsub(s, "[\r\n\t]", " ")
    if maxLen and #s > maxLen then s = string.sub(s, 1, maxLen) .. "..." end
    return s
end

local function Audit(ply, action, details)
    if not GetConVar("trainfitter_audit_log"):GetBool() then return end
    EnsureDir()

    local sid   = IsValid(ply) and (ply:SteamID64() or "0") or "CONSOLE"
    local stamp = os.date("%Y-%m-%d %H:%M:%S")
    local line  = string.format("[%s] %s %s :: %s\n",
        stamp, sid, Sanitize(action, 32), Sanitize(details or "", 256))

    if file.Exists(AUDIT_FILE, "DATA") and file.Size(AUDIT_FILE, "DATA") > 1024 * 1024 then
        if file.Exists(AUDIT_FILE_OLD, "DATA") then file.Delete(AUDIT_FILE_OLD) end
        file.Rename(AUDIT_FILE, AUDIT_FILE_OLD)
    end
    file.Append(AUDIT_FILE, line)
end

local nicksDirty = false

local function LoadNicks()
    local data = ReadJSON(NICKS_FILE, {})
    local clean = {}
    for sid, nick in pairs(data) do
        if isstring(sid) and string.match(sid, "^%d+$") and isstring(nick) then
            clean[sid] = string.sub(nick, 1, 64)
        end
    end
    Trainfitter.NickCache = clean
end

local function SaveNicks() WriteJSON(NICKS_FILE, Trainfitter.NickCache) end

function Trainfitter.ResolveName(sid64)
    if not isstring(sid64) or sid64 == "" or sid64 == "0" then return "Console" end
    local ply = player.GetBySteamID64 and player.GetBySteamID64(sid64)
    if IsValid(ply) then
        local nick = ply:Nick()
        if Trainfitter.NickCache[sid64] ~= nick then
            Trainfitter.NickCache[sid64] = nick
            nicksDirty = true
        end
        return nick
    end
    return Trainfitter.NickCache[sid64] or "<unknown>"
end

hook.Add("PlayerInitialSpawn", "Trainfitter.NickCache", function(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID64()
    if not sid then return end
    if Trainfitter.NickCache[sid] ~= ply:Nick() then
        Trainfitter.NickCache[sid] = ply:Nick()
        nicksDirty = true
    end
end)

timer.Create("Trainfitter.NicksFlush", 60, 0, function()
    if nicksDirty then SaveNicks(); nicksDirty = false end
end)

hook.Add("ShutDown", "Trainfitter.NicksFlushShutdown", function()
    if nicksDirty then SaveNicks() end
end)

local function SavePersistent() WriteJSON(PERSIST_FILE, Trainfitter.Persistent) end

local function LoadPersistent()
    local data = ReadJSON(PERSIST_FILE, {})
    local clean = {}
    local maxP = GetConVar("trainfitter_max_persistent"):GetInt()
    local dropped = 0
    for _, wsid in ipairs(data) do
        if IsValidWSID(wsid) then
            if #clean < maxP then
                table.insert(clean, wsid)
            else
                dropped = dropped + 1
            end
        end
    end
    Trainfitter.Persistent = clean
    if dropped > 0 then
        MsgC(Color(255, 180, 80), string.format(
            "[Trainfitter] Trimmed persistent.json: %d wsid over cap %d\n",
            dropped, maxP))
    end
end

local function SetFromArray(arr)
    local t = {}
    for _, v in ipairs(arr) do
        if IsValidWSID(v) then t[v] = true end
    end
    return t
end

local function ArrayFromSet(s)
    local arr = {}
    for wsid in pairs(s) do table.insert(arr, wsid) end
    table.sort(arr)
    return arr
end

local function LoadLists()
    Trainfitter.Whitelist = SetFromArray(ReadJSON(WHITELIST_FILE, {}))
    Trainfitter.Blacklist = SetFromArray(ReadJSON(BLACKLIST_FILE, {}))
end

local function SaveWhitelist() WriteJSON(WHITELIST_FILE, ArrayFromSet(Trainfitter.Whitelist)) end
local function SaveBlacklist() WriteJSON(BLACKLIST_FILE, ArrayFromSet(Trainfitter.Blacklist)) end

local function CheckLists(wsid)
    if Trainfitter.Blacklist[wsid] then
        return "addon is blacklisted"
    end
    if GetConVar("trainfitter_use_whitelist"):GetBool() then
        if not Trainfitter.Whitelist[wsid] then
            return "whitelist enabled, this addon is not on it"
        end
    end
    return nil
end

local function LoadStats()
    local data = ReadJSON(STATS_FILE, {})
    local clean = {}
    for wsid, info in pairs(data) do
        if IsValidWSID(wsid) and istable(info) then
            clean[wsid] = {
                count = tonumber(info.count) or 0,
                title = tostring(info.title or ""),
                last  = tonumber(info.last) or 0,
            }
        end
    end
    Trainfitter.Stats = clean
end

local function SaveStats() WriteJSON(STATS_FILE, Trainfitter.Stats) end

local statsDirty = false
local function BumpStats(wsid, title)
    if not GetConVar("trainfitter_stats_enabled"):GetBool() then return end
    local s = Trainfitter.Stats[wsid] or { count = 0, title = "", last = 0 }
    s.count = s.count + 1
    if title and title ~= "" then s.title = title end
    s.last = os.time()
    Trainfitter.Stats[wsid] = s
    statsDirty = true
end

timer.Create("Trainfitter.StatsFlush", 30, 0, function()
    if statsDirty then
        SaveStats()
        statsDirty = false
    end
end)

hook.Add("ShutDown", "Trainfitter.StatsFlushShutdown", function()
    if statsDirty then SaveStats() end
end)

local function ServerHasSteamworks()
    return steamworks ~= nil
       and isfunction(steamworks.DownloadUGC)
       and isfunction(game.MountGMA)
end

local function ShouldUseHttp()
    local cv = GetConVar("trainfitter_use_http")
    if cv and cv:GetBool() then return true end
    if not ServerHasSteamworks() then return true end
    if isfunction(game.IsDedicated) and not game.IsDedicated() then return true end
    return false
end

local GMA_CACHE_DIR = PERSIST_DIR .. "/gmas"

local function SweepStaleGMACache()
    if not file.IsDir(GMA_CACHE_DIR, "DATA") then return end
    local files = file.Find(GMA_CACHE_DIR .. "/*.gma", "DATA") or {}
    local removed, kept = 0, 0
    for _, fname in ipairs(files) do
        local rel  = GMA_CACHE_DIR .. "/" .. fname
        local size = file.Size(rel, "DATA") or 0
        local age  = os.time() - (file.Time(rel, "DATA") or 0)
        if size < 1000 or age > 30 * 24 * 3600 then
            pcall(file.Delete, rel)
            removed = removed + 1
        else
            kept = kept + 1
        end
    end
    if removed > 0 then
        MsgC(Color(200, 220, 255), string.format(
            "[Trainfitter] Cache sweep: removed %d broken/stale GMA(s), kept %d.\n",
            removed, kept))
    end
end

local function InvalidateGMACache(wsid)
    if not isstring(wsid) or wsid == "" then return end
    local cacheFile = GMA_CACHE_DIR .. "/" .. wsid .. ".gma"
    if file.Exists(cacheFile, "DATA") then
        pcall(file.Delete, cacheFile)
        MsgC(Color(255, 200, 120),
            "[Trainfitter] Invalidated HTTP cache for " .. wsid .. "\n")
    end
end

local function FindSubscribedAddonPath(wsid)
    if not isfunction(engine.GetAddons) then return nil end
    local list = engine.GetAddons() or {}
    for _, a in ipairs(list) do
        if a and tostring(a.wsid or "") == wsid then
            local p = a.file
            if isstring(p) and p ~= "" and file.Exists(p, "GAME") then
                return p
            end
        end
    end
    return nil
end

local function HttpFetchGMA(wsid, callback)
    if not isfunction(game.MountGMA) then
        callback(nil, "MountGMA missing")
        return
    end
    if not file.IsDir(PERSIST_DIR, "DATA") then file.CreateDir(PERSIST_DIR) end
    if not file.IsDir(GMA_CACHE_DIR, "DATA") then file.CreateDir(GMA_CACHE_DIR) end

    local cacheFile = GMA_CACHE_DIR .. "/" .. wsid .. ".gma"
    local cacheAbs  = "data/" .. cacheFile

    if file.Exists(cacheFile, "DATA") and (file.Size(cacheFile, "DATA") or 0) > 1000 then
        callback(cacheAbs)
        return
    end

    Trainfitter.SafeFetchWorkshopInfo(wsid, function(info, err)
        if not info then
            callback(nil, "metadata fetch failed: " .. tostring(err or "unknown"))
            return
        end

        if isstring(info.file_url) and info.file_url ~= "" then
            local maxBytes = (GetConVar("trainfitter_max_mb"):GetInt() or 200) * 1024 * 1024
            http.Fetch(info.file_url, function(gmaBody)
                if not gmaBody or #gmaBody < 1000 then
                    callback(nil, "GMA body too small")
                    return
                end
                if #gmaBody > maxBytes then
                    callback(nil, string.format(
                        "GMA body too large (%d B > limit %d B)", #gmaBody, maxBytes))
                    return
                end
                if string.sub(gmaBody, 1, 4) ~= "GMAD" then
                    callback(nil, "downloaded payload is not a GMA")
                    return
                end
                file.Write(cacheFile, gmaBody)
                MsgC(Color(120, 220, 150), string.format(
                    "[Trainfitter] HTTP-fetched GMA: %s (%.1f MB)\n",
                    wsid, #gmaBody / 1024 / 1024))
                callback(cacheAbs)
            end, function(httpErr) callback(nil, "http.Fetch: " .. tostring(httpErr)) end)
            return
        end

        local subPath = FindSubscribedAddonPath(wsid)
        if subPath then
            MsgC(Color(120, 220, 150),
                "[Trainfitter] Using already-subscribed addon path: " .. subPath .. "\n")
            callback(subPath)
            return
        end

        if steamworks and isfunction(steamworks.Subscribe) then
            MsgC(Color(180, 220, 255), string.format(
                "[Trainfitter] No file_url and not subscribed yet. "
                .. "Asking Steam to subscribe %s and waiting for the download…\n", wsid))
            pcall(steamworks.Subscribe, wsid)

            local timerName = "trainfitter_sub_wait_" .. wsid
            local elapsed   = 0
            local maxWait   = 60
            timer.Create(timerName, 1, maxWait, function()
                elapsed = elapsed + 1
                local p = FindSubscribedAddonPath(wsid)
                if p then
                    timer.Remove(timerName)
                    MsgC(Color(120, 220, 150),
                        "[Trainfitter] Steam finished subscription for " .. wsid
                        .. " (after " .. elapsed .. "s): " .. p .. "\n")
                    callback(p)
                elseif elapsed >= maxWait then
                    timer.Remove(timerName)
                    callback(nil, "subscribe + wait timed out after " .. maxWait .. "s")
                end
            end)
            return
        end

        callback(nil,
            "no file_url in Steam response and item not subscribed in Steam. "
            .. "Workaround: open the addon page (browser) and click Subscribe, then retry. "
            .. "On dedicated server install gmsv_workshop and trainfitter_use_http 0.")
    end)
end

local function SnapshotMetrostroiTable(t)
    local snap = {}
    if not istable(t) then return snap end
    for category, bucket in pairs(t) do
        if istable(bucket) then
            snap[category] = {}
            for n in pairs(bucket) do snap[category][n] = true end
        end
    end
    return snap
end

local function ServerExecuteSkinFiles(files, wsid)
    if not istable(files) then return 0 end
    local beforeSkins = Metrostroi and SnapshotMetrostroiTable(Metrostroi.Skins) or {}
    local beforeMasks = Metrostroi and SnapshotMetrostroiTable(Metrostroi.Masks) or {}

    local function execFile(fp)
        local c = file.Read(fp, "GAME")
        if not isstring(c) or #c == 0 then return false end

        if Trainfitter.ValidateSkinLua
           and Trainfitter.ShouldContentScan
           and Trainfitter.ShouldContentScan() then
            local ok, reason = Trainfitter.ValidateSkinLua(c, fp)
            if not ok then
                MsgC(Color(255, 120, 120),
                    "[Trainfitter] Refused to execute skin file: "
                    .. tostring(reason) .. "\n")
                if Audit then
                    pcall(Audit, nil, "skin_exec_rejected", tostring(reason))
                end
                return false
            end
        end

        local fn = CompileString(c, fp, false)
        if isstring(fn) or not isfunction(fn) then return false end
        return pcall(fn)
    end

    local executed = 0
    for _, fpath in ipairs(files) do
        if isstring(fpath) and string.sub(string.lower(fpath), -4) == ".lua" then
            local low = string.lower(fpath)
            local rel = string.sub(low, 5)
            if string.sub(low, 1, 21) == "lua/metrostroi/skins/"
               or string.sub(low, 1, 21) == "lua/metrostroi/masks/" then
                if execFile(fpath) then executed = executed + 1 end
                pcall(AddCSLuaFile, rel)
            end
        end
    end

    local function diffInto(currentTbl, beforeTbl, owned, seen, kind)
        if not istable(currentTbl) then return end
        for category, bucket in pairs(currentTbl) do
            if istable(bucket) then
                for name, data in pairs(bucket) do
                    local wasBefore = beforeTbl[category] and beforeTbl[category][name]
                    local key = kind .. "|" .. category .. "|" .. name
                    if not wasBefore and not seen[key] then
                        seen[key] = true
                        local typ = (istable(data) and data.typ) or ""
                        table.insert(owned, {
                            kind     = kind,
                            category = category,
                            name     = name,
                            typ      = typ,
                        })
                    end
                end
            end
        end
    end

    if Metrostroi then
        local owned = Trainfitter.SkinOwnership[wsid] or {}
        local seen = {}
        for _, e in ipairs(owned) do
            seen[(e.kind or "skin") .. "|" .. e.category .. "|" .. e.name] = true
        end
        diffInto(Metrostroi.Skins, beforeSkins, owned, seen, "skin")
        diffInto(Metrostroi.Masks, beforeMasks, owned, seen, "mask")
        Trainfitter.SkinOwnership[wsid] = owned
    end

    return executed
end

local serverMountQueue    = {}
local serverMountInFlight = false

local function finalize(wsid, ok, reason)
    if Trainfitter.FinalizePending then
        pcall(Trainfitter.FinalizePending, wsid, ok, reason)
    end
end

local function onGMAReady(wsid, path)
    if not path then
        finalize(wsid, false, "download failed")
        serverMountInFlight = false
        processServerMountQueue()
        return
    end

    if Trainfitter.ScanGMA and Trainfitter.ShouldScanGMA and Trainfitter.ShouldScanGMA() then
        local callOK, safe, reason = pcall(Trainfitter.ScanGMA, path)
        if not callOK then
            MsgC(Color(255, 120, 120), string.format(
                "[Trainfitter] Scanner crashed on %s: %s — REFUSING mount.\n",
                wsid, tostring(safe)))
            if Audit then
                pcall(Audit, nil, "scanner_crashed_refused",
                    wsid .. " :: " .. tostring(safe))
            end
            InvalidateGMACache(wsid)
            finalize(wsid, false, "scanner crashed: " .. tostring(safe))
            serverMountInFlight = false
            processServerMountQueue()
            return
        elseif not safe then
            MsgC(Color(255, 120, 120), string.format(
                "[Trainfitter] Server refused to mount %s: %s\n",
                wsid, tostring(reason)))
            if Audit then
                pcall(Audit, nil, "server_mount_rejected",
                    wsid .. " :: " .. tostring(reason))
            end
            InvalidateGMACache(wsid)
            finalize(wsid, false, tostring(reason))
            serverMountInFlight = false
            processServerMountQueue()
            return
        end
    end

    local ok, files = game.MountGMA(path)
    if ok and istable(files) then
        Trainfitter.MountedServer[wsid] = true
        local executed = ServerExecuteSkinFiles(files, wsid)
        MsgC(Color(120, 220, 150), string.format(
            "[Trainfitter] Server mounted %s: %d skin scripts executed\n",
            wsid, executed))
        finalize(wsid, true)
    else
        MsgC(Color(255, 120, 120), string.format(
            "[Trainfitter] MountGMA failed for %s\n", wsid))
        InvalidateGMACache(wsid)
        finalize(wsid, false, "MountGMA failed")
    end
    serverMountInFlight = false
    processServerMountQueue()
end

local function safeNativeDownload(wsid, cb)
    timer.Simple(0, function()
        local ok, err = pcall(steamworks.DownloadUGC, wsid, function(path, _f)
            cb(path)
        end)
        if not ok then
            MsgC(Color(255, 120, 120), string.format(
                "[Trainfitter] steamworks.DownloadUGC threw on %s: %s\n",
                wsid, tostring(err)))
            cb(nil)
        end
    end)
end

local SERVER_MOUNT_TIMEOUT = 90

function processServerMountQueue()
    if serverMountInFlight or #serverMountQueue == 0 then return end
    local wsid = table.remove(serverMountQueue, 1)
    if Trainfitter.MountedServer[wsid] then
        processServerMountQueue()
        return
    end

    serverMountInFlight = true

    local watchdogName = "Trainfitter.MountWatchdog." .. wsid
    local fired = false
    timer.Create(watchdogName, SERVER_MOUNT_TIMEOUT, 1, function()
        if fired then return end
        fired = true
        MsgC(Color(255, 120, 120), string.format(
            "[Trainfitter] Mount watchdog: %s did not finish within %ds, releasing queue.\n",
            wsid, SERVER_MOUNT_TIMEOUT))
        finalize(wsid, false, "mount timeout")
        serverMountInFlight = false
        processServerMountQueue()
    end)

    local function done(path)
        if fired then return end
        fired = true
        timer.Remove(watchdogName)
        onGMAReady(wsid, path)
    end

    if ShouldUseHttp() then
        HttpFetchGMA(wsid, function(path, err)
            if not path and err then
                MsgC(Color(255, 120, 120), string.format(
                    "[Trainfitter] HTTP fetch failed for %s: %s\n", wsid, tostring(err)))
            end
            done(path)
        end)
    else
        safeNativeDownload(wsid, function(path)
            done(path)
        end)
    end
end

local MAX_SERVER_QUEUE = 64

local function ServerMount(wsid)
    if not IsValidWSID(wsid) then return end
    if not isfunction(game.MountGMA) then return end
    if Trainfitter.MountedServer[wsid] then return end
    for _, q in ipairs(serverMountQueue) do
        if q == wsid then return end
    end
    if #serverMountQueue >= MAX_SERVER_QUEUE then
        MsgC(Color(255, 180, 80), string.format(
            "[Trainfitter] Server mount queue full (%d). Dropping %s.\n",
            MAX_SERVER_QUEUE, wsid))
        return
    end
    table.insert(serverMountQueue, wsid)
    processServerMountQueue()
end

Trainfitter.ServerSteamworksUnavailable = false

local function ServerMountPersistent()
    if Trainfitter.IntegrityGuard and Trainfitter.IntegrityGuard() then return end
    if not GetConVar("trainfitter_server_premount"):GetBool() then return end
    if not isfunction(game.MountGMA) then return end

    Trainfitter.ServerSteamworksUnavailable = not ServerHasSteamworks()
    for _, wsid in ipairs(Trainfitter.Persistent) do
        ServerMount(wsid)
    end
end

local function SendPersistentList(target)
    net.Start(NET.SyncPersistent)
    net.WriteUInt(#Trainfitter.Persistent, 16)
    for _, wsid in ipairs(Trainfitter.Persistent) do
        net.WriteString(wsid)
    end
    if target then net.Send(target) else net.Broadcast() end
end

local function BroadcastDownload(wsid, initiatorName, title, sizeMB, initiatorSid)
    Trainfitter.SessionBroadcast[wsid] = {
        title         = title or "",
        sizeMB        = sizeMB or 0,
        since         = os.time(),
        initiatorSid  = initiatorSid or "",
        initiatorName = initiatorName or "",
    }

    net.Start(NET.Broadcast)
    net.WriteString(wsid)
    net.WriteString(initiatorName or "")
    net.WriteString(title or "")
    net.WriteFloat(sizeMB or 0)
    net.WriteString(initiatorSid or "")
    net.Broadcast()
end

local SKIN_NW_KEYS = {
    train = "Texture",
    pass  = "PassTexture",
    cab   = "CabTexture",
}

local MASK_NW_KEYS = {
    front    = "MaskTexture",
    mask     = "MaskTexture",
    rear     = "RearMaskTexture",
    rearmask = "RearMaskTexture",
}

local function GetTrainNWKey(kind, category)
    if kind == "mask" then
        return MASK_NW_KEYS[category]
    end
    return SKIN_NW_KEYS[category]
end

local function ResetTrainsForOwnedSkins(owned)
    if not istable(owned) then return 0 end

    local byKey = {}
    for _, entry in ipairs(owned) do
        local key = GetTrainNWKey(entry.kind or "skin", entry.category)
        if key and entry.name and entry.name ~= "" then
            byKey[key] = byKey[key] or {}
            byKey[key][entry.name] = true
        end
    end
    if not next(byKey) then return 0 end

    local reset = 0
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) then
            local class = ent:GetClass()
            if class and string.StartWith(class, "gmod_subway_")
               and class ~= "gmod_subway_base" then
                for key, names in pairs(byKey) do
                    local current = ent:GetNW2String(key, "")
                    if names[current] then
                        ent:SetNW2String(key, "")
                        reset = reset + 1
                    end
                end
            end
        end
    end
    return reset
end

function BroadcastForget(wsid, initiatorSid)
    if not wsid or wsid == "" then return end
    Trainfitter.SessionBroadcast[wsid] = nil
    Trainfitter.MountedServer[wsid] = nil

    local owned = Trainfitter.SkinOwnership[wsid]
    local resetCount = 0
    if owned then
        resetCount = ResetTrainsForOwnedSkins(owned)
        if Metrostroi then
            for _, entry in ipairs(owned) do
                local rootTbl = (entry.kind == "mask") and Metrostroi.Masks or Metrostroi.Skins
                if istable(rootTbl) then
                    local bucket = rootTbl[entry.category]
                    if istable(bucket) then
                        local rec = bucket[entry.name]
                        if istable(rec) and rec._trainfitter_stub then
                            bucket[entry.name] = nil
                        end
                    end
                end
            end
        end
        Trainfitter.SkinOwnership[wsid] = nil
    end
    if resetCount > 0 then
        MsgC(Color(200, 220, 255),
            string.format("[Trainfitter] Reset NW2String on %d trains (wsid %s)\n",
                resetCount, wsid))
    end

    net.Start(NET.ForgetSkin)
    net.WriteString(wsid)
    net.WriteString(initiatorSid or "")
    net.Broadcast()
end

local function SendActiveSkin(target)
    local a = Trainfitter.ActiveSkin
    net.Start(NET.ActiveSkin)
    if a then
        net.WriteBool(true)
        net.WriteString(a.wsid)
        net.WriteString(a.title or "")
        net.WriteString(a.initiator or "")
        net.WriteFloat(a.sizeMB or 0)
        net.WriteUInt(a.since or 0, 32)
        net.WriteString(a.initiatorSid or "")
    else
        net.WriteBool(false)
    end
    if target then net.Send(target) else net.Broadcast() end
end

local function SetActiveSkin(wsid, title, sizeMB, initiatorName, initiatorSid)
    local old = Trainfitter.ActiveSkin
    Trainfitter.ActiveSkin = {
        wsid         = wsid,
        title        = title or "",
        sizeMB       = sizeMB or 0,
        initiator    = initiatorName or "",
        initiatorSid = initiatorSid or "",
        since        = os.time(),
    }
    SendActiveSkin()

    if old and old.wsid and old.wsid ~= wsid then
        local inFav = false
        for _, f in ipairs(Trainfitter.Persistent) do
            if f == old.wsid then inFav = true break end
        end
        if not inFav then
            BroadcastForget(old.wsid, initiatorSid)
        end
    end
end

local function HandleRequest(ply, wsid, makePersistent)
    if not IsValid(ply) then return end

    if Trainfitter.IntegrityGuard and Trainfitter.IntegrityGuard() then
        Notify(ply, "[Trainfitter] Addon files were modified — refusing to operate. Tell the admin.",
            Color(255, 100, 100))
        return
    end

    if not IsValidWSID(wsid) then
        Notify(ply, "[Trainfitter] Invalid WSID.", Color(255, 100, 100))
        return
    end


    if not Trainfitter.CanDownload(ply) then
        Notify(ply, "[Trainfitter] Not enough permissions to download.", Color(255, 100, 100))
        return
    end

    local reason = CheckLists(wsid)
    if reason then
        Notify(ply, "[Trainfitter] Denied: " .. reason .. ".", Color(255, 100, 100))
        Audit(ply, "request_rejected", wsid .. " (" .. reason .. ")")
        return
    end

    local sid = ply:SteamID64() or "0"
    local now = CurTime()
    local cd  = GetConVar("trainfitter_request_cooldown"):GetFloat()
    if lastRequest[sid] and (now - lastRequest[sid]) < cd then
        Notify(ply, "[Trainfitter] Too often. Wait a bit.",
            Color(255, 180, 80))
        return
    end

    lastRequest[sid] = now

    local hookret = hook.Run("Trainfitter.CanRequest", ply, wsid, makePersistent)
    if hookret == false then
        Notify(ply, "[Trainfitter] Request rejected by server hook.",
            Color(255, 100, 100))
        Audit(ply, "hook_rejected", wsid)
        return
    end

    if makePersistent and not Trainfitter.CanMakePersistent(ply) then
        Notify(ply, "[Trainfitter] Only admins can mark addon as persistent.",
            Color(255, 100, 100))
        makePersistent = false
    end

    local maxMB = GetConVar("trainfitter_max_mb"):GetInt()
    Trainfitter.SafeFetchWorkshopInfo(wsid, function(info, err)
        if not IsValid(ply) then return end

        if not info or not info.title or info.title == "" then
            Notify(ply, "[Trainfitter] Addon " .. wsid .. " not found in Workshop"
                .. (err and (" (" .. err .. ")") or "."), Color(255, 100, 100))
            Audit(ply, "request_rejected", wsid .. " (not found: " .. tostring(err or "no title") .. ")")
            return
        end

        local appid = info.creator_appid or info.consumer_appid
        if appid and appid ~= Trainfitter.GMOD_APPID then
            Notify(ply, string.format(
                "[Trainfitter] '%s' is not a Garry's Mod addon (appid %s). Denied.",
                info.title or wsid, tostring(appid)), Color(255, 100, 100))
            Audit(ply, "request_rejected", wsid .. " (wrong appid)")
            return
        end

        local sizeMB = (info.size or 0) / (1024 * 1024)
        if sizeMB > maxMB then
            Notify(ply, string.format(
                "[Trainfitter] '%s' weighs %.1f MB, limit %d MB. Denied.",
                info.title, sizeMB, maxMB), Color(255, 100, 100))
            Audit(ply, "request_rejected", string.format("%s (%.1f MB > %d MB)", wsid, sizeMB, maxMB))
            return
        end

        local extra = sizeMB / 10
        lastRequest[sid] = CurTime() + extra

        Trainfitter.PendingRequest[wsid] = {
            initiatorSid    = sid,
            initiatorName   = ply:Nick(),
            title           = info.title,
            sizeMB          = sizeMB,
            makePersistent  = makePersistent,
            since           = os.time(),
        }

        Notify(ply, string.format(
            "[Trainfitter] Validating '%s' on server (%.1f MB)…",
            info.title, sizeMB), Color(150, 220, 255))
        Audit(ply, "download_requested",
            string.format("%s '%s' (%.1f MB)", wsid, info.title, sizeMB))

        if Trainfitter.MountedServer[wsid] then
            finalize(wsid, true)
        else
            ServerMount(wsid)
        end
    end)
end

function Trainfitter.FinalizePending(wsid, ok, reason)
    local p = Trainfitter.PendingRequest[wsid]
    if not p then return end
    Trainfitter.PendingRequest[wsid] = nil

    local initiator = nil
    if p.initiatorSid and player.GetBySteamID64 then
        initiator = player.GetBySteamID64(p.initiatorSid)
    end

    if not ok then
        if IsValid(initiator) then
            Notify(initiator, string.format(
                "[Trainfitter] Failed to install '%s': %s",
                p.title or wsid, tostring(reason or "unknown")),
                Color(255, 110, 110))
        end
        if Audit then
            pcall(Audit, nil, "request_finalize_failed",
                wsid .. " :: " .. tostring(reason or "unknown"))
        end
        return
    end

    BroadcastDownload(wsid, p.initiatorName or "", p.title or "", p.sizeMB or 0, p.initiatorSid or "")
    SetActiveSkin(wsid, p.title, p.sizeMB, p.initiatorName, p.initiatorSid)
    BumpStats(wsid, p.title)
    if Audit then
        pcall(Audit, nil, "download_broadcast",
            string.format("%s '%s' (%.1f MB)", wsid,
                p.title or "", p.sizeMB or 0))
    end

    local nickForMsg = p.initiatorName
    if (not nickForMsg) or nickForMsg == "" then nickForMsg = "Server" end

    for _, pl in ipairs(player.GetAll()) do
        Notify(pl, string.format(
            "[Trainfitter] %s installed '%s' (%.1f MB)",
            nickForMsg, p.title or wsid, p.sizeMB or 0),
            Color(150, 220, 255))
    end

    if p.makePersistent then
        local old = Trainfitter.Persistent[1]
        if old ~= wsid then
            Trainfitter.Persistent = { wsid }
            SavePersistent()
            SendPersistentList()
            ServerMount(wsid)
            if IsValid(initiator) then
                Notify(initiator, "[Trainfitter] '" .. (p.title or wsid)
                    .. "' saved as active skin.", Color(100, 255, 150))
            end
            if Audit then
                pcall(Audit, nil, "persistent_added",
                    wsid .. " '" .. (p.title or "") .. "'")
            end
            if old then
                BroadcastForget(old, p.initiatorSid or "")
                if Audit then pcall(Audit, nil, "persistent_replaced", "forgot " .. old) end
            end
        end
    end
end

net.Receive(NET.Request, function(len, ply)
    if len > 128 * 8 then
        Audit(ply, "netspam_rejected", "NET.Request len=" .. len)
        return
    end
    local wsid = net.ReadString()
    local persist = net.ReadBool()
    HandleRequest(ply, wsid, persist)
end)

net.Receive(NET.RemovePersistent, function(len, ply)
    if len > 128 * 8 then
        Audit(ply, "netspam_rejected", "NET.RemovePersistent len=" .. len)
        return
    end
    if not Trainfitter.CanMakePersistent(ply) then
        Notify(ply, "[Trainfitter] No permission to remove persistent.", Color(255, 100, 100))
        return
    end
    local wsid = net.ReadString()
    if not IsValidWSID(wsid) then return end

    local removed = false
    for i, existing in ipairs(Trainfitter.Persistent) do
        if existing == wsid then
            table.remove(Trainfitter.Persistent, i)
            removed = true
            break
        end
    end
    if removed then
        SavePersistent()
        SendPersistentList()
        Notify(ply, "[Trainfitter] WSID " .. wsid .. " removed from persistent.",
            Color(255, 220, 120))
        Audit(ply, "persistent_removed", wsid)
    end
end)

local function BuildServerIssues()
    local issues = {}

    if not Metrostroi then
        table.insert(issues, {
            severity = "error",
            msg = "Metrostroi Subway Simulator not detected on the server. Skins won't work.",
        })
    end

    local isDedicated = isfunction(game.IsDedicated) and game.IsDedicated() or false
    if not ServerHasSteamworks() and isDedicated then
        table.insert(issues, {
            severity = "warn",
            msg = "gmsv_workshop not installed on dedicated server. HTTP fallback is active (slower). For best performance install gmsv_workshop_<platform>.dll into garrysmod/lua/bin/.",
        })
    end

    return issues
end

local lastStatusReq = {}
net.Receive(NET.GetServerStatus, function(_, ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID64() or "0"
    local now = CurTime()
    if lastStatusReq[sid] and (now - lastStatusReq[sid]) < 5 then return end
    lastStatusReq[sid] = now

    local issues = BuildServerIssues()
    net.Start(NET.ServerStatus)
    net.WriteUInt(math.min(#issues, 16), 4)
    for i = 1, math.min(#issues, 16) do
        net.WriteString(issues[i].severity or "warn")
        net.WriteString(string.sub(issues[i].msg or "", 1, 512))
    end
    net.Send(ply)
end)

local VALID_SKIN_CATEGORIES = { train = true, pass = true, cab = true }
local VALID_MASK_CATEGORIES = { front = true, mask = true, rear = true, rearmask = true }

local function IsValidOwnership(kind, category)
    if kind == "mask" then return VALID_MASK_CATEGORIES[category] == true end
    return VALID_SKIN_CATEGORIES[category] == true
end

local function EnsureSkinStub(kind, category, name, typ)
    if not Metrostroi then return end
    local rootName = (kind == "mask") and "Masks" or "Skins"
    Metrostroi[rootName] = Metrostroi[rootName] or {}
    Metrostroi[rootName][category] = Metrostroi[rootName][category] or {}
    local existing = Metrostroi[rootName][category][name]
    if existing == nil then
        Metrostroi[rootName][category][name] = {
            name     = name,
            typ      = typ ~= "" and typ or nil,
            textures = {},
            _trainfitter_stub = true,
        }
    elseif istable(existing) and existing._trainfitter_stub then
        if typ ~= "" then existing.typ = typ end
    end
end

local SESSION_TTL  = 30 * 60
local SESSION_CAP  = 128
local PENDING_TTL  = 5 * 60

local function PruneSessionState()
    local now = os.time()
    local cutoff = now - SESSION_TTL
    local broadcastCount, removed = 0, 0

    for wsid, data in pairs(Trainfitter.SessionBroadcast) do
        if istable(data) and (data.since or 0) < cutoff
           and not Trainfitter.MountedServer[wsid] then
            Trainfitter.SessionBroadcast[wsid] = nil
            removed = removed + 1
        else
            broadcastCount = broadcastCount + 1
        end
    end

    if broadcastCount > SESSION_CAP then
        local entries = {}
        for wsid, data in pairs(Trainfitter.SessionBroadcast) do
            if istable(data) then
                table.insert(entries, { wsid = wsid, since = data.since or 0 })
            end
        end
        table.sort(entries, function(a, b) return a.since < b.since end)
        for i = 1, broadcastCount - SESSION_CAP do
            local e = entries[i]
            if e and not Trainfitter.MountedServer[e.wsid] then
                Trainfitter.SessionBroadcast[e.wsid] = nil
                removed = removed + 1
            end
        end
    end

    for wsid in pairs(Trainfitter.SkinOwnership) do
        if not Trainfitter.SessionBroadcast[wsid]
           and not Trainfitter.MountedServer[wsid] then
            local inPersistent = false
            for _, p in ipairs(Trainfitter.Persistent) do
                if p == wsid then inPersistent = true break end
            end
            if not inPersistent then
                Trainfitter.SkinOwnership[wsid] = nil
            end
        end
    end

    local pendingCutoff = now - PENDING_TTL
    for wsid, p in pairs(Trainfitter.PendingRequest) do
        if istable(p) and (p.since or 0) < pendingCutoff then
            Trainfitter.PendingRequest[wsid] = nil
            removed = removed + 1
        end
    end

    if removed > 0 then
        MsgC(Color(200, 220, 255), string.format(
            "[Trainfitter] Pruned %d stale session entries.\n", removed))
    end
end

timer.Create("Trainfitter.SessionPrune", 300, 0, PruneSessionState)

net.Receive(NET.ReportSkins, function(len, ply)
    if len > 8 * 1024 * 8 then return end
    if not IsValid(ply) then return end
    if not Trainfitter.CanDownload(ply) then
        Audit(ply, "report_skins_no_perm", "len=" .. len)
        return
    end

    local wsid = net.ReadString()
    if not IsValidWSID(wsid) then return end

    local knownWsid =
           Trainfitter.SessionBroadcast[wsid] ~= nil
        or Trainfitter.MountedServer[wsid]    ~= nil
        or Trainfitter.SkinOwnership[wsid]    ~= nil
    if not knownWsid then
        for _, persistentWsid in ipairs(Trainfitter.Persistent) do
            if persistentWsid == wsid then knownWsid = true break end
        end
    end
    if not knownWsid then
        Audit(ply, "report_skins_unknown_wsid", wsid)
        return
    end

    local count = net.ReadUInt(8)
    if count > 128 then return end

    local owned = {}
    for i = 1, count do
        local kind     = net.ReadString()
        local category = net.ReadString()
        local name     = net.ReadString()
        local typ      = net.ReadString()
        if (kind == "skin" or kind == "mask")
           and IsValidOwnership(kind, category)
           and isstring(name) and name ~= "" and #name <= 64
           and isstring(typ)  and #typ <= 32 then
            table.insert(owned, { kind = kind, category = category, name = name, typ = typ })
        end
    end

    local SKINS_PER_WSID_CAP = 256

    local merged = Trainfitter.SkinOwnership[wsid] or {}
    local seen = {}
    for _, e in ipairs(merged) do
        seen[(e.kind or "skin") .. "|" .. e.category .. "|" .. e.name] = true
    end
    for _, e in ipairs(owned) do
        if #merged >= SKINS_PER_WSID_CAP then break end
        local key = e.kind .. "|" .. e.category .. "|" .. e.name
        if not seen[key] then
            seen[key] = true
            table.insert(merged, e)
        end
        EnsureSkinStub(e.kind, e.category, e.name, e.typ)
    end
    Trainfitter.SkinOwnership[wsid] = merged
end)

net.Receive(NET.DeleteSkin, function(len, ply)
    if len > 128 * 8 then
        Audit(ply, "netspam_rejected", "NET.DeleteSkin len=" .. len)
        return
    end
    if not Trainfitter.CanMakePersistent(ply) then
        Notify(ply, "[Trainfitter] No permission to delete skins.", Color(255, 100, 100))
        return
    end

    local wsid = net.ReadString()
    if not IsValidWSID(wsid) then return end

    for i = #Trainfitter.Persistent, 1, -1 do
        if Trainfitter.Persistent[i] == wsid then
            table.remove(Trainfitter.Persistent, i)
        end
    end
    SavePersistent()
    SendPersistentList()

    if Trainfitter.ActiveSkin and Trainfitter.ActiveSkin.wsid == wsid then
        Trainfitter.ActiveSkin = nil
        SendActiveSkin()
    end

    Trainfitter.SessionBroadcast[wsid] = nil
    Trainfitter.MountedServer[wsid]    = nil

    BroadcastForget(wsid, ply:SteamID64() or "")

    Notify(ply, "[Trainfitter] Skin " .. wsid .. " removed for all players.",
        Color(100, 255, 150))
    Audit(ply, "skin_deleted", wsid)
end)

net.Receive(NET.RequestList, function(_, ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID64() or "0"
    local now = CurTime()
    if lastListReq[sid] and (now - lastListReq[sid]) < 5 then return end
    lastListReq[sid] = now
    SendPersistentList(ply)
end)

local ADMIN_CVARS = {
    { name = "trainfitter_max_mb",               kind = "int",  min = 1, max = 8192 },
    { name = "trainfitter_require_admin",        kind = "bool" },
    { name = "trainfitter_request_cooldown",     kind = "int",  min = 0, max = 60 },
    { name = "trainfitter_audit_log",            kind = "bool" },
    { name = "trainfitter_use_whitelist",        kind = "bool" },
    { name = "trainfitter_stats_enabled",        kind = "bool" },
    { name = "trainfitter_server_premount",      kind = "bool" },
}

local function SendAdminConfig(target)
    if not IsValid(target) then return end
    net.Start(NET.AdminConfig)
    net.WriteBool(Trainfitter.CanManage(target))
    net.WriteUInt(#ADMIN_CVARS, 8)
    for _, c in ipairs(ADMIN_CVARS) do
        local cv = GetConVar(c.name)
        net.WriteString(c.name)
        net.WriteString(c.kind)
        net.WriteString(cv and cv:GetString() or "")
    end
    net.Send(target)
end

local lastAdminGet = {}
net.Receive(NET.AdminGetConfig, function(_, ply)
    if not IsValid(ply) then return end
    if not Trainfitter.CanManage(ply) then
        Audit(ply, "admin_get_no_perm", "")
        return
    end
    local sid = ply:SteamID64() or "0"
    local now = CurTime()
    if lastAdminGet[sid] and (now - lastAdminGet[sid]) < 3 then return end
    lastAdminGet[sid] = now
    SendAdminConfig(ply)
end)

net.Receive(NET.AdminSetConVar, function(len, ply)
    if len > 512 * 8 then return end
    if not IsValid(ply) then return end
    if not Trainfitter.CanManage(ply) then
        Notify(ply, "[Trainfitter] No permission to change settings.", Color(255, 100, 100))
        return
    end

    local name  = net.ReadString()
    local value = net.ReadString()

    local meta
    for _, c in ipairs(ADMIN_CVARS) do
        if c.name == name then meta = c break end
    end
    if not meta then
        Audit(ply, "admin_setcvar_rejected", "unknown convar: " .. name)
        return
    end

    if meta.kind == "bool" then
        if value ~= "0" and value ~= "1" then return end
    elseif meta.kind == "int" then
        local n = tonumber(value)
        if not n then return end
        n = math.Clamp(math.floor(n), meta.min or 0, meta.max or 1000000)
        value = tostring(n)
    end

    local cv = GetConVar(name)
    if not cv then return end
    cv:SetString(value)

    Audit(ply, "admin_setcvar", name .. "=" .. value)

    local actor = ply:Nick() or "Console"
    local broadcastMsg = string.format("[Trainfitter] %s changed %s = %s", actor, name, value)
    for _, p in ipairs(player.GetAll()) do
        Notify(p, broadcastMsg, Color(150, 220, 255))
        if Trainfitter.CanManage(p) then SendAdminConfig(p) end
    end
end)

hook.Add("PlayerInitialSpawn", "Trainfitter.SyncPersistent", function(ply)
    timer.Simple(5, function()
        if not IsValid(ply) then return end
        SendPersistentList(ply)
        SendActiveSkin(ply)

        for _, wsid in ipairs(Trainfitter.Persistent) do
            local info = Trainfitter.SessionBroadcast[wsid] or {}
            net.Start(NET.Broadcast)
            net.WriteString(wsid)
            net.WriteString("")
            net.WriteString(info.title or "")
            net.WriteFloat(info.sizeMB or 0)
            net.WriteString(info.initiatorSid or "")
            net.Send(ply)
        end
    end)
end)

concommand.Add("trainfitter_list", function(ply)
    local function say(s)
        if IsValid(ply) then ply:ChatPrint(s) else print(s) end
    end
    say("[Trainfitter] Persistent list (" .. #Trainfitter.Persistent .. "):")
    for i, wsid in ipairs(Trainfitter.Persistent) do
        say("  " .. i .. ". " .. wsid)
    end
end)

concommand.Add("trainfitter_remove", function(ply, _, args)
    if IsValid(ply) and not Trainfitter.CanMakePersistent(ply) then return end
    local wsid = args[1]
    if not IsValidWSID(wsid) then
        local s = "Usage: trainfitter_remove <wsid>"
        if IsValid(ply) then ply:ChatPrint(s) else print(s) end
        return
    end
    for i, existing in ipairs(Trainfitter.Persistent) do
        if existing == wsid then
            table.remove(Trainfitter.Persistent, i)
            SavePersistent()
            SendPersistentList()
            Audit(ply, "persistent_removed", wsid)
            local s = "[Trainfitter] Removed: " .. wsid
            if IsValid(ply) then ply:ChatPrint(s) else print(s) end
            return
        end
    end
end)

concommand.Add("trainfitter_reload", function(ply)
    if IsValid(ply) and not Trainfitter.CanMakePersistent(ply) then return end
    LoadPersistent(); LoadLists(); LoadStats()
    SendPersistentList()
    ServerMountPersistent()
    Audit(ply, "reload", "count=" .. #Trainfitter.Persistent)
    local s = "[Trainfitter] Reloaded: " .. #Trainfitter.Persistent .. " persistent entries"
    if IsValid(ply) then ply:ChatPrint(s) else print(s) end
end)

concommand.Add("trainfitter_audit", function(ply, _, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local n = math.Clamp(tonumber(args[1]) or 30, 1, 500)
    if not file.Exists(AUDIT_FILE, "DATA") then
        local s = "[Trainfitter] No audit log yet."
        if IsValid(ply) then ply:ChatPrint(s) else print(s) end
        return
    end
    local content = file.Read(AUDIT_FILE, "DATA") or ""
    local lines = string.Split(content, "\n")
    local total = #lines
    local startIdx = math.max(1, total - n)
    local out = { "[Trainfitter] Last " .. (total - startIdx + 1) .. " audit lines:" }

    for i = startIdx, total do
        local line = lines[i]
        if line and line ~= "" then
            local stamp, sid, rest = string.match(line, "^%[([^%]]+)%] (%S+) (.+)$")
            if stamp and sid then
                local nick = sid == "CONSOLE" and "Console" or Trainfitter.ResolveName(sid)
                line = string.format("[%s] %s [%s] %s", stamp, nick, sid, rest)
            end
            table.insert(out, line)
        end
    end

    for _, l in ipairs(out) do
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, l) else print(l) end
    end
end)

local function ListMutator(set, saveFn, cmdName)
    concommand.Add("trainfitter_" .. cmdName .. "_add", function(ply, _, args)
        if IsValid(ply) and not Trainfitter.CanManage(ply) then return end
        local wsid = args[1]
        if not IsValidWSID(wsid) then
            local s = "Usage: trainfitter_" .. cmdName .. "_add <wsid>"
            if IsValid(ply) then ply:ChatPrint(s) else print(s) end
            return
        end
        set[wsid] = true
        saveFn()
        Audit(ply, cmdName .. "_add", wsid)
        local s = "[Trainfitter] " .. cmdName .. " += " .. wsid
        if IsValid(ply) then ply:ChatPrint(s) else print(s) end
    end)

    concommand.Add("trainfitter_" .. cmdName .. "_remove", function(ply, _, args)
        if IsValid(ply) and not Trainfitter.CanManage(ply) then return end
        local wsid = args[1]
        if not IsValidWSID(wsid) or not set[wsid] then return end
        set[wsid] = nil
        saveFn()
        Audit(ply, cmdName .. "_remove", wsid)
        local s = "[Trainfitter] " .. cmdName .. " -= " .. wsid
        if IsValid(ply) then ply:ChatPrint(s) else print(s) end
    end)

    concommand.Add("trainfitter_" .. cmdName .. "_list", function(ply)
        if IsValid(ply) and not Trainfitter.CanManage(ply) then return end
        local function say(s)
            if IsValid(ply) then ply:ChatPrint(s) else print(s) end
        end
        local arr = ArrayFromSet(set)
        say("[Trainfitter] " .. cmdName .. " list (" .. #arr .. "):")
        for i, wsid in ipairs(arr) do say("  " .. i .. ". " .. wsid) end
    end)
end

ListMutator(Trainfitter.Whitelist, SaveWhitelist, "whitelist")
ListMutator(Trainfitter.Blacklist, SaveBlacklist, "blacklist")

concommand.Add("trainfitter_stats", function(ply)
    local function say(s)
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, s) else print(s) end
    end
    local arr = {}
    for wsid, s in pairs(Trainfitter.Stats) do
        table.insert(arr, { wsid = wsid, count = s.count, title = s.title })
    end
    table.sort(arr, function(a, b) return a.count > b.count end)
    say(string.format("[Trainfitter] Top %d addons:", math.min(#arr, 20)))
    for i = 1, math.min(#arr, 20) do
        say(string.format("  %2d. [%7s] %4dx  %s", i, arr[i].wsid, arr[i].count, arr[i].title))
    end
end)

LoadPersistent()
LoadLists()
LoadStats()
LoadNicks()

pcall(SweepStaleGMACache)

local function PersistentSet()
    local s = {}
    for _, w in ipairs(Trainfitter.Persistent or {}) do s[w] = true end
    return s
end

local function PruneNonPersistentCache()
    if not file.IsDir(GMA_CACHE_DIR, "DATA") then return 0 end
    local persist = PersistentSet()
    local files   = file.Find(GMA_CACHE_DIR .. "/*.gma", "DATA") or {}
    local removed = 0
    for _, fname in ipairs(files) do
        local wsid = string.match(fname, "^(%d+)%.gma$")
        if wsid and not persist[wsid] then
            if pcall(file.Delete, GMA_CACHE_DIR .. "/" .. fname) then
                removed = removed + 1
            end
        end
    end
    return removed
end

function Trainfitter.ForgetNonPersistent()
    local persist = PersistentSet()
    local forgotten = {}

    for wsid in pairs(Trainfitter.MountedServer or {}) do
        if not persist[wsid] then forgotten[wsid] = true end
    end
    for wsid in pairs(Trainfitter.SessionBroadcast or {}) do
        if not persist[wsid] then forgotten[wsid] = true end
    end
    for wsid in pairs(Trainfitter.SkinOwnership or {}) do
        if not persist[wsid] then forgotten[wsid] = true end
    end

    local count = 0
    for wsid in pairs(forgotten) do
        BroadcastForget(wsid, "")
        count = count + 1
    end

    if Trainfitter.ActiveSkin and not persist[Trainfitter.ActiveSkin.wsid] then
        Trainfitter.ActiveSkin = nil
        SendActiveSkin()
    end

    local removedCache = PruneNonPersistentCache()
    if count > 0 or removedCache > 0 then
        MsgC(Color(200, 220, 255), string.format(
            "[Trainfitter] Forgot %d non-persistent skin(s); pruned %d cached GMA(s).\n",
            count, removedCache))
    end
    return count, removedCache
end

hook.Add("InitPostEntity", "Trainfitter.DeferredPremount", function()
    timer.Simple(2, function()
        pcall(Trainfitter.ForgetNonPersistent)
    end)
    timer.Simple(3, function()
        local ok, err = pcall(ServerMountPersistent)
        if not ok then
            MsgC(Color(255, 120, 120),
                "[Trainfitter] Deferred premount error: " .. tostring(err) .. "\n")
        end
    end)
end)

concommand.Add("trainfitter_cache_clear", function(ply)
    if IsValid(ply) and not Trainfitter.CanManage(ply) then return end
    if not file.IsDir(GMA_CACHE_DIR, "DATA") then
        local s = "[Trainfitter] HTTP-cache dir not present — nothing to clear."
        if IsValid(ply) then ply:ChatPrint(s) else print(s) end
        return
    end
    local files = file.Find(GMA_CACHE_DIR .. "/*.gma", "DATA") or {}
    local n = 0
    for _, fname in ipairs(files) do
        if pcall(file.Delete, GMA_CACHE_DIR .. "/" .. fname) then n = n + 1 end
    end
    Audit(ply, "cache_clear", "removed=" .. n)
    local s = "[Trainfitter] Removed " .. n .. " cached GMA(s)."
    if IsValid(ply) then ply:ChatPrint(s) else print(s) end
end)

concommand.Add("trainfitter_purge_all", function(ply)
    if IsValid(ply) and not Trainfitter.CanManage(ply) then return end

    local persistentCopy = {}
    for _, w in ipairs(Trainfitter.Persistent or {}) do
        table.insert(persistentCopy, w)
    end

    Trainfitter.Persistent = {}
    SavePersistent()
    SendPersistentList()

    if Trainfitter.ActiveSkin then
        Trainfitter.ActiveSkin = nil
        SendActiveSkin()
    end

    local forgottenWsids = {}
    for wsid in pairs(Trainfitter.MountedServer or {})    do forgottenWsids[wsid] = true end
    for wsid in pairs(Trainfitter.SessionBroadcast or {}) do forgottenWsids[wsid] = true end
    for wsid in pairs(Trainfitter.SkinOwnership or {})    do forgottenWsids[wsid] = true end
    for _, wsid in ipairs(persistentCopy)                 do forgottenWsids[wsid] = true end

    local forgotten = 0
    for wsid in pairs(forgottenWsids) do
        BroadcastForget(wsid, "")
        forgotten = forgotten + 1
    end

    Trainfitter.MountedServer    = {}
    Trainfitter.SessionBroadcast = {}
    Trainfitter.SkinOwnership    = {}
    Trainfitter.PendingRequest   = {}

    local removedCache = 0
    if file.IsDir(GMA_CACHE_DIR, "DATA") then
        for _, fname in ipairs(file.Find(GMA_CACHE_DIR .. "/*.gma", "DATA") or {}) do
            if pcall(file.Delete, GMA_CACHE_DIR .. "/" .. fname) then
                removedCache = removedCache + 1
            end
        end
    end

    Audit(ply, "purge_all", string.format(
        "persistent=%d forgotten=%d cache=%d", #persistentCopy, forgotten, removedCache))
    local s = string.format(
        "[Trainfitter] Purged: %d persistent, %d active broadcasts, %d cached GMAs.",
        #persistentCopy, forgotten, removedCache)
    if IsValid(ply) then ply:ChatPrint(s) else print(s) end
end)

concommand.Add("trainfitter_forget_all", function(ply)
    if IsValid(ply) and not Trainfitter.CanManage(ply) then return end
    local n, c = Trainfitter.ForgetNonPersistent()
    local s = string.format("[Trainfitter] Forgot %d non-persistent, pruned %d cached.", n, c)
    if IsValid(ply) then ply:ChatPrint(s) else print(s) end
    Audit(ply, "forget_all", string.format("forgotten=%d cache=%d", n, c))
end)
