-- Trainfitter - sh_gma_scan.lua
-- Made by SellingVika

Trainfitter = Trainfitter or {}

local DATA_PREFIXES = {
    "materials/",
    "models/",
    "sound/",
    "resource/localization/",
}

local DANGEROUS_PREFIXES = {
    "materials/console/",
    "materials/vgui/logos/",
    "materials/gui/",
}

local FULL_BLOCKED_PREFIXES = {
    "lua/includes/",
    "lua/menu/",
    "gamemodes/",
    "addons/",
    "bin/",
    "cfg/",
    "data/",
}

local ALLOWED_ROOT = {
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
    vmt = true, vtf = true, png = true, jpg = true, jpeg = true,
    mdl = true, vvd = true, phy = true, vtx = true, ani = true,
    wav = true, mp3 = true, ogg = true,
    properties = true,
}

local DROP_EXTS = {
    txt = true, json = true, md = true, psd = true, xcf = true, bak = true, ini = true, log = true,
    smd = true, qc = true, qci = true, dmx = true, fbx = true, obj = true, blend = true, tga = true,
    pdn = true, xml = true, csv = true, db = true, html = true, htm = true, pcf = true, ttf = true, otf = true,
}

local DANGEROUS_EXTS = {
    exe = true, dll = true, so = true, dylib = true, elf = true,
    bat = true, cmd = true, com = true, scr = true, msi = true,
    vbs = true, vbe = true, js = true, jse = true, wsf = true, wsh = true,
    ps1 = true, psm1 = true, sh = true, bash = true, vcs = true,
    jar = true, py = true, pyc = true, pyo = true, rb = true, php = true,
    pl = true, app = true, deb = true, rpm = true, run = true, bin = true,
    cfg = true, vdf = true, bsp = true, nav = true, ain = true,
}

local MAX_FILE_SIZE          = 256 * 1024 * 1024
local MAX_TOTAL_UNCOMPRESSED = 2048 * 1024 * 1024
local MAX_TOTAL_FILES        = 8192
local MAX_LUA_FILES          = 512
local MAX_TOTAL_LUA_BYTES    = 8 * 1024 * 1024
local MAX_HEADER_STRING      = 1024 * 1024
local MAX_NAME_LEN           = 1024

Trainfitter.MEL_WSID = "3401843254"

function Trainfitter.GetMaxLuaSize()
    local cv = GetConVar("trainfitter_max_lua_kb")
    local kb = cv and cv:GetInt() or 256
    if kb < 1    then kb = 1    end
    if kb > 4096 then kb = 4096 end
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

function Trainfitter.ShouldAllowFullLua()
    local cv = GetConVar("trainfitter_allow_full_lua")
    return cv ~= nil and cv:GetBool() == true
end

function Trainfitter.ShouldAllowMasks()
    if Trainfitter.ShouldAllowFullLua() then return true end
    local cv = GetConVar("trainfitter_allow_masks")
    return cv == nil or cv:GetBool() ~= false
end

function Trainfitter.MELSupportEnabled()
    local cv = GetConVar("trainfitter_mel_support")
    return cv ~= nil and cv:GetBool() == true
end

function Trainfitter.MELPresent()
    return istable(MEL) and isfunction(MEL.DefineRecipe) and istable(MEL.Recipes) and istable(MEL.InjectStack)
end

function Trainfitter.AllowCollections()
    local cv = GetConVar("trainfitter_allow_collections")
    return cv ~= nil and cv:GetBool() == true
end

function Trainfitter.GetMaxCollection()
    local cv = GetConVar("trainfitter_max_collection")
    local n = cv and cv:GetInt() or 0
    if n <= 0 then return math.huge end
    return n
end

local function StartsWith(s, p)
    return string.sub(s, 1, #p) == p
end

local function AnyPrefix(s, list)
    for _, p in ipairs(list) do
        if StartsWith(s, p) then return p end
    end
    return nil
end

local function GetExt(p)
    return string.match(p, "%.([^%./]+)$") or ""
end

local function U32(b)
    if not b or #b < 4 then return nil end
    local b1, b2, b3, b4 = string.byte(b, 1, 4)
    return b1 + b2 * 0x100 + b3 * 0x10000 + b4 * 0x1000000
end

local function U64(b)
    if not b or #b < 8 then return nil end
    local lo = U32(string.sub(b, 1, 4))
    local hi = U32(string.sub(b, 5, 8))
    if hi >= 0x80000000 then return nil end
    return lo + hi * 4294967296
end

local function PackU32(n)
    n = math.floor(n)
    return string.char(n % 256, math.floor(n / 0x100) % 256, math.floor(n / 0x10000) % 256, math.floor(n / 0x1000000) % 256)
end

local function PackU64(n)
    local lo = n % 4294967296
    local hi = math.floor(n / 4294967296)
    return PackU32(lo) .. PackU32(hi)
end

local function ReadCString(f, cap)
    local parts = {}
    local total = 0
    while true do
        local pos = f:Tell()
        local chunk = f:Read(256)
        if not chunk or #chunk == 0 then return nil end
        local z = string.find(chunk, "\0", 1, true)
        if z then
            parts[#parts + 1] = string.sub(chunk, 1, z - 1)
            f:Seek(pos + z)
            return table.concat(parts)
        end
        parts[#parts + 1] = chunk
        total = total + #chunk
        if total > cap then return nil end
    end
end

local function I32(b, pos)
    local v = U32(string.sub(b, pos, pos + 3))
    if v == nil then return nil end
    if v >= 0x80000000 then v = v - 4294967296 end
    return v
end

local function U16(b, pos)
    local b1, b2 = string.byte(b, pos, pos + 1)
    if not b2 then return nil end
    return b1 + b2 * 256
end

local HEADER_CHECKS = {
    mdl = function(h, size)
        if string.sub(h, 1, 4) ~= "IDST" then return "bad MDL magic" end
        local ver = I32(h, 5)
        if not ver or ver < 44 or ver > 53 then return "unsupported MDL version" end
        local len = I32(h, 77)
        if not len or len < 200 or len > size then return "MDL length field is out of range" end
    end,
    vvd = function(h, size)
        if string.sub(h, 1, 4) ~= "IDSV" then return "bad VVD magic" end
        if I32(h, 5) ~= 4 then return "unsupported VVD version" end
        local lods = I32(h, 13)
        if not lods or lods < 1 or lods > 8 then return "bad VVD LOD count" end
        local fixupOff, vertOff, tanOff = I32(h, 53), I32(h, 57), I32(h, 61)
        for _, o in ipairs({ fixupOff, vertOff, tanOff }) do
            if not o or o < 0 or o > size then return "VVD offset out of range" end
        end
    end,
    vtx = function(h, size)
        if I32(h, 1) ~= 7 then return "unsupported VTX version" end
        local lods = I32(h, 21)
        if not lods or lods < 1 or lods > 8 then return "bad VTX LOD count" end
        local matOff, parts, partOff = I32(h, 25), I32(h, 29), I32(h, 33)
        if not matOff or matOff < 0 or matOff > size then return "VTX offset out of range" end
        if not parts or parts < 0 or parts > 256 then return "bad VTX body part count" end
        if not partOff or partOff < 0 or partOff > size then return "VTX offset out of range" end
    end,
    phy = function(h, size)
        if I32(h, 1) ~= 16 then return "bad PHY header size" end
        local solids = I32(h, 9)
        if not solids or solids < 0 or solids > 1024 then return "bad PHY solid count" end
    end,
    vtf = function(h, size)
        if string.sub(h, 1, 4) ~= "VTF\0" then return "bad VTF magic" end
        if I32(h, 5) ~= 7 then return "unsupported VTF version" end
        local minor = I32(h, 9)
        if not minor or minor < 0 or minor > 6 then return "unsupported VTF version" end
        local hsize = I32(h, 13)
        if not hsize or hsize < 48 or hsize > 4096 or hsize > size then return "bad VTF header size" end
        local w, hh = U16(h, 17), U16(h, 19)
        if not w or not hh or w < 1 or hh < 1 or w > 16384 or hh > 16384 then return "bad VTF dimensions" end
        local frames = U16(h, 25)
        if not frames or frames < 1 or frames > 4096 then return "bad VTF frame count" end
    end,
}

local function Classify(lower)
    if string.match(lower, "^lua/metrostroi/skins/[^/]+%.lua$") then return "skin" end
    if string.match(lower, "^lua/metrostroi_data/languages/[^/]+%.lua$") then return "language" end
    if string.match(lower, "^lua/autorun/[^/]+%.lua$") then return "autorun" end
    if string.match(lower, "^lua/autorun/server/[^/]+%.lua$") then return "autorun_sv" end
    if string.match(lower, "^lua/autorun/client/[^/]+%.lua$") then return "autorun_cl" end
    if string.match(lower, "^lua/metrostroi/masks/[^/]+%.lua$") then return "mask" end
    if StartsWith(lower, "lua/recipies/") then
        if string.find(lower, "/disabled/", 1, true) then return "other" end
        local name = string.match(lower, "([^/]+)$") or ""
        if name == "warning.lua" or name == "license.lua" then return "other" end
        return "recipe"
    end
    return "other"
end

local function Fail(report, reason, key)
    report.ok = false
    report.reason = reason
    report.reasonKey = key
    return report
end

function Trainfitter.ScanGMA(gmapath, opts)
    opts = opts or {}
    local fullLua    = opts.fullLua == true
    local allowMasks = opts.allowMasks == true or fullLua
    local maxLuaSize = Trainfitter.GetMaxLuaSize()

    local report = {
        ok = false, files = {}, entries = {}, bodies = {}, byClass = {
            skin = {}, language = {}, autorun = {}, autorun_sv = {}, autorun_cl = {}, mask = {}, recipe = {}, other = {},
        },
        hasLua = false, usesMEL = false, metro = false, luaBytes = 0, totalBytes = 0,
    }

    if not isstring(gmapath) or gmapath == "" then return Fail(report, "no GMA path") end
    local f = file.Open(gmapath, "rb", "GAME")
    if not f then return Fail(report, "cannot open GMA: " .. gmapath) end

    local ok, err = pcall(function()
        if f:Read(4) ~= "GMAD" then error("not a GMA file", 0) end
        local vb = f:Read(1)
        local version = vb and string.byte(vb) or 0
        if version < 1 or version > 3 then error("unsupported GMA version " .. version, 0) end
        report.header = { version = version }
        report.header.steamid = f:Read(8)
        report.header.timestamp = f:Read(8)
        if not report.header.timestamp or #report.header.timestamp < 8 then error("truncated GMA header", 0) end
        report.header.required = {}
        if version > 1 then
            for _ = 1, 4096 do
                local s = ReadCString(f, MAX_HEADER_STRING)
                if s == nil then error("malformed GMA header", 0) end
                if s == "" then break end
                report.header.required[#report.header.required + 1] = s
            end
        end
        report.header.name = ReadCString(f, MAX_HEADER_STRING)
        report.header.desc = ReadCString(f, MAX_HEADER_STRING)
        report.header.author = ReadCString(f, MAX_HEADER_STRING)
        if not report.header.name or not report.header.desc or not report.header.author then error("malformed GMA header", 0) end
        report.header.addonVersion = f:Read(4)

        local offset = 0
        for i = 1, MAX_TOTAL_FILES + 1 do
            local num = U32(f:Read(4))
            if num == nil then error("truncated GMA index", 0) end
            if num == 0 then break end
            if i > MAX_TOTAL_FILES then error("too many files (>" .. MAX_TOTAL_FILES .. ")", 0) end
            local name = ReadCString(f, MAX_NAME_LEN)
            if not name or name == "" then error("malformed file name in GMA index", 0) end
            local size = U64(f:Read(8))
            local crc = f:Read(4)
            if size == nil or not crc or #crc < 4 then error("malformed GMA index entry", 0) end
            if size > MAX_FILE_SIZE then
                error(string.format("file too big: %s (%d MB)", name, math.floor(size / 1048576)), 0)
            end
            report.totalBytes = report.totalBytes + size
            if report.totalBytes > MAX_TOTAL_UNCOMPRESSED then error("addon is too large when unpacked", 0) end
            report.entries[#report.entries + 1] = { name = name, size = size, crc = crc, offset = offset }
            report.files[#report.files + 1] = name
            offset = offset + size
        end
        report.dataStart = f:Tell()
        if report.dataStart + offset > f:Size() then error("GMA data section is truncated", 0) end
    end)
    if not ok then
        f:Close()
        return Fail(report, tostring(err))
    end

    local luaCount = 0
    for _, e in ipairs(report.entries) do
        local lower = string.lower(e.name)
        e.lower = lower
        if string.find(lower, "..", 1, true) or string.find(lower, ":", 1, true) or string.find(lower, "\\", 1, true)
           or StartsWith(lower, "/") or string.find(lower, "\0", 1, true) then
            f:Close()
            return Fail(report, "blocked path: " .. e.name)
        end
        local ext = GetExt(lower)
        if DANGEROUS_EXTS[ext] then
            f:Close()
            return Fail(report, "disallowed file type: " .. e.name)
        end
        if ext == "lua" then
            if not StartsWith(lower, "lua/") then
                f:Close()
                return Fail(report, "lua file outside lua/: " .. e.name)
            end
            if fullLua and AnyPrefix(lower, FULL_BLOCKED_PREFIXES) then
                f:Close()
                return Fail(report, "blocked path: " .. e.name)
            end
            luaCount = luaCount + 1
            if luaCount > MAX_LUA_FILES then
                f:Close()
                return Fail(report, "too many lua files (>" .. MAX_LUA_FILES .. ")")
            end
            if e.size > maxLuaSize then
                f:Close()
                return Fail(report, string.format("lua file too large: %s (%d KB, limit %d KB - raise trainfitter_max_lua_kb if you trust it)",
                    e.name, math.ceil(e.size / 1024), math.floor(maxLuaSize / 1024)))
            end
            e.isLua = true
            e.class = Classify(lower)
            report.hasLua = true
        elseif ALLOWED_ROOT[lower] then
            e.drop = true
        elseif StartsWith(lower, "lua/") then
            e.drop = true
        elseif fullLua then
            if AnyPrefix(lower, FULL_BLOCKED_PREFIXES) then
                f:Close()
                return Fail(report, "blocked path: " .. e.name)
            end
            e.keep = true
        elseif DROP_EXTS[ext] then
            e.drop = true
        else
            if not AnyPrefix(lower, DATA_PREFIXES) or AnyPrefix(lower, DANGEROUS_PREFIXES) then
                f:Close()
                return Fail(report, "file in unsupported folder: " .. e.name
                    .. " (only materials/, models/, sound/, resource/localization/ are allowed)")
            end
            if not ALLOWED_EXTS[ext] then
                f:Close()
                return Fail(report, "disallowed file type: " .. e.name)
            end
            e.keep = true
        end
        if e.keep and (StartsWith(lower, "materials/") or StartsWith(lower, "models/") or StartsWith(lower, "sound/"))
           and string.find(lower, "metrostroi", 1, true) then
            report.metro = true
        end
    end

    for _, e in ipairs(report.entries) do
        if e.keep and not fullLua then
            local check = HEADER_CHECKS[GetExt(e.lower)]
            if check then
                if e.size < 16 then
                    f:Close()
                    return Fail(report, "malformed file: " .. e.name)
                end
                f:Seek(report.dataStart + e.offset)
                local h = f:Read(math.min(e.size, 128)) or ""
                local bad = check(h .. string.rep("\0", 128 - #h), e.size)
                if bad then
                    f:Close()
                    return Fail(report, "malformed file " .. e.name .. ": " .. bad)
                end
            end
            if not string.find(e.lower, "metrostroi", 1, true)
               and file.Exists(e.name, "GAME") and not file.Exists(e.name, "WORKSHOP") then
                f:Close()
                return Fail(report, "addon tries to replace a base game file: " .. e.name)
            end
        end
    end

    for _, e in ipairs(report.entries) do
        if e.isLua then
            report.luaBytes = report.luaBytes + e.size
            if report.luaBytes > MAX_TOTAL_LUA_BYTES then
                f:Close()
                return Fail(report, "too much lua in addon (>" .. math.floor(MAX_TOTAL_LUA_BYTES / 1048576) .. " MB)")
            end
            f:Seek(report.dataStart + e.offset)
            local body = e.size > 0 and f:Read(e.size) or ""
            if not isstring(body) or #body < e.size then
                f:Close()
                return Fail(report, "truncated lua body: " .. e.name)
            end
            if string.byte(body, 1) == 0x1B and (not fullLua or Trainfitter.ShouldRejectBytecode()) then
                f:Close()
                return Fail(report, "lua bytecode is not allowed: " .. e.name)
            end
            report.bodies[e.lower] = body
            local bucket = report.byClass[e.class]
            bucket[#bucket + 1] = e.lower
            if e.class == "recipe" or string.find(body, "MetrostroiExtensionsLib", 1, true)
               or string.match(body, "[^%w_%.]MEL%s*[%.:%[]") or string.match(body, "^MEL%s*[%.:%[]") then
                report.usesMEL = true
            end
            if not report.metro and (string.find(body, "Metrostroi", 1, true) or string.find(body, "gmod_subway", 1, true)) then
                report.metro = true
            end
        end
    end
    f:Close()

    for _, bucket in pairs(report.byClass) do table.sort(bucket) end
    local c = report.byClass
    if #c.skin > 0 or #c.recipe > 0 then report.metro = true end

    local needsMasks = #c.autorun > 0 or #c.autorun_sv > 0 or #c.autorun_cl > 0 or #c.mask > 0 or #c.recipe > 0
    report.needsMasks = needsMasks
    local entryPoints = #c.skin + #c.autorun + #c.autorun_sv + #c.autorun_cl + #c.mask + #c.recipe + #c.language

    if not report.metro and not fullLua then
        return Fail(report, "not a Metrostroi addon (no Metrostroi skins, masks, recipes or assets)", "not_metro")
    end
    if needsMasks and not allowMasks then
        return Fail(report, "addon contains masks/scripts; enable 'trainfitter_allow_masks 1' to allow them", "masks_disabled")
    end
    if #c.other > 0 and entryPoints == 0 and not fullLua then
        return Fail(report, "addon ships Lua that only works as a full addon (entities/weapons); only 'trainfitter_allow_full_lua 1' can load it", "full_only")
    end

    report.ok = true
    return report
end

function Trainfitter.CleanGMADir()
    return SERVER and "trainfitter/gmas" or "trainfitter/gmas_cl"
end

function Trainfitter.CleanGMAName(wsid, report)
    local sig = {}
    for _, e in ipairs(report.entries) do
        if e.keep then sig[#sig + 1] = e.name .. ":" .. e.size .. ":" .. e.crc end
    end
    return string.format("%s/%s_%s.dat", Trainfitter.CleanGMADir(), wsid, util.CRC(table.concat(sig, "|")))
end

function Trainfitter.RepackGMA(srcPath, report, wsid, callback)
    local dst = Trainfitter.CleanGMAName(wsid, report)
    local dir = Trainfitter.CleanGMADir()
    if not file.IsDir("trainfitter", "DATA") then file.CreateDir("trainfitter") end
    if not file.IsDir(dir, "DATA") then file.CreateDir(dir) end

    local header = {}
    header[#header + 1] = "GMAD"
    header[#header + 1] = string.char(3)
    header[#header + 1] = report.header.steamid or string.rep("\0", 8)
    header[#header + 1] = report.header.timestamp or string.rep("\0", 8)
    header[#header + 1] = "\0"
    header[#header + 1] = (report.header.name or "trainfitter") .. "\0"
    header[#header + 1] = (report.header.desc or "") .. "\0"
    header[#header + 1] = (report.header.author or "") .. "\0"
    header[#header + 1] = report.header.addonVersion or PackU32(1)
    local keep = {}
    local dataSize = 0
    for _, e in ipairs(report.entries) do
        if e.keep then
            keep[#keep + 1] = e
            header[#header + 1] = PackU32(#keep) .. e.name .. "\0" .. PackU64(e.size) .. e.crc
            dataSize = dataSize + e.size
        end
    end
    header[#header + 1] = PackU32(0)
    local headerStr = table.concat(header)
    local expected = #headerStr + dataSize + 4

    if file.Exists(dst, "DATA") and file.Size(dst, "DATA") == expected then
        callback("data/" .. dst)
        return
    end

    local prefix = dir .. "/" .. wsid .. "_"
    for _, fname in ipairs(file.Find(dir .. "/" .. wsid .. "_*.dat", "DATA") or {}) do
        local rel = dir .. "/" .. fname
        if rel ~= dst and StartsWith(rel, prefix) then pcall(file.Delete, rel) end
    end

    local src = file.Open(srcPath, "rb", "GAME")
    if not src then callback(nil, "cannot reopen source GMA") return end
    local out = file.Open(dst, "wb", "DATA")
    if not out then src:Close() callback(nil, "cannot write " .. dst) return end
    out:Write(headerStr)

    local budget = SERVER and 0.02 or 0.008
    local co = coroutine.create(function()
        local chunk = 1048576
        local started = SysTime()
        for _, e in ipairs(keep) do
            src:Seek(report.dataStart + e.offset)
            local left = e.size
            while left > 0 do
                local take = math.min(left, chunk)
                local data = src:Read(take)
                if not data or #data ~= take then error("short read in " .. e.name, 0) end
                out:Write(data)
                left = left - take
                if SysTime() - started > budget then
                    coroutine.yield()
                    started = SysTime()
                end
            end
        end
        out:Write(PackU32(0))
    end)

    local tname = "Trainfitter.Repack." .. wsid
    local function finish(ok, err)
        timer.Remove(tname)
        src:Close()
        out:Close()
        if not ok then
            pcall(file.Delete, dst)
            callback(nil, err)
            return
        end
        if file.Size(dst, "DATA") ~= expected then
            pcall(file.Delete, dst)
            callback(nil, "repacked GMA has unexpected size")
            return
        end
        callback("data/" .. dst)
    end

    local function step()
        local ok, err = coroutine.resume(co)
        if not ok then finish(false, "repack failed: " .. tostring(err)) return end
        if coroutine.status(co) == "dead" then finish(true) end
    end

    timer.Create(tname, 0, 0, step)
    step()
end
