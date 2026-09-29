-- Trainfitter - sh_sandbox.lua
-- Made by SellingVika

Trainfitter = Trainfitter or {}

local SB = {}
Trainfitter.Sandbox = SB

local _R = _G
local type, pairs, ipairs, next, select, unpack = type, pairs, ipairs, next, select, unpack
local tostring, tonumber, error, pcall, xpcall, assert = tostring, tonumber, error, pcall, xpcall, assert
local rawget, rawset, rawequal = rawget, rawset, rawequal
local setmetatable, getmetatable = setmetatable, getmetatable
local getfenv, setfenv = getfenv, setfenv
local string_sub, string_find, string_lower = string.sub, string.find, string.lower
local string_format, string_gsub, string_match = string.format, string.gsub, string.match
local string_rep = string.rep
local table_sort, table_concat = table.sort, table.concat
local math_floor, math_min, math_max = math.floor, math.min, math.max
local debug_sethook, debug_gethook = debug and debug.sethook, debug and debug.gethook
local debug_getinfo, debug_getmetatable = debug and debug.getinfo, debug and debug.getmetatable
local collectgarbage, SysTime, CompileString = collectgarbage, SysTime, CompileString
local coroutine_running = coroutine.running
local jit_off = jit and jit.off
local real_isentity, real_IsValid, real_Color = isentity, IsValid, Color
local real_string, real_table, real_math, real_bit = string, table, math, bit
local real_hook_Add, real_hook_Remove = hook.Add, hook.Remove
local real_timer = timer
local real_include = include
local MsgC = MsgC
if istable(Trainfitter.SinkOriginals) then
    CompileString = Trainfitter.SinkOriginals["_G.CompileString"] or CompileString
    real_include = Trainfitter.SinkOriginals["_G.include"] or real_include
end

local HOOK_STEP = 1000
local CALLBACK_BUDGET = 25000000
local MEM_LIMIT_KB = 256 * 1024
local CPU_WINDOW, CPU_SHARE = 5, 0.5
local MEM_WINDOW, MEM_WINDOW_KB = 10, 512 * 1024
local LIMITS = {
    totalCpu = 0.6, memRetain = 256 * 1024, memAllow = 16 * 1024, nwKeys = 256, recipes = 64,
    memCeiling = (jit and jit.arch == "x86") and 700 * 1024 or 2048 * 1024, memSuspect = 64 * 1024,
}
local MAX_HOOKS, MAX_TIMERS, MAX_SIMPLE, MAX_CSENTS = 64, 64, 256, 512
local MAX_INCLUDE_DEPTH = 16
local MAX_COPY_ENTRIES, MAX_COPY_DEPTH = 200000, 48
local MAX_ENTS_PER_CALL, EDICT_CEILING = 512, 7680

SB.Available = isfunction(setfenv) and isfunction(debug_sethook) and isfunction(debug_gethook)
    and isfunction(debug_getinfo) and isfunction(debug_getmetatable)

local P2R    = setmetatable({}, { __mode = "k" })
local PKIND  = setmetatable({}, { __mode = "k" })
local R2P    = setmetatable({}, { __mode = "kv" })
local R2P_RO = setmetatable({}, { __mode = "kv" })
local SB_CSENTS = setmetatable({}, { __mode = "k" })
local MCACHE = setmetatable({}, { __mode = "k" })
local ENVS   = setmetatable({}, { __mode = "k" })
local RFN2W  = setmetatable({}, { __mode = "kv" })
local W2RFN  = setmetatable({}, { __mode = "k" })
local SFN2RW = setmetatable({}, { __mode = "kv" })
local RW2SFN = setmetatable({}, { __mode = "k" })
local SAFEFN = setmetatable({}, { __mode = "k" })
local PROTECTED = setmetatable({}, { __mode = "k" })
local SBMT = setmetatable({}, { __mode = "k" })
local COLOR_META = FindMetaTable and FindMetaTable("Color")

local function CopyColor(c)
    return real_Color(tonumber(rawget(c, "r")) or 0, tonumber(rawget(c, "g")) or 0, tonumber(rawget(c, "b")) or 0, tonumber(rawget(c, "a")) or 255)
end

local KILL = setmetatable({}, { __tostring = function() return "sandbox execution limit exceeded" end })

local STRMETA = getmetatable("")
local LOCKED_METAS = {}
for _, name in ipairs({ "Color", "VMatrix", "IMaterial", "ITexture", "IMesh", "ConVar", "File", "CEffectData",
                        "CRecipientFilter", "bf_read", "CSoundPatch", "IGModAudioChannel", "ProjectedTexture" }) do
    local m = FindMetaTable and FindMetaTable(name)
    if istable(m) and rawget(m, "__index") == m then
        LOCKED_METAS[#LOCKED_METAS + 1] = m
    end
end

local METRO_PREFIXES = { "gmod_subway_", "gmod_train_", "gmod_track_" }

local function IsSubwayClass(class)
    return type(class) == "string" and string_sub(class, 1, 12) == "gmod_subway_"
end
SB.IsSubwayClass = IsSubwayClass

local function IsMetroClass(class)
    if type(class) ~= "string" then return false end
    for i = 1, #METRO_PREFIXES do
        local p = METRO_PREFIXES[i]
        if string_sub(class, 1, #p) == p then return true end
    end
    return false
end
SB.IsMetroClass = IsMetroClass

local DENY_SOURCES = {
    "/includes/", "lua/includes", "/menu/", "derma/", "vgui/", "gamemodes/", "ulib", "ulx", "/sam/", "/sam_",
    "fadmin", "serverguard", "evolve", "maestro", "cami", "admin", "trainfitter", "anticheat", "/bin/",
    "lua/autorun/server/sv_", "xadmin", "sadmin", "vcmod", "gprotect", "fpp", "nadmod",
}

local function FunctionAllowed(f)
    local info = debug_getinfo(f, "S")
    if not info or info.what ~= "Lua" then return false end
    local src = string_lower(info.source or "")
    if string_sub(src, 1, 1) ~= "@" then return false end
    for i = 1, #DENY_SOURCES do
        if string_find(src, DENY_SOURCES[i], 1, true) then return false end
    end
    return true
end

local G = { depth = 0 }
local GUARD = setmetatable({}, { __mode = "k" })

local function HookFn()
    if not G.killed then
        G.used = G.used + HOOK_STEP
        if G.used > G.budget then
            G.killed = "instruction limit exceeded"
        elseif collectgarbage("count") - G.mem0 > MEM_LIMIT_KB then
            G.killed = "memory limit exceeded"
        end
        if G.killed then debug_sethook(HookFn, "", 1) end
    end
    if G.killed then
        local info = debug_getinfo(2, "f")
        if info and GUARD[info.func] then return end
        error(KILL, 0)
    end
end

local SAFE_STRING = {}
local BLOCKED_STRING = { dump = true }

local function SafeStrIndex(s, k)
    local v = SAFE_STRING[k]
    if v ~= nil then return v end
    if BLOCKED_STRING[k] then return nil end
    v = real_string[k]
    if v ~= nil then return v end
    if tonumber(k) then return string_sub(s, k, k) end
end

local function LockedIndex(m)
    return function(_, k)
        if type(k) == "string" and string_sub(k, 1, 2) == "__" then return nil end
        return m[k]
    end
end
local LOCKED_INDEX = {}
for i = 1, #LOCKED_METAS do LOCKED_INDEX[i] = LockedIndex(LOCKED_METAS[i]) end

local HEAP = { lastCeil = 0, all = setmetatable({}, { __mode = "k" }) }
local GCPU = { t = 0, win = 0, per = {} }

function HEAP.Floor()
    if not HEAP.floor then
        collectgarbage("collect")
        HEAP.floor = collectgarbage("count")
    end
    return HEAP.floor
end

function HEAP.Check(sb)
    local floor = HEAP.Floor()
    collectgarbage("collect")
    local heap = collectgarbage("count")
    if heap < floor then HEAP.floor = heap floor = heap end
    if heap - floor > LIMITS.memRetain then
        sb:Kill("memory usage too high")
    else
        sb.memNet = 0
    end
end

function HEAP.Ceiling(now)
    if now - HEAP.lastCeil < 30 then return end
    local floor = HEAP.Floor()
    if collectgarbage("count") - floor < LIMITS.memCeiling then return end
    HEAP.lastCeil = now
    collectgarbage("collect")
    if collectgarbage("count") - floor < LIMITS.memCeiling then return end
    local worst, most = nil, LIMITS.memSuspect
    for s in pairs(HEAP.all) do
        if not s.dead and (s.memLife or 0) > most then worst, most = s, s.memLife end
    end
    if worst then worst:Kill("server memory is almost full") end
end

local function Enter(sb, budget, accounted)
    G.depth = G.depth + 1
    if G.depth == 1 then
        G.saved = { debug_gethook() }
        G.killed = false
        G.used = 0
        G.budget = budget or CALLBACK_BUDGET
        G.sb = sb
        G.accounted = accounted
        G.t0 = SysTime()
        G.mem0 = collectgarbage("count")
        G.thread = coroutine_running()
        G.entCount = 0
        G.spawned = nil
        G.entAbort = false
        G.entKill = false
        G.strIndex = STRMETA.__index
        STRMETA.__index = SafeStrIndex
        G.lockedSaved = {}
        for i = 1, #LOCKED_METAS do
            G.lockedSaved[i] = rawget(LOCKED_METAS[i], "__index")
            rawset(LOCKED_METAS[i], "__index", LOCKED_INDEX[i])
        end
        debug_sethook(HookFn, "", HOOK_STEP)
    end
end

local function Leave()
    G.depth = G.depth - 1
    if G.depth > 0 then return end
    local h = G.saved
    if h and h[1] then debug_sethook(h[1], h[2], h[3] or 0) else debug_sethook() end
    STRMETA.__index = G.strIndex
    for i = 1, #LOCKED_METAS do rawset(LOCKED_METAS[i], "__index", G.lockedSaved[i]) end
    local sb = G.sb
    G.sb = nil
    if G.entAbort then
        local spawned = G.spawned
        G.spawned = nil
        G.entAbort = false
        if spawned then
            for i = 1, #spawned do
                if real_IsValid(spawned[i]) then spawned[i]:Remove() end
            end
        end
        if G.entKill and sb then sb:Kill("too many entities created") end
        G.entKill = false
    end
    G.spawned = nil
    if sb and not sb.dead then
        local now = SysTime()
        local dm = collectgarbage("count") - G.mem0
        sb.memLife = (sb.memLife or 0) + dm
        sb.memNet = (sb.memNet or 0) + dm
        if now - (sb.memDecay or 0) >= MEM_WINDOW then
            sb.memNet = math_max(0, sb.memNet - LIMITS.memAllow)
            sb.memDecay = now
        end
        if sb.memNet > LIMITS.memRetain then HEAP.Check(sb) end
        if not sb.dead then HEAP.Ceiling(now) end
    end
    if sb and G.accounted and not sb.dead then
        local now = SysTime()
        local dt = now - G.t0
        sb.cpu = sb.cpu + dt
        local dm = collectgarbage("count") - G.mem0
        if dm > 0 then sb.mem = sb.mem + dm end
        if now - sb.cpuWin >= CPU_WINDOW then
            if sb.cpu > CPU_WINDOW * CPU_SHARE then sb:Kill("CPU usage too high") end
            sb.cpu, sb.cpuWin = 0, now
        end
        if now - sb.memWin >= MEM_WINDOW then
            if sb.mem > MEM_WINDOW_KB then sb:Kill("memory growth too high") end
            sb.mem, sb.memWin = 0, now
        end
        if SERVER then
            GCPU.t = GCPU.t + dt
            GCPU.per[sb] = (GCPU.per[sb] or 0) + dt
            if now - GCPU.win >= CPU_WINDOW then
                if GCPU.t > CPU_WINDOW * LIMITS.totalCpu then
                    local worst, most = nil, 0
                    for s, v in pairs(GCPU.per) do
                        if v > most and not s.dead then worst, most = s, v end
                    end
                    if worst then worst:Kill("total sandbox CPU usage too high") end
                end
                GCPU.t, GCPU.win, GCPU.per = 0, now, {}
            end
        end
    end
end

local function Pack(...) return { n = select("#", ...), ... } end
GUARD[Enter] = true
GUARD[Leave] = true
GUARD[Pack] = true

if SERVER then
    local getEdicts = ents.GetEdictCount
    local function EntGuard(ent)
        if G.depth == 0 or not G.sb then return end
        G.entCount = (G.entCount or 0) + 1
        local spawned = G.spawned
        if not spawned then spawned = {} G.spawned = spawned end
        spawned[#spawned + 1] = ent
        if G.entAbort then return end
        local tooMany = G.entCount > MAX_ENTS_PER_CALL
        if tooMany or (getEdicts and getEdicts() >= EDICT_CEILING) then
            G.entAbort = true
            G.entKill = tooMany
            if not G.killed then G.killed = tooMany and "too many entities created" or "server entity limit reached" end
            debug_sethook(HookFn, "", 1)
        end
    end
    GUARD[EntGuard] = true
    hook.Add("OnEntityCreated", "Trainfitter.SandboxEntityGuard", EntGuard)
end

local function SafeError(e)
    if e == KILL then return G.killed or "sandbox execution limit exceeded" end
    local t = type(e)
    if t == "string" then return e end
    if t == "number" or t == "boolean" or t == "nil" then return tostring(e) end
    return "error object of type " .. t
end
SB.SafeError = SafeError

local Wrap, Unwrap, WrapFn, ReverseWrap

local function WrapAll(...)
    local n = select("#", ...)
    if n == 0 then return end
    if n == 1 then return Wrap((...)) end
    local t = { ... }
    for i = 1, n do t[i] = Wrap(t[i]) end
    return unpack(t, 1, n)
end

local function UnwrapAll(...)
    local n = select("#", ...)
    if n == 0 then return end
    local seen = {}
    if n == 1 then return Unwrap((...), seen, 0) end
    local t = { ... }
    for i = 1, n do t[i] = Unwrap(t[i], seen, 0) end
    return unpack(t, 1, n)
end

local TABLE_MT, RO_TABLE_MT, ENT_TABLE_MT, ENT_MT, UD_MT = {}, {}, {}, {}, {}

local TABLE_KINDS = { table = true, rotable = true, enttable = true }
local ENTITY_KINDS = { train = true, client = true, player = true, other = true, null = true }

local function SafeAssetPath(p)
    if type(p) ~= "string" or #p > 260 then return nil end
    if string_find(p, "..", 1, true) or string_find(p, ":", 1, true) or string_find(p, "\0", 1, true) then return nil end
    local c = string_sub(p, 1, 1)
    if c == "/" or c == "\\" then return nil end
    return p
end

local function MakeTableProxy(real, kind)
    local mt = TABLE_MT
    if kind == "rotable" then mt = RO_TABLE_MT elseif kind == "enttable" then mt = ENT_TABLE_MT end
    local p = setmetatable({}, mt)
    P2R[p] = real
    PKIND[p] = kind
    if kind == "rotable" then R2P_RO[real] = p else R2P[real] = p end
    return p
end

local function AttachedToTrain(e)
    local p = e:GetParent()
    for _ = 1, 6 do
        if not real_IsValid(p) then return false end
        if IsSubwayClass(p:GetClass()) then return true end
        p = p:GetParent()
    end
    return false
end

local function EntityKind(e)
    if not real_IsValid(e) then return "null" end
    if e:IsPlayer() then return "player" end
    if CLIENT and e:EntIndex() == -1 then
        if SB_CSENTS[e] or AttachedToTrain(e) then return "client" end
        return "other"
    end
    if IsSubwayClass(e:GetClass()) then return "train" end
    return "other"
end

local function MakeEntityProxy(e)
    local p = setmetatable({}, ENT_MT)
    P2R[p] = e
    PKIND[p] = EntityKind(e)
    R2P[e] = p
    return p
end

local PASS_USERDATA = { Vector = true, Angle = true, VMatrix = true }
local UD_METHODS = {
    IMaterial = { GetName = true, GetShader = true, IsError = true, GetString = true, GetFloat = true, GetInt = true,
                  GetVector = true, GetVector4D = true, GetVectorLinear = true, GetColor = true, Width = true,
                  Height = true, GetTexture = true, GetMatrix = true },
    ITexture  = { GetName = true, Width = true, Height = true, GetMappingWidth = true, GetMappingHeight = true,
                  IsError = true, IsErrorTexture = true, GetNumAnimationFrames = true, GetColor = true },
}

local DENY_WRAP = setmetatable({}, { __mode = "k" })
local DENY_GLOBALS = {
    "string", "table", "math", "bit", "os", "io", "debug", "jit", "package", "coroutine", "utf8", "hook", "net",
    "concommand", "util", "file", "http", "sql", "game", "engine", "ents", "player", "timer", "scripted_ents",
    "weapons", "gmod", "cvars", "cookie", "duplicator", "constraint", "construct", "gamemode", "properties",
    "usermessage", "umsg", "system", "physenv", "navmesh", "ai", "sound", "resource", "steamworks", "render",
    "surface", "vgui", "gui", "input", "chat", "language", "spawnmenu", "presets", "list", "baseclass", "effects",
    "team", "undo", "cleanup", "numpad", "drive", "GAMEMODE", "GM", "CAMI", "ULib", "ulx", "sam", "SAM",
    "serverguard", "FAdmin", "evolve", "maestro", "Trainfitter", "MEL", "MetrostroiExtensionsLib", "Metrostroi",
    "Turbostroi",
}

local function RefreshDenyWrap()
    local function add(t) if type(t) == "table" then DENY_WRAP[t] = true end end
    add(_R)
    for i = 1, #DENY_GLOBALS do add(rawget(_R, DENY_GLOBALS[i])) end
    local pkg = rawget(_R, "package")
    if type(pkg) == "table" then add(rawget(pkg, "loaded")) end
    if istable(hook) and isfunction(hook.GetTable) then add(hook.GetTable()) end
    if istable(net) then add(rawget(net, "Receivers")) end
    if istable(concommand) and isfunction(concommand.GetTable) then
        local a, b = concommand.GetTable()
        add(a) add(b)
    end
    local reg = debug and debug.getregistry and debug.getregistry()
    if type(reg) == "table" then
        add(reg)
        for _, v in pairs(reg) do
            if type(v) == "table" and type(rawget(v, "MetaName")) == "string" then add(v) end
        end
    end
end
SB.RefreshDenyWrap = RefreshDenyWrap

local function IsEntTable(v)
    return type(rawget(v, "ClassName")) == "string" and (rawget(v, "Type") ~= nil or rawget(v, "Base") ~= nil)
end

local function TableKindFor(v, ro)
    if ro then return "rotable" end
    if IsEntTable(v) then
        if IsSubwayClass(rawget(v, "ClassName")) then return "enttable" end
        return "rotable"
    end
    return "table"
end

Wrap = function(v, ro)
    local tv = type(v)
    if tv == "nil" or tv == "boolean" or tv == "number" or tv == "string" then return v end
    if tv == "table" then
        if P2R[v] ~= nil or PROTECTED[v] then return v end
        if DENY_WRAP[v] then return nil end
        if COLOR_META and debug_getmetatable(v) == COLOR_META then return CopyColor(v) end
        local kind = TableKindFor(v, ro)
        local p = (kind == "rotable") and R2P_RO[v] or R2P[v]
        if p then return p end
        return MakeTableProxy(v, kind)
    end
    if tv == "function" then return WrapFn(v) end
    if PASS_USERDATA[tv] then return v end
    if UD_METHODS[tv] then
        local p = R2P[v]
        if p then return p end
        p = setmetatable({}, UD_MT)
        P2R[p] = v
        PKIND[p] = tv
        R2P[v] = p
        return p
    end
    if real_isentity(v) then
        local p = R2P[v]
        if p then return p end
        return MakeEntityProxy(v)
    end
    return nil
end

local function WrapAllRO(...)
    local n = select("#", ...)
    if n == 0 then return end
    local t = { ... }
    for i = 1, n do t[i] = Wrap(t[i], true) end
    return unpack(t, 1, n)
end

local function DeepCopy(t, seen, depth, noAdopt)
    local c = seen[t]
    if c ~= nil then return c end
    if PROTECTED[t] then error("sandbox library tables cannot leave the sandbox", 3) end
    if depth > MAX_COPY_DEPTH then error("table nested too deeply", 3) end
    local out = {}
    seen[t] = out
    seen.__count = (seen.__count or 0)
    for k, v in next, t do
        seen.__count = seen.__count + 1
        if seen.__count > MAX_COPY_ENTRIES then error("table too large", 3) end
        local rk = Unwrap(k, seen, depth + 1)
        if rk ~= nil then out[rk] = Unwrap(v, seen, depth + 1) end
    end
    local mt = debug_getmetatable(t)
    if type(mt) == "table" then
        local rmt = P2R[mt]
        if rmt == nil then rmt = DeepCopy(mt, seen, depth + 1, true) end
        setmetatable(out, rmt)
    elseif mt == nil and not noAdopt and rawget(t, 1) == nil and rawget(t, "__index") == nil and not SBMT[t] then
        local keys = {}
        for k in next, t do keys[#keys + 1] = k end
        for i = 1, #keys do rawset(t, keys[i], nil) end
        setmetatable(t, TABLE_MT)
        P2R[t] = out
        PKIND[t] = "table"
        R2P[out] = t
    end
    return out
end

Unwrap = function(v, seen, depth)
    local tv = type(v)
    if tv == "nil" or tv == "boolean" or tv == "number" or tv == "string" then return v end
    if tv == "table" then
        local r = P2R[v]
        if r ~= nil then
            local kind = PKIND[v]
            if kind == "player" or kind == "other" or kind == "null" then return NULL end
            return r
        end
        if COLOR_META and debug_getmetatable(v) == COLOR_META then return CopyColor(v) end
        return DeepCopy(v, seen or {}, depth or 0)
    end
    if tv == "function" then
        local r = W2RFN[v]
        if r then return r end
        local rw = SFN2RW[v]
        if rw then return rw end
        local owner = ENVS[getfenv(v)]
        if owner then return ReverseWrap(v, owner) end
        return v
    end
    if tv == "thread" then return nil end
    return v
end

WrapFn = function(f)
    local s = RW2SFN[f]
    if s then return s end
    if SAFEFN[f] then return f end
    local w = RFN2W[f]
    if w then return w end
    if ENVS[getfenv(f)] then return f end
    if FunctionAllowed(f) then
        w = function(...) return WrapAll(f(UnwrapAll(...))) end
    else
        w = function() error("this function is protected and cannot be called from a sandboxed addon", 2) end
    end
    RFN2W[f] = w
    W2RFN[w] = f
    return w
end

ReverseWrap = function(fn, sb)
    local w = SFN2RW[fn]
    if w then return w end
    w = function(...)
        if sb.dead then return end
        if G.depth > 0 then
            if coroutine_running() == G.thread then
                return UnwrapAll(fn(WrapAll(...)))
            end
            debug_sethook(HookFn, "", HOOK_STEP)
            local res = Pack(pcall(fn, WrapAll(...)))
            debug_sethook()
            if not res[1] then error(res[2], 0) end
            return UnwrapAll(unpack(res, 2, res.n))
        end
        return sb:Call(fn, ...)
    end
    GUARD[w] = true
    SFN2RW[fn] = w
    RW2SFN[w] = fn
    return w
end

local BLOCKED_WRITE_KEYS = {}
for _, k in ipairs({
    "CanProperty", "CanTool", "PhysgunPickup", "PhysgunDrop", "GravGunPickupAllowed", "GravGunPunt",
    "CanEditVariables", "CanDrive", "SpawnFunction", "OnDuplicated", "PreEntityCopy", "PostEntityPaste",
    "PostEntityCopy", "OnEntityCopyTableFinish", "UpdateTransmitState", "AcceptInput", "KeyValue", "Use",
    "OnTakeDamage", "StartTouch", "Touch", "EndTouch", "SetOwner", "SetCreator", "CanPlayerEnter", "CanEnter",
    "GetPlayer", "SetPlayer", "Spawnable", "Editable", "PhysgunDisabled", "m_tblToolsAllowed", "DoNotDuplicate",
    "DisableDuplicator",
}) do BLOCKED_WRITE_KEYS[k] = true end
local BLOCKED_WRITE_WORDS = { "owner", "cppi", "fpp", "creator", "steamid", "admin", "access", "permission", "protect" }

local function BlockedWriteKey(k)
    if type(k) ~= "string" then return false end
    if BLOCKED_WRITE_KEYS[k] then return true end
    local l = string_lower(k)
    for i = 1, #BLOCKED_WRITE_WORDS do
        if string_find(l, BLOCKED_WRITE_WORDS[i], 1, true) then return true end
    end
    return false
end
SB.BlockedWriteKey = BlockedWriteKey

local CheckSpawnerWrite
do
    local SPAWNER_ERR = "the train spawner can only create Metrostroi trains"

    local function IsSpawnerTable(r)
        if type(r) ~= "table" or not istable(scripted_ents) then return false end
        for c, st in pairs(scripted_ents.GetList()) do
            if IsSubwayClass(c) and type(st) == "table" and type(st.t) == "table" and rawget(st.t, "Spawner") == r then
                return true
            end
        end
        return false
    end

    local function SpawnerClassOK(c)
        return c == nil or IsSubwayClass(c)
    end

    local function FilterSpawnFunc(f)
        if type(f) ~= "function" or RW2SFN[f] == nil then return f end
        local g = function(...)
            local c = f(...)
            if IsSubwayClass(c) then return c end
            error(SPAWNER_ERR, 2)
        end
        RW2SFN[g] = RW2SFN[f]
        return g
    end

    CheckSpawnerWrite = function(r, rk, rv)
        if rk == "head" or rk == "interim" then
            if not SpawnerClassOK(rv) and IsSpawnerTable(r) then error(SPAWNER_ERR, 3) end
        elseif rk == "spawnfunc" then
            if IsSpawnerTable(r) then return FilterSpawnFunc(rv) end
        elseif rk == "Spawner" and type(rv) == "table" then
            if not SpawnerClassOK(rawget(rv, "head")) or not SpawnerClassOK(rawget(rv, "interim")) then error(SPAWNER_ERR, 3) end
            local sf = rawget(rv, "spawnfunc")
            if sf ~= nil then rawset(rv, "spawnfunc", FilterSpawnFunc(sf)) end
        end
        return rv
    end
end

TABLE_MT.__index = function(p, k)
    local r = P2R[p]
    if r == nil then return nil end
    return Wrap(r[Unwrap(k)])
end
TABLE_MT.__newindex = function(p, k, v)
    if BlockedWriteKey(k) then error("field '" .. tostring(k) .. "' cannot be changed from the sandbox", 2) end
    local r = P2R[p]
    if r == nil then error("detached sandbox proxy", 2) end
    local rk = Unwrap(k)
    if rk == nil then error("table index is nil", 2) end
    r[rk] = CheckSpawnerWrite(r, rk, Unwrap(v))
end
TABLE_MT.__tostring = function() return "table: sandbox" end
TABLE_MT.__metatable = false

RO_TABLE_MT.__index = function(p, k)
    local r = P2R[p]
    if r == nil then return nil end
    return Wrap(r[Unwrap(k)], true)
end
RO_TABLE_MT.__newindex = function() error("this table is read-only in the sandbox", 2) end
RO_TABLE_MT.__tostring = TABLE_MT.__tostring
RO_TABLE_MT.__metatable = false

ENT_TABLE_MT.__index = TABLE_MT.__index
ENT_TABLE_MT.__newindex = function(p, k, v)
    if BlockedWriteKey(k) then error("field '" .. tostring(k) .. "' of an entity cannot be changed from the sandbox", 2) end
    local r = P2R[p]
    if r == nil then error("detached sandbox proxy", 2) end
    local rk = Unwrap(k)
    if rk == nil then error("table index is nil", 2) end
    r[rk] = CheckSpawnerWrite(r, rk, Unwrap(v))
end
ENT_TABLE_MT.__tostring = TABLE_MT.__tostring
ENT_TABLE_MT.__metatable = false

UD_MT.__index = function(p, k)
    local u = P2R[p]
    local allowed = UD_METHODS[PKIND[p]]
    if type(k) ~= "string" or not allowed or not allowed[k] then return nil end
    local cache = MCACHE[p]
    if not cache then cache = {} MCACHE[p] = cache end
    local f = cache[k]
    if f then return f end
    local target = u[k]
    if type(target) ~= "function" then return nil end
    f = function(_, ...) return WrapAll(target(u, UnwrapAll(...))) end
    SAFEFN[f] = true
    cache[k] = f
    return f
end
UD_MT.__newindex = function() error("read-only object", 2) end
UD_MT.__tostring = function(p) return tostring(PKIND[p]) end
UD_MT.__metatable = false

local READ_METHODS = {}
for _, n in ipairs({
    "IsValid", "EntIndex", "GetClass", "GetModel", "GetPos", "GetAngles", "GetForward", "GetRight", "GetUp",
    "LocalToWorld", "WorldToLocal", "LocalToWorldAngles", "WorldToLocalAngles", "GetSkin", "SkinCount",
    "GetBodygroup", "GetBodygroupName", "GetBodygroupCount", "FindBodygroupByName", "GetNumBodyGroups", "GetBodyGroups",
    "GetColor", "GetMaterial", "GetMaterials", "GetSubMaterial", "GetModelScale", "GetNoDraw", "GetParent",
    "GetChildren", "GetVelocity", "OBBMins", "OBBMaxs", "OBBCenter", "BoundingRadius", "IsPlayer", "IsVehicle",
    "IsNPC", "IsWeapon", "IsWorld", "IsDormant", "IsOnGround", "WaterLevel", "Health", "GetMaxHealth",
    "GetMoveType", "GetSolid", "GetRenderMode", "GetRenderFX", "GetCreationTime", "GetOwner", "CPPIGetOwner",
    "GetCreator", "GetBonePosition", "LookupBone", "GetBoneCount", "GetBoneName", "LookupAttachment",
    "GetAttachment", "GetAttachments", "GetPoseParameter", "GetSequence", "LookupSequence", "GetCycle",
    "GetManipulateBonePosition", "GetManipulateBoneAngles", "GetManipulateBoneScale", "GetFlexNum", "GetName",
    "GetLocalPos", "GetLocalAngles", "GetNWAngle", "GetNWBool", "GetNWEntity", "GetNWFloat", "GetNWInt",
    "GetNWString", "GetNWVector", "GetNW2Angle", "GetNW2Bool", "GetNW2Entity", "GetNW2Float", "GetNW2Int",
    "GetNW2String", "GetNW2Var", "GetNW2Vector", "GetNetworkedAngle", "GetNetworkedBool", "GetNetworkedEntity",
    "GetNetworkedFloat", "GetNetworkedInt", "GetNetworkedString", "GetNetworkedVector", "GetDTAngle", "GetDTBool",
    "GetDTEntity", "GetDTFloat", "GetDTInt", "GetDTString", "GetDTVector", "GetRenderOrigin", "GetRenderAngles",
    "GetBoneMatrix", "GetHitBoxBounds", "GetModelRadius", "GetModelBounds", "GetModelRenderBounds",
}) do READ_METHODS[n] = true end

local PLAYER_METHODS = {}
for _, n in ipairs({
    "IsValid", "EntIndex", "GetClass", "Nick", "Name", "GetName", "SteamID", "SteamID64", "UserID", "AccountID",
    "IsBot", "IsPlayer", "IsAdmin", "IsSuperAdmin", "Team", "GetPos", "EyePos", "EyeAngles", "GetAimVector",
    "GetShootPos", "GetVehicle", "InVehicle", "Alive", "GetUserGroup", "IsUserGroup", "IsListenServerHost",
    "GetActiveWeapon", "GetViewEntity", "KeyDown", "GetAngles", "GetForward", "GetVelocity", "Ping",
    "GetNWAngle", "GetNWBool", "GetNWEntity", "GetNWFloat", "GetNWInt", "GetNWString", "GetNWVector",
    "GetNW2Angle", "GetNW2Bool", "GetNW2Entity", "GetNW2Float", "GetNW2Int", "GetNW2String", "GetNW2Vector",
}) do PLAYER_METHODS[n] = true end

local COSMETIC_METHODS = {}
for _, n in ipairs({
    "SetNoDraw", "SetModel", "SetModelScale", "SetPos", "SetAngles", "SetLocalPos", "SetLocalAngles", "SetColor",
    "SetMaterial", "SetSubMaterial", "SetSkin", "SetBodygroup", "SetBodyGroups", "SetRenderMode", "SetRenderFX",
    "SetupBones", "InvalidateBoneCache", "ManipulateBonePosition", "ManipulateBoneAngles", "ManipulateBoneScale",
    "ManipulateBoneJiggle", "SetPoseParameter", "SetCycle", "SetSequence", "SetPlaybackRate", "FrameAdvance",
    "DrawModel", "SetLOD", "SetRenderBounds", "SetRenderOrigin", "SetRenderAngles", "DrawShadow", "DestroyShadow",
    "CreateShadow", "MarkShadowAsDirty", "SetFlexWeight", "SetFlexScale", "EnableMatrix", "DisableMatrix",
    "SetRenderClipPlaneEnabled", "SetRenderClipPlane", "RemoveEffects", "AddEffects", "SetNextClientThink",
}) do COSMETIC_METHODS[n] = true end

local CLIENTSIDE_ONLY_METHODS = { SetParent = true, Remove = true, SetMoveType = true, Spawn = true, SetNoDraw = true }

local SERVER_TRAIN_METHODS = {}
for _, n in ipairs({
    "SetNW2Angle", "SetNW2Bool", "SetNW2Float", "SetNW2Int", "SetNW2String", "SetNW2Vector",
    "SetNWAngle", "SetNWBool", "SetNWFloat", "SetNWInt", "SetNWString", "SetNWVector",
    "SetNetworkedAngle", "SetNetworkedBool", "SetNetworkedFloat", "SetNetworkedInt", "SetNetworkedString",
    "SetNetworkedVector", "SetSkin", "SetBodygroup", "SetBodyGroups", "SetColor", "SetMaterial", "SetSubMaterial",
    "SetRenderMode", "SetRenderFX",
}) do SERVER_TRAIN_METHODS[n] = true end

local NW_SETTERS, MAT_SETTERS, CheckNW = {}, { SetMaterial = 1, SetSubMaterial = 2 }
for n in pairs(SERVER_TRAIN_METHODS) do
    if string_sub(n, 1, 5) == "SetNW" or string_sub(n, 1, 12) == "SetNetworked" then NW_SETTERS[n] = true end
end
do
    local NW_SEEN = {}

    CheckNW = function(key, value)
        if type(key) ~= "string" or key == "" or #key > 64 then error("bad networked variable name", 3) end
        if type(value) == "string" and #value > 1024 then error("networked value is too long", 3) end
        if NW_SEEN[key] then return end
        local sb = G.sb
        if sb then
            sb.nwKeys = (sb.nwKeys or 0) + 1
            if sb.nwKeys > LIMITS.nwKeys then error("too many networked variable names", 3) end
        end
        NW_SEEN[key] = true
    end
end

local function MethodAllowed(kind, k)
    if kind == "player" then return PLAYER_METHODS[k] end
    if READ_METHODS[k] then return true end
    if kind == "null" or kind == "other" then return false end
    if CLIENT then
        if COSMETIC_METHODS[k] then return true end
        if kind == "client" and CLIENTSIDE_ONLY_METHODS[k] then return true end
        return k == "GetTable"
    end
    if kind == "train" then return SERVER_TRAIN_METHODS[k] or k == "GetTable" end
    return false
end

local TABLE_ACCESS = { train = true, client = true }

local function BoundMethod(p, e, kind, k)
    if not MethodAllowed(kind, k) then return nil end
    local cache = MCACHE[p]
    if not cache then cache = {} MCACHE[p] = cache end
    local f = cache[k]
    if f then return f end
    local target = e[k]
    if type(target) ~= "function" then return nil end
    if k == "GetTable" then
        f = function()
            if not real_IsValid(e) then return nil end
            local t = e:GetTable()
            if not t then return nil end
            local p2 = R2P[t]
            if p2 and PKIND[p2] == "enttable" then return p2 end
            return MakeTableProxy(t, "enttable")
        end
    elseif SERVER and NW_SETTERS[k] then
        f = function(_, key, value, ...)
            CheckNW(key, value)
            return WrapAll(target(e, key, UnwrapAll(value, ...)))
        end
    elseif SERVER and MAT_SETTERS[k] then
        local idx = MAT_SETTERS[k]
        f = function(_, ...)
            local path = select(idx, ...)
            if path ~= nil and (type(path) ~= "string" or not SafeAssetPath(path)) then error("bad material path", 2) end
            return WrapAll(target(e, UnwrapAll(...)))
        end
    else
        f = function(_, ...) return WrapAll(target(e, UnwrapAll(...))) end
    end
    SAFEFN[f] = true
    cache[k] = f
    return f
end

ENT_MT.__index = function(p, k)
    local e = P2R[p]
    local kind = PKIND[p]
    if type(k) ~= "string" then return nil end
    local m = BoundMethod(p, e, kind, k)
    if m ~= nil then return m end
    if not TABLE_ACCESS[kind] or not real_IsValid(e) then return nil end
    local t = e:GetTable()
    if not t then return nil end
    return Wrap(t[k])
end
ENT_MT.__newindex = function(p, k, v)
    local e = P2R[p]
    if not TABLE_ACCESS[PKIND[p]] then error("this entity is read-only in the sandbox", 2) end
    if type(k) ~= "string" and type(k) ~= "number" then error("bad entity field", 2) end
    if BlockedWriteKey(k) then error("field '" .. tostring(k) .. "' of an entity cannot be changed from the sandbox", 2) end
    if not real_IsValid(e) then return end
    local t = e:GetTable()
    if t then t[k] = CheckSpawnerWrite(t, k, Unwrap(v)) end
end
ENT_MT.__eq = function(a, b) return P2R[a] == P2R[b] end
ENT_MT.__tostring = function(p) return tostring(P2R[p]) end
ENT_MT.__metatable = false

local function IsEntityProxy(v)
    return ENTITY_KINDS[PKIND[v]] == true
end

local function CheckPattern(s, pat, plain)
    if plain then return end
    if type(pat) ~= "string" or type(s) ~= "string" then return end
    if #pat > 512 then error("pattern too long", 3) end
    local q = 0
    local i = 1
    while i <= #pat do
        local c = string_sub(pat, i, i)
        if c == "%" then i = i + 1
        elseif c == "*" or c == "+" or c == "-" or c == "?" then q = q + 1 end
        i = i + 1
    end
    local n = #s
    if (q > 1 and n > 65536) or (q > 2 and n > 4096) or (q > 4 and n > 512) or n > 4194304 then
        error("pattern too complex for this string", 3)
    end
end

SAFE_STRING.rep = function(s, n, sep)
    s = tostring(s)
    n = tonumber(n) or 0
    local total = #s * math_max(n, 0) + (sep and #tostring(sep) * math_max(n - 1, 0) or 0)
    if total > 33554432 then error("string.rep result too large", 2) end
    return string_rep(s, n, sep)
end
SAFE_STRING.find = function(s, pat, init, plain) CheckPattern(s, pat, plain) return real_string.find(s, pat, init, plain) end
SAFE_STRING.match = function(s, pat, init) CheckPattern(s, pat) return real_string.match(s, pat, init) end
SAFE_STRING.gmatch = function(s, pat) CheckPattern(s, pat) return real_string.gmatch(s, pat) end
SAFE_STRING.gsub = function(s, pat, repl, n) CheckPattern(s, pat) return real_string.gsub(s, pat, repl, n) end
SAFE_STRING.dump = nil

local function BuildStringLib()
    local s = {}
    for k, v in pairs(real_string) do
        if not BLOCKED_STRING[k] then s[k] = v end
    end
    for k, v in pairs(SAFE_STRING) do s[k] = v end
    return s
end

local function SbType(v)
    if IsEntityProxy(v) then return type(P2R[v]) end
    return type(v)
end

local function SbPairs(t)
    local r = P2R[t]
    if r == nil then return next, t, nil end
    local kind = PKIND[t]
    local src = r
    local ro = kind == "rotable"
    if not TABLE_KINDS[kind] then
        if not TABLE_ACCESS[kind] or not real_IsValid(r) then return function() end, t, nil end
        src = r:GetTable() or {}
    end
    local keys = {}
    for k in pairs(src) do keys[#keys + 1] = k end
    local i = 0
    return function()
        while true do
            i = i + 1
            local k = keys[i]
            if k == nil then return nil end
            local v = rawget(src, k)
            if v ~= nil then
                local wk = Wrap(k, ro)
                if wk ~= nil then return wk, Wrap(v, ro) end
            end
        end
    end, t, nil
end

local function SbIpairs(t)
    local r = P2R[t]
    if r == nil or not TABLE_KINDS[PKIND[t]] then
        if r ~= nil then return function() end, t, 0 end
        return ipairs(t)
    end
    local ro = PKIND[t] == "rotable"
    return function(_, i)
        i = i + 1
        local v = r[i]
        if v == nil then return nil end
        return i, Wrap(v, ro)
    end, t, 0
end

local function SbNext(t, k)
    local r = P2R[t]
    if r == nil then return next(t, k) end
    if not TABLE_KINDS[PKIND[t]] then return nil end
    local ro = PKIND[t] == "rotable"
    local ok, nk, nv = pcall(next, r, Unwrap(k))
    if not ok or nk == nil then return nil end
    return Wrap(nk, ro), Wrap(nv, ro)
end

local function SbUnpack(t, i, j)
    local r = P2R[t]
    if r == nil then return unpack(t, i, j) end
    if not TABLE_KINDS[PKIND[t]] then return end
    if PKIND[t] == "rotable" then return WrapAllRO(unpack(r, i or 1, j or #r)) end
    return WrapAll(unpack(r, i or 1, j or #r))
end

local function SbLen(t)
    local r = P2R[t]
    if r == nil then return #t end
    if TABLE_KINDS[PKIND[t]] then return #r end
    return 0
end

local function SbSortedPairs(t, desc)
    local keys = {}
    for k in SbPairs(t) do keys[#keys + 1] = k end
    table_sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta ~= tb then return ta < tb end
        if ta == "number" or ta == "string" then
            if desc then return a > b end
            return a < b
        end
        return tostring(a) < tostring(b)
    end)
    local i = 0
    return function()
        i = i + 1
        local k = keys[i]
        if k == nil then return nil end
        return k, t[k]
    end
end

local TABLE_READERS = {
    Count = true, HasValue = true, KeyFromValue = true, KeysFromValue = true, GetKeys = true, concat = true,
    Copy = true, IsEmpty = true, Random = true, maxn = true, Reverse = true, IsSequential = true,
    GetFirstKey = true, GetFirstValue = true, GetLastKey = true, GetLastValue = true, SortByKey = true,
    ClearKeys = true, CollapseKeyValue = true, Flip = true, GetWinningKey = true, getn = true,
}
local TABLE_ARRAY_MUTATORS = { insert = true, remove = true, sort = true, Shuffle = true }
local TABLE_BLOCKED = { Print = true, ToString = true, ForEach = true, foreach = true, foreachi = true }

local function BuildTableLib()
    local lib = {}
    for name, fn in pairs(real_table) do
        if type(fn) == "function" and not TABLE_BLOCKED[name] then
            local reader = TABLE_READERS[name]
            local wrapped = function(t, ...)
                local r = P2R[t]
                if r ~= nil then
                    local kind = PKIND[t]
                    if not TABLE_KINDS[kind] then error("table." .. name .. " expects a table", 2) end
                    if not reader and not (kind == "table" and TABLE_ARRAY_MUTATORS[name]) then
                        error("table." .. name .. " cannot modify this table from the sandbox", 2)
                    end
                    return WrapAll(fn(r, UnwrapAll(...)))
                end
                return fn(t, ...)
            end
            SAFEFN[wrapped] = true
            lib[name] = wrapped
        end
    end
    lib.getn = SbLen
    lib.Len = SbLen
    return lib
end

local function CleanPath(p)
    if type(p) ~= "string" then return nil end
    p = string_lower(string_gsub(p, "\\", "/"))
    p = string_gsub(p, "^%./", "")
    p = string_gsub(p, "^/+", "")
    if p == "" or string_find(p, "..", 1, true) or string_find(p, ":", 1, true) or string_find(p, "\0", 1, true) then
        return nil
    end
    return p
end


local TRUSTED_INCLUDES = { "^metrostroi/extensions/constants/[%w_]+%.lua$" }

local function TrustedInclude(p)
    for i = 1, #TRUSTED_INCLUDES do
        if string_match(p, TRUSTED_INCLUDES[i]) then return true end
    end
    return false
end

local ALLOWED_HOOKS = {
    InitPostEntity = true, Initialize = true, PostGamemodeLoaded = true, OnGamemodeLoaded = true, Think = true,
    Tick = true, OnEntityCreated = true, EntityRemoved = true, NetworkEntityCreated = true,
    PostDrawOpaqueRenderables = true, PostDrawTranslucentRenderables = true, PreDrawOpaqueRenderables = true,
    PreDrawTranslucentRenderables = true, PostCleanupMap = true,
}
local LATE_HOOKS = { InitPostEntity = true, Initialize = true, PostGamemodeLoaded = true, OnGamemodeLoaded = true }

local function HookAllowed(event)
    if type(event) ~= "string" or #event > 64 then return false end
    if ALLOWED_HOOKS[event] then return true end
    return string_sub(event, 1, 10) == "Metrostroi"
end

SB.GameStarted = false
hook.Add("InitPostEntity", "Trainfitter.SandboxGameStarted", function()
    SB.GameStarted = true
    RefreshDenyWrap()
end)
RefreshDenyWrap()

local METRO_FN_SKIN = { AddSkin = true, AddLastStationTex = true, AddPassSchemeTex = true }
local METRO_FN_MASK = {
    AddSkin = true, AddLastStationTex = true, AddPassSchemeTex = true, AngleFromPanel = true,
    PositionFromPanel = true, GenerateClientProps = true, GetPhrase = true, HasPhrase = true, VectorAngle = true,
    InsertHide = true, DrawLine = true, DrawRectOL = true, DrawRectOutline = true, DrawTextRect = true,
    DrawTextRectOL = true, DrawClockDigit = true, GetTimedT = true, GetSyncTime = true, ServerTime = true,
    TrainCount = true, GetLowVal = true,
}
local METRO_DATA = {
    Skins = true, SpawnedTrains = true, TrainClasses = true, TrainSpawnerClasses = true, Version = true,
    Loaded = true, IsTrainClass = true, Languages = true, CurrentLanguageTable = true, ChoosedLang = true,
    BaseSystems = true,
}

local SANDBOX = {}
SANDBOX.__index = SANDBOX

function SB.New(opts)
    opts = opts or {}
    RefreshDenyWrap()
    HEAP.Floor()
    local sb = setmetatable({
        id        = tostring(opts.id or "anon"),
        bodies    = opts.bodies or {},
        mel       = opts.mel == true,
        fileBudget = opts.fileBudget or 100000000,
        hooks     = {},
        hookCount = 0,
        timers    = {},
        timerCount = 0,
        simplePending = 0,
        csents    = {},
        lateInit  = {},
        envs      = {},
        dead      = false,
        cpu = 0, cpuWin = SysTime(), mem = 0, memWin = SysTime(),
        logCount = 0, logWin = SysTime(), errCount = 0, errWin = SysTime(),
        includeDepth = 0,
        currentDir = "",
        recipes = {},
    }, SANDBOX)
    HEAP.all[sb] = true
    return sb
end

function SANDBOX:Log(...)
    local now = SysTime()
    if now - self.logWin > 60 then self.logWin, self.logCount = now, 0 end
    self.logCount = self.logCount + 1
    if self.logCount > 100 then return end
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    local line = table_concat(parts, "\t")
    if #line > 500 then line = string_sub(line, 1, 500) .. "..." end
    MsgC(Color(170, 200, 230), "[Trainfitter:" .. self.id .. "] ", Color(220, 220, 220), line, "\n")
end

function SANDBOX:Report(err)
    local now = SysTime()
    if now - self.errWin > 30 then self.errWin, self.errCount = now, 0 end
    self.errCount = self.errCount + 1
    if self.errCount > 5 then return end
    local msg = SafeError(err)
    if #msg > 400 then msg = string_sub(msg, 1, 400) .. "..." end
    MsgC(Color(255, 150, 90), "[Trainfitter:" .. self.id .. "] sandboxed code error: ", Color(230, 230, 230), msg, "\n")
end

function SANDBOX:Kill(reason)
    if self.dead then return end
    self.dead = true
    self.stopped = true
    MsgC(Color(255, 110, 110), "[Trainfitter:" .. self.id .. "] sandbox disabled: " .. tostring(reason) .. "\n")
    self:Cleanup()
    for _, env in pairs(self.envs) do
        for k in pairs(env) do rawset(env, k, nil) end
    end
    self.bodies = {}
end

function SANDBOX:Stop()
    self.stopped = true
    self:Cleanup()
end

function SANDBOX:Cleanup()
    for event, ids in pairs(self.hooks) do
        for key in pairs(ids) do real_hook_Remove(event, key) end
    end
    self.hooks, self.hookCount = {}, 0
    for key in pairs(self.timers) do real_timer.Remove(key) end
    self.timers, self.timerCount = {}, 0
    for ent in pairs(self.csents) do
        if real_IsValid(ent) then ent:Remove() end
    end
    self.csents = {}
end

function SANDBOX:Destroy()
    self.dead = true
    self.stopped = true
    self:Cleanup()
end

function SANDBOX:CallHook(fn, ...)
    if self.dead or self.stopped then return end
    local args = Pack(WrapAllRO(...))
    Enter(self, CALLBACK_BUDGET, true)
    local res = Pack(pcall(fn, unpack(args, 1, args.n)))
    Leave()
    if not res[1] then self:Report(res[2]) end
end

function SANDBOX:Call(fn, ...)
    if self.dead then return end
    local args = Pack(WrapAll(...))
    Enter(self, CALLBACK_BUDGET, true)
    local res = Pack(pcall(fn, unpack(args, 1, args.n)))
    Leave()
    if not res[1] then
        self:Report(res[2])
        return
    end
    return UnwrapAll(unpack(res, 2, res.n))
end

function SANDBOX:Key(name)
    return "trainfitter_sb:" .. self.id .. ":" .. tostring(name)
end

function SANDBOX:BuildHookLib()
    local sb = self
    local lib = {}
    lib.Add = function(event, id, fn)
        if not HookAllowed(event) then error("hook '" .. tostring(event) .. "' is not available to sandboxed addons", 2) end
        if type(fn) ~= "function" then return end
        local key = sb:Key(id)
        sb.hooks[event] = sb.hooks[event] or {}
        if not sb.hooks[event][key] then
            if sb.hookCount >= MAX_HOOKS then error("too many hooks", 2) end
            sb.hookCount = sb.hookCount + 1
        end
        sb.hooks[event][key] = { fn = fn, id = id }
        real_hook_Add(event, key, function(...)
            if sb.dead or sb.stopped then return end
            sb:CallHook(fn, ...)
        end)
        if LATE_HOOKS[event] and SB.GameStarted then
            sb.lateInit[#sb.lateInit + 1] = { event = event, key = key }
        end
    end
    lib.Remove = function(event, id)
        if type(event) ~= "string" then return end
        local key = sb:Key(id)
        if sb.hooks[event] and sb.hooks[event][key] then
            sb.hooks[event][key] = nil
            sb.hookCount = sb.hookCount - 1
            real_hook_Remove(event, key)
        end
    end
    lib.GetTable = function()
        local out = {}
        for event, ids in pairs(sb.hooks) do
            out[event] = {}
            for _, rec in pairs(ids) do out[event][rec.id] = rec.fn end
        end
        return out
    end
    return lib
end

function SANDBOX:FireLateInit()
    local queue = self.lateInit
    self.lateInit = {}
    for i = 1, #queue do
        local q = queue[i]
        local rec = self.hooks[q.event] and self.hooks[q.event][q.key]
        if rec then self:CallHook(rec.fn) end
    end
end

function SANDBOX:BuildTimerLib()
    local sb = self
    local lib = {}
    local function key(name)
        if type(name) ~= "string" and type(name) ~= "number" then error("bad timer name", 3) end
        return sb:Key(name)
    end
    lib.Simple = function(delay, fn)
        if type(fn) ~= "function" then return end
        if sb.simplePending >= MAX_SIMPLE then error("too many pending timers", 2) end
        sb.simplePending = sb.simplePending + 1
        real_timer.Simple(math_max(tonumber(delay) or 0, 0), function()
            sb.simplePending = sb.simplePending - 1
            if not sb.dead and not sb.stopped then sb:CallHook(fn) end
        end)
    end
    lib.Create = function(name, delay, reps, fn)
        local k = key(name)
        if type(fn) ~= "function" then return end
        if not sb.timers[k] then
            if sb.timerCount >= MAX_TIMERS then error("too many timers", 2) end
            sb.timerCount = sb.timerCount + 1
        end
        sb.timers[k] = true
        real_timer.Create(k, math_max(tonumber(delay) or 0, 0), math_max(math_floor(tonumber(reps) or 1), 0), function()
            if sb.dead or sb.stopped then real_timer.Remove(k) return end
            sb:CallHook(fn)
        end)
    end
    lib.Remove = function(name)
        local k = key(name)
        if sb.timers[k] then
            sb.timers[k] = nil
            sb.timerCount = sb.timerCount - 1
        end
        real_timer.Remove(k)
    end
    lib.Adjust = function(name, delay, reps, fn)
        local k = key(name)
        if not sb.timers[k] then return false end
        local real
        if type(fn) == "function" then
            real = function()
                if sb.dead or sb.stopped then real_timer.Remove(k) return end
                sb:CallHook(fn)
            end
        end
        return real_timer.Adjust(k, math_max(tonumber(delay) or 0, 0), reps and math_max(math_floor(tonumber(reps) or 1), 0) or nil, real)
    end
    for _, n in ipairs({ "Exists", "Start", "Stop", "Toggle", "Pause", "UnPause", "TimeLeft", "RepsLeft", "IsPaused" }) do
        local f = real_timer[n]
        if isfunction(f) then
            lib[n] = function(name) return f(key(name)) end
        end
    end
    return lib
end

local function ProxyList(list)
    local out = {}
    if type(list) ~= "table" then return out end
    for i = 1, #list do out[i] = Wrap(list[i]) end
    return out
end

local function ListIterator(list)
    local i = 0
    return function()
        i = i + 1
        local v = list[i]
        if v == nil then return nil end
        return i, v
    end
end

function SANDBOX:BuildMetrostroiView(fnSet)
    local view = setmetatable({}, {
        __index = function(_, k)
            if not istable(Metrostroi) then return nil end
            if fnSet[k] then return Wrap(Metrostroi[k]) end
            if METRO_DATA[k] then return Wrap(Metrostroi[k], true) end
            return nil
        end,
        __newindex = function() error("the Metrostroi table is read-only for sandboxed addons", 2) end,
        __metatable = false,
    })
    PROTECTED[view] = true
    return view
end

local MEL_GUARDED = setmetatable({}, { __mode = "k" })

local function MELTargetClass(v)
    if type(v) == "string" then return v end
    if type(v) == "table" then return rawget(v, "entclass") or rawget(v, "ClassName") end
    if real_isentity(v) and real_IsValid(v) then return v:GetClass() end
end

local function GuardMEL(mel)
    local function guard(name, check)
        local orig = rawget(mel, name)
        if type(orig) ~= "function" or MEL_GUARDED[orig] then return end
        local g = function(...)
            if G.depth > 0 then check(...) end
            return orig(...)
        end
        MEL_GUARDED[g] = true
        rawset(mel, name, g)
    end
    local function classCheck(v)
        if not IsMetroClass(MELTargetClass(v)) then error("MEL cannot target this entity class from a sandboxed addon", 4) end
    end
    local function nameCheck(fname)
        if type(fname) ~= "string" or BlockedWriteKey(fname) then error("MEL cannot inject into this function from a sandboxed addon", 4) end
    end
    guard("getEntTable", function(c) classCheck(c) end)
    for _, n in ipairs({ "InjectIntoServerFunction", "InjectIntoClientFunction", "InjectIntoSharedFunction" }) do
        guard(n, function(v, fname) classCheck(v) nameCheck(fname) end)
    end
    guard("InjectIntoSystemFunction", function(_, fname) nameCheck(fname) end)
end

function SANDBOX:BuildMELView()
    local sb = self
    local MEL_WRITABLE = { RecipeSpecific = true }
    if istable(_R.MEL) then GuardMEL(_R.MEL) end
    local overrides = {}
    overrides.DefineRecipe = function(name, trainType)
        if type(name) ~= "string" or #name > 64 or not string_match(name, "^[%w_%-%.]+$") then
            error("invalid recipe name", 2)
        end
        if #sb.recipes >= LIMITS.recipes then error("too many recipes in one addon", 2) end
        local cls
        local rt = Unwrap(trainType)
        local mel = _R.MEL
        local function knownClass(c)
            return type(c) == "string" and #c <= 64 and scripted_ents.GetStored(c) ~= nil and IsMetroClass(c)
        end
        if type(rt) == "table" then
            local parts = {}
            if #rt == 0 or #rt > 32 then error("invalid train type", 2) end
            for i = 1, #rt do
                if not knownClass(rt[i]) then error("invalid train type", 2) end
                parts[i] = rt[i]
            end
            rt = parts
            cls = table_concat(parts, "-") .. "_" .. name
        elseif type(rt) == "string" then
            local family = istable(mel.TrainFamilies) and mel.TrainFamilies[rt] ~= nil
            if not (rt == "all" or family or knownClass(rt) or (#rt <= 32 and string_match(rt, "^[%w_]+$"))) then
                error("invalid train type", 2)
            end
            cls = rt .. "_" .. name
        else
            error("invalid train type", 2)
        end
        if #cls > 160 or not string_match(cls, "^[%w_%-%.]+$") then error("invalid recipe class", 2) end
        local scope = rawget(_R, "CURRENT_SCOPE")
        if istable(mel.BaseRecipies) and istable(mel.BaseRecipies[cls]) and mel.BaseRecipies[cls][scope] ~= nil then
            error("recipe '" .. cls .. "' already exists", 2)
        end
        sb.recipes[#sb.recipes + 1] = cls
        return WrapAll(mel.DefineRecipe(name, rt))
    end
    for _, f in pairs(overrides) do SAFEFN[f] = true end
    local view = setmetatable({}, {
        __index = function(_, k)
            local mel = _R.MEL
            if not istable(mel) then return nil end
            if overrides[k] then return overrides[k] end
            local v = mel[k]
            if type(v) == "table" and not MEL_WRITABLE[k] then return Wrap(v, true) end
            return Wrap(v)
        end,
        __newindex = function(_, k, v)
            local mel = _R.MEL
            if not istable(mel) or overrides[k] or type(k) ~= "string" then error("cannot modify MEL here", 2) end
            if rawget(mel, k) ~= nil then
                error("MEL." .. k .. " cannot be replaced from a sandboxed addon", 2)
            end
            mel[k] = Unwrap(v)
        end,
        __metatable = false,
    })
    PROTECTED[view] = true
    return view
end

local function ConVarView(name)
    if type(name) ~= "string" then return nil end
    local low = string_lower(name)
    if not (string_sub(low, 1, 10) == "metrostroi" or string_sub(low, 1, 11) == "trainfitter"
        or string_sub(low, 1, 4) == "mel_" or string_sub(low, 1, 5) == "gmod_") then
        return nil
    end
    for _, w in ipairs({ "password", "passwd", "token", "secret", "apikey", "api_key", "webhook", "mysql", "database", "rcon" }) do
        if string_find(low, w, 1, true) then return nil end
    end
    local cv = GetConVar(name)
    if not cv then return nil end
    if FCVAR_PROTECTED and cv:IsFlagSet(FCVAR_PROTECTED) then return nil end
    local view = {}
    for _, m in ipairs({ "GetInt", "GetFloat", "GetBool", "GetString", "GetName", "GetDefault", "GetHelpText", "GetMin", "GetMax" }) do
        view[m] = function() return cv[m](cv) end
        SAFEFN[view[m]] = true
    end
    return view
end

function SANDBOX:BuildEnv(level)
    local sb = self
    local env = {}
    PROTECTED[env] = true
    ENVS[env] = sb

    local function lib(t)
        PROTECTED[t] = true
        for _, v in pairs(t) do
            if type(v) == "function" then SAFEFN[v] = true end
        end
        return t
    end

    env.string = lib(BuildStringLib())
    local function shallow(src)
        local t = {}
        for k, v in pairs(src) do t[k] = v end
        return t
    end
    local mathlib = shallow(real_math)
    mathlib.randomseed = nil
    env.math = lib(mathlib)
    env.bit = lib(shallow(real_bit))
    env.table = lib(BuildTableLib())
    if istable(utf8) then env.utf8 = lib(shallow(utf8)) end

    local base = {
        type = SbType, tostring = tostring, tonumber = tonumber, pairs = SbPairs, ipairs = SbIpairs, next = SbNext,
        select = select, unpack = SbUnpack, rawequal = rawequal,
        error = function(e, level)
            if type(e) == "table" and P2R[e] == nil then e = SafeError(e) end
            level = tonumber(level) or 1
            if level > 0 then level = level + 1 end
            error(e, level)
        end,
        assert = function(v, msg, ...)
            if not v then
                if msg == nil then msg = "assertion failed!" end
                if type(msg) == "table" and P2R[msg] == nil then msg = SafeError(msg) end
                error(msg, 0)
            end
            return v, msg, ...
        end,
        Format = string_format, SortedPairs = SbSortedPairs,
        SortedPairsByValue = function(t, desc)
            local items = {}
            for k, v in SbPairs(t) do items[#items + 1] = { k, v } end
            table_sort(items, function(a, b)
                if desc then return a[2] > b[2] end
                return a[2] < b[2]
            end)
            local i = 0
            return function()
                i = i + 1
                if items[i] then return items[i][1], items[i][2] end
            end
        end,
        Vector = Vector, Angle = Angle, Color = real_Color, ColorAlpha = ColorAlpha, IsColor = IsColor,
        HSVToColor = HSVToColor, Lerp = Lerp, LerpVector = LerpVector, LerpAngle = LerpAngle,
        isnumber = isnumber, isstring = isstring, isbool = isbool, isfunction = isfunction, isvector = isvector,
        isangle = isangle, ismatrix = ismatrix,
        istable = function(v) return type(v) == "table" and not IsEntityProxy(v) end,
        isentity = IsEntityProxy, IsEntity = IsEntityProxy,
        IsValid = function(v)
            if IsEntityProxy(v) then return real_IsValid(P2R[v]) end
            if P2R[v] ~= nil then return real_IsValid(P2R[v]) end
            return real_IsValid(v)
        end,
        CurTime = CurTime, RealTime = RealTime, SysTime = SysTime, FrameTime = FrameTime,
        UnPredictedCurTime = UnPredictedCurTime, SERVER = SERVER, CLIENT = CLIENT,
        print = function(...) sb:Log(...) end,
        Msg = function(...) sb:Log(...) end,
        MsgN = function(...) sb:Log(...) end,
        MsgC = function(...)
            local parts = {}
            for i = 1, select("#", ...) do
                local v = select(i, ...)
                if type(v) ~= "table" then parts[#parts + 1] = tostring(v) end
            end
            sb:Log(table_concat(parts))
        end,
        ErrorNoHalt = function(...) sb:Log("error:", ...) end,
        ErrorNoHaltWithStack = function(...) sb:Log("error:", ...) end,
        PrintTable = function(t)
            for k, v in SbPairs(t) do sb:Log(tostring(k), tostring(v)) end
        end,
        Material = function(path, params)
            path = SafeAssetPath(path)
            if not path then return nil end
            if params ~= nil and type(params) ~= "string" then params = nil end
            return Wrap(Material(path, params))
        end,
        Model = function(path)
            path = SafeAssetPath(path)
            if path and CLIENT and util and util.PrecacheModel then util.PrecacheModel(path) end
            return path
        end,
        Sound = function(path) return SafeAssetPath(path) end,
        AddCSLuaFile = function() end,
        pcall = function(f, ...)
            local res = Pack(pcall(f, ...))
            if G.killed then error(KILL, 0) end
            if not res[1] and type(res[2]) == "table" and P2R[res[2]] == nil then
                local mt = debug_getmetatable(res[2])
                if mt ~= nil and not SBMT[mt] then res[2] = Wrap(res[2]) end
            end
            return unpack(res, 1, res.n)
        end,
        xpcall = function(f, handler, ...)
            local h = handler
            if type(handler) == "function" then
                h = function(e)
                    if type(e) == "table" and P2R[e] == nil then
                        local mt = debug_getmetatable(e)
                        if mt ~= nil and not SBMT[mt] then e = Wrap(e) end
                    end
                    return handler(e)
                end
            end
            local res = Pack(xpcall(f, h, ...))
            if G.killed then error(KILL, 0) end
            return unpack(res, 1, res.n)
        end,
        setmetatable = function(t, mt)
            if type(t) ~= "table" or P2R[t] ~= nil or PROTECTED[t] then error("cannot set metatable here", 2) end
            if mt ~= nil and (type(mt) ~= "table" or P2R[mt] ~= nil or PROTECTED[mt]) then error("bad metatable", 2) end
            local cur = debug_getmetatable(t)
            if cur ~= nil and not SBMT[cur] then error("cannot replace this metatable", 2) end
            if mt ~= nil then SBMT[mt] = true end
            return setmetatable(t, mt)
        end,
        getmetatable = function(t)
            if type(t) ~= "table" or P2R[t] ~= nil or PROTECTED[t] then return nil end
            local mt = debug_getmetatable(t)
            if mt == nil or P2R[mt] ~= nil or PROTECTED[mt] then return nil end
            if not SBMT[mt] then return nil end
            return getmetatable(t)
        end,
        include = function(path) return sb:Include(path, level) end,
    }
    for k, v in pairs(base) do
        env[k] = v
        if type(v) == "function" then SAFEFN[v] = true end
    end

    if level == "data" then
        env.Metrostroi = nil
    elseif level == "skin" then
        env.Metrostroi = self:BuildMetrostroiView(METRO_FN_SKIN)
    else
        env.Metrostroi = self:BuildMetrostroiView(METRO_FN_MASK)
        env.hook = lib(self:BuildHookLib())
        env.timer = lib(self:BuildTimerLib())
        env.NULL = Wrap(NULL)
        env.Entity = function(i) return Wrap(Entity(tonumber(i) or 0)) end
        env.ents = lib({
            FindByClass  = function(c) if type(c) ~= "string" then return {} end return ProxyList(ents.FindByClass(c)) end,
            FindByModel  = function(m) if type(m) ~= "string" then return {} end return ProxyList(ents.FindByModel(m)) end,
            FindInSphere = function(p, r) return ProxyList(ents.FindInSphere(p, math_min(tonumber(r) or 0, 65536))) end,
            FindInBox    = function(a, b) return ProxyList(ents.FindInBox(a, b)) end,
            GetAll       = function() return ProxyList(ents.GetAll()) end,
            GetByIndex   = function(i) return Wrap(ents.GetByIndex(tonumber(i) or 0)) end,
            GetCount     = function() return ents.GetCount() end,
            Iterator     = function() return ListIterator(ProxyList(ents.GetAll())) end,
        })
        env.player = lib({
            GetAll         = function() return ProxyList(player.GetAll()) end,
            GetHumans      = function() return ProxyList(player.GetHumans()) end,
            GetBots        = function() return ProxyList(player.GetBots()) end,
            GetByID        = function(i) return Wrap(player.GetByID(tonumber(i) or 0)) end,
            GetBySteamID   = function(s) return Wrap(player.GetBySteamID(tostring(s))) end,
            GetBySteamID64 = function(s) return Wrap(player.GetBySteamID64(tostring(s))) end,
            GetCount       = function() return player.GetCount() end,
            Iterator       = function() return ListIterator(ProxyList(player.GetAll())) end,
        })
        local function stored(c)
            if not IsSubwayClass(c) then return nil end
            local st = scripted_ents.GetStored(c)
            if not istable(st) or not istable(st.t) then return nil end
            return { t = Wrap(st.t), Base = st.Base, isBaseType = st.isBaseType, ClassName = c }
        end
        env.scripted_ents = lib({
            GetStored = stored,
            Get       = function(c) if IsSubwayClass(c) then return Wrap(scripted_ents.Get(c), true) end end,
            GetList   = function()
                local out = {}
                for c in pairs(scripted_ents.GetList()) do
                    if IsSubwayClass(c) then out[c] = stored(c) end
                end
                return out
            end,
        })
        env.game = lib({
            SinglePlayer = game.SinglePlayer, IsDedicated = game.IsDedicated, GetMap = game.GetMap,
            MaxPlayers = game.MaxPlayers,
        })
        env.util = lib({
            PrecacheModel = function(m) m = SafeAssetPath(m) if m and CLIENT then util.PrecacheModel(m) end end,
            PrecacheSound = function(s) s = SafeAssetPath(s) if s and CLIENT then util.PrecacheSound(s) end end,
            IsValidModel = function(m) m = SafeAssetPath(m) return m ~= nil and CLIENT and util.IsValidModel(m) or false end,
        })
        env.GetConVar = ConVarView
        env.GetConVarNumber = function(n) local v = ConVarView(n) return v and v.GetFloat() or 0 end
        env.GetConVarString = function(n) local v = ConVarView(n) return v and v.GetString() or "" end
        env.SafeRemoveEntity = function(p)
            if PKIND[p] == "client" and real_IsValid(P2R[p]) then
                sb.csents[P2R[p]] = nil
                P2R[p]:Remove()
            end
        end
        if CLIENT then
            env.LocalPlayer = function() return Wrap(LocalPlayer()) end
            env.ClientsideModel = function(model, group)
                model = SafeAssetPath(model)
                if not model then return nil end
                local n = 0
                for e in pairs(sb.csents) do
                    if real_IsValid(e) then n = n + 1 else sb.csents[e] = nil end
                end
                if n >= MAX_CSENTS then error("too many clientside models", 2) end
                local e = ClientsideModel(model, tonumber(group) or RENDERGROUP_OPAQUE)
                if not real_IsValid(e) then return nil end
                sb.csents[e] = true
                SB_CSENTS[e] = true
                return Wrap(e)
            end
            env.language = lib({
                GetPhrase = function(k) return language.GetPhrase(tostring(k)) end,
            })
        end
        if self.mel and istable(_R.MEL) then
            local mel = self:BuildMELView()
            env.MEL = mel
            env.MetrostroiExtensionsLib = mel
        end
        for _, k in ipairs({ "SafeRemoveEntity", "Entity", "GetConVar", "GetConVarNumber", "GetConVarString",
                             "LocalPlayer", "ClientsideModel" }) do
            if type(env[k]) == "function" then SAFEFN[env[k]] = true end
        end
    end

    env._G = env
    setmetatable(env, {
        __index = function(_, k)
            if k == "RECIPE" and sb.mel then return Wrap(rawget(_R, "RECIPE")) end
            return nil
        end,
        __metatable = false,
    })
    return env
end

function SANDBOX:Env(level)
    local env = self.envs[level]
    if not env then
        env = self:BuildEnv(level)
        self.envs[level] = env
    end
    return env
end

local function Compile(body, name)
    if type(body) ~= "string" or body == "" then return nil, "empty file" end
    if string.byte(body, 1) == 0x1B then return nil, "lua bytecode is not allowed" end
    local fn = CompileString(body, name, false)
    if type(fn) == "string" then return nil, fn end
    if type(fn) ~= "function" then return nil, "compile failed" end
    return fn
end
SB.Compile = Compile

local function DirOf(path)
    local d = string_match(path, "^lua/(.+)/[^/]+$")
    return d or ""
end

function SANDBOX:ExecBody(path, level)
    local body = self.bodies[path]
    local fn, err = Compile(body, "@" .. path)
    if not fn then error(err, 0) end
    setfenv(fn, self:Env(level))
    if jit_off then pcall(jit_off, fn, true) end
    local prevDir = self.currentDir
    self.currentDir = DirOf(path)
    local res = Pack(pcall(fn))
    self.currentDir = prevDir
    if not res[1] then error(res[2], 0) end
    return unpack(res, 2, res.n)
end

function SANDBOX:Include(path, level)
    local p = CleanPath(path)
    if not p then error("include blocked: bad path", 2) end
    local candidates = {}
    if self.currentDir ~= "" then candidates[#candidates + 1] = "lua/" .. self.currentDir .. "/" .. p end
    candidates[#candidates + 1] = "lua/" .. p
    for i = 1, #candidates do
        local c = candidates[i]
        if self.bodies[c] then
            if self.includeDepth >= MAX_INCLUDE_DEPTH then error("include depth limit", 2) end
            self.includeDepth = self.includeDepth + 1
            local res = Pack(pcall(self.ExecBody, self, c, level))
            self.includeDepth = self.includeDepth - 1
            if not res[1] then error(res[2], 0) end
            return unpack(res, 2, res.n)
        end
    end
    if TrustedInclude(p) and file.Exists(p, "LUA") then
        return WrapAll(real_include(p))
    end
    error("include blocked: " .. p, 2)
end

function SANDBOX:RunFile(path, level)
    if self.dead then return false, "sandbox disabled" end
    if not SB.Available then return false, "sandbox unavailable (debug.sethook/setfenv missing)" end
    if type(self.bodies[path]) ~= "string" then return false, "missing file body" end
    Enter(self, self.fileBudget, false)
    local res = Pack(pcall(self.ExecBody, self, path, level))
    local killed = G.killed
    Leave()
    if not res[1] then
        return false, killed or SafeError(res[2])
    end
    return true, nil, res
end

function SANDBOX:Invoke(fn, ...)
    return self:Call(fn, ...)
end

GUARD[SANDBOX.Call] = true
GUARD[SANDBOX.CallHook] = true
GUARD[SANDBOX.RunFile] = true
GUARD[SANDBOX.ExecBody] = true
GUARD[SANDBOX.Include] = true
GUARD[SafeError] = true

if SERVER then (function()
    local ORIG = Trainfitter.SinkOriginals or {}
    Trainfitter.SinkOriginals = ORIG
    local SINK_ERR = " cannot be used while a sandboxed addon is running"

    local function GuardSink(tbl, tname, name, allow)
        if type(tbl) ~= "table" then return end
        local key = tname .. "." .. name
        local orig = ORIG[key]
        if orig == nil then
            orig = rawget(tbl, name)
            if type(orig) ~= "function" then return end
            ORIG[key] = orig
        end
        rawset(tbl, name, function(...)
            if G.depth > 0 and not (allow and allow(...)) then error(name .. SINK_ERR, 2) end
            return orig(...)
        end)
    end

    local function ReadMode(_, mode)
        return type(mode) == "string" and not string_find(mode, "[wa%+]")
    end
    local function SelectOnly(q)
        return type(q) == "string" and string_match(q, "^%s*[Ss][Ee][Ll][Ee][Cc][Tt]%s") ~= nil and not string_find(q, ";", 1, true)
    end

    for _, n in ipairs({ "RunString", "RunStringEx", "CompileString", "CompileFile", "BroadcastLua", "HTTP" }) do
        GuardSink(_R, "_G", n)
    end
    GuardSink(_R, "_G", "include", function(p) return type(p) == "string" and TrustedInclude(p) end)
    GuardSink(_R, "_G", "AddCSLuaFile", function(p) return p == nil end)
    GuardSink(_R, "_G", "RunConsoleCommand", function(cmd) return cmd == "say" end)
    GuardSink(game, "game", "ConsoleCommand")
    GuardSink(game, "game", "CleanUpMap")
    GuardSink(util, "util", "AddNetworkString")
    GuardSink(sql, "sql", "Query", SelectOnly)
    GuardSink(file, "file", "Open", ReadMode)
    for _, n in ipairs({ "Write", "Append", "Delete", "Rename" }) do GuardSink(file, "file", n) end
    local PLAYER = FindMetaTable("Player")
    for _, n in ipairs({ "SendLua", "SetUserGroup", "ConCommand", "Ban", "Kick" }) do GuardSink(PLAYER, "Player", n) end
end)() end

SB.Wrap = Wrap
SB.Unwrap = function(v) return Unwrap(v) end
SB.IsProxy = function(v) return P2R[v] ~= nil end
SB.RealOf = function(v) return P2R[v] end
SB.GuardDepth = function() return G.depth end
