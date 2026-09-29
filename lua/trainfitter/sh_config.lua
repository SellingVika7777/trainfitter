-- Trainfitter - sh_config.lua
-- Made by SellingVika

Trainfitter          = Trainfitter or {}
Trainfitter.Config   = Trainfitter.Config or {}

Trainfitter.Net = {
    Request          = "Trainfitter.Request",
    RequestCollection = "Trainfitter.RequestCollection",
    Broadcast        = "Trainfitter.Broadcast",
    ActiveSkin       = "Trainfitter.ActiveSkin",
    ForgetSkin       = "Trainfitter.ForgetSkin",
    RemovePersistent = "Trainfitter.RemovePersistent",
    SyncPersistent   = "Trainfitter.SyncPersistent",
    Notify           = "Trainfitter.Notify",
    RequestList      = "Trainfitter.RequestList",
    AdminGetConfig   = "Trainfitter.AdminGetConfig",
    AdminConfig      = "Trainfitter.AdminConfig",
    AdminSetConVar   = "Trainfitter.AdminSetConVar",
    DeleteSkin       = "Trainfitter.DeleteSkin",
    ReportSkins      = "Trainfitter.ReportSkins",
    GetServerStatus  = "Trainfitter.GetServerStatus",
    ServerStatus     = "Trainfitter.ServerStatus",
    AdminManageList  = "Trainfitter.AdminManageList",
    AdminListData    = "Trainfitter.AdminListData",
    Metrics          = "Trainfitter.Metrics",
    GetMetrics       = "Trainfitter.GetMetrics",
    GetLogs          = "Trainfitter.GetLogs",
    Logs             = "Trainfitter.Logs",
    ResyncSkins      = "Trainfitter.ResyncSkins",
    HostFetch        = "Trainfitter.HostFetch",
    HostFetched      = "Trainfitter.HostFetched",
}

if SERVER then
    CreateConVar("trainfitter_max_mb", "200", FCVAR_ARCHIVE + FCVAR_NOTIFY,
        "Maximum size of a single Workshop addon in MB for Trainfitter downloads.", 1, 8192)

    CreateConVar("trainfitter_require_admin", "0", FCVAR_ARCHIVE + FCVAR_NOTIFY,
        "1 = only admins can request downloads / favorites. 0 = everyone.", 0, 1)

    CreateConVar("trainfitter_request_cooldown", "2", FCVAR_ARCHIVE,
        "Seconds between download requests from the same player.", 0, 60)

    CreateConVar("trainfitter_max_persistent", "1", FCVAR_ARCHIVE,
        "Max addons kept in favorites (auto-mount on boot). 0 = unlimited.", 0, 50)

    CreateConVar("trainfitter_max_loaded", "0", FCVAR_ARCHIVE,
        "Max addons loaded on the server at once (whole session). 0 = unlimited.", 0, 256)

    CreateConVar("trainfitter_max_per_player", "1", FCVAR_ARCHIVE,
        "Max addons a regular player may have loaded at once. 0 = unlimited.", 0, 256)

    CreateConVar("trainfitter_max_per_admin", "1", FCVAR_ARCHIVE,
        "Max addons an admin may have loaded at once. 0 = unlimited.", 0, 256)

    CreateConVar("trainfitter_audit_log", "1", FCVAR_ARCHIVE,
        "Write events to data/trainfitter/audit.log.", 0, 1)

    CreateConVar("trainfitter_use_whitelist", "0", FCVAR_ARCHIVE,
        "1 = only wsids from whitelist.json allowed. 0 = all except blacklist.", 0, 1)

    CreateConVar("trainfitter_stats_enabled", "1", FCVAR_ARCHIVE,
        "Track download counters to data/trainfitter/stats.json.", 0, 1)

    CreateConVar("trainfitter_server_premount", "1", FCVAR_ARCHIVE,
        "Server pre-mounts persistent GMAs on boot (speeds up ENT.Skins).", 0, 1)

    CreateConVar("trainfitter_max_session_addons", "100", FCVAR_ARCHIVE,
        "Max different addons players may load during one map session (admins exempt). 0 = unlimited.", 0, 1000)

    CreateConVar("trainfitter_max_new_per_hour", "20", FCVAR_ARCHIVE,
        "Max new addons one player may load per hour (admins exempt). 0 = unlimited.", 0, 1000)

    CreateConVar("trainfitter_cache_max_gb", "20", FCVAR_ARCHIVE,
        "Max size of the Trainfitter GMA cache in data/ (GB). Oldest files are removed first. 0 = unlimited.", 0, 1000)

    CreateConVar("trainfitter_use_http", "0", FCVAR_ARCHIVE,
        "1 = force HTTP fetch even on dedicated server with gmsv_workshop. "
        .. "0 = auto: native on dedicated srcds with gmsv_workshop, HTTP on listen-server / when "
        .. "gmsv_workshop missing.", 0, 1)
end

CreateConVar("trainfitter_allow_masks", "1", { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY },
    "1 = allow masks, pults and other scripted Metrostroi addons. Their Lua runs in the Trainfitter sandbox.", 0, 1)

CreateConVar("trainfitter_mel_support", "0", { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY },
    "1 = this server runs Metrostroi Extensions Library (MEL), addons that require MEL are allowed. "
    .. "0 = addons that require MEL are rejected.", 0, 1)

CreateConVar("trainfitter_allow_full_lua", "0", { FCVAR_ARCHIVE, FCVAR_REPLICATED },
    "DANGEROUS: 1 = addons on the whitelist run their Lua WITHOUT the sandbox with full server permissions. "
    .. "Addons that are not whitelisted always stay sandboxed.", 0, 1)

CreateConVar("trainfitter_max_lua_kb", "256", { FCVAR_ARCHIVE, FCVAR_REPLICATED },
    "Max size of one addon Lua file in KB.", 1, 4096)

CreateConVar("trainfitter_sandbox_instr_m", "100", { FCVAR_ARCHIVE, FCVAR_REPLICATED },
    "Max sandbox instructions (millions) for loading one addon file.", 1, 10000)

CreateConVar("trainfitter_reject_bytecode", "1", { FCVAR_ARCHIVE, FCVAR_REPLICATED },
    "1 = reject Lua bytecode (default, safe). Only affects trainfitter_allow_full_lua mode.", 0, 1)

CreateConVar("trainfitter_allow_collections", "0", { FCVAR_ARCHIVE, FCVAR_REPLICATED },
    "1 = let players apply whole Workshop collections at once. 0 = single addons only.", 0, 1)

CreateConVar("trainfitter_max_collection", "0", { FCVAR_ARCHIVE, FCVAR_REPLICATED },
    "Max addons pulled from one collection. 0 = unlimited.", 0, 256)

if CLIENT then
    CreateClientConVar("trainfitter_auto_subscribe", "1", true, false,
        "1 = auto-subscribe to Workshop addons via Steam when applying a skin "
        .. "(only on listen-server / single-player). 0 = never auto-subscribe.")

    CreateClientConVar("trainfitter_skins_enabled", "1", true, false,
        "1 = download and mount Trainfitter skins for you. "
        .. "0 = skip them entirely (saves CPU / RAM / bandwidth, trains stay default).")
end

Trainfitter.Config.DefaultMaxMB    = 200
Trainfitter.Config.MountTimeoutSec = 900

Trainfitter.WSID_MAX_LEN = 20
Trainfitter.GMOD_APPID   = 4000

Trainfitter.SkinNWKeys = {
    train = "Texture",
    pass  = "PassTexture",
    cab   = "CabTexture",
}

Trainfitter.MaskNWKeys = {
    front    = "MaskTexture",
    mask     = "MaskTexture",
    rear     = "RearMaskTexture",
    rearmask = "RearMaskTexture",
}

function Trainfitter.GetTrainNWKey(kind, category)
    if kind == "mask" then return Trainfitter.MaskNWKeys[category] end
    return Trainfitter.SkinNWKeys[category]
end

function Trainfitter.IsValidWSID(s)
    if not isstring(s) then return false end
    if #s < 4 or #s > Trainfitter.WSID_MAX_LEN then return false end
    return string.match(s, "^%d+$") ~= nil
end

Trainfitter._wsInfoCache = Trainfitter._wsInfoCache or {}
local WSINFO_TTL = 60

function Trainfitter.SafeFetchWorkshopInfo(wsid, cb)
    if not Trainfitter.IsValidWSID(wsid) then
        cb(nil, "invalid wsid")
        return
    end

    local cached = Trainfitter._wsInfoCache[wsid]
    if cached and (SysTime() - cached.at) < WSINFO_TTL then
        cb(cached.info)
        return
    end

    http.Post(
        "https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/",
        {
            ["itemcount"]           = "1",
            ["publishedfileids[0]"] = wsid,
        },
        function(body)
            if not isstring(body) or #body > 4 * 1024 * 1024 then
                cb(nil, "steam response too large")
                return
            end
            local ok, data = pcall(util.JSONToTable, body)
            if not ok or not istable(data) or not istable(data.response) then
                cb(nil, "bad Steam API response")
                return
            end
            local d = data.response.publishedfiledetails
                  and data.response.publishedfiledetails[1]
            if not istable(d) then
                cb(nil, "no publishedfiledetails")
                return
            end
            if d.result ~= nil and tonumber(d.result) ~= 1 then
                cb(nil, "Steam result=" .. tostring(d.result))
                return
            end
            local info = {
                title          = isstring(d.title) and d.title or "",
                size           = tonumber(d.file_size) or 0,
                creator_appid  = tonumber(d.creator_app_id) or tonumber(d.creator_appid),
                consumer_appid = tonumber(d.consumer_app_id) or tonumber(d.consumer_appid),
                description    = isstring(d.description) and d.description or "",
                previewurl     = isstring(d.preview_url) and d.preview_url or "",
                file_url       = isstring(d.file_url) and d.file_url or "",
                hcontent_file  = isstring(d.hcontent_file) and d.hcontent_file or "",
            }
            Trainfitter._wsInfoCache[wsid] = { at = SysTime(), info = info }
            cb(info)
        end,
        function(err) cb(nil, "http.Post: " .. tostring(err)) end
    )
end

Trainfitter._depsCache = Trainfitter._depsCache or {}
local DEPS_TTL = 600

local function ParseRequiredItems(body, wsid)
    local out, seen = {}, {}
    local s = string.find(body, 'id="RequiredItems"', 1, true)
    if not s then return out end
    local e = string.find(body, "rightSectionTopTitle", s, true) or (s + 20000)
    local seg = string.sub(body, s, e)
    for id in string.gmatch(seg, "filedetails/%?id=(%d+)") do
        if id ~= wsid and not seen[id] and Trainfitter.IsValidWSID(id) then
            seen[id] = true
            out[#out + 1] = id
        end
    end
    return out
end

function Trainfitter.FetchRequiredItems(wsid, cb)
    if not Trainfitter.IsValidWSID(wsid) then cb(nil, "invalid wsid") return end
    local cached = Trainfitter._depsCache[wsid]
    if cached and (SysTime() - cached.at) < DEPS_TTL then cb(cached.list, cached.source) return end

    local function store(list, source)
        Trainfitter._depsCache[wsid] = { at = SysTime(), list = list, source = source }
        cb(list, source)
    end

    local function viaWeb()
        http.Fetch("https://steamcommunity.com/sharedfiles/filedetails/?id=" .. wsid, function(body, _, _, code)
            if not isstring(body) or (code and code >= 400) or #body > 8 * 1024 * 1024 then
                cb(nil, "workshop page unavailable")
                return
            end
            if not string.find(body, "sharedfiles_content_ctn", 1, true) then
                cb(nil, "workshop page unreadable")
                return
            end
            store(ParseRequiredItems(body, wsid), "web")
        end, function(err) cb(nil, "http: " .. tostring(err)) end, { ["Accept-Language"] = "en-US,en" })
    end

    if SERVER and steamworks and isstring(steamworks.gmsv_workshop) and isfunction(steamworks.FileInfo) then
        local ok = pcall(steamworks.FileInfo, wsid, function(info)
            if istable(info) and info.error == nil and istable(info.children) then
                local list = {}
                for _, id in ipairs(info.children) do
                    id = tostring(id)
                    if id ~= wsid and Trainfitter.IsValidWSID(id) then list[#list + 1] = id end
                end
                store(list, "steam")
            else
                viaWeb()
            end
        end)
        if ok then return end
    end
    viaWeb()
end

function Trainfitter.FetchCollectionChildren(wsid, cb)
    if not Trainfitter.IsValidWSID(wsid) then
        cb(nil, "invalid wsid")
        return
    end

    http.Post(
        "https://api.steampowered.com/ISteamRemoteStorage/GetCollectionDetails/v1/",
        {
            ["collectioncount"]      = "1",
            ["publishedfileids[0]"]  = wsid,
        },
        function(body)
            if not isstring(body) or #body > 4 * 1024 * 1024 then
                cb(nil, "steam response too large")
                return
            end
            local ok, data = pcall(util.JSONToTable, body)
            if not ok or not istable(data) or not istable(data.response) then
                cb(nil, "bad Steam API response")
                return
            end
            local d = data.response.collectiondetails
                  and data.response.collectiondetails[1]
            if not istable(d) then
                cb(nil, "not a collection")
                return
            end
            if d.result ~= nil and tonumber(d.result) ~= 1 then
                cb(nil, "not a collection (result=" .. tostring(d.result) .. ")")
                return
            end
            local children = {}
            if istable(d.children) then
                for _, c in ipairs(d.children) do
                    local cw = istable(c) and tostring(c.publishedfileid or "")
                    if cw and Trainfitter.IsValidWSID(cw) then
                        children[#children + 1] = cw
                    end
                end
            end
            cb(children)
        end,
        function(err) cb(nil, "http.Post: " .. tostring(err)) end
    )
end

if LFAdmin and LFAdmin.RegisterAccess then
    LFAdmin.RegisterAccess("trainfitter_download",   "v")
    LFAdmin.RegisterAccess("trainfitter_persistent", "a")
    LFAdmin.RegisterAccess("trainfitter_manage",     "s")
    LFAdmin.RegisterAccess("trainfitter_logs",       "a")
end

if SERVER and ULib and ULib.ucl and ULib.ucl.registerAccess then
    ULib.ucl.registerAccess("trainfitter_download",
        ULib.ACCESS_ALL, "Use Trainfitter to download skins.", "Trainfitter")
    ULib.ucl.registerAccess("trainfitter_persistent",
        ULib.ACCESS_ADMIN, "Mark skins as persistent / save active.", "Trainfitter")
    ULib.ucl.registerAccess("trainfitter_manage",
        ULib.ACCESS_SUPERADMIN,
        "Change Trainfitter settings, whitelist/blacklist, delete cache.", "Trainfitter")
    ULib.ucl.registerAccess("trainfitter_logs",
        ULib.ACCESS_ADMIN, "View Trainfitter audit logs in the menu.", "Trainfitter")
end

Trainfitter.Privileges = {
    { Name = "trainfitter_download",   MinAccess = "user",       Description = "Use Trainfitter to download skins." },
    { Name = "trainfitter_persistent", MinAccess = "admin",      Description = "Mark skins as persistent / save active." },
    { Name = "trainfitter_manage",     MinAccess = "superadmin", Description = "Change Trainfitter settings, lists, cache." },
    { Name = "trainfitter_logs",       MinAccess = "admin",      Description = "View Trainfitter audit logs." },
}

function Trainfitter.RegisterCAMIPrivileges()
    if not (CAMI and isfunction(CAMI.RegisterPrivilege)) then return end
    for _, p in ipairs(Trainfitter.Privileges) do
        if not (isfunction(CAMI.GetPrivilege) and CAMI.GetPrivilege(p.Name)) then
            CAMI.RegisterPrivilege({ Name = p.Name, MinAccess = p.MinAccess, Description = p.Description })
        end
    end
end
Trainfitter.RegisterCAMIPrivileges()

local function IsRamziLike(ply)
    if not IsValid(ply) then return false end
    if isfunction(ply.IsRamzi) and ply:IsRamzi() then return true end
    if LFAdmin and isfunction(ply.IsSuperAdmin) and ply:IsSuperAdmin() then
        return true
    end
    return false
end

local function LFAdminHasAccess(ply, accessName)
    if not LFAdmin or not LFAdmin.CustomAccess then return nil end
    local ac = LFAdmin.CustomAccess[accessName]
    if not ac then return nil end
    if not ply.HasAccess then return nil end
    if IsRamziLike(ply) then return true end
    return ply:HasAccess(ac.access) == true
end

local function ULXHasAccess(ply, accessName)
    if not ULib or not ULib.ucl or not isfunction(ULib.ucl.query) then return nil end
    local ok = ULib.ucl.query(ply, accessName)
    if ok == nil then return nil end
    return ok == true
end

Trainfitter._PermProviders      = Trainfitter._PermProviders or {}
Trainfitter._PermProviderByName = Trainfitter._PermProviderByName or {}

function Trainfitter.RegisterPermissionProvider(name, fn)
    if not isstring(name) or not isfunction(fn) then return false end
    if Trainfitter._PermProviderByName[name] then
        for _, p in ipairs(Trainfitter._PermProviders) do
            if p.name == name then p.fn = fn break end
        end
    else
        Trainfitter._PermProviders[#Trainfitter._PermProviders + 1] = { name = name, fn = fn }
    end
    Trainfitter._PermProviderByName[name] = fn
    return true
end

function Trainfitter.UnregisterPermissionProvider(name)
    if not Trainfitter._PermProviderByName[name] then return false end
    Trainfitter._PermProviderByName[name] = nil
    for i, p in ipairs(Trainfitter._PermProviders) do
        if p.name == name then table.remove(Trainfitter._PermProviders, i) break end
    end
    return true
end

if not Trainfitter._builtinProvidersRegistered then
    Trainfitter._builtinProvidersRegistered = true

    Trainfitter.RegisterPermissionProvider("ramzi", function(ply)
        if IsRamziLike(ply) then return true end
        return nil
    end)

    Trainfitter.RegisterPermissionProvider("lfadmin", function(ply, priv)
        return LFAdminHasAccess(ply, priv)
    end)

    Trainfitter.RegisterPermissionProvider("ulx", function(ply, priv)
        return ULXHasAccess(ply, priv)
    end)

    Trainfitter.RegisterPermissionProvider("evolve", function(ply, priv)
        if evolve and isfunction(ply.EV_HasPrivilege) and ply:EV_HasPrivilege(priv) == true then
            return true
        end
        return nil
    end)

    Trainfitter.RegisterPermissionProvider("CAMI", function(ply, priv)
        if not (CAMI and isfunction(CAMI.PlayerHasAccess)) then return nil end
        local decided, result = false, false
        CAMI.PlayerHasAccess(ply, priv, function(hasAccess)
            decided, result = true, (hasAccess == true)
        end, nil, { Fallback = "no_one" })
        if not decided then return nil end
        return result == true
    end)
end

local function IsServerOwner(ply)
    if not IsValid(ply) then return false end
    if isfunction(ply.IsListenServerHost) and ply:IsListenServerHost() then return true end
    if isfunction(game.SinglePlayer) and game.SinglePlayer() then return true end
    return false
end

local function CheckPrivilege(ply, accessName, fallback)
    if not IsValid(ply) then return false end
    if IsServerOwner(ply) then return true end

    local denied = false
    for _, p in ipairs(Trainfitter._PermProviders) do
        local ok, res = pcall(p.fn, ply, accessName)
        if ok and res == true then return true end
        if ok and res == false then denied = true end
    end
    if denied then return false end

    return fallback(ply) == true
end

function Trainfitter.CanDownload(ply)
    if SERVER and not GetConVar("trainfitter_require_admin"):GetBool() then
        return true
    end
    return CheckPrivilege(ply, "trainfitter_download",
        function(p) return p:IsAdmin() end)
end

function Trainfitter.CanMakePersistent(ply)
    return CheckPrivilege(ply, "trainfitter_persistent",
        function(p) return p:IsAdmin() end)
end

function Trainfitter.CanManage(ply)
    return CheckPrivilege(ply, "trainfitter_manage",
        function(p) return p:IsSuperAdmin() end)
end

function Trainfitter.CanViewLogs(ply)
    if Trainfitter.CanManage(ply) then return true end
    return CheckPrivilege(ply, "trainfitter_logs",
        function(p) return p:IsAdmin() end)
end
