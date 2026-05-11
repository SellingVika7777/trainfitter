-- Trainfitter — sh_gma_scan.lua
-- Made by SellingVika.

Trainfitter = Trainfitter or {}

local DANGEROUS_PREFIXES = {
    "lua/includes/",
    "lua/menu/",
    "lua/derma/",
    "lua/vgui/",
    "lua/weapons/",
    "lua/effects/",
    "lua/entities/",
    "lua/postprocess/",
    "lua/matproxy/",
    "lua/sitools/",
    "lua/wire/",
    "gamemodes/",
    "maps/",
    "addons/",
    "bin/",
    "cfg/",
    "data/",
    "scripts/vehicles/",
    "scripts/weapons/",
}

local DATA_PREFIXES = {
    "materials/",
    "models/",
    "sound/",
    "resource/",
    "scripts/",
}

local LUA_ALLOWED_PREFIXES = {
    "lua/metrostroi/skins/",
    "lua/metrostroi/masks/",
    "lua/autorun/",
}

local ALLOWED_EXACT = {
    ["addon.json"]    = true,
    ["addon.txt"]     = true,
    ["workshop.json"] = true,
    ["readme"]        = true,
    ["readme.md"]     = true,
    ["readme.txt"]    = true,
    ["license"]       = true,
    ["license.txt"]   = true,
    ["license.md"]    = true,
    ["changelog"]     = true,
    ["changelog.md"]  = true,
    ["changelog.txt"] = true,
}

local ALLOWED_EXTS = {
    lua = true,
    vmt = true, vtf = true, png = true, jpg = true, jpeg = true,
    mdl = true, vvd = true, phy = true, vtx = true, ani = true,
    wav = true, mp3 = true, ogg = true,
    ttf = true, otf = true,
    txt = true, md = true, json = true, properties = true,
    pcf = true,
}

local MAX_LUA_FILE_SIZE      = 64   * 1024
local MAX_FILE_SIZE          = 256  * 1024 * 1024
local MAX_TOTAL_UNCOMPRESSED = 1024 * 1024 * 1024
local MAX_TOTAL_FILES        = 4096
local MAX_LUA_FILES          = 256
local MAX_TOTAL_LUA_BYTES    = 4 * 1024 * 1024

local function PreflightCheck(content, displayPath)
    if not isstring(content) or #content == 0 then
        return false, "empty lua file: " .. tostring(displayPath)
    end
    if #content > MAX_LUA_FILE_SIZE then
        return false, string.format(
            "lua file too large: %s (%d B, max %d B)",
            tostring(displayPath), #content, MAX_LUA_FILE_SIZE)
    end
    for i = 1, math.min(#content, 4096) do
        if string.byte(content, i) == 0 then
            return false, "NUL byte in " .. tostring(displayPath)
        end
    end
    return true
end

function Trainfitter.ValidateSkinLua(content, displayPath)
    return PreflightCheck(content, displayPath)
end

function Trainfitter.ValidateMaskLua(content, displayPath)
    return PreflightCheck(content, displayPath)
end

local function ShallowCopy(t)
    if not istable(t) then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = v end
    return r
end

local function SafeStringLib()
    local s = ShallowCopy(string)
    s.dump = nil
    return s
end

local function StripMetas(t, seen)
    if not istable(t) then return end
    seen = seen or {}
    if seen[t] then return end
    seen[t] = true
    pcall(setmetatable, t, nil)
    for _, v in pairs(t) do
        if istable(v) then StripMetas(v, seen) end
    end
end

local SAFE_ENT_METHODS = {
    "IsValid", "EntIndex", "GetClass", "GetModel",
    "GetPos", "GetAngles", "GetForward", "GetRight", "GetUp",
    "GetNWVar", "GetNW2Var",
    "GetNWString", "GetNWInt", "GetNWFloat", "GetNWBool",
    "GetNW2String", "GetNW2Int", "GetNW2Float", "GetNW2Bool",
    "Nick", "GetName", "Name",
    "SteamID", "SteamID64", "UserID", "AccountID",
    "Team", "GetTeam",
    "IsBot", "IsPlayer", "IsAdmin", "IsSuperAdmin",
    "EyePos", "EyeAngles",
}

local function MakeEntProxy(ent)
    if not isentity(ent) then return ent end
    if not IsValid(ent) then
        return {
            IsValid  = function() return false end,
            EntIndex = function() return 0 end,
        }
    end
    local p = {}
    for _, name in ipairs(SAFE_ENT_METHODS) do
        local fn = ent[name]
        if isfunction(fn) then
            p[name] = function(_, ...) return fn(ent, ...) end
        end
    end
    return p
end

local function ProxyList(list)
    if not istable(list) then return {} end
    local out = {}
    for _, e in ipairs(list) do
        local p = MakeEntProxy(e)
        if p then out[#out + 1] = p end
    end
    return out
end

local function ProxyArgs(...)
    local n = select("#", ...)
    if n == 0 then return end
    local args = {...}
    for i = 1, n do
        if isentity(args[i]) then args[i] = MakeEntProxy(args[i]) end
    end
    return unpack(args, 1, n)
end

local function ProxyCallback(fn)
    if not isfunction(fn) then return fn end
    return function(...) return fn(ProxyArgs(...)) end
end

local function ProxyTableFunctions(t)
    if not istable(t) then return t end
    local r = {}
    for k, v in pairs(t) do
        if isfunction(v) then r[k] = ProxyCallback(v) else r[k] = v end
    end
    return r
end

local function MakeMetrostroiView()
    if not istable(Metrostroi) then return {} end
    local function wrap(fn)
        if not isfunction(fn) then return nil end
        return function(c, t)
            StripMetas(t)
            return fn(c, ProxyTableFunctions(t))
        end
    end
    return {
        AddSkin           = wrap(Metrostroi.AddSkin),
        AddMask           = wrap(Metrostroi.AddMask),
        RegisterSkin      = wrap(Metrostroi.RegisterSkin),
        DefineSkin        = wrap(Metrostroi.DefineSkin),
        RegisterMask      = wrap(Metrostroi.RegisterMask),
        DefineMask        = wrap(Metrostroi.DefineMask),
        AddLastStationTex = Metrostroi.AddLastStationTex,
    }
end

local function MakeNamespacedHook(prefix)
    local function ns(id) return prefix .. "::" .. tostring(id) end
    return {
        Add = function(name, id, fn)
            if not isstring(name) or not isfunction(fn) then return end
            return hook.Add(name, ns(id), ProxyCallback(fn))
        end,
        Remove = function(name, id)
            if not isstring(name) then return end
            return hook.Remove(name, ns(id))
        end,
    }
end

local function MakeNamespacedTimer(prefix)
    local function ns(name) return prefix .. "::" .. tostring(name) end
    return {
        Create   = function(name, ...) if not isstring(name) then return end return timer.Create(ns(name), ...) end,
        Simple   = timer.Simple,
        Exists   = function(name) if not isstring(name) then return false end return timer.Exists(ns(name)) end,
        Remove   = function(name) if not isstring(name) then return end return timer.Remove(ns(name)) end,
        Adjust   = function(name, ...) if not isstring(name) then return end return timer.Adjust(ns(name), ...) end,
        Start    = function(name) if not isstring(name) then return end return timer.Start(ns(name)) end,
        Stop     = function(name) if not isstring(name) then return end return timer.Stop(ns(name)) end,
        Toggle   = function(name) if not isstring(name) then return end return timer.Toggle(ns(name)) end,
        Pause    = function(name) if not isstring(name) then return end return timer.Pause(ns(name)) end,
        UnPause  = function(name) if not isstring(name) then return end return timer.UnPause(ns(name)) end,
        TimeLeft = function(name) if not isstring(name) then return 0  end return timer.TimeLeft(ns(name)) end,
        RepsLeft = function(name) if not isstring(name) then return 0  end return timer.RepsLeft(ns(name)) end,
    }
end

local function MakePathPrefix(path)
    local s = tostring(path or "anon")
    s = string.gsub(s, "[^%w_/.%-]", "_")
    return "trainfitter_sb:" .. s
end

local function SafeMaterial(path, params)
    if not isstring(path) then return nil end
    if string.find(path, "..", 1, true)  then return nil end
    if string.find(path, ":",  1, true)  then return nil end
    if string.sub(path, 1, 1) == "/"     then return nil end
    if string.sub(path, 1, 1) == "\\"    then return nil end
    return Material(path, params)
end

local function BuildSkinSandbox()
    local sb = {
        Metrostroi = MakeMetrostroiView(),

        Color  = Color,
        Vector = Vector,
        Angle  = Angle,

        table  = ShallowCopy(table),
        string = SafeStringLib(),
        math   = ShallowCopy(math),
        bit    = ShallowCopy(bit),

        IsValid    = IsValid,
        isnumber   = isnumber,
        isstring   = isstring,
        istable    = istable,
        isbool     = isbool,
        isfunction = isfunction,
        isvector   = isvector,
        isangle    = isangle,
        isentity   = isentity,
        isnan      = isnan,
        isinf      = isinf,

        type        = type,
        tostring    = tostring,
        tonumber    = tonumber,
        ErrorNoHalt = ErrorNoHalt,
        Format      = Format,

        pairs   = pairs,
        ipairs  = ipairs,
        next    = next,
        select  = select,
        unpack  = unpack,

        pcall  = pcall,
        error  = error,
        assert = assert,

        SERVER = SERVER,
        CLIENT = CLIENT,

        Material = SafeMaterial,
        AddCSLuaFile = function() end,
        print = function() end,
    }
    sb._G = sb
    return sb
end

local function BuildMaskSandbox(prefix)
    local sb = BuildSkinSandbox()

    sb.hook  = MakeNamespacedHook(prefix)
    sb.timer = MakeNamespacedTimer(prefix)

    sb.FindMetaTable = function(name)
        if name ~= "Entity" then return nil end
        local mt = FindMetaTable("Entity")
        if not mt or not isfunction(mt.GetClass) then return nil end
        return { GetClass = mt.GetClass }
    end

    sb.Entity = function(idx) return MakeEntProxy(Entity(idx)) end

    sb.ents = {
        FindByClass  = function(c)    return ProxyList(ents.FindByClass(c)) end,
        FindInSphere = function(p, r) return ProxyList(ents.FindInSphere(p, r)) end,
        FindInBox    = function(a, b) return ProxyList(ents.FindInBox(a, b)) end,
        GetAll       = function()     return ProxyList(ents.GetAll()) end,
        GetByIndex   = function(i)    return MakeEntProxy(ents.GetByIndex(i)) end,
        GetCount     = ents.GetCount,
    }

    sb.player = {
        GetAll         = function()  return ProxyList(player.GetAll()) end,
        GetHumans      = function()  return ProxyList(player.GetHumans()) end,
        GetBots        = function()  return ProxyList(player.GetBots()) end,
        GetByID        = function(i) return MakeEntProxy(player.GetByID(i)) end,
        GetBySteamID   = function(s) return MakeEntProxy(player.GetBySteamID(s)) end,
        GetBySteamID64 = function(s) return MakeEntProxy(player.GetBySteamID64(s)) end,
        GetCount       = player.GetCount,
    }

    sb.print      = print
    sb.MsgC       = MsgC
    sb.Msg        = Msg
    sb.MsgN       = MsgN
    sb.PrintTable = PrintTable

    sb._G = sb
    return sb
end

local SANDBOX_INSTR_LIMIT = 100 * 1000 * 1000

function Trainfitter.ExecSandboxed(content, path, kind)
    if not isstring(content) or #content == 0 then
        return false, "empty content"
    end
    if string.byte(content, 1) == 0x1B then
        return false, "lua bytecode rejected"
    end
    local fn, compileErr = CompileString(content, path, false)
    if isstring(fn) then return false, "compile: " .. fn end
    if not isfunction(fn) then return false, "compile returned non-function" end

    if not isfunction(setfenv) then
        return false, "setfenv unavailable — refusing to execute without sandbox"
    end

    local prefix = MakePathPrefix(path)
    local sb = (kind == "mask") and BuildMaskSandbox(prefix) or BuildSkinSandbox()
    local setOk, setErr = pcall(setfenv, fn, sb)
    if not setOk then return false, "setfenv failed: " .. tostring(setErr) end

    local hookSet = false
    if debug and isfunction(debug.sethook) then
        debug.sethook(function() error("instruction limit exceeded", 2) end,
                      "", SANDBOX_INSTR_LIMIT)
        hookSet = true
    end

    local ok, runErr = pcall(fn)

    if hookSet then debug.sethook() end

    if not ok then return false, "runtime: " .. tostring(runErr) end
    return true
end

local function read_cstr(f, maxlen)
    if not f then return "" end
    maxlen = maxlen or 128

    local ok, s = pcall(f.ReadString, f, maxlen)
    if ok and isstring(s) then return s end

    local out = {}
    for _ = 1, maxlen do
        local b = f:Read(1)
        if not b or #b == 0 then break end
        if b == "\0" then break end
        out[#out + 1] = b
    end
    return table.concat(out)
end

local function read_u32(f)
    local b = f:Read(4)
    if not b or #b < 4 then return 0 end
    return string.byte(b, 1)
         + string.byte(b, 2) * 0x100
         + string.byte(b, 3) * 0x10000
         + string.byte(b, 4) * 0x1000000
end

local function read_u64_as_num(f)
    local b = f:Read(8)
    if not b or #b < 8 then return 0 end
    local lo = string.byte(b, 1)
           + string.byte(b, 2) * 0x100
           + string.byte(b, 3) * 0x10000
           + string.byte(b, 4) * 0x1000000
    local hi = string.byte(b, 5)
           + string.byte(b, 6) * 0x100
           + string.byte(b, 7) * 0x10000
           + string.byte(b, 8) * 0x1000000
    return lo + hi * 2^32
end

local function is_dangerous_path(p)
    for _, pref in ipairs(DANGEROUS_PREFIXES) do
        if string.sub(p, 1, #pref) == pref then return pref end
    end
    if string.find(p, "..", 1, true)   then return ".." end
    if string.find(p, "\0",   1, true) then return "\\0" end
    if string.find(p, ":",    1, true) then return ":"  end
    if string.sub(p, 1, 1) == "/"      then return "/"  end
    if string.sub(p, 1, 1) == "\\"     then return "\\" end
    return nil
end

local function is_lua_addon_path(p)
    for _, pref in ipairs(LUA_ALLOWED_PREFIXES) do
        if string.sub(p, 1, #pref) == pref then return pref end
    end
    return nil
end

local function is_allowed_path(p, is_lua)
    if ALLOWED_EXACT[p] then return true end

    if is_lua then
        return is_lua_addon_path(p) ~= nil
    end

    for _, pref in ipairs(DATA_PREFIXES) do
        if string.sub(p, 1, #pref) == pref then return true end
    end
    return false
end

local function get_ext(p)
    local dot = string.find(p, "%.[^%./]+$")
    if not dot then return "" end
    return string.sub(p, dot + 1)
end

function Trainfitter.ScanGMA(gmapath)
    if not isstring(gmapath) or gmapath == "" then
        return false, "no path", nil
    end

    local f = file.Open(gmapath, "rb", "GAME")
    if not f then
        return true, "ugc handle (skipped)", nil
    end

    local magic = f:Read(4)
    if magic ~= "GMAD" then
        f:Close()
        return false, "not a gma (magic=" .. tostring(magic) .. ")", nil
    end

    local version = f:Read(1)
    version = version and string.byte(version) or 0
    if version > 3 then
        f:Close()
        return false, "unsupported gma version " .. version, nil
    end

    f:Read(8); f:Read(8)

    if version >= 2 then
        for _ = 1, 1024 do
            local s = read_cstr(f, 128)
            if not s or s == "" then break end
        end
    end

    read_cstr(f, 512)
    read_cstr(f, 4096)
    read_cstr(f, 256)

    f:Read(4)

    local files            = {}
    local entries          = {}
    local skinFileCount    = 0
    local maskFileCount    = 0
    local materialsCount   = 0
    local metroAssetCount  = 0
    local luaFileCount     = 0
    local totalBytes       = 0

    for i = 1, MAX_TOTAL_FILES + 1 do
        local filenum = read_u32(f)
        if filenum == 0 then break end

        if i > MAX_TOTAL_FILES then
            f:Close()
            return false, "too many files (>" .. MAX_TOTAL_FILES .. ")", files
        end

        local name = read_cstr(f, 512)
        local size = read_u64_as_num(f)
        f:Read(4)

        if not name or name == "" then
            f:Close()
            return false, "empty filename in index", files
        end
        if size > MAX_FILE_SIZE then
            f:Close()
            return false, string.format("file too big: %s (%d MB)",
                name, math.floor(size / 1024 / 1024)), files
        end

        totalBytes = totalBytes + size
        if totalBytes > MAX_TOTAL_UNCOMPRESSED then
            f:Close()
            return false, string.format(
                "addon total uncompressed size exceeds %d MB",
                math.floor(MAX_TOTAL_UNCOMPRESSED / 1024 / 1024)), files
        end

        table.insert(files, name)

        local lower = string.lower(name)

        local danger = is_dangerous_path(lower)
        if danger then
            f:Close()
            return false,
                "blocked path: " .. name .. " (bad token '" .. danger .. "')",
                files
        end

        local ext = string.lower(get_ext(lower))
        if ext == "" or not ALLOWED_EXTS[ext] then
            f:Close()
            return false,
                "disallowed file type: '" .. name .. "' (." .. ext .. ")",
                files
        end

        local isLua       = (ext == "lua")
        local addonPref   = isLua and is_lua_addon_path(lower) or nil
        local isAddonLua  = addonPref ~= nil
        local isMaskLua   = addonPref == "lua/metrostroi/masks/"
        local isAutorunLua = addonPref == "lua/autorun/"

        if not isLua and not is_allowed_path(lower, false) then
            f:Close()
            return false,
                "file in unsupported folder: '" .. name ..
                "' — only materials/, models/, sound/, resource/, scripts/ allowed",
                files
        end

        if isLua then
            luaFileCount = luaFileCount + 1
            if luaFileCount > MAX_LUA_FILES then
                f:Close()
                return false,
                    "too many lua files in addon (>" .. MAX_LUA_FILES .. ")",
                    files
            end
            if isAddonLua and size > MAX_LUA_FILE_SIZE then
                f:Close()
                return false, string.format(
                    "addon lua file too large: %s (%d B, max %d B)",
                    name, size, MAX_LUA_FILE_SIZE), files
            end
        end

        if isMaskLua then
            maskFileCount = maskFileCount + 1
        elseif isAddonLua and not isAutorunLua then
            skinFileCount = skinFileCount + 1
        elseif string.sub(lower, 1, 10) == "materials/" then
            materialsCount = materialsCount + 1
        end

        if not isLua then
            local startsAsset =
                   string.sub(lower, 1, 10) == "materials/"
                or string.sub(lower, 1,  7) == "models/"
                or string.sub(lower, 1,  6) == "sound/"
            if startsAsset and string.find(lower, "metrostroi", 1, true) then
                metroAssetCount = metroAssetCount + 1
            end
        end

        table.insert(entries, {
            name        = name,
            size        = size,
            isLua       = isLua,
            isAddonLua  = isAddonLua,
            isMaskLua   = isMaskLua,
            isAutorunLua = isAutorunLua,
        })
    end

    if skinFileCount == 0 and maskFileCount == 0 and metroAssetCount == 0 then
        f:Close()
        return false,
            "not a Metrostroi addon (no lua/metrostroi/skins/*.lua, "
            .. "no lua/metrostroi/masks/*.lua, and no materials/models/sound "
            .. "with 'metrostroi' in path; materials=" .. materialsCount .. ")",
            files
    end

    local luaBytesScanned = 0
    for _, e in ipairs(entries) do
        if e.isAddonLua then
            if luaBytesScanned + e.size > MAX_TOTAL_LUA_BYTES then
                f:Close()
                return false, string.format(
                    "too much lua content in addon (>%d MB)",
                    math.floor(MAX_TOTAL_LUA_BYTES / 1024 / 1024)), files
            end
            local body = f:Read(e.size)
            luaBytesScanned = luaBytesScanned + e.size
            if not isstring(body) or #body < e.size then
                f:Close()
                return false, "truncated lua body for " .. e.name, files
            end
            local validator = e.isAutorunLua
                              and Trainfitter.ValidateMaskLua
                              or  Trainfitter.ValidateSkinLua
            local ok, reason = validator(body, e.name)
            if not ok then
                f:Close()
                return false, reason, files
            end
        else
            if e.size > 0 then
                local okT, pos  = pcall(f.Tell, f)
                local seeked    = false
                if okT and isnumber(pos) then
                    local okS = pcall(f.Seek, f, pos + e.size)
                    seeked = okS == true
                end
                if not seeked then
                    local remaining = e.size
                    while remaining > 0 do
                        local take = remaining > 65536 and 65536 or remaining
                        local chunk = f:Read(take)
                        if not chunk or #chunk == 0 then break end
                        remaining = remaining - #chunk
                    end
                end
            end
        end
    end

    f:Close()
    return true, nil, files
end

if CLIENT then
    CreateClientConVar("trainfitter_gma_scan", "1", true, false,
        "1 = scan GMA before mounting (guards against non-skin addons).")
end

if SERVER then
    CreateConVar("trainfitter_server_gma_scan", "1",
        { FCVAR_ARCHIVE, FCVAR_PROTECTED },
        "1 = server-side strict Metrostroi-only GMA validation (keep enabled).")

    CreateConVar("trainfitter_content_scan", "1",
        { FCVAR_ARCHIVE, FCVAR_PROTECTED },
        "1 = runtime content scan on every .lua file before execution.")
end

function Trainfitter.ShouldScanGMA()
    if SERVER then
        local cv = GetConVar("trainfitter_server_gma_scan")
        return cv == nil or cv:GetBool() ~= false
    end
    local cv = GetConVar("trainfitter_gma_scan")
    return cv and cv:GetBool() ~= false
end

function Trainfitter.ShouldContentScan()
    if SERVER then
        local cv = GetConVar("trainfitter_content_scan")
        return cv == nil or cv:GetBool() ~= false
    end
    return true
end
