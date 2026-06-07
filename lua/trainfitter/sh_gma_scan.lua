-- Trainfitter - sh_gma_scan.lua
-- Made by SellingVika

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
}

local LUA_ALLOWED_PREFIXES_FULL = {
    "lua/metrostroi/masks/",
    "lua/metrostroi/",
    "lua/autorun/",
    "lua/entities/",
    "lua/weapons/",
    "lua/effects/",
}

local FULL_MODE_EXEMPT = {
    ["lua/weapons/"]  = true,
    ["lua/effects/"]  = true,
    ["lua/entities/"] = true,
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

--# исполняемые/бинарники - это уже не аддон а доставка малвари, режем даже в full-режиме
local DANGEROUS_EXTS = {
    exe = true, dll = true, so = true, dylib = true, elf = true,
    bat = true, cmd = true, com = true, scr = true, msi = true,
    vbs = true, vbe = true, js = true, jse = true, wsf = true, wsh = true,
    ps1 = true, psm1 = true, sh = true, bash = true,
    jar = true, py = true, pyc = true, pyo = true, rb = true, php = true,
    pl = true, app = true, deb = true, rpm = true, run = true, bin = true,
}

local MAX_FILE_SIZE          = 256  * 1024 * 1024
local MAX_TOTAL_UNCOMPRESSED = 1024 * 1024 * 1024
local MAX_TOTAL_FILES        = 4096
local MAX_LUA_FILES          = 256
local MAX_TOTAL_LUA_BYTES    = 4 * 1024 * 1024

function Trainfitter.GetMaxLuaSize()
    --# в full-режиме per-file КБ-лимит не душим, остаётся только жёсткий общий потолок lua
    if Trainfitter.ShouldAllowFullLua and Trainfitter.ShouldAllowFullLua() then
        return MAX_TOTAL_LUA_BYTES
    end
    local cv = GetConVar("trainfitter_max_lua_kb")
    local kb = cv and cv:GetInt() or 64
    if kb < 1    then kb = 1    end
    if kb > 1024 then kb = 1024 end
    return kb * 1024
end

function Trainfitter.GetSandboxInstrLimit()
    local cv = GetConVar("trainfitter_sandbox_instr_m")
    local m = cv and cv:GetInt() or 100
    if m < 1     then m = 1     end
    if m > 10000 then m = 10000 end
    return m * 1000000
end

function Trainfitter.ShouldRejectBytecode()
    local cv = GetConVar("trainfitter_reject_bytecode")
    return cv == nil or cv:GetBool() ~= false
end

local function PreflightCheck(content, displayPath)
    if not isstring(content) or #content == 0 then
        return false, "empty lua file: " .. tostring(displayPath)
    end
    local maxSize = Trainfitter.GetMaxLuaSize()
    if #content > maxSize then
        return false, string.format(
            "lua file too large: %s (%d B, max %d B - raise trainfitter_max_lua_kb if you trust the addon)",
            tostring(displayPath), #content, maxSize)
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

    local function Viktoooor(fn)
        if not isfunction(fn) then return nil end
        return function(c, t)
            return fn(c, ProxyTableFunctions(t))
        end
    end

    local function OkDa(fn)
        if not isfunction(fn) then return nil end
        return function(...) return fn(...) end
    end

    return {
        AddSkin           = OkDa(Metrostroi.AddSkin),
        AddMask           = Viktoooor(Metrostroi.AddMask),
        RegisterSkin      = OkDa(Metrostroi.RegisterSkin),
        DefineSkin        = OkDa(Metrostroi.DefineSkin),
        RegisterMask      = Viktoooor(Metrostroi.RegisterMask),
        DefineMask        = Viktoooor(Metrostroi.DefineMask),
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

        Material     = SafeMaterial,
        AddCSLuaFile = function() end,
        print        = function() end,
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

function Trainfitter.ExecSandboxed(content, path, kind)
    if not isstring(content) or #content == 0 then
        return false, "empty content"
    end

    if Trainfitter.ShouldRejectBytecode() and string.byte(content, 1) == 0x1B then
        return false, "lua bytecode rejected (set trainfitter_reject_bytecode 0 to allow)"
    end

    local fn, compileErr = CompileString(content, path, false)
    if isstring(fn) then return false, "compile: " .. fn end
    if not isfunction(fn) then return false, "compile returned non-function" end

    if not isfunction(setfenv) then
        return false, "setfenv unavailable - refusing to execute without sandbox"
    end

    local prefix = MakePathPrefix(path)
    local sb = (kind == "mask") and BuildMaskSandbox(prefix) or BuildSkinSandbox()
    local setOk, setErr = pcall(setfenv, fn, sb)
    if not setOk then return false, "setfenv failed: " .. tostring(setErr) end

    local hookSet = false
    if debug and isfunction(debug.sethook) then
        local limit = Trainfitter.GetSandboxInstrLimit()
        debug.sethook(function() error("instruction limit exceeded", 2) end, "", limit)
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

local function is_dangerous_path(p, fullLua)
    --# в safe-режиме режем опасные папки, в full админ доверяет источнику - не наша забота
    if not fullLua then
        for _, pref in ipairs(DANGEROUS_PREFIXES) do
            if string.sub(p, 1, #pref) == pref then return pref end
        end
    end
    --# а это всегда: выход за пределы папки аддона = чистая атака, не фича
    if string.find(p, "..", 1, true)   then return ".." end
    if string.find(p, "\0",   1, true) then return "\\0" end
    if string.find(p, ":",    1, true) then return ":"  end
    if string.sub(p, 1, 1) == "/"      then return "/"  end
    if string.sub(p, 1, 1) == "\\"     then return "\\" end
    return nil
end

local function is_lua_addon_path(p, fullLua)
    for _, pref in ipairs(LUA_ALLOWED_PREFIXES) do
        if string.sub(p, 1, #pref) == pref then return pref end
    end
    if fullLua then
        for _, pref in ipairs(LUA_ALLOWED_PREFIXES_FULL) do
            if string.sub(p, 1, #pref) == pref then return pref end
        end
        --# full-режим: любой lua считается addon-lua и гоняется несандбоксенно (это и есть full lua)
        return "lua/"
    end
    return nil
end

local function is_allowed_path(p, is_lua, fullLua)
    if ALLOWED_EXACT[p] then return true end

    if is_lua then
        return is_lua_addon_path(p, fullLua) ~= nil
    end

    --# full-режим: любой не-lua путь ок, выходы за пределы уже отсеяны выше
    if fullLua then return true end

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

function Trainfitter.ScanGMA(gmapath, fullLuaOverride)
    if not isstring(gmapath) or gmapath == "" then
        return false, "no path", nil
    end

    local fullLua
    if fullLuaOverride ~= nil then
        fullLua = fullLuaOverride == true
    else
        fullLua = Trainfitter.ShouldAllowFullLua and Trainfitter.ShouldAllowFullLua() or false
    end

    local maxLuaSize = Trainfitter.GetMaxLuaSize()

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
    local luaBodies        = {}
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

        local danger = is_dangerous_path(lower, fullLua)
        if danger then
            f:Close()
            local hint = ""
            if not fullLua and FULL_MODE_EXEMPT[danger] then
                hint = " - enable convar 'trainfitter_allow_full_lua 1' to install pults/SENT addons"
            end
            return false,
                "blocked path: " .. name .. " (bad token '" .. danger .. "')" .. hint,
                files
        end

        local ext = string.lower(get_ext(lower))
        local badExt
        if fullLua then
            --# full: пускаем всё кроме исполняемых/бинарников
            badExt = (ext == "" and not ALLOWED_EXACT[lower]) or DANGEROUS_EXTS[ext]
        else
            --# safe: строгий whitelist типов
            badExt = ext == "" or not ALLOWED_EXTS[ext]
        end
        if badExt then
            f:Close()
            return false,
                "disallowed file type: '" .. name .. "' (." .. ext .. ")",
                files
        end

        local isLua       = (ext == "lua")
        local addonPref   = isLua and is_lua_addon_path(lower, fullLua) or nil
        local isAddonLua  = addonPref ~= nil
        local isMaskLua   = addonPref == "lua/metrostroi/masks/"
        local isAutorunLua = addonPref == "lua/autorun/"

        if not isLua and not is_allowed_path(lower, false, fullLua) then
            f:Close()
            return false,
                "file in unsupported folder: '" .. name ..
                "' - only materials/, models/, sound/, resource/, scripts/ allowed",
                files
        end

        if isLua and not isAddonLua then
            f:Close()
            local hint = ""
            if not fullLua then
                local needsFull =
                       string.sub(lower, 1, 21) == "lua/metrostroi/masks/"
                    or string.sub(lower, 1, 15) == "lua/metrostroi/"
                    or string.sub(lower, 1, 12) == "lua/autorun/"
                    or string.sub(lower, 1, 13) == "lua/entities/"
                    or string.sub(lower, 1, 12) == "lua/weapons/"
                    or string.sub(lower, 1, 12) == "lua/effects/"
                if needsFull then
                    hint = " - addon contains masks or pults; enable convar "
                        .. "'trainfitter_allow_full_lua 1' to install advanced addons"
                end
            end
            return false,
                "unsupported lua path: '" .. name .. "'" .. hint,
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
            if not fullLua and isAddonLua and size > maxLuaSize then
                f:Close()
                return false, string.format(
                    "addon lua file too large: %s (%d B, max %d B - raise trainfitter_max_lua_kb if you trust the source)",
                    name, size, maxLuaSize), files
            end
        end

        if isMaskLua then
            maskFileCount = maskFileCount + 1
        elseif isAddonLua and not isAutorunLua then
            skinFileCount = skinFileCount + 1
        elseif isAddonLua and isAutorunLua and fullLua then
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

    --# маркер metrostroi требуем только в safe-режиме, в full админ ставит что хочет
    if not fullLua and skinFileCount == 0 and maskFileCount == 0 and metroAssetCount == 0 then
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
            luaBodies[string.lower(e.name)] = body
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
    return true, nil, files, luaBodies
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

    CreateConVar("trainfitter_allow_full_lua", "0",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED },
        "DANGEROUS: 1 = allow pults / custom SENT / full-Lua addons. " ..
        "These run UNSANDBOXED with full server permissions. " ..
        "Only enable if you fully trust everyone who can install addons.")

    CreateConVar("trainfitter_max_lua_kb", "64",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED },
        "Max size of one addon-lua file in KB. Default 64. Clamped to 1-1024. " ..
        "Raise if your masks are bigger than 64KB (rare but happens).")

    CreateConVar("trainfitter_sandbox_instr_m", "100",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED },
        "Max sandbox instruction count in millions. Default 100. Clamped to 1-10000. " ..
        "Raise if heavy masks time out during init.")

    CreateConVar("trainfitter_reject_bytecode", "1",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED },
        "1 = reject Lua bytecode (default, safe). 0 = allow it (DANGEROUS).")

    CreateConVar("trainfitter_allow_collections", "0",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED },
        "1 = let players apply whole Workshop collections at once. 0 = single addons only.")

    CreateConVar("trainfitter_max_collection", "0",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED },
        "Max addons pulled from one collection. 0 = unlimited (use with care).")
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

function Trainfitter.ShouldAllowFullLua()
    local cv = GetConVar("trainfitter_allow_full_lua")
    return cv ~= nil and cv:GetBool() == true
end

function Trainfitter.AllowCollections()
    local cv = GetConVar("trainfitter_allow_collections")
    return cv == nil or cv:GetBool() ~= false
end

function Trainfitter.GetMaxCollection()
    local cv = GetConVar("trainfitter_max_collection")
    local n = cv and cv:GetInt() or 0
    if n <= 0 then return math.huge end
    return n
end
