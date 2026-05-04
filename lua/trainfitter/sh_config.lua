-- Trainfitter — sh_config.lua
-- Made by SellingVika.

Trainfitter          = Trainfitter or {}
Trainfitter.Config   = Trainfitter.Config or {}

Trainfitter.Net = {
    Request          = "Trainfitter.Request",
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
}

if SERVER then
    CreateConVar("trainfitter_max_mb", "200", FCVAR_ARCHIVE + FCVAR_NOTIFY,
        "Maximum size of a single Workshop addon in MB for Trainfitter downloads.", 1, 8192)

    CreateConVar("trainfitter_require_admin", "0", FCVAR_ARCHIVE + FCVAR_NOTIFY,
        "1 = only admins can request downloads / favorites. 0 = everyone.", 0, 1)

    CreateConVar("trainfitter_request_cooldown", "2", FCVAR_ARCHIVE,
        "Seconds between download requests from the same player.", 0, 60)

    CreateConVar("trainfitter_max_persistent", "1", FCVAR_ARCHIVE,
        "Max addons in favorites. Single-slot model: values > 1 are ignored.", 1, 1)

    CreateConVar("trainfitter_audit_log", "1", FCVAR_ARCHIVE,
        "Write events to data/trainfitter/audit.log.", 0, 1)

    CreateConVar("trainfitter_use_whitelist", "0", FCVAR_ARCHIVE,
        "1 = only wsids from whitelist.json allowed. 0 = all except blacklist.", 0, 1)

    CreateConVar("trainfitter_stats_enabled", "1", FCVAR_ARCHIVE,
        "Track download counters to data/trainfitter/stats.json.", 0, 1)

    CreateConVar("trainfitter_server_premount", "1", FCVAR_ARCHIVE,
        "Server pre-mounts persistent GMAs on boot (speeds up ENT.Skins).", 0, 1)

    CreateConVar("trainfitter_use_http", "0", FCVAR_ARCHIVE,
        "1 = force HTTP fetch even on dedicated server with gmsv_workshop. "
        .. "0 = auto: native on dedicated srcds with gmsv_workshop, HTTP on listen-server / when "
        .. "gmsv_workshop missing.", 0, 1)
end

if CLIENT then
    CreateClientConVar("trainfitter_auto_subscribe", "1", true, false,
        "1 = auto-subscribe to Workshop addons via Steam when applying a skin "
        .. "(only on listen-server / single-player). 0 = never auto-subscribe.")
end

Trainfitter.Config.DefaultMaxMB    = 200
Trainfitter.Config.MountTimeoutSec = 60

Trainfitter.WSID_MAX_LEN = 20
Trainfitter.GMOD_APPID   = 4000

function Trainfitter.IsValidWSID(s)
    if not isstring(s) then return false end
    if #s < 4 or #s > Trainfitter.WSID_MAX_LEN then return false end
    return string.match(s, "^%d+$") ~= nil
end

function Trainfitter.SafeFetchWorkshopInfo(wsid, cb)
    if not Trainfitter.IsValidWSID(wsid) then
        cb(nil, "invalid wsid")
        return
    end

    http.Post(
        "https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/",
        {
            ["itemcount"]           = "1",
            ["publishedfileids[0]"] = wsid,
        },
        function(body)
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
            cb({
                title          = isstring(d.title) and d.title or "",
                size           = tonumber(d.file_size) or 0,
                creator_appid  = tonumber(d.creator_app_id) or tonumber(d.creator_appid),
                consumer_appid = tonumber(d.consumer_app_id) or tonumber(d.consumer_appid),
                description    = isstring(d.description) and d.description or "",
                previewurl     = isstring(d.preview_url) and d.preview_url or "",
                file_url       = isstring(d.file_url) and d.file_url or "",
                hcontent_file  = isstring(d.hcontent_file) and d.hcontent_file or "",
            })
        end,
        function(err) cb(nil, "http.Post: " .. tostring(err)) end
    )
end

if LFAdmin and LFAdmin.RegisterAccess then
    LFAdmin.RegisterAccess("trainfitter_download",   "v")
    LFAdmin.RegisterAccess("trainfitter_persistent", "a")
    LFAdmin.RegisterAccess("trainfitter_manage",     "s")
end

if SERVER and ULib and ULib.ucl and ULib.ucl.registerAccess then
    ULib.ucl.registerAccess("trainfitter_download",
        ULib.ACCESS_ALL, "Use Trainfitter to download skins.", "Trainfitter")
    ULib.ucl.registerAccess("trainfitter_persistent",
        ULib.ACCESS_ADMIN, "Mark skins as persistent / save active.", "Trainfitter")
    ULib.ucl.registerAccess("trainfitter_manage",
        ULib.ACCESS_SUPERADMIN,
        "Change Trainfitter settings, whitelist/blacklist, delete cache.", "Trainfitter")
end

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

local function CheckPrivilege(ply, accessName, fallback)
    if not IsValid(ply) then return false end
    if IsRamziLike(ply) then return true end
    if LFAdminHasAccess(ply, accessName) == true then return true end
    if ULXHasAccess(ply, accessName)     == true then return true end
    return fallback(ply)
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
