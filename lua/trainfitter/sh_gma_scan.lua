--# Trainfitter - sh_gma_scan.lua
--# Made by SellingVika
--# вся защита от мудаков живёт тут разбор GMA руками валидация песочница никаких net file.Write ents.Create внутри песочницы попадос кто-то хочет насрать через скин пусть пробьёт всё подряд удачи

Trainfitter = Trainfitter or {}

--# сюда класть нельзя ничего вообще нашёл что-то из списка в GMA - аддон в топку без обсуждения никаких lua/entities lua/weapons gamemodes bin data и всё такое
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

--# обычный контент текстурки модельки звуки всё это ок пускаем без вопросов
local DATA_PREFIXES = {
    "materials/",
    "models/",
    "sound/",
    "resource/",
    "scripts/",
}

--# куда вообще можно lua класть в safe-режиме ТОЛЬКО скины маски autorun пульты переехали в full-режим (см ниже) потому что они содержат настоящий код а не данные
local LUA_ALLOWED_PREFIXES = {
    "lua/metrostroi/skins/",
}

--# дополнительные lua-пути только в full-режиме тут живут маски пульты custom SENT кастомные effects-ы и прочее тяжёлое выполняются БЕЗ песочницы потому что SENT в песочнице не живёт masks/ первым чтоб классификация isMaskLua сработала
local LUA_ALLOWED_PREFIXES_FULL = {
    "lua/metrostroi/masks/",
    "lua/metrostroi/",
    "lua/autorun/",
    "lua/entities/",
    "lua/weapons/",
    "lua/effects/",
}

--# префиксы которые в safe считаются опасными а в full ок используется в is_dangerous_path чтоб разные пользователи могли решать разные сценарии
local FULL_MODE_EXEMPT = {
    ["lua/weapons/"]  = true,
    ["lua/effects/"]  = true,
    ["lua/entities/"] = true,
}

--# мета-файлы которые ок видеть в корне аддона типа README addon.json и прочая бюрократия
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

--# расширения которые мы вообще согласны увидеть чужие .exe .dll .bat .so .py - соси не пускаем
local ALLOWED_EXTS = {
    lua = true,
    vmt = true, vtf = true, png = true, jpg = true, jpeg = true,
    mdl = true, vvd = true, phy = true, vtx = true, ani = true,
    wav = true, mp3 = true, ogg = true,
    ttf = true, otf = true,
    txt = true, md = true, json = true, properties = true,
    pcf = true,
}

--# жёсткие лимиты которые конварами НЕ настраиваются нахрена они тогда лимиты если их каждый сможет крутануть
local MAX_FILE_SIZE          = 256  * 1024 * 1024
local MAX_TOTAL_UNCOMPRESSED = 1024 * 1024 * 1024
local MAX_TOTAL_FILES        = 4096
local MAX_LUA_FILES          = 256
local MAX_TOTAL_LUA_BYTES    = 4 * 1024 * 1024

--# мягкий лимит на размер одного addon-lua файла берётся из конвара trainfitter_max_lua_kb (дефолт 64 кб) если у кого-то скин жирнее пусть админ поднимет clamped 1-1024 кб чтобы дебилы не прописали 999999 и не словили OOM
function Trainfitter.GetMaxLuaSize()
    local cv = GetConVar("trainfitter_max_lua_kb")
    local kb = cv and cv:GetInt() or 64
    if kb < 1    then kb = 1    end
    if kb > 1024 then kb = 1024 end
    return kb * 1024
end

--# лимит инструкций для песочницы в миллионах из конвара trainfitter_sandbox_instr_m (дефолт 100) бесконечные циклы маски умирают пока не достигнут clamped 1-10000 миллионов
function Trainfitter.GetSandboxInstrLimit()
    local cv = GetConVar("trainfitter_sandbox_instr_m")
    local m = cv and cv:GetInt() or 100
    if m < 1     then m = 1     end
    if m > 10000 then m = 10000 end
    return m * 1000000
end

--# режем ли мы lua-bytecode дефолт да (безопасно) можно отключить через trainfitter_reject_bytecode 0 если ты ОЧЕНЬ доверяешь источникам и тебе зачем-то нужен прекомпил
function Trainfitter.ShouldRejectBytecode()
    local cv = GetConVar("trainfitter_reject_bytecode")
    return cv == nil or cv:GetBool() ~= false
end

--# базовая проверка тела lua перед компиляцией не пустой не огромный без NUL-байтов в начале (NUL обычно намекает что это бинарь а не код)
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

--# скины и маски валидируются одинаково но оставляю две функции мало ли захочется развести правила дешевле менять одну функцию
function Trainfitter.ValidateSkinLua(content, displayPath)
    return PreflightCheck(content, displayPath)
end

function Trainfitter.ValidateMaskLua(content, displayPath)
    return PreflightCheck(content, displayPath)
end

--# поверхностная копия таблицы нужна чтоб песочница получила свою table string math bit мутирует у себя пофиг в глобал ничего не утекает
local function ShallowCopy(t)
    if not istable(t) then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = v end
    return r
end

--# string без dump потому что string.dump умеет дампить байткод через него можно вытащить внутренности замыкания в песочнице этот атракцион не нужен ну нахер
local function SafeStringLib()
    local s = ShallowCopy(string)
    s.dump = nil
    return s
end


--# whitelist методов entity которые отдаём наружу через прокси только read-only геттеры никаких Remove/SetPos/ConCommand/SendLua кто попытается ent:DoBadThing() из песочницы получит nil и errror
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

--# заворачиваем настоящую entity в безобидную табличку с whitelist-методами маска получает прокси и колон-вызов чего-нибудь весёлого типа ent:Kick() ловит nil потому что Kick в whitelist нет no vlom hack побег через __index закрыт намертво
local function MakeEntProxy(ent)
    if not isentity(ent) then return ent end
    if not IsValid(ent) then
        --# невалидная entity тоже должна как-то отвечать иначе чужой код упадёт на простой проверке IsValid
        return {
            IsValid  = function() return false end,
            EntIndex = function() return 0 end,
        }
    end
    local p = {}
    for _, name in ipairs(SAFE_ENT_METHODS) do
        local fn = ent[name]
        if isfunction(fn) then
            --# замыкаем настоящую entity в closure снаружи её не достать никак чисто кошмарик
            p[name] = function(_, ...) return fn(ent, ...) end
        end
    end
    return p
end

--# пачка entity - пачка прокси тривиально
local function ProxyList(list)
    if not istable(list) then return {} end
    local out = {}
    for _, e in ipairs(list) do
        local p = MakeEntProxy(e)
        if p then out[#out + 1] = p end
    end
    return out
end

--# если среди args есть entity заменяем на прокси нужно для хук-коллбэков движок зовёт hook с настоящими entity мы их перехватываем ещё ДО того как они доедут до кода маски
local function ProxyArgs(...)
    local n = select("#", ...)
    if n == 0 then return end
    local args = {...}
    for i = 1, n do
        if isentity(args[i]) then args[i] = MakeEntProxy(args[i]) end
    end
    return unpack(args, 1, n)
end

--# обёртка над коллбэком проксирует args перед вызовом
local function ProxyCallback(fn)
    if not isfunction(fn) then return fn end
    return function(...) return fn(ProxyArgs(...)) end
end

--# поверхностная копия таблицы где все функции заменены на ProxyCallback юзается для масок чтоб их Render/Think получали проксированные args
local function ProxyTableFunctions(t)
    if not istable(t) then return t end
    local r = {}
    for k, v in pairs(t) do
        if isfunction(v) then r[k] = ProxyCallback(v) else r[k] = v end
    end
    return r
end

--# что из Metrostroi отдать в песочницу скины - чистая дата идут как есть проксировать там нечего маски у них Render(train)/Think(train) которые движок зовёт с реальной entity значит args надо проксировать на входе
local function MakeMetrostroiView()
    if not istable(Metrostroi) then return {} end

    --# Viktoooor обёртка для масочных регистраторов заворачивает переданную таблицу так чтоб её функции получали прокси-args
    local function Viktoooor(fn)
        if not isfunction(fn) then return nil end
        return function(c, t)
            return fn(c, ProxyTableFunctions(t))
        end
    end

    --# OkDa тут вообще не паримся тупо пускаем как есть скинам обёртка нахуй не нужна только мешает регистрации в меню
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

--# хуки с неймспейсом чтобы маска Vasya не могла снять хук маски Petya или какой-нибудь системный префикс уникален на каждый запуск ExecSandboxed
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
        --# hook.Run/Call/GetTable намеренно НЕ даны из них можно стрельнуть в любой системный хук с любыми аргументами типа hook.Run("PlayerSay", admin, "/give me all") нет спасибо
    }
end

--# таймеры с тем же неймспейсом чтоб не конфликтовать по именам разные маски не пересекаются
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

--# уникальный префикс из пути файла для namespace хуков/таймеров всё кроме безопасных символов в подчёркивание потому что не доверяю
local function MakePathPrefix(path)
    local s = tostring(path or "anon")
    s = string.gsub(s, "[^%w_/.%-]", "_")
    return "trainfitter_sb:" .. s
end

--# Material с защитой от path traversal никаких .. : абсолютных путей иначе можно вытащить произвольный материал с диска через хитрожопый Material с /etc или похожее
local function SafeMaterial(path, params)
    if not isstring(path) then return nil end
    if string.find(path, "..", 1, true)  then return nil end
    if string.find(path, ":",  1, true)  then return nil end
    if string.sub(path, 1, 1) == "/"     then return nil end
    if string.sub(path, 1, 1) == "\\"    then return nil end
    return Material(path, params)
end

--# песочница СКИНА минимум API только то что нужно чтоб зарегать данные net/file/http/ents/player/hook/timer не пускаем это для масок
local function BuildSkinSandbox()
    local sb = {
        Metrostroi = MakeMetrostroiView(),

        --# конструкторы базовых типов безопасно просто создают объекты
        Color  = Color,
        Vector = Vector,
        Angle  = Angle,

        --# stdlib с изолированными копиями мутации остаются у скина string без dump чтоб байткод не утёк
        table  = ShallowCopy(table),
        string = SafeStringLib(),
        math   = ShallowCopy(math),
        bit    = ShallowCopy(bit),

        --# проверки типов вреда никакого
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

        Material     = SafeMaterial,    --# обёрнутый не голый чтоб через .. не вылезли
        AddCSLuaFile = function() end,  --# маске нечего синкать клиенту
        print        = function() end,  --# молчим нечего консоль засирать
    }
    sb._G = sb
    return sb
end

--# песочница МАСКИ то же что у скина плюс entity-API через прокси плюс хуки/таймеры с неймспейсом плюс print маски это поведение скины это просто данные разница принципиальная
local function BuildMaskSandbox(prefix)
    local sb = BuildSkinSandbox()

    sb.hook  = MakeNamespacedHook(prefix)
    sb.timer = MakeNamespacedTimer(prefix)

    --# FindMetaTable историческая дыра уровня "взял весь мета-стол - дёргай любой метод" оставляем РОВНО одну функцию из Entity-меты GetClass и больше нихуя хочется других методов иди через прокси там есть whitelist
    sb.FindMetaTable = function(name)
        if name ~= "Entity" then return nil end
        local mt = FindMetaTable("Entity")
        if not mt or not isfunction(mt.GetClass) then return nil end
        return { GetClass = mt.GetClass }
    end

    --# Entity(idx) отдаём прокси а не настоящую entity
    sb.Entity = function(idx) return MakeEntProxy(Entity(idx)) end

    --# ents всё через прокси никаких настоящих entity наружу
    sb.ents = {
        FindByClass  = function(c)    return ProxyList(ents.FindByClass(c)) end,
        FindInSphere = function(p, r) return ProxyList(ents.FindInSphere(p, r)) end,
        FindInBox    = function(a, b) return ProxyList(ents.FindInBox(a, b)) end,
        GetAll       = function()     return ProxyList(ents.GetAll()) end,
        GetByIndex   = function(i)    return MakeEntProxy(ents.GetByIndex(i)) end,
        GetCount     = ents.GetCount,
    }

    --# player то же самое иначе самое смешное было бы дать настоящий Player тогда :ConCommand("rcon ...") / :Kick() / :SendLua("ply.Health=0") в одну строку мдааа нет
    sb.player = {
        GetAll         = function()  return ProxyList(player.GetAll()) end,
        GetHumans      = function()  return ProxyList(player.GetHumans()) end,
        GetBots        = function()  return ProxyList(player.GetBots()) end,
        GetByID        = function(i) return MakeEntProxy(player.GetByID(i)) end,
        GetBySteamID   = function(s) return MakeEntProxy(player.GetBySteamID(s)) end,
        GetBySteamID64 = function(s) return MakeEntProxy(player.GetBySteamID64(s)) end,
        GetCount       = player.GetCount,
    }

    --# принтеры пусть пишут в консоль безвредно админ хоть видит логи маски
    sb.print      = print
    sb.MsgC       = MsgC
    sb.Msg        = Msg
    sb.MsgN       = MsgN
    sb.PrintTable = PrintTable

    sb._G = sb
    return sb
end

--# главный вход скомпилировать lua-строку и запустить в нашей песочнице kind определяет какую (skin / mask)
function Trainfitter.ExecSandboxed(content, path, kind)
    if not isstring(content) or #content == 0 then
        return false, "empty content"
    end

    --# lua-байткод всегда начинается с \27 (ESC) текстовый исходник никогда байткод опасен потому что обходит парсер и любую защиту через regex по дефолту режем но админ может разрешить через trainfitter_reject_bytecode 0 если очень хочется
    if Trainfitter.ShouldRejectBytecode() and string.byte(content, 1) == 0x1B then
        return false, "lua bytecode rejected (set trainfitter_reject_bytecode 0 to allow)"
    end

    local fn, compileErr = CompileString(content, path, false)
    if isstring(fn) then return false, "compile: " .. fn end
    if not isfunction(fn) then return false, "compile returned non-function" end

    --# если setfenv почему-то отсутствует ОТКАЗ без него мы не подменим env и код выполнится в глобальном _G это fail-open такое разрешать нельзя
    if not isfunction(setfenv) then
        return false, "setfenv unavailable - refusing to execute without sandbox"
    end

    local prefix = MakePathPrefix(path)
    local sb = (kind == "mask") and BuildMaskSandbox(prefix) or BuildSkinSandbox()
    local setOk, setErr = pcall(setfenv, fn, sb)
    if not setOk then return false, "setfenv failed: " .. tostring(setErr) end

    --# hook на счётчик инструкций после лимита (по дефолту 100M, настраивается trainfitter_sandbox_instr_m) кидает error pcall его ловит while true do end умирает за пару сек
    local hookSet = false
    if debug and isfunction(debug.sethook) then
        local limit = Trainfitter.GetSandboxInstrLimit()
        debug.sethook(function() error("instruction limit exceeded", 2) end, "", limit)
        hookSet = true
    end

    local ok, runErr = pcall(fn)

    --# снять hook ОБЯЗАТЕЛЬНО иначе он висит на main thread и убьёт первое что попадётся а это будет какой-нибудь невинный кусок движка лол
    if hookSet then debug.sethook() end

    if not ok then return false, "runtime: " .. tostring(runErr) end
    return true
end

--# ============================================================================
--# GMA-парсер вскрываем .gma бинарник руками не через file.Read("...","GAME") на каждый lua-файл отдельно потому что file.Read может быть перехвачен каким-нибудь анти-чит-хуком на file.Open (привет lenofag/sv_vzlom.lua) и подсунуть мусор качаем напрямую из бинарника и кешируем тела на потом
--# ============================================================================

--# чтение C-строки (zero-terminated) сначала пробуем штатный ReadString если не вышло побайтово до \0 или лимита
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

--# little-endian u32 - number lua в u32-битопы нативно не умеет поэтому собираем умножением
local function read_u32(f)
    local b = f:Read(4)
    if not b or #b < 4 then return 0 end
    return string.byte(b, 1)
         + string.byte(b, 2) * 0x100
         + string.byte(b, 3) * 0x10000
         + string.byte(b, 4) * 0x1000000
end

--# u64 - double до 2^53 точно дальше лоси но файлы такого размера всё равно отвергаем по MAX_FILE_SIZE так что похуй
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

--# это не наш путь чек если что-то из DANGEROUS_PREFIXES - возвращаем сам префикс для лога плюс path traversal .. \0 : лидирующие слеши нахер в full-режиме часть префиксов (lua/entities lua/weapons lua/effects) становится разрешённой потому что пульты и SENT там живут
local function is_dangerous_path(p, fullLua)
    for _, pref in ipairs(DANGEROUS_PREFIXES) do
        if string.sub(p, 1, #pref) == pref then
            if fullLua and FULL_MODE_EXEMPT[pref] then
                --# в full-режиме это ок пропускаем дальше
            else
                return pref
            end
        end
    end
    if string.find(p, "..", 1, true)   then return ".." end
    if string.find(p, "\0",   1, true) then return "\\0" end
    if string.find(p, ":",    1, true) then return ":"  end
    if string.sub(p, 1, 1) == "/"      then return "/"  end
    if string.sub(p, 1, 1) == "\\"     then return "\\" end
    return nil
end

--# это lua и при этом в разрешённой папке если да возвращаем какой именно префикс совпал для классификации потом в full-режиме добавляются LUA_ALLOWED_PREFIXES_FULL (metrostroi/ entities/ etc)
local function is_lua_addon_path(p, fullLua)
    for _, pref in ipairs(LUA_ALLOWED_PREFIXES) do
        if string.sub(p, 1, #pref) == pref then return pref end
    end
    if fullLua then
        for _, pref in ipairs(LUA_ALLOWED_PREFIXES_FULL) do
            if string.sub(p, 1, #pref) == pref then return pref end
        end
    end
    return nil
end

--# путь вообще разрешён для lua только LUA_ALLOWED_PREFIXES (+ FULL если включено) для остального материалы/модели/звуки либо exact-match по ALLOWED_EXACT (типа readme.md в корне)
local function is_allowed_path(p, is_lua, fullLua)
    if ALLOWED_EXACT[p] then return true end

    if is_lua then
        return is_lua_addon_path(p, fullLua) ~= nil
    end

    for _, pref in ipairs(DATA_PREFIXES) do
        if string.sub(p, 1, #pref) == pref then return true end
    end
    return false
end

--# расширение файла без точки пусто если расширения нет вообще
local function get_ext(p)
    local dot = string.find(p, "%.[^%./]+$")
    if not dot then return "" end
    return string.sub(p, dot + 1)
end

--# ScanGMA главная проверка перед маунтом парсит .gma руками бежит по индексу валидирует пути/расширения/размеры читает тела lua-файлов и тоже их валидирует всё прошло - отдаёт список файлов плюс словарь lua-тел чтоб потом не перечитывать через возможно-захуканный file.Read
function Trainfitter.ScanGMA(gmapath)
    if not isstring(gmapath) or gmapath == "" then
        return false, "no path", nil
    end

    --# в full-lua режиме пускаем больше путей и потом исполняем их без песочницы решение принимаем один раз на старте скана чтоб не менялось в процессе
    local fullLua = Trainfitter.ShouldAllowFullLua and Trainfitter.ShouldAllowFullLua() or false

    --# снимаем лимит на размер lua один раз тоже чтоб не плавал в процессе скана
    local maxLuaSize = Trainfitter.GetMaxLuaSize()

    local f = file.Open(gmapath, "rb", "GAME")
    if not f then
        --# на каких-то путях file.Open отдаёт nil (например ugc handle) это не ошибка GMA просто скан невозможен помечаем как пропустили
        return true, "ugc handle (skipped)", nil
    end

    --# магия GMA "GMAD" в начале нет магии не наш клиент
    local magic = f:Read(4)
    if magic ~= "GMAD" then
        f:Close()
        return false, "not a gma (magic=" .. tostring(magic) .. ")", nil
    end

    --# версия до 3 знаем всё что выше пожалуйста не лезь мало ли
    local version = f:Read(1)
    version = version and string.byte(version) or 0
    if version > 3 then
        f:Close()
        return false, "unsupported gma version " .. version, nil
    end

    --# SteamID u64 + timestamp u64 пропускаем нам неинтересно
    f:Read(8); f:Read(8)

    --# в v2+ тут список required-аддонов (c-строки до пустой) скипаем все нам они не нужны
    if version >= 2 then
        for _ = 1, 1024 do
            local s = read_cstr(f, 128)
            if not s or s == "" then break end
        end
    end

    --# имя/описание/автор тоже скипаем
    read_cstr(f, 512)
    read_cstr(f, 4096)
    read_cstr(f, 256)

    --# addon version скипаем
    f:Read(4)

    --# дальше идёт индекс файлов {u32 filenum, cstr name, u64 size, u32 crc} заканчивается когда filenum == 0

    local files            = {}
    local entries          = {}
    local luaBodies        = {} --# сюда складываем тела .lua чтоб не перечитывать потом
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
        f:Read(4) --# crc не проверяем gmod сам это делает на маунте

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

        --# путь подозрительный сразу нахер весь GMA если safe-режим и путь был бы ок в full-режиме подсказываем какой конвар включить
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

        --# расширение в whitelist нет пиздуй отсюда
        local ext = string.lower(get_ext(lower))
        if ext == "" or not ALLOWED_EXTS[ext] then
            f:Close()
            return false,
                "disallowed file type: '" .. name .. "' (." .. ext .. ")",
                files
        end

        --# классификация lua / addon-lua / mask-lua / autorun-lua
        local isLua       = (ext == "lua")
        local addonPref   = isLua and is_lua_addon_path(lower, fullLua) or nil
        local isAddonLua  = addonPref ~= nil
        local isMaskLua   = addonPref == "lua/metrostroi/masks/"
        local isAutorunLua = addonPref == "lua/autorun/"

        --# не-lua и не в разрешённой data-папке отказ
        if not isLua and not is_allowed_path(lower, false, fullLua) then
            f:Close()
            return false,
                "file in unsupported folder: '" .. name ..
                "' - only materials/, models/, sound/, resource/, scripts/ allowed",
                files
        end

        --# lua в неразрешённом пути в safe-режиме это обычно значит "аддон содержит маски/пульты" даём явную подсказку какой конвар включить чтоб это поставить
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
            --# tight cap на размер addon-lua настраивается конваром (дефолт 64 КБ)
            if isAddonLua and size > maxLuaSize then
                f:Close()
                return false, string.format(
                    "addon lua file too large: %s (%d B, max %d B - raise trainfitter_max_lua_kb if you trust the source)",
                    name, size, maxLuaSize), files
            end
        end

        --# считаем счётчики чтоб потом проверить "это вообще metrostroi-аддон или нет" в full-режиме autorun lua тоже считаем как контент иначе чистые пульты с инитом только в lua/autorun/server/ не прошли бы marker-проверку
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

    --# если в GMA нет ни одного metrostroi-признака это вообще не наш аддон не маунтим до свидания
    if skinFileCount == 0 and maskFileCount == 0 and metroAssetCount == 0 then
        f:Close()
        return false,
            "not a Metrostroi addon (no lua/metrostroi/skins/*.lua, "
            .. "no lua/metrostroi/masks/*.lua, and no materials/models/sound "
            .. "with 'metrostroi' in path; materials=" .. materialsCount .. ")",
            files
    end

    --# второй проход читаем тела lua валидируем и кешируем остальное скипаем (через Seek или ручным чтением)
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
            --# тело валидно кешим потом ExecSandboxed возьмёт его отсюда а не через file.Read
            luaBodies[string.lower(e.name)] = body
        else
            if e.size > 0 then
                --# не-lua просто скипаем сначала пытаемся Seek (быстро) если не получилось читаем чанками и выкидываем
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

--# клиентский convar игрок может выключить у себя сканирование на свой риск конечно
if CLIENT then
    CreateClientConVar("trainfitter_gma_scan", "1", true, false,
        "1 = scan GMA before mounting (guards against non-skin addons).")
end

--# серверные convars управляющие защитой каждый можно крутить отдельно чтоб владелец сервера сам решал что ему важнее (безопасность или гибкость)
if SERVER then
    --# главные сторожа GMA-скана PROTECTED чтоб клиент не дёрнул их через rcon-suggest
    CreateConVar("trainfitter_server_gma_scan", "1",
        { FCVAR_ARCHIVE, FCVAR_PROTECTED },
        "1 = server-side strict Metrostroi-only GMA validation (keep enabled).")

    CreateConVar("trainfitter_content_scan", "1",
        { FCVAR_ARCHIVE, FCVAR_PROTECTED },
        "1 = runtime content scan on every .lua file before execution.")

    --# ОПАСНО включает full-Lua режим когда включено можно ставить пульты custom SENT расширенные маски кастомные effects-ы всё что содержит реальный код эти файлы выполняются БЕЗ ПЕСОЧНИЦЫ с полными правами сервера включать ТОЛЬКО если ты доверяешь ВСЕМ кто может ставить аддоны лучше комбинировать с trainfitter_use_whitelist 1 и trainfitter_require_admin 1 REPLICATED чтоб клиентский ScanGMA знал решение сервера и не резал mask/pult сам (PROTECTED не ставим оно конфликтует с REPLICATED по смыслу одно прячет от клиента второе шлёт ему значение свитча 0/1 клиенту знать безопасно)
    CreateConVar("trainfitter_allow_full_lua", "0",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED },
        "DANGEROUS: 1 = allow pults / custom SENT / full-Lua addons. " ..
        "These run UNSANDBOXED with full server permissions. " ..
        "Only enable if you fully trust everyone who can install addons.")

    --# гибкие лимиты все REPLICATED чтоб клиент тоже считал одинаково
    --# trainfitter_max_lua_kb максимальный размер одного addon-lua файла в КБ дефолт 64 если твой скин жирнее (бывает) подними диапазон 1-1024 (1 МБ максимум)
    CreateConVar("trainfitter_max_lua_kb", "64",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED },
        "Max size of one addon-lua file in KB. Default 64. Clamped to 1-1024. " ..
        "Raise if your masks are bigger than 64KB (rare but happens).")

    --# trainfitter_sandbox_instr_m лимит инструкций для песочницы в миллионах дефолт 100 (тысячные доли секунды убегания) подними если у тебя тяжёлая инициализация маски с процедурной генерацией текстур диапазон 1-10000
    CreateConVar("trainfitter_sandbox_instr_m", "100",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED },
        "Max sandbox instruction count in millions. Default 100. Clamped to 1-10000. " ..
        "Raise if heavy masks time out during init.")

    --# trainfitter_reject_bytecode 1 (дефолт) = режем lua-байткод 0 = пускаем байткод дыра в любую щель но если ты ВОТ ПРЯМ доверяешь источникам и тебе зачем-то нужен прекомпил - можно
    CreateConVar("trainfitter_reject_bytecode", "1",
        { FCVAR_ARCHIVE, FCVAR_REPLICATED },
        "1 = reject Lua bytecode (default, safe). 0 = allow it (DANGEROUS).")
end

--# сканировать ли GMA вообще дефолт да и не надо ничего трогать
function Trainfitter.ShouldScanGMA()
    if SERVER then
        local cv = GetConVar("trainfitter_server_gma_scan")
        return cv == nil or cv:GetBool() ~= false
    end
    local cv = GetConVar("trainfitter_gma_scan")
    return cv and cv:GetBool() ~= false
end

--# сканировать ли отдельный .lua перед компиляцией на клиенте всегда true и точка
function Trainfitter.ShouldContentScan()
    if SERVER then
        local cv = GetConVar("trainfitter_content_scan")
        return cv == nil or cv:GetBool() ~= false
    end
    return true
end

--# full-lua режим (см конвар trainfitter_allow_full_lua) работает одинаково на сервере и клиенте (convar реплицируется) если включено ScanGMA пускает больше lua-путей (маски пульты SENT) а ServerExecuteSkinFiles исполняет эти расширенные пути БЕЗ ПЕСОЧНИЦЫ на клиенте то же самое клиентский ScanGMA не отвергает то что сервер принял
function Trainfitter.ShouldAllowFullLua()
    local cv = GetConVar("trainfitter_allow_full_lua")
    return cv ~= nil and cv:GetBool() == true
end
