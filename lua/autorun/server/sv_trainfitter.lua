-- Trainfitter - sv_trainfitter.lua
-- Made by SellingVika

local function LoadWorkshopModule()
    if steamworks and isstring(steamworks.gmsv_workshop) then return end
    local installed = isfunction(util.IsBinaryModuleInstalled) and util.IsBinaryModuleInstalled("workshop")
    if not installed then
        if isfunction(game.IsDedicated) and game.IsDedicated() then
            MsgC(Color(255, 180, 80),
                "[Trainfitter] gmsv_workshop is not installed - dedicated server falls back to HTTP (legacy addons only).\n" ..
                "[Trainfitter] Put gmsv_workshop_<platform>.dll into garrysmod/lua/bin/ (see README).\n")
        end
        return
    end
    local ok, err = pcall(require, "workshop")
    if not ok then
        MsgC(Color(255, 120, 120), "[Trainfitter] require('workshop') failed: " .. tostring(err)
            .. " - update gmsv_workshop for this Garry's Mod version.\n")
        return
    end
    if steamworks and isfunction(steamworks.DownloadUGC) then
        MsgC(Color(120, 220, 150), "[Trainfitter] gmsv_workshop " .. tostring(steamworks.gmsv_workshop or "(legacy)")
            .. " loaded - native Workshop downloads enabled.\n")
    else
        MsgC(Color(255, 180, 80), "[Trainfitter] gmsv_workshop loaded but cannot reach Steam - falling back to HTTP.\n")
    end
end
LoadWorkshopModule()

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
Trainfitter.LoadedThisSession = Trainfitter.LoadedThisSession or {}
Trainfitter.ActiveSkin        = Trainfitter.ActiveSkin

local PERSIST_DIR     = "trainfitter"
local PERSIST_FILE    = PERSIST_DIR .. "/persistent.json"
local WHITELIST_FILE  = PERSIST_DIR .. "/whitelist.json"
local BLACKLIST_FILE  = PERSIST_DIR .. "/blacklist.json"
local STATS_FILE      = PERSIST_DIR .. "/stats.json"
local NICKS_FILE      = PERSIST_DIR .. "/nicks.json"
local AUDIT_FILE      = PERSIST_DIR .. "/audit.log"
local AUDIT_FILE_OLD  = PERSIST_DIR .. "/audit.log.old"

local lastRequest      = {}
local lastListReq      = {}
local lastStatusReq    = {}
local lastAdminGet     = {}
local lastReportSkins  = {}
local lastNetGlobal    = {}
local lastCollectionReq = {}
local lastResyncReq    = {}
local lastLogsReq      = {}
local hourlyNew        = {}
local auditSeen        = {}

local NET_GLOBAL_COOLDOWN = 0.5

local function NetGlobalThrottled(ply)
    if not IsValid(ply) then return true end
    local sid = ply:SteamID64() or "0"
    local now = CurTime()
    if lastNetGlobal[sid] and (now - lastNetGlobal[sid]) < NET_GLOBAL_COOLDOWN then
        return true
    end
    lastNetGlobal[sid] = now
    return false
end

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

local function SafeNick(ply)
    if not IsValid(ply) then return "Console" end
    local nick = ply:Nick() or "?"
    return Sanitize(nick, 32)
end

local function Audit(ply, action, details)
    if not GetConVar("trainfitter_audit_log"):GetBool() then return end
    if IsValid(ply) then
        local key = (ply:SteamID64() or "0") .. "|" .. tostring(action)
        local now = CurTime()
        local rec = auditSeen[key]
        if rec and now - rec.t < 60 then
            rec.n = rec.n + 1
            if rec.n > 20 then return end
        else
            auditSeen[key] = { t = now, n = 1 }
        end
    end
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
    if maxP <= 0 then maxP = math.huge end
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

local function FillSetInPlace(setTbl, arr)
    for k in pairs(setTbl) do setTbl[k] = nil end
    if istable(arr) then
        for _, v in ipairs(arr) do
            if isstring(v) and v ~= "" then setTbl[v] = true end
        end
    end
end

local function LoadLists()
    FillSetInPlace(Trainfitter.Whitelist, ReadJSON(WHITELIST_FILE, {}))
    FillSetInPlace(Trainfitter.Blacklist, ReadJSON(BLACKLIST_FILE, {}))
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
local STATS_CAP = 5000

local function TrimStats()
    local list = {}
    for w, st in pairs(Trainfitter.Stats) do list[#list + 1] = { w = w, last = tonumber(st.last) or 0 } end
    if #list <= STATS_CAP then return end
    table.sort(list, function(a, b) return a.last < b.last end)
    for i = 1, #list - STATS_CAP do Trainfitter.Stats[list[i].w] = nil end
end

local function BumpStats(wsid, title)
    if not GetConVar("trainfitter_stats_enabled"):GetBool() then return end
    if not Trainfitter.Stats[wsid] then TrimStats() end
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

local function WorkshopModuleStatus()
    if not (steamworks and isfunction(steamworks.gmsv_workshop_status)) then return nil end
    local ok, ready, msg = pcall(steamworks.gmsv_workshop_status)
    if not ok then return false, tostring(ready) end
    return ready == true, tostring(msg or "")
end

local function IsDedicated()
    return isfunction(game.IsDedicated) and game.IsDedicated() or false
end

local function ForceHttp()
    local cv = GetConVar("trainfitter_use_http")
    return cv and cv:GetBool() or false
end

local function ShouldUseHttp()
    if ForceHttp() then return true end
    if not ServerHasSteamworks() then return true end
    if not IsDedicated() then return true end
    return false
end

local GMA_CACHE_DIR  = PERSIST_DIR .. "/gmas"
local HTTP_CACHE_DIR = PERSIST_DIR .. "/http"

local function SweepStaleGMACache()
    local files = {}
    for _, dir in ipairs({ GMA_CACHE_DIR, HTTP_CACHE_DIR }) do
        if file.IsDir(dir, "DATA") then
            for _, fname in ipairs(file.Find(dir .. "/*.gma", "DATA") or {}) do
                pcall(file.Delete, dir .. "/" .. fname)
            end
            for _, fname in ipairs(file.Find(dir .. "/*.dat", "DATA") or {}) do
                files[#files + 1] = dir .. "/" .. fname
            end
        end
    end
    local removed, kept = 0, 0
    for _, rel in ipairs(files) do
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

local function EnforceCacheCap()
    local cv = GetConVar("trainfitter_cache_max_gb")
    local cap = (cv and cv:GetInt() or 20) * 1024 * 1024 * 1024
    if cap <= 0 then return end
    local files, total = {}, 0
    for _, dir in ipairs({ GMA_CACHE_DIR, HTTP_CACHE_DIR }) do
        if file.IsDir(dir, "DATA") then
            for _, fname in ipairs(file.Find(dir .. "/*.dat", "DATA") or {}) do
                local rel = dir .. "/" .. fname
                local size = file.Size(rel, "DATA") or 0
                total = total + size
                files[#files + 1] = { rel = rel, size = size, t = file.Time(rel, "DATA") or 0 }
            end
        end
    end
    if total <= cap then return end
    table.sort(files, function(a, b) return a.t < b.t end)
    for _, f in ipairs(files) do
        if total <= cap then break end
        file.Delete(f.rel)
        if not file.Exists(f.rel, "DATA") then total = total - f.size end
    end
end

local function InvalidateGMACache(wsid)
    if not isstring(wsid) or wsid == "" then return end
    local cacheFile = HTTP_CACHE_DIR .. "/" .. wsid .. ".dat"
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
    if not file.IsDir(HTTP_CACHE_DIR, "DATA") then file.CreateDir(HTTP_CACHE_DIR) end

    local cacheFile = HTTP_CACHE_DIR .. "/" .. wsid .. ".dat"
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

        local url = isstring(info.file_url) and info.file_url or ""
        local host = string.match(url, "^https://([%w%.%-]+)/") or ""
        local trustedHost = host == "steamusercontent-a.akamaihd.net" or string.match(host, "%.steamusercontent%.com$")
            or host == "steamusercontent.com" or string.match(host, "%.steamcontent%.com$")
            or string.match(host, "%.steamstatic%.com$")
        if url ~= "" and not trustedHost then
            callback(nil, "Workshop returned an unexpected download host")
            return
        end

        if url ~= "" then
            local maxBytes = (GetConVar("trainfitter_max_mb"):GetInt() or 200) * 1024 * 1024
            http.Fetch(url, function(gmaBody, _, _, code)
                if code and code >= 400 then
                    callback(nil, "HTTP " .. tostring(code))
                    return
                end
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
                if file.Write(cacheFile, gmaBody) == false or not file.Exists(cacheFile, "DATA") then
                    callback(nil, "cannot write " .. cacheFile)
                    return
                end
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

        callback(nil,
            "this Workshop item has no public download URL. Install gmsv_workshop on the dedicated server "
            .. "(garrysmod/lua/bin) or subscribe to it with the listen-server host account.")
    end)
end

local hostFetchWaiters = {}

local function ListenHost()
    if IsDedicated() then return nil end
    for _, p in ipairs(player.GetHumans()) do
        if p:IsListenServerHost() then return p end
    end
    return nil
end

local function HostFetchGMA(wsid, callback)
    local host = ListenHost()
    if not IsValid(host) then callback(nil, "no listen-server host") return end
    hostFetchWaiters[wsid] = hostFetchWaiters[wsid] or {}
    table.insert(hostFetchWaiters[wsid], callback)
    if #hostFetchWaiters[wsid] > 1 then return end
    net.Start(NET.HostFetch)
    net.WriteString(wsid)
    net.Send(host)
    timer.Create("Trainfitter.HostFetch." .. wsid, 150, 1, function()
        local waiters = hostFetchWaiters[wsid]
        hostFetchWaiters[wsid] = nil
        for _, cb in ipairs(waiters or {}) do cb(nil, "host download timed out") end
    end)
end

net.Receive(NET.HostFetched, function(len, ply)
    if len > 512 * 8 then return end
    if not IsValid(ply) or not ply:IsListenServerHost() then return end
    local wsid = net.ReadString()
    local path = net.ReadString()
    local waiters = hostFetchWaiters[wsid]
    if not waiters then return end
    hostFetchWaiters[wsid] = nil
    timer.Remove("Trainfitter.HostFetch." .. wsid)
    local ok = Trainfitter.ReadableGamePath(path)
    for _, cb in ipairs(waiters) do
        if ok then cb(path) else cb(nil, "host returned no usable path") end
    end
end)

local serverMountQueue    = {}
local serverMountInFlight = false
local processServerMountQueue

local function finalize(wsid, ok, reason)
    if Trainfitter.FinalizePending then
        pcall(Trainfitter.FinalizePending, wsid, ok, reason)
    end
end

local function RecordOwnership(wsid, owned)
    local list = Trainfitter.SkinOwnership[wsid] or {}
    local seen = {}
    for _, e in ipairs(list) do seen[(e.kind or "skin") .. "|" .. e.category .. "|" .. e.name] = true end
    for _, e in ipairs(owned or {}) do
        local key = e.kind .. "|" .. e.category .. "|" .. e.name
        if not seen[key] then
            seen[key] = true
            list[#list + 1] = { kind = e.kind, category = e.category, name = e.name, typ = e.typ }
        end
    end
    Trainfitter.SkinOwnership[wsid] = list
end

local function MountAndRun(wsid, report, mountPath, fullLua)
    local ok, files = game.MountGMA(mountPath)
    if not ok then return false, "MountGMA failed" end
    Trainfitter.MountedServer[wsid] = true
    Trainfitter.LoadedThisSession[wsid] = true
    local summary = Trainfitter.RunAddonLua(wsid, report, {
        allowMasks = Trainfitter.ShouldAllowMasks(),
        mel = Trainfitter.MELSupportEnabled(),
        unsafe = fullLua,
    })
    RecordOwnership(wsid, summary.owned)
    MsgC(Color(120, 220, 150), string.format(
        "[Trainfitter] Server mounted %s: %d files, %d script(s) in sandbox\n",
        wsid, istable(files) and #files or 0, summary.executed))
    if summary.failed > 0 then
        pcall(Audit, nil, "sandbox_errors", wsid .. " :: " .. table.concat(summary.errors, " | "))
    end
    return true
end

local function onGMAReady(wsid, path)
    local function release()
        serverMountInFlight = false
        processServerMountQueue()
    end

    if not path then
        finalize(wsid, false, "download failed")
        release()
        return
    end

    local fullLua = Trainfitter.ShouldAllowFullLua() and Trainfitter.Whitelist[wsid] == true
    local callOK, report = pcall(Trainfitter.ScanGMA, path, {
        fullLua = fullLua,
        allowMasks = Trainfitter.ShouldAllowMasks(),
    })
    local reject
    if not callOK then
        reject = "scanner crashed: " .. tostring(report)
    elseif not report.ok then
        reject = tostring(report.reason)
    elseif report.usesMEL and not Trainfitter.MELSupportEnabled() then
        reject = "addon requires Metrostroi Extensions Library (MEL); enable 'trainfitter_mel_support 1' if this server runs MEL"
    elseif report.usesMEL and not Trainfitter.MELPresent() then
        reject = "addon requires Metrostroi Extensions Library (MEL), but MEL is not installed on this server"
    elseif report.hasLua and not fullLua and not Trainfitter.Sandbox.Available then
        reject = "sandbox unavailable on this server (debug.sethook missing)"
    else
        local maxMB = math.max(GetConVar("trainfitter_max_mb"):GetInt(), 64)
        if report.totalBytes > maxMB * 4 * 1024 * 1024 then
            reject = string.format("addon unpacks to %d MB, more than 4x the %d MB limit", math.floor(report.totalBytes / 1048576), maxMB)
        end
    end

    if reject then
        MsgC(Color(255, 120, 120), string.format("[Trainfitter] Server refused to mount %s: %s\n", wsid, reject))
        pcall(Audit, nil, "server_mount_rejected", wsid .. " :: " .. reject)
        InvalidateGMACache(wsid)
        finalize(wsid, false, reject)
        release()
        return
    end

    local function run(mountPath)
        local ok, res, err = pcall(MountAndRun, wsid, report, mountPath, fullLua)
        if not ok then
            MsgC(Color(255, 120, 120), string.format("[Trainfitter] mount/exec threw for %s: %s\n", wsid, tostring(res)))
            pcall(Audit, nil, "mount_exec_threw", wsid .. " :: " .. tostring(res))
            finalize(wsid, false, "mount/exec error")
        elseif not res then
            InvalidateGMACache(wsid)
            finalize(wsid, false, err or "mount failed")
        else
            finalize(wsid, true)
        end
        release()
    end

    if fullLua or not report.hasLua then
        run(path)
        return
    end

    Trainfitter.RepackGMA(path, report, wsid, function(cleanPath, err)
        if not cleanPath then
            MsgC(Color(255, 120, 120), string.format("[Trainfitter] Repack failed for %s: %s\n", wsid, tostring(err)))
            finalize(wsid, false, "repack failed: " .. tostring(err))
            release()
            return
        end
        pcall(EnforceCacheCap)
        run(cleanPath)
    end)
end

local function safeNativeDownload(wsid, cb)
    timer.Simple(0, function()
        local ok, err = pcall(steamworks.DownloadUGC, wsid, function(path, f)
            local resolved, rerr = Trainfitter.ResolveUGCPath(wsid, path, f)
            if not resolved and path then
                MsgC(Color(255, 120, 120), string.format("[Trainfitter] %s: %s\n", wsid, tostring(rerr)))
            end
            cb(resolved)
        end)
        if not ok then
            MsgC(Color(255, 120, 120), string.format(
                "[Trainfitter] steamworks.DownloadUGC threw on %s: %s\n",
                wsid, tostring(err)))
            cb(nil)
        end
    end)
end

local SERVER_MOUNT_TIMEOUT = 900

function processServerMountQueue()
    if serverMountInFlight or #serverMountQueue == 0 then return end
    local wsid = table.remove(serverMountQueue, 1)
    if Trainfitter.LoadedThisSession[wsid] then
        Trainfitter.MountedServer[wsid] = true
        finalize(wsid, true)
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

    local function viaHttp()
        HttpFetchGMA(wsid, function(path, err)
            if not path and err then
                MsgC(Color(255, 120, 120), string.format(
                    "[Trainfitter] HTTP fetch failed for %s: %s\n", wsid, tostring(err)))
            end
            done(path)
        end)
    end

    if ShouldUseHttp() then
        if not ForceHttp() and not IsDedicated() and IsValid(ListenHost()) then
            HostFetchGMA(wsid, function(path, err)
                if path then
                    done(path)
                else
                    MsgC(Color(255, 180, 80), string.format(
                        "[Trainfitter] Host download of %s failed (%s), trying HTTP\n", wsid, tostring(err)))
                    viaHttp()
                end
            end)
        else
            viaHttp()
        end
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
    if Trainfitter.LoadedThisSession[wsid] then
        Trainfitter.MountedServer[wsid] = true
        return
    end
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


local function IsTrustedFull(wsid)
    return Trainfitter.ShouldAllowFullLua() and Trainfitter.Whitelist[wsid] == true
end

local function WriteBroadcast(wsid, initiatorName, title, sizeMB, initiatorSid)
    net.Start(NET.Broadcast)
    net.WriteString(wsid)
    net.WriteString(initiatorName or "")
    net.WriteString(title or "")
    net.WriteFloat(sizeMB or 0)
    net.WriteString(initiatorSid or "")
    net.WriteBool(IsTrustedFull(wsid))
end

local function BroadcastDownload(wsid, initiatorName, title, sizeMB, initiatorSid)
    Trainfitter.SessionBroadcast[wsid] = {
        title         = title or "",
        sizeMB        = sizeMB or 0,
        since         = os.time(),
        initiatorSid  = initiatorSid or "",
        initiatorName = initiatorName or "",
    }
    WriteBroadcast(wsid, initiatorName, title, sizeMB, initiatorSid)
    net.Broadcast()
end

local GetTrainNWKey = Trainfitter.GetTrainNWKey

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
        if not IsValid(ent) then continue end
        local class = ent:GetClass()
        if class and string.StartWith(class, "gmod_subway_")
           and class ~= "gmod_subway_base" then
            for key, names in pairs(byKey) do
                if not IsValid(ent) then break end
                local current = ent:GetNW2String(key, "")
                if names[current] then
                    ent:SetNW2String(key, "")
                    reset = reset + 1
                end
            end
        end
    end
    return reset
end

local function BroadcastForget(wsid, initiatorSid)
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

local function IsPersistentWsid(w)
    for _, pw in ipairs(Trainfitter.Persistent) do
        if pw == w then return true end
    end
    return false
end

local function TrimOwnSessionSkins(sid, perCap, keepWsid)
    if not sid or sid == "" then return end
    if perCap == math.huge then return end

    local mine = {}
    for w, d in pairs(Trainfitter.SessionBroadcast) do
        if w ~= keepWsid and istable(d) and d.initiatorSid == sid and not IsPersistentWsid(w) then
            mine[#mine + 1] = { wsid = w, since = d.since or 0 }
        end
    end

    local keepOthers = perCap - 1
    if keepOthers < 0 then keepOthers = 0 end
    if #mine <= keepOthers then return end

    table.sort(mine, function(a, b) return a.since < b.since end)
    while #mine > keepOthers do
        local victim = table.remove(mine, 1)
        BroadcastForget(victim.wsid, sid)
    end
end

local function SetActiveSkin(wsid, title, sizeMB, initiatorName, initiatorSid)
    Trainfitter.ActiveSkin = {
        wsid         = wsid,
        title        = title or "",
        sizeMB       = sizeMB or 0,
        initiator    = initiatorName or "",
        initiatorSid = initiatorSid or "",
        since        = os.time(),
    }
    SendActiveSkin()
end

local function CapOf(convarName)
    local cv = GetConVar(convarName)
    local n = cv and cv:GetInt() or 0
    if n <= 0 then return math.huge end
    return n
end

local function CountLoaded()
    local seen = {}
    for w in pairs(Trainfitter.SessionBroadcast) do seen[w] = true end
    for w in pairs(Trainfitter.PendingRequest)  do seen[w] = true end
    local n = 0
    for _ in pairs(seen) do n = n + 1 end
    return n
end

local function CountLoadedBy(sid)
    local seen = {}
    for w, d in pairs(Trainfitter.SessionBroadcast) do
        if istable(d) and d.initiatorSid == sid then seen[w] = true end
    end
    for w, d in pairs(Trainfitter.PendingRequest) do
        if istable(d) and d.initiatorSid == sid then seen[w] = true end
    end
    local n = 0
    for _ in pairs(seen) do n = n + 1 end
    return n
end

local function SessionLoadedCount()
    local n = 0
    for _ in pairs(Trainfitter.LoadedThisSession) do n = n + 1 end
    return n
end

local function HourlyUsed(sid)
    local rec = hourlyNew[sid]
    if not rec or os.time() - rec.t >= 3600 then return 0 end
    return rec.n
end

local function HourlyBump(sid)
    local rec = hourlyNew[sid]
    if not rec or os.time() - rec.t >= 3600 then
        hourlyNew[sid] = { t = os.time(), n = 1 }
    else
        rec.n = rec.n + 1
    end
end

local function HandleRequest(ply, wsid, makePersistent, skipCooldown)
    if not IsValid(ply) then return end

    if not IsValidWSID(wsid) then
        Notify(ply, "[Trainfitter] WSID is bogus", Color(255, 100, 100))
        return
    end

    local sid = ply:SteamID64() or "0"
    local now = CurTime()
    local cd  = math.max(GetConVar("trainfitter_request_cooldown"):GetFloat(), 1)
    if not skipCooldown and lastRequest[sid] and (now - lastRequest[sid]) < cd then
        Notify(ply, "[Trainfitter] Slow down, take a breath",
            Color(255, 180, 80))
        return
    end
    lastRequest[sid] = now

    if not Trainfitter.CanDownload(ply) then
        Notify(ply, "[Trainfitter] Not enough perms to download, sorry kid", Color(255, 100, 100))
        return
    end

    local reason = CheckLists(wsid)
    if reason then
        Notify(ply, "[Trainfitter] Denied: " .. reason, Color(255, 100, 100))
        Audit(ply, "request_rejected", wsid .. " (" .. reason .. ")")
        return
    end

    local isNewAddon = not Trainfitter.LoadedThisSession[wsid]
    local privileged = Trainfitter.CanMakePersistent(ply)
    if isNewAddon and not privileged then
        local sessionCap = CapOf("trainfitter_max_session_addons")
        if SessionLoadedCount() >= sessionCap then
            Notify(ply, "[Trainfitter] This map session already loaded its maximum of addons, ask an admin", Color(255, 100, 100))
            Audit(ply, "session_cap", wsid)
            return
        end
        if HourlyUsed(sid) >= CapOf("trainfitter_max_new_per_hour") then
            Notify(ply, "[Trainfitter] You reached your hourly limit of new addons, try later", Color(255, 100, 100))
            Audit(ply, "hourly_cap", wsid)
            return
        end
    end

    local hookret = hook.Run("Trainfitter.CanRequest", ply, wsid, makePersistent)
    if hookret == false then
        Notify(ply, "[Trainfitter] Server hook said nope",
            Color(255, 100, 100))
        Audit(ply, "hook_rejected", wsid)
        return
    end

    if makePersistent and not Trainfitter.CanMakePersistent(ply) then
        Notify(ply, "[Trainfitter] Only admins mark addons as persistent",
            Color(255, 100, 100))
        makePersistent = false
    end

    local adminTier = Trainfitter.CanMakePersistent(ply)
    local alreadyLoaded = Trainfitter.SessionBroadcast[wsid] ~= nil
        or Trainfitter.PendingRequest[wsid] ~= nil
    if not alreadyLoaded then
        if CountLoaded() >= CapOf("trainfitter_max_loaded") then
            Notify(ply, "[Trainfitter] Server is at its loaded-addon limit, ask an admin",
                Color(255, 100, 100))
            Audit(ply, "load_limit_server", wsid)
            return
        end
    end

    local maxMB = GetConVar("trainfitter_max_mb"):GetInt()
    Trainfitter.SafeFetchWorkshopInfo(wsid, function(info, err)
        if not IsValid(ply) then return end

        if not info or not info.title or info.title == "" then
            Notify(ply, "[Trainfitter] Addon " .. wsid .. " nowhere in Workshop"
                .. (err and (" (" .. err .. ")") or ""), Color(255, 100, 100))
            Audit(ply, "request_rejected", wsid .. " (not found: " .. tostring(err or "no title") .. ")")
            return
        end

        local appid = info.creator_appid or info.consumer_appid
        if appid and appid ~= Trainfitter.GMOD_APPID then
            Notify(ply, string.format(
                "[Trainfitter] '%s' is not a gmod addon (appid %s), nope",
                info.title or wsid, tostring(appid)), Color(255, 100, 100))
            Audit(ply, "request_rejected", wsid .. " (wrong appid)")
            return
        end

        local sizeMB = (info.size or 0) / (1024 * 1024)
        if sizeMB > maxMB then
            Notify(ply, string.format(
                "[Trainfitter] '%s' weighs %.1f MB at a %d MB cap, denied",
                info.title, sizeMB, maxMB), Color(255, 100, 100))
            Audit(ply, "request_rejected", string.format("%s (%.1f MB > %d MB)", wsid, sizeMB, maxMB))
            return
        end

        local title = info.title
        local function proceed()
            local extra = sizeMB / 10
            lastRequest[sid] = CurTime() + extra

            Trainfitter.PendingRequest[wsid] = {
                initiatorSid    = sid,
                initiatorName   = SafeNick(ply),
                title           = Sanitize(info.title or "", 128),
                sizeMB          = sizeMB,
                makePersistent  = makePersistent,
                adminTier       = adminTier,
                since           = os.time(),
            }

            if not Trainfitter.LoadedThisSession[wsid] and not privileged then HourlyBump(sid) end

            Notify(ply, string.format(
                "[Trainfitter] X-raying '%s' on server (%.1f MB)",
                info.title, sizeMB), Color(150, 220, 255))
            Audit(ply, "download_requested",
                string.format("%s '%s' (%.1f MB)", wsid, info.title, sizeMB))

            if Trainfitter.LoadedThisSession[wsid] then
                Trainfitter.MountedServer[wsid] = true
                finalize(wsid, true)
            else
                ServerMount(wsid)
            end
        end

        Trainfitter.FetchRequiredItems(wsid, function(deps)
            if not IsValid(ply) then return end
            local needsMEL = false
            for _, d in ipairs(deps or {}) do
                if d == Trainfitter.MEL_WSID then needsMEL = true end
            end
            if needsMEL and not Trainfitter.MELSupportEnabled() then
                Notify(ply, string.format(
                    "[Trainfitter] '%s' requires Metrostroi Extensions Library (MEL), MEL support is off on this server",
                    title), Color(255, 100, 100))
                Audit(ply, "request_rejected", wsid .. " (requires MEL, support disabled)")
                return
            end
            if needsMEL and not Trainfitter.MELPresent() then
                Notify(ply, string.format(
                    "[Trainfitter] '%s' requires Metrostroi Extensions Library (MEL), but MEL is not installed here",
                    title), Color(255, 100, 100))
                Audit(ply, "request_rejected", wsid .. " (requires MEL, MEL missing)")
                return
            end
            proceed()
        end)
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
                "[Trainfitter] '%s' didn't make it: %s",
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

    local perCap = CapOf(p.adminTier and "trainfitter_max_per_admin" or "trainfitter_max_per_player")
    TrimOwnSessionSkins(p.initiatorSid, perCap, wsid)

    BumpStats(wsid, p.title)
    if Audit then
        pcall(Audit, nil, "download_broadcast",
            string.format("%s '%s' (%.1f MB)", wsid,
                p.title or "", p.sizeMB or 0))
    end

    local nickForMsg = p.initiatorName
    if (not nickForMsg) or nickForMsg == "" then nickForMsg = "Server" end

    for _, pl in ipairs(player.GetAll()) do
        if IsValid(initiator) and pl == initiator then continue end
        Notify(pl, string.format(
            "[Trainfitter] %s installed '%s' (%.1f MB)",
            nickForMsg, p.title or wsid, p.sizeMB or 0),
            Color(150, 220, 255))
    end

    if IsValid(initiator) then
        Notify(initiator, string.format(
            "[Trainfitter] '%s' applied - pick it in gmod_train_spawner and press R on your train",
            p.title or wsid),
            Color(100, 255, 150))
    end

    if p.makePersistent then
        local maxP = GetConVar("trainfitter_max_persistent"):GetInt()
        if maxP <= 0 then maxP = math.huge end

        local already = false
        for _, w in ipairs(Trainfitter.Persistent) do
            if w == wsid then already = true break end
        end

        if not already then
            table.insert(Trainfitter.Persistent, wsid)
            ServerMount(wsid)
            if IsValid(initiator) then
                Notify(initiator, "[Trainfitter] '" .. (p.title or wsid)
                    .. "' is live, enjoy", Color(100, 255, 150))
            end
            if Audit then
                pcall(Audit, nil, "persistent_added",
                    wsid .. " '" .. (p.title or "") .. "'")
            end

            while #Trainfitter.Persistent > maxP do
                local dropped = table.remove(Trainfitter.Persistent, 1)
                if dropped and dropped ~= wsid then
                    BroadcastForget(dropped, p.initiatorSid or "")
                    if Audit then pcall(Audit, nil, "persistent_trimmed", "forgot " .. dropped) end
                end
            end

            SavePersistent()
            SendPersistentList()
        end
    end
end

net.Receive(NET.Request, function(len, ply)
    if NetGlobalThrottled(ply) then return end
    if len > 128 * 8 then
        Audit(ply, "netspam_rejected", "NET.Request len=" .. len)
        return
    end
    local wsid = net.ReadString()
    local persist = net.ReadBool()
    HandleRequest(ply, wsid, persist)
end)

local COLLECTION_COOLDOWN = 10

net.Receive(NET.RequestCollection, function(len, ply)
    if NetGlobalThrottled(ply) then return end
    if len > 128 * 8 then
        Audit(ply, "netspam_rejected", "NET.RequestCollection len=" .. len)
        return
    end
    if not IsValid(ply) then return end

    local wsid = net.ReadString()
    if not IsValidWSID(wsid) then return end

    if not Trainfitter.CanDownload(ply) then
        Notify(ply, "[Trainfitter] Not enough perms to download, sorry kid", Color(255, 100, 100))
        return
    end

    local csid = ply:SteamID64() or "0"
    if lastCollectionReq[csid] and (CurTime() - lastCollectionReq[csid]) < COLLECTION_COOLDOWN then
        Notify(ply, "[Trainfitter] Easy with the collections, wait a bit", Color(255, 180, 80))
        return
    end
    lastCollectionReq[csid] = CurTime()

    if Trainfitter.AllowCollections and not Trainfitter.AllowCollections() then
        Notify(ply, "[Trainfitter] Collections are off on this server, ask an admin", Color(255, 100, 100))
        Audit(ply, "collection_denied", wsid)
        return
    end

    Trainfitter.FetchCollectionChildren(wsid, function(children, err)
        if not IsValid(ply) then return end
        if not istable(children) then
            Notify(ply, "[Trainfitter] Not a collection: " .. tostring(err or "?"), Color(255, 100, 100))
            return
        end
        if #children == 0 then
            Notify(ply, "[Trainfitter] That collection is empty", Color(255, 100, 100))
            return
        end

        local cap = (Trainfitter.GetMaxCollection and Trainfitter.GetMaxCollection()) or math.huge

        local sid         = ply:SteamID64() or "0"
        local isAdminTier = Trainfitter.CanMakePersistent(ply)
        local perCap      = CapOf(isAdminTier and "trainfitter_max_per_admin" or "trainfitter_max_per_player")
        local newBudget   = math.max(0, math.min(CapOf("trainfitter_max_loaded") - CountLoaded(), perCap - CountLoadedBy(sid)))

        local toDispatch = {}
        for _, cw in ipairs(children) do
            if #toDispatch >= cap then break end
            local isNew = not (Trainfitter.SessionBroadcast[cw] or Trainfitter.PendingRequest[cw])
            if isNew then
                if newBudget <= 0 then continue end
                newBudget = newBudget - 1
            end
            toDispatch[#toDispatch + 1] = cw
        end

        local total = #toDispatch
        if total == 0 then
            Notify(ply, "[Trainfitter] No free slots for this collection, ask an admin", Color(255, 100, 100))
            Audit(ply, "collection_no_slots", wsid)
            return
        end
        if total < #children then
            Notify(ply, string.format("[Trainfitter] Applying %d of %d (limits / already loaded)", total, #children),
                Color(150, 220, 255))
        else
            Notify(ply, string.format("[Trainfitter] Applying collection: %d items", total), Color(150, 220, 255))
        end
        Audit(ply, "collection_apply", wsid .. " (" .. total .. "/" .. #children .. " items)")

        for i = 1, total do
            local cw = toDispatch[i]
            timer.Simple((i - 1) * 0.4, function()
                if IsValid(ply) then HandleRequest(ply, cw, false, true) end
            end)
        end
    end)
end)

net.Receive(NET.RemovePersistent, function(len, ply)
    if NetGlobalThrottled(ply) then return end
    if len > 128 * 8 then
        Audit(ply, "netspam_rejected", "NET.RemovePersistent len=" .. len)
        return
    end
    if not IsValid(ply) then return end
    if not Trainfitter.CanMakePersistent(ply) then
        Notify(ply, "[Trainfitter] No perms to remove persistent", Color(255, 100, 100))
        return
    end
    local wsid = net.ReadString()
    if not IsValidWSID(wsid) then
        Audit(ply, "removepersistent_bad_wsid", tostring(wsid):sub(1, 64))
        return
    end

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
        Notify(ply, "[Trainfitter] WSID " .. wsid .. " yanked from persistent",
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

    local isDedicated = IsDedicated()
    if not ServerHasSteamworks() and isDedicated then
        table.insert(issues, {
            severity = "warn",
            msg = "gmsv_workshop is not installed on this dedicated server - only legacy Workshop items can be downloaded. Install gmsv_workshop into garrysmod/lua/bin/.",
        })
    end
    local wsReady, wsMsg = WorkshopModuleStatus()
    if wsReady == false and isDedicated then
        table.insert(issues, { severity = "warn", msg = "gmsv_workshop is loaded but not ready: " .. tostring(wsMsg) })
    end
    if Trainfitter.MELPresent() and not Trainfitter.MELSupportEnabled() then
        table.insert(issues, {
            severity = "warn",
            msg = "Metrostroi Extensions Library (MEL) is installed, but MEL support is off - addons that require MEL will be rejected.",
        })
    end
    if Trainfitter.MELSupportEnabled() and not Trainfitter.MELPresent() then
        table.insert(issues, {
            severity = "error",
            msg = "MEL support is on, but Metrostroi Extensions Library is not installed on the server.",
        })
    end
    if not Trainfitter.Sandbox.Available then
        table.insert(issues, { severity = "error", msg = "Lua sandbox is unavailable, masks cannot be loaded." })
    end

    return issues
end

net.Receive(NET.GetServerStatus, function(_, ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID64() or "0"
    local now = CurTime()
    if lastStatusReq[sid] and (now - lastStatusReq[sid]) < 5 then return end
    lastStatusReq[sid] = now
    if not Trainfitter.CanManage(ply) then return end

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

    local onlineSids = {}
    for _, p in ipairs(player.GetAll()) do
        local s = p:SteamID64()
        if s then onlineSids[s] = true end
    end
    for sid in pairs(lastRequest)   do if not onlineSids[sid] then lastRequest[sid]   = nil; removed = removed + 1 end end
    for sid in pairs(lastListReq)   do if not onlineSids[sid] then lastListReq[sid]   = nil; removed = removed + 1 end end
    for sid in pairs(lastAdminGet)  do if not onlineSids[sid] then lastAdminGet[sid]  = nil; removed = removed + 1 end end
    for sid in pairs(lastStatusReq) do if not onlineSids[sid] then lastStatusReq[sid] = nil; removed = removed + 1 end end
    for key in pairs(lastReportSkins) do
        local sid = string.match(key, "^([^|]+)|")
        if sid and not onlineSids[sid] then
            lastReportSkins[key] = nil
            removed = removed + 1
        end
    end
    for sid in pairs(lastNetGlobal) do if not onlineSids[sid] then lastNetGlobal[sid] = nil; removed = removed + 1 end end
    for _, t in ipairs({ lastCollectionReq, lastResyncReq, lastLogsReq }) do
        for sid in pairs(t) do if not onlineSids[sid] then t[sid] = nil; removed = removed + 1 end end
    end
    for sid, rec in pairs(hourlyNew) do if os.time() - rec.t >= 3600 then hourlyNew[sid] = nil end end
    for key, rec in pairs(auditSeen) do if CurTime() - rec.t >= 60 then auditSeen[key] = nil end end

    local NICK_CACHE_CAP = 4096
    local nickCount = 0
    for _ in pairs(Trainfitter.NickCache) do nickCount = nickCount + 1 end
    if nickCount > NICK_CACHE_CAP then
        local kept = {}
        for sid in pairs(onlineSids) do
            if Trainfitter.NickCache[sid] then kept[sid] = Trainfitter.NickCache[sid] end
        end
        Trainfitter.NickCache = kept
        nicksDirty = true
        removed = removed + (nickCount - table.Count(kept))
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
    if NetGlobalThrottled(ply) then return end
    if not Trainfitter.CanDownload(ply) then
        Audit(ply, "report_skins_no_perm", "len=" .. len)
        return
    end

    local wsid = net.ReadString()
    if not IsValidWSID(wsid) then return end

    local sid = ply:SteamID64() or "0"
    local rsKey = sid .. "|" .. wsid
    local now = CurTime()
    if lastReportSkins[rsKey] and (now - lastReportSkins[rsKey]) < 5 then return end
    lastReportSkins[rsKey] = now

    local sb = Trainfitter.SessionBroadcast[wsid]
    local isInitiator = istable(sb) and sb.initiatorSid == sid
    if not (isInitiator or Trainfitter.CanMakePersistent(ply)) then
        Audit(ply, "report_skins_not_owner", wsid)
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
    if NetGlobalThrottled(ply) then return end
    if len > 128 * 8 then
        Audit(ply, "netspam_rejected", "NET.DeleteSkin len=" .. len)
        return
    end
    if not IsValid(ply) then return end

    local wsid = net.ReadString()
    if not IsValidWSID(wsid) then return end

    local sid     = ply:SteamID64() or "0"
    local isAdmin = Trainfitter.CanMakePersistent(ply) == true
    local isOwner = false

    if Trainfitter.ActiveSkin
       and Trainfitter.ActiveSkin.wsid == wsid
       and Trainfitter.ActiveSkin.initiatorSid == sid then
        isOwner = true
    end
    local sb = Trainfitter.SessionBroadcast[wsid]
    if not isOwner and istable(sb) and sb.initiatorSid == sid then
        isOwner = true
    end

    if not isAdmin and not isOwner then
        Notify(ply, "[Trainfitter] You can only remove skins you applied yourself",
            Color(255, 100, 100))
        Audit(ply, "skin_delete_denied", wsid)
        return
    end

    if isAdmin then
        for i = #Trainfitter.Persistent, 1, -1 do
            if Trainfitter.Persistent[i] == wsid then
                table.remove(Trainfitter.Persistent, i)
            end
        end
        SavePersistent()
        SendPersistentList()
    elseif IsPersistentWsid(wsid) then
        Notify(ply, "[Trainfitter] This addon is a server favorite, only admins can remove it", Color(255, 100, 100))
        return
    end

    if Trainfitter.ActiveSkin and Trainfitter.ActiveSkin.wsid == wsid then
        Trainfitter.ActiveSkin = nil
        SendActiveSkin()
    end

    Trainfitter.SessionBroadcast[wsid] = nil
    Trainfitter.MountedServer[wsid]    = nil

    BroadcastForget(wsid, sid)

    Notify(ply, "[Trainfitter] Skin " .. wsid .. " wiped for everyone",
        Color(100, 255, 150))
    Audit(ply, isAdmin and "skin_deleted_admin" or "skin_deleted_owner", wsid)
end)

net.Receive(NET.RequestList, function(_, ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID64() or "0"
    local now = CurTime()
    if lastListReq[sid] and (now - lastListReq[sid]) < 5 then return end
    lastListReq[sid] = now
    SendPersistentList(ply)
end)


net.Receive(NET.ResyncSkins, function(_, ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID64() or "0"
    local now = CurTime()
    if lastResyncReq[sid] and (now - lastResyncReq[sid]) < 5 then return end
    lastResyncReq[sid] = now

    SendPersistentList(ply)
    SendActiveSkin(ply)
    for wsid, info in pairs(Trainfitter.SessionBroadcast) do
        if istable(info) then
            WriteBroadcast(wsid, "", info.title, info.sizeMB, info.initiatorSid)
            net.Send(ply)
        end
    end
end)

local ADMIN_CVARS = {
    { name = "trainfitter_max_mb",               kind = "int",  min = 1, max = 8192 },
    { name = "trainfitter_require_admin",        kind = "bool" },
    { name = "trainfitter_request_cooldown",     kind = "int",  min = 0, max = 60 },
    { name = "trainfitter_max_persistent",       kind = "int",  min = 0, max = 50 },
    { name = "trainfitter_max_loaded",           kind = "int",  min = 0, max = 256 },
    { name = "trainfitter_max_per_player",       kind = "int",  min = 0, max = 256 },
    { name = "trainfitter_max_per_admin",        kind = "int",  min = 0, max = 256 },
    { name = "trainfitter_audit_log",            kind = "bool" },
    { name = "trainfitter_use_whitelist",        kind = "bool" },
    { name = "trainfitter_stats_enabled",        kind = "bool" },
    { name = "trainfitter_server_premount",      kind = "bool" },
    { name = "trainfitter_use_http",             kind = "bool" },
    { name = "trainfitter_max_session_addons",   kind = "int",  min = 0, max = 1000 },
    { name = "trainfitter_max_new_per_hour",     kind = "int",  min = 0, max = 1000 },
    { name = "trainfitter_cache_max_gb",         kind = "int",  min = 0, max = 1000 },
    { name = "trainfitter_allow_masks",          kind = "bool" },
    { name = "trainfitter_mel_support",          kind = "bool" },
    { name = "trainfitter_allow_full_lua",       kind = "bool" },
    { name = "trainfitter_max_lua_kb",           kind = "int",  min = 1, max = 4096 },
    { name = "trainfitter_sandbox_instr_m",      kind = "int",  min = 1, max = 10000 },
    { name = "trainfitter_reject_bytecode",      kind = "bool" },
    { name = "trainfitter_allow_collections",    kind = "bool" },
    { name = "trainfitter_max_collection",       kind = "int",  min = 0, max = 256 },
}

local function SendAdminConfig(target)
    if not IsValid(target) then return end
    local canManage = Trainfitter.CanManage(target)
    net.Start(NET.AdminConfig)
    net.WriteBool(canManage)
    net.WriteBool(Trainfitter.CanViewLogs(target))
    if canManage then
        net.WriteUInt(#ADMIN_CVARS, 8)
        for _, c in ipairs(ADMIN_CVARS) do
            local cv = GetConVar(c.name)
            net.WriteString(c.name)
            net.WriteString(c.kind)
            net.WriteString(cv and cv:GetString() or "")
        end
    else
        net.WriteUInt(0, 8)
    end
    net.Send(target)
end

local MANAGED_LISTS = {
    whitelist = { set = Trainfitter.Whitelist, save = SaveWhitelist },
    blacklist = { set = Trainfitter.Blacklist, save = SaveBlacklist },
}
local MANAGED_ORDER = { "whitelist", "blacklist" }

local function SendAdminLists(target)
    if not IsValid(target) then return end
    net.Start(NET.AdminListData)
    net.WriteUInt(#MANAGED_ORDER, 8)
    for _, name in ipairs(MANAGED_ORDER) do
        local arr = ArrayFromSet(MANAGED_LISTS[name].set)
        local n = math.min(#arr, 256)
        net.WriteString(name)
        net.WriteUInt(n, 16)
        for i = 1, n do net.WriteString(arr[i]) end
    end
    net.Send(target)
end

net.Receive(NET.AdminGetConfig, function(_, ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID64() or "0"
    local now = CurTime()
    if lastAdminGet[sid] and (now - lastAdminGet[sid]) < 1 then return end
    lastAdminGet[sid] = now
    if not (Trainfitter.CanManage(ply) or Trainfitter.CanViewLogs(ply)) then
        Audit(ply, "admin_get_no_perm", "")
        return
    end
    SendAdminConfig(ply)
    if Trainfitter.CanManage(ply) then SendAdminLists(ply) end
end)

net.Receive(NET.AdminManageList, function(len, ply)
    if len > 256 * 8 then return end
    if not IsValid(ply) then return end
    if NetGlobalThrottled(ply) then return end
    if not Trainfitter.CanManage(ply) then
        Notify(ply, "[Trainfitter] No perms to manage lists", Color(255, 100, 100))
        return
    end

    local listName = net.ReadString()
    local action   = net.ReadString()
    local wsid     = net.ReadString()

    local L = MANAGED_LISTS[listName]
    if not L then return end
    if action ~= "add" and action ~= "remove" then return end
    if not IsValidWSID(wsid) then
        Notify(ply, "[Trainfitter] WSID is bogus", Color(255, 100, 100))
        return
    end

    if action == "add" then
        L.set[wsid] = true
    else
        L.set[wsid] = nil
    end
    L.save()
    Audit(ply, "list_" .. action, listName .. " " .. wsid)

    for _, p in ipairs(player.GetAll()) do
        if Trainfitter.CanManage(p) then SendAdminLists(p) end
    end
end)

local LOGS_MAX_PER_PAGE = 50

net.Receive(NET.GetLogs, function(_, ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID64() or "0"
    local now = CurTime()
    if lastLogsReq[sid] and (now - lastLogsReq[sid]) < 1 then return end
    lastLogsReq[sid] = now
    if not Trainfitter.CanViewLogs(ply) then return end

    local page    = net.ReadUInt(16)
    local perPage = math.Clamp(net.ReadUInt(8), 1, LOGS_MAX_PER_PAGE)

    local lines = {}
    if file.Exists(AUDIT_FILE, "DATA") then
        local all = string.Split(file.Read(AUDIT_FILE, "DATA") or "", "\n")
        for i = 1, #all do
            if all[i] and all[i] ~= "" then lines[#lines + 1] = all[i] end
        end
    end
    local total = #lines

    local maxPage = total > 0 and math.ceil(total / perPage) - 1 or 0
    if page > maxPage then page = maxPage end

    local hiExclusive = total - (page * perPage)
    local loInclusive = math.max(1, hiExclusive - perPage + 1)
    local out = {}
    if hiExclusive >= 1 then
        for i = hiExclusive, loInclusive, -1 do
            local line = lines[i]
            local stamp, lsid, rest = string.match(line, "^%[([^%]]+)%] (%S+) (.+)$")
            if stamp and lsid then
                local nick = (lsid == "CONSOLE") and "Console" or Trainfitter.ResolveName(lsid)
                out[#out + 1] = { stamp = stamp, nick = nick or "?", sid = lsid, rest = rest or "" }
            else
                out[#out + 1] = { stamp = "", nick = "", sid = "", rest = line }
            end
        end
    end

    net.Start(NET.Logs)
    net.WriteUInt(page, 16)
    net.WriteUInt(total, 16)
    net.WriteUInt(#out, 8)
    for _, e in ipairs(out) do
        net.WriteString(string.sub(e.stamp, 1, 32))
        net.WriteString(string.sub(e.nick,  1, 48))
        net.WriteString(string.sub(e.sid,   1, 20))
        net.WriteString(string.sub(e.rest,  1, 200))
    end
    net.Send(ply)
end)

net.Receive(NET.AdminSetConVar, function(len, ply)
    if len > 512 * 8 then return end
    if not IsValid(ply) then return end
    if NetGlobalThrottled(ply) then return end
    if not Trainfitter.CanManage(ply) then
        Notify(ply, "[Trainfitter] No perms to touch settings", Color(255, 100, 100))
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

    if cv:GetString() == value then return end

    cv:SetString(value)
    if cv:GetString() ~= value then
        RunConsoleCommand(name, value)
    end

    Audit(ply, "admin_setcvar", name .. "=" .. value)

    local actor = SafeNick(ply)
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
            WriteBroadcast(wsid, "", info.title, info.sizeMB, info.initiatorSid)
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
        local s = "[Trainfitter] No audit log yet, nothing to show"
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
pcall(EnforceCacheCap)

local function PersistentSet()
    local s = {}
    for _, w in ipairs(Trainfitter.Persistent or {}) do s[w] = true end
    return s
end

local function PruneNonPersistentCache()
    local persist = PersistentSet()
    local removed = 0
    for _, dir in ipairs({ GMA_CACHE_DIR, HTTP_CACHE_DIR }) do
        if file.IsDir(dir, "DATA") then
            for _, fname in ipairs(file.Find(dir .. "/*.dat", "DATA") or {}) do
                local wsid = string.match(fname, "^(%d+)")
                if wsid and not persist[wsid] then
                    local rel = dir .. "/" .. fname
                    file.Delete(rel)
                    if not file.Exists(rel, "DATA") then removed = removed + 1 end
                end
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

hook.Add("InitPostEntity", "Trainfitter.RegisterCAMI", function()
    if Trainfitter.RegisterCAMIPrivileges then pcall(Trainfitter.RegisterCAMIPrivileges) end
end)

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
    local n = 0
    for _, dir in ipairs({ GMA_CACHE_DIR, HTTP_CACHE_DIR }) do
        if file.IsDir(dir, "DATA") then
            for _, fname in ipairs(file.Find(dir .. "/*.dat", "DATA") or {}) do
                local rel = dir .. "/" .. fname
                file.Delete(rel)
                if not file.Exists(rel, "DATA") then n = n + 1 end
            end
        end
    end
    Audit(ply, "cache_clear", "removed=" .. n)
    local s = "[Trainfitter] Wiped " .. n .. " cached GMA(s)"
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
    for _, dir in ipairs({ GMA_CACHE_DIR, HTTP_CACHE_DIR }) do
        if file.IsDir(dir, "DATA") then
            for _, fname in ipairs(file.Find(dir .. "/*.dat", "DATA") or {}) do
                local rel = dir .. "/" .. fname
                file.Delete(rel)
                if not file.Exists(rel, "DATA") then removedCache = removedCache + 1 end
            end
        end
    end
    Trainfitter.StopAllSandboxes()

    Audit(ply, "purge_all", string.format(
        "persistent=%d forgotten=%d cache=%d", #persistentCopy, forgotten, removedCache))
    local s = string.format(
        "[Trainfitter] Nuked: %d persistent, %d active broadcasts, %d cached GMAs",
        #persistentCopy, forgotten, removedCache)
    if IsValid(ply) then ply:ChatPrint(s) else print(s) end
end)

concommand.Add("trainfitter_forget_all", function(ply)
    if IsValid(ply) and not Trainfitter.CanManage(ply) then return end
    local n, c = Trainfitter.ForgetNonPersistent()
    local s = string.format("[Trainfitter] Forgot %d non-persistent, pruned %d cached", n, c)
    if IsValid(ply) then ply:ChatPrint(s) else print(s) end
    Audit(ply, "forget_all", string.format("forgotten=%d cache=%d", n, c))
end)
