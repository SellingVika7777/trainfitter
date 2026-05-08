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
    local r = {}
    for k, v in pairs(t) do r[k] = v end
    return r
end

local function BuildSkinSandbox()
    local sb = {
        Metrostroi = Metrostroi,

        Color  = Color,
        Vector = Vector,
        Angle  = Angle,

        table  = table,
        string = string,
        math   = math,
        bit    = bit,

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

        Material = Material,
        AddCSLuaFile = function() end,
        print = function() end,
    }
    sb._G = sb
    return sb
end

local function BuildMaskSandbox()
    local sb = BuildSkinSandbox()

    sb.hook            = hook
    sb.timer           = timer
    sb.scripted_ents   = scripted_ents
    sb.Entity          = Entity
    sb.SafeRemoveEntity = SafeRemoveEntity
    sb.FindMetaTable   = FindMetaTable

    sb.ents = {
        FindByClass     = ents.FindByClass,
        FindInSphere    = ents.FindInSphere,
        FindInBox       = ents.FindInBox,
        GetAll          = ents.GetAll,
        GetByIndex      = ents.GetByIndex,
        GetCount        = ents.GetCount,
    }

    sb.player = {
        GetAll         = player.GetAll,
        GetHumans      = player.GetHumans,
        GetBots        = player.GetBots,
        GetByID        = player.GetByID,
        GetBySteamID   = player.GetBySteamID,
        GetBySteamID64 = player.GetBySteamID64,
        GetCount       = player.GetCount,
    }

    sb.print       = print
    sb.MsgC        = MsgC
    sb.Msg         = Msg
    sb.MsgN        = MsgN
    sb.PrintTable  = PrintTable

    sb.getmetatable = getmetatable

    sb._G = sb
    return sb
end

function Trainfitter.ExecSandboxed(content, path, kind)
    if not isstring(content) or #content == 0 then
        return false, "empty content"
    end
    local fn, compileErr = CompileString(content, path, false)
    if isstring(fn) then return false, "compile: " .. fn end
    if not isfunction(fn) then return false, "compile returned non-function" end

    local sb = (kind == "mask") and BuildMaskSandbox() or BuildSkinSandbox()
    if isfunction(setfenv) then
        local ok = pcall(setfenv, fn, sb)
        if not ok then return false, "setfenv failed" end
    end

    local ok, runErr = pcall(fn)
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
