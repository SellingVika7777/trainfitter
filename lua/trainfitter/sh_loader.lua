-- Trainfitter - sh_loader.lua
-- Made by SellingVika

Trainfitter = Trainfitter or {}
Trainfitter.Sandboxes = Trainfitter.Sandboxes or {}

local SB = Trainfitter.Sandbox

local function Log(color, msg)
    MsgC(color, "[Trainfitter] " .. msg .. "\n")
end

local COL_WARN = Color(255, 180, 80)
local COL_ERR  = Color(255, 120, 120)
local COL_INFO = Color(150, 220, 255)

local function SnapshotTable(t)
    local snap = {}
    if not istable(t) then return snap end
    for category, bucket in pairs(t) do
        if istable(bucket) then
            snap[category] = {}
            for name in pairs(bucket) do snap[category][name] = true end
        end
    end
    return snap
end

local function Snapshot()
    if not istable(Metrostroi) then return { skins = {}, masks = {} } end
    return { skins = SnapshotTable(Metrostroi.Skins), masks = SnapshotTable(Metrostroi.Masks) }
end

local function DiffOwned(before)
    local owned = {}
    if not istable(Metrostroi) then return owned end
    local function diff(current, prev, kind)
        if not istable(current) then return end
        for category, bucket in pairs(current) do
            if istable(bucket) then
                for name, data in pairs(bucket) do
                    if not (prev[category] and prev[category][name]) then
                        owned[#owned + 1] = {
                            kind = kind, category = tostring(category), name = tostring(name),
                            typ = istable(data) and isstring(data.typ) and data.typ or "",
                            display = istable(data) and isstring(data.name) and data.name or tostring(name),
                        }
                    end
                end
            end
        end
    end
    diff(Metrostroi.Skins, before.skins, "skin")
    diff(Metrostroi.Masks, before.masks, "mask")
    return owned
end

local function RecipeScope(path)
    local fname = string.match(path, "([^/]+)$") or ""
    local scope = string.sub(fname, 1, 2)
    if string.sub(fname, 3, 3) ~= "_" or (scope ~= "sv" and scope ~= "sh" and scope ~= "cl") then scope = "sh" end
    return scope
end

local function CleanText(s, max)
    if not isstring(s) then return "" end
    s = string.gsub(s, "[%c]", " ")
    if #s > max then s = string.sub(s, 1, max) end
    return s
end

local function ValidSpecific(v)
    if not istable(v) then return false end
    for _, item in pairs(v) do
        if not istable(item) or not isstring(item.name) then return false end
    end
    return true
end

local RECIPE_METHODS = { "Init", "BeforeInject", "InjectNeeded", "Inject", "InjectSystem", "InjectSpawner" }

local function ValidTrainType(tt)
    if isstring(tt) then
        if tt == "all" or (istable(MEL.TrainFamilies) and MEL.TrainFamilies[tt] ~= nil) then return tt end
        if #tt <= 64 and scripted_ents.GetStored(tt) ~= nil then return tt end
        if #tt <= 32 and string.match(tt, "^[%w_]+$") then return tt end
        return nil
    end
    if istable(tt) then
        local out = {}
        for i = 1, math.min(#tt, 32) do
            if not isstring(tt[i]) or #tt[i] > 64 or scripted_ents.GetStored(tt[i]) == nil then return nil end
            out[i] = tt[i]
        end
        if #out == 0 then return nil end
        return out
    end
    return nil
end

local function RegisterRecipe(sb, path, scope)
    local recipe = rawget(_G, "RECIPE")
    _G.RECIPE = nil
    if not istable(recipe) then return false, "file did not define a recipe" end
    local cls = recipe.ClassName
    local mine = false
    for _, c in ipairs(sb.recipes) do if c == cls then mine = true end end
    if not mine or not isstring(cls) or #cls > 160 or not string.match(cls, "^[%w_%-%.]+$") then
        return false, "recipe was not defined through MEL.DefineRecipe"
    end
    local trainType = ValidTrainType(recipe.TrainType)
    if not trainType then return false, "recipe has an invalid train type" end

    local frozen = {}
    for k, v in pairs(recipe) do
        if isstring(k) then frozen[k] = v end
    end
    local noop = function() end
    for _, m in ipairs(RECIPE_METHODS) do
        frozen[m] = isfunction(recipe[m]) and recipe[m] or noop
    end
    if not isfunction(recipe.InjectNeeded) then frozen.InjectNeeded = function() return true end end
    frozen.TrainType = trainType
    frozen.ClassName = cls
    frozen.Name = isstring(recipe.Name) and recipe.Name or cls
    frozen.Scope = scope
    frozen.Description = CleanText(recipe.Description or "No description", 200)
    frozen.Specific = {}
    frozen.BackportPriority = nil

    MEL.Recipes[cls] = MEL.Recipes[cls] or {}
    if MEL.Recipes[cls][scope] then return false, "recipe " .. cls .. " is already loaded" end
    MEL.Recipes[cls][scope] = frozen

    pcall(frozen.Init, frozen)
    local cvName = "metrostroi_ext_" .. cls
    if not ConVarExists(cvName) then
        CreateConVar(cvName, 1, { FCVAR_ARCHIVE, FCVAR_REPLICATED },
            "Status of Metrostroi Extensions recipe \"" .. cls .. "\": " .. frozen.Description .. ".", 0, 1)
    end
    local cv = GetConVar(cvName)
    if not cv or cv:GetBool() then
        table.insert(MEL.InjectStack, frozen)
        if istable(frozen.Specific) then
            local added = 0
            for key, value in pairs(frozen.Specific) do
                if isstring(key) and #key <= 64 and ValidSpecific(value) and added < 64 then
                    MEL.RecipeSpecific[key] = value
                    added = added + 1
                end
            end
        end
    end
    return true
end

local function MELReinject()
    if not Trainfitter.MELPresent() then return false, "MEL is not installed" end
    if MEL.FirstTimeInject then return true end
    local hooks = hook.GetTable().InitPostEntity
    local injector = hooks and hooks.MetrostroiExtensionsLibInject
    if not isfunction(injector) then return false, "this MEL version cannot hot-load recipes" end
    MEL.FunctionInjectStack = {}
    MEL.EntTables = {}
    MEL.TrainClasses = {}
    MEL.MetrostroiClasses = {}
    MEL.RandomFields = {}
    if SERVER then
        MEL.SyncTableHashed = {}
    else
        MEL.ShowHideOverrides = {}
        MEL.AnimateOverrides = {}
        MEL.AnimateValueOverrides = {}
        MEL.HidePanelOverrides = {}
        MEL.ClientPropsToReload = {}
        MEL.DecoratorCache = {}
    end
    local ok, err = pcall(injector)
    if not ok then return false, tostring(err) end
    if CLIENT then
        timer.Simple(1.5, function()
            if not istable(Metrostroi) or not istable(Metrostroi.SpawnedTrains) then return end
            for ent in pairs(Metrostroi.SpawnedTrains) do
                if IsValid(ent) then
                    ent.ClientPropsInitialized = false
                    if isfunction(ent.RemoveCSEnts) then pcall(ent.RemoveCSEnts, ent) end
                    if isfunction(ent.ClearButtons) then pcall(ent.ClearButtons, ent) end
                end
            end
        end)
    end
    return true
end
Trainfitter.MELReinject = MELReinject

local function Trim(s)
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

local LANG_MAX_TEXT, LANG_MAX_VALUE = 262144, 4096

local function OverridableKey(k)
    return string.sub(k, 1, 9) == "Entities." and string.find(k, ".Spawner.", 1, true) ~= nil
end

local function MergeLanguage(text, source)
    if not isstring(text) or #text > LANG_MAX_TEXT or not istable(Metrostroi) or not istable(Metrostroi.Languages) then return 0 end
    local added, current, ignoring = 0, nil, false
    local langs = Metrostroi.Languages
    local newKeys = {}
    for line in string.gmatch(text, "[^\n\r]+") do
        if string.find(line, "%][^\\]?#") then
            ignoring = false
        elseif not ignoring then
            if string.find(line, "[^\\]?#%[") then ignoring = true end
            local lang = string.match(Trim(line), "^%[(%w+)%]$")
            if lang then
                if #lang <= 8 then
                    current = lang
                    langs[lang] = langs[lang] or {}
                else
                    current = nil
                end
            else
                local k, v = string.match(line, "([^=]+)=([^=]+)")
                if k and v and current then
                    k, v = Trim(k), Trim(v)
                    if #k > 0 and #k <= 256 and #v <= 1024 and added < 5000
                       and (langs[current][k] == nil or OverridableKey(k)) then
                        v = string.gsub(string.gsub(v, "\\n", "\n"), "\\t", "\t")
                        langs[current][k] = v
                        newKeys[#newKeys + 1] = { current, k }
                        added = added + 1
                    end
                end
            end
        end
    end
    for _, pair in ipairs(newKeys) do
        local tbl = langs[pair[1]]
        local str = tbl[pair[2]]
        if isstring(str) then
            for _ = 1, 32 do
                local s, e = string.find(str, "@%[[^]]+%]")
                if not s then break end
                local rep = tbl[string.match(str, "@%[([^]]+)%]")]
                if not isstring(rep) or #str + #rep > LANG_MAX_VALUE then break end
                str = string.sub(str, 1, s - 1) .. rep .. string.sub(str, e + 1)
            end
            tbl[pair[2]] = str
        end
    end
    local en = langs.en
    if istable(en) then
        for _, pair in ipairs(newKeys) do
            if pair[1] == "en" then
                for code, tbl in pairs(langs) do
                    if code ~= "en" and istable(tbl) and tbl[pair[2]] == nil then tbl[pair[2]] = en[pair[2]] end
                end
            end
        end
    end
    return added
end

local function RunUnsafe(path, body)
    if Trainfitter.ShouldRejectBytecode() and string.byte(body, 1) == 0x1B then
        return false, "lua bytecode rejected"
    end
    local fn = CompileString(body, path, false)
    if not isfunction(fn) then return false, tostring(fn) end
    return pcall(fn)
end

function Trainfitter.StopSandbox(wsid)
    local sb = Trainfitter.Sandboxes[wsid]
    if sb then sb:Stop() end
end

function Trainfitter.StopAllSandboxes()
    for _, sb in pairs(Trainfitter.Sandboxes) do sb:Stop() end
end

function Trainfitter.RunAddonLua(wsid, report, opts)
    opts = opts or {}
    local summary = { executed = 0, failed = 0, skipped = 0, recipes = 0, languages = 0, errors = {} }
    local before = Snapshot()
    local unsafe = opts.unsafe == true
    local allowMasks = opts.allowMasks == true or unsafe
    local mel = opts.mel == true and Trainfitter.MELPresent()

    local old = Trainfitter.Sandboxes[wsid]
    if old then old:Stop() end
    local sb = SB.New({
        id = wsid, bodies = report.bodies, mel = mel,
        fileBudget = Trainfitter.GetSandboxInstrLimit(),
    })
    Trainfitter.Sandboxes[wsid] = sb

    local unsafeHooksBefore
    if unsafe then
        unsafeHooksBefore = {}
        for n in pairs(hook.GetTable().InitPostEntity or {}) do unsafeHooksBefore[n] = true end
    end

    local function run(path, level)
        local ok, err, res
        if unsafe and level == "mask" then
            ok, err = RunUnsafe(path, report.bodies[path])
        else
            ok, err, res = sb:RunFile(path, level)
        end
        if ok then
            summary.executed = summary.executed + 1
        else
            summary.failed = summary.failed + 1
            summary.errors[#summary.errors + 1] = path .. ": " .. tostring(err)
            Log(COL_ERR, "sandboxed " .. path .. " (" .. wsid .. ") failed: " .. tostring(err))
        end
        return ok, res
    end

    local c = report.byClass
    for _, p in ipairs(c.skin) do run(p, "skin") end

    if allowMasks then
        for _, p in ipairs(c.autorun) do run(p, "mask") end
        for _, p in ipairs(SERVER and c.autorun_sv or c.autorun_cl) do run(p, "mask") end
        for _, p in ipairs(c.mask) do run(p, "mask") end

        if #c.recipe > 0 then
            if not mel then
                summary.skipped = summary.skipped + #c.recipe
                Log(COL_WARN, wsid .. ": skipped " .. #c.recipe .. " MEL recipe(s) - MEL support is off or MEL is missing")
            else
                local prevScope = rawget(_G, "CURRENT_SCOPE")
                for _, p in ipairs(c.recipe) do
                    local scope = RecipeScope(p)
                    if (SERVER and scope == "cl") or (CLIENT and scope == "sv") then continue end
                    _G.CURRENT_SCOPE = scope
                    _G.RECIPE = nil
                    local ok = run(p, "mask")
                    if ok then
                        local rok, rerr = RegisterRecipe(sb, p, scope)
                        if rok then
                            summary.recipes = summary.recipes + 1
                        else
                            summary.errors[#summary.errors + 1] = p .. ": " .. tostring(rerr)
                            Log(COL_WARN, wsid .. ": recipe " .. p .. " not registered: " .. tostring(rerr))
                        end
                    end
                    _G.RECIPE = nil
                end
                _G.CURRENT_SCOPE = prevScope
            end
        end
    end

    if CLIENT then
        for _, p in ipairs(c.language) do
            local ok, res = run(p, "data")
            if ok and istable(res) and isstring(res[2]) then
                summary.languages = summary.languages + MergeLanguage(res[2], p)
            end
        end
    end

    sb:FireLateInit()

    if unsafe then
        for name, fn in pairs(hook.GetTable().InitPostEntity or {}) do
            if not unsafeHooksBefore[name] and isfunction(fn) then
                local ok, err = pcall(fn)
                if not ok then Log(COL_WARN, "late InitPostEntity hook '" .. tostring(name) .. "' failed: " .. tostring(err)) end
            end
        end
    end

    if summary.recipes > 0 then
        local ok, err = MELReinject()
        if not ok then Log(COL_WARN, wsid .. ": MEL re-inject failed: " .. tostring(err)) end
    end

    if CLIENT and summary.languages > 0 and istable(Metrostroi) and isfunction(Metrostroi.LoadLanguage) and summary.recipes == 0 then
        pcall(Metrostroi.LoadLanguage, Metrostroi.ChoosedLang)
    end

    summary.owned = DiffOwned(before)
    Log(COL_INFO, string.format("%s: %d script(s) ran in sandbox, %d failed, %d recipe(s), %d phrase(s), %d new skin(s)",
        wsid, summary.executed, summary.failed, summary.recipes, summary.languages, #summary.owned))
    return summary
end
