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

local FORBIDDEN_PATTERNS = {
    { pat = "RunString",                 label = "RunString"               },
    { pat = "RunStringEx",               label = "RunStringEx"             },
    { pat = "CompileString",             label = "CompileString"           },
    { pat = "CompileFile",               label = "CompileFile"             },
    { pat = "loadstring",                label = "loadstring"              },
    { pat = "loadfile",                  label = "loadfile"                },
    { pat = "dofile",                    label = "dofile"                  },
    { pat = "dostring",                  label = "dostring"                },
    { pat = "setfenv",                   label = "setfenv"                 },
    { pat = "getfenv",                   label = "getfenv"                 },
    { pat = "%f[%w]load%s*%(",           label = "load()"                  },
    { pat = "%f[%w]xpcall%s*%(",         label = "xpcall()"                },
    { pat = "string%.dump",              label = "string.dump"             },

    { pat = "package%.loaded",           label = "package.loaded"          },
    { pat = "package%.preload",          label = "package.preload"         },
    { pat = "package%.loadlib",          label = "package.loadlib"         },
    { pat = "package%.loaders",          label = "package.loaders"         },
    { pat = "package%.searchers",        label = "package.searchers"       },
    { pat = "package%.cpath",            label = "package.cpath"           },
    { pat = "package%.path",             label = "package.path"            },
    { pat = "package%.seeall",           label = "package.seeall"          },
    { pat = "%f[%w]package%.",           label = "package.*"               },

    { pat = "http%.",                    label = "http.*"                  },
    { pat = "%f[%w_]http%f[^%w_]",       label = "http (namespace ref)"    },
    { pat = "HTTP%s*%(",                 label = "HTTP()"                  },
    { pat = "%f[%a]socket%.",            label = "socket.*"                },
    { pat = "%f[%w_]socket%f[^%w_]",     label = "socket (namespace ref)"  },

    { pat = "ffi%.",                     label = "ffi.*"                   },
    { pat = "%f[%w_]ffi%f[^%w_]",        label = "ffi (LuaJIT FFI)"        },

    { pat = "file%.Write",               label = "file.Write"              },
    { pat = "file%.Append",              label = "file.Append"             },
    { pat = "file%.Delete",              label = "file.Delete"             },
    { pat = "file%.CreateDir",           label = "file.CreateDir"          },
    { pat = "file%.Rename",              label = "file.Rename"             },
    { pat = "%f[%w_]sql%f[^%w_]",        label = "sql (namespace ref)"     },
    { pat = "sql%.",                     label = "sql.*"                   },
    { pat = "cookie%.Set",               label = "cookie.Set"              },
    { pat = "%f[%w_]cookie%f[^%w_]",     label = "cookie (persistence)"    },
    { pat = "util%.SetPData",            label = "util.SetPData"           },
    { pat = ":SetPData",                 label = ":SetPData"               },
    { pat = "%f[%w_]io%f[^%w_]",         label = "io (stdlib I/O)"         },
    { pat = "%f[%w_]os%f[^%w_]",         label = "os (stdlib process)"     },

    { pat = "RunConsoleCommand",         label = "RunConsoleCommand"       },
    { pat = "game%.ConsoleCommand",      label = "game.ConsoleCommand"     },
    { pat = "cvars%.",                   label = "cvars.*"                 },
    { pat = "CreateConVar",              label = "CreateConVar"            },
    { pat = "CreateClientConVar",        label = "CreateClientConVar"      },
    { pat = "os%.execute",               label = "os.execute"              },
    { pat = "os%.exit",                  label = "os.exit"                 },
    { pat = "os%.remove",                label = "os.remove"               },
    { pat = "os%.rename",                label = "os.rename"               },
    { pat = "os%.getenv",                label = "os.getenv"               },
    { pat = "collectgarbage",            label = "collectgarbage"          },

    { pat = "concommand%.Add",           label = "concommand.Add"          },
    { pat = "concommand%.Run",           label = "concommand.Run"          },
    { pat = "%f[%w_]concommand%f[^%w_]", label = "concommand (alias)"      },
    { pat = "hook%.Add",                 label = "hook.Add"                },
    { pat = "hook%.Remove",              label = "hook.Remove"             },
    { pat = "hook%.Run",                 label = "hook.Run"                },
    { pat = "hook%.Call",                label = "hook.Call"               },
    { pat = "hook%.GetTable",            label = "hook.GetTable"           },
    { pat = "%f[%w_]hook%f[^%w_]",       label = "hook (alias)"            },
    { pat = "timer%.Create",             label = "timer.Create"            },
    { pat = "timer%.Simple",             label = "timer.Simple"            },
    { pat = "timer%.Adjust",             label = "timer.Adjust"            },
    { pat = "%f[%w_]timer%f[^%w_]",      label = "timer (alias)"           },
    { pat = "net%.Start",                label = "net.Start"               },
    { pat = "net%.Send",                 label = "net.Send"                },
    { pat = "net%.Broadcast",            label = "net.Broadcast"           },
    { pat = "net%.Receive",              label = "net.Receive"             },
    { pat = "net%.WriteData",            label = "net.WriteData"           },
    { pat = "%f[%w_]net%f[^%w_]",        label = "net (alias)"             },
    { pat = "util%.AddNetworkString",    label = "util.AddNetworkString"   },
    { pat = "%f[%w_]coroutine%f[^%w_]",  label = "coroutine (uncommon)"    },
    { pat = "coroutine%.",               label = "coroutine.*"             },
    { pat = "usermessage%.",             label = "usermessage.*"           },
    { pat = "%f[%w]umsg%.",              label = "umsg.*"                  },
    { pat = "datastream%.",              label = "datastream.*"            },
    { pat = "gamemode%.Call",            label = "gamemode.Call"           },
    { pat = "gamemode%.Register",        label = "gamemode.Register"       },
    { pat = "gmod%.GetGamemode",         label = "gmod.GetGamemode"        },

    { pat = "ents%.Create",              label = "ents.Create"             },
    { pat = "ents%.FindByClass",         label = "ents.FindByClass"        },
    { pat = "ents%.FindInSphere",        label = "ents.FindInSphere"       },
    { pat = "scripted_ents%.",           label = "scripted_ents.*"         },
    { pat = "weapons%.Register",         label = "weapons.Register"        },
    { pat = "%f[%w]list%.Add",           label = "list.Add"                },
    { pat = "%f[%w]list%.Set",           label = "list.Set"                },
    { pat = "properties%.Add",           label = "properties.Add"          },
    { pat = "spawnmenu%.",               label = "spawnmenu.*"             },
    { pat = "%f[%w]tool%.",              label = "tool.*"                  },

    { pat = "vgui%.Create",              label = "vgui.Create"             },
    { pat = "vgui%.Register",            label = "vgui.Register"           },
    { pat = "vgui%.RegisterFile",        label = "vgui.RegisterFile"       },

    { pat = ":Kick%s*%(",                label = ":Kick()"                 },
    { pat = ":Ban%s*%(",                 label = ":Ban()"                  },
    { pat = ":Kill%s*%(",                label = ":Kill()"                 },
    { pat = ":StripWeapons",             label = ":StripWeapons"           },
    { pat = ":StripAmmo",                label = ":StripAmmo"              },
    { pat = ":Give%s*%(",                label = ":Give()"                 },
    { pat = ":ConCommand",               label = ":ConCommand"             },
    { pat = ":SendLua",                  label = ":SendLua"                },
    { pat = ":Freeze%s*%(",              label = ":Freeze()"               },
    { pat = ":Spawn%s*%(",               label = ":Spawn()"                },
    { pat = ":SetPos",                   label = ":SetPos"                 },
    { pat = "%f[%w]player%.GetAll",      label = "player.GetAll"           },
    { pat = "%f[%w]player%.GetByID",     label = "player.GetByID"          },

    { pat = "_G%[",                      label = "_G[...]"                 },
    { pat = "_G%.",                      label = "_G.*"                    },
    { pat = "%f[%w_]_G%f[^%w_]",         label = "_G (global env)"         },
    { pat = "%f[%w_]package%f[^%w_]",    label = "package (module system)" },
    { pat = "%f[%w_]debug%f[^%w_]",      label = "debug (introspection)"   },
    { pat = "%f[%w_]jit%f[^%w_]",        label = "jit (LuaJIT internals)"  },
    { pat = "%f[%w_]getfenv%f[^%w_]",    label = "getfenv"                 },
    { pat = "%f[%w_]setfenv%f[^%w_]",    label = "setfenv"                 },
    { pat = "_ENV",                      label = "_ENV"                    },
    { pat = "getmetatable",              label = "getmetatable"            },
    { pat = "setmetatable",              label = "setmetatable"            },
    { pat = "debug%.",                   label = "debug.*"                 },
    { pat = "jit%.",                     label = "jit.*"                   },
    { pat = "rawget",                    label = "rawget"                  },
    { pat = "rawset",                    label = "rawset"                  },
    { pat = "rawequal",                  label = "rawequal"                },
    { pat = "rawlen",                    label = "rawlen"                  },
    { pat = "%f[%w]system%.",            label = "system.*"                },
    { pat = "%f[%w]engine%.",            label = "engine.*"                },

    { pat = "%f[%w]include%s*%(",        label = "include()"               },
    { pat = "AddCSLuaFile",               label = "AddCSLuaFile"           },
    { pat = "%f[%w]require%s*%(",        label = "require()"               },
    { pat = "%f[%w]module%s*%(",         label = "module()"                },

    { pat = "string%.char",              label = "string.char"             },
    { pat = "string%.byte",              label = "string.byte"             },
    { pat = "string%.rep",               label = "string.rep"              },
    { pat = "bit%.bxor",                 label = "bit.bxor"                },
    { pat = "bit%.lshift",               label = "bit.lshift"              },
    { pat = "bit%.rshift",               label = "bit.rshift"              },
    { pat = "bit%.band",                 label = "bit.band"                },
    { pat = "bit%.bor",                  label = "bit.bor"                 },
}

local REQUIRED_MARKERS = {
    "Metrostroi%.Skins",
    "Metrostroi%.RegisterSkin",
    "Metrostroi%.DefineSkin",
    "Metrostroi%.AddSkin",
    "Metrostroi%.Masks",
    "Metrostroi%.RegisterMask",
    "Metrostroi%.AddMask",
    "Metrostroi%.DefineMask",
}

local function NormalizeForScanning(s)
    s = string.gsub(s, "%-%-%[%[.-%]%]", " ")
    s = string.gsub(s, "%-%-[^\n]*",      " ")

    s = string.gsub(s, '"[^"\n]*"',      '""')
    s = string.gsub(s, "'[^'\n]*'",      "''")
    s = string.gsub(s, "%[=-%[.-%]=-%]", "[[]]")

    s = string.gsub(s, "%s+", " ")

    s = string.gsub(s, " ?([%.%[%]%(%),;=:]) ?", "%1")
    return s
end

function Trainfitter.ValidateSkinLua(content, displayPath)
    if not isstring(content) or #content == 0 then
        return false, "empty lua file: " .. tostring(displayPath)
    end
    if #content > MAX_LUA_FILE_SIZE then
        return false, string.format(
            "lua file too large: %s (%d B, max %d B)",
            tostring(displayPath), #content, MAX_LUA_FILE_SIZE)
    end

    for i = 1, math.min(#content, 4096) do
        local b = string.byte(content, i)
        if b == 0 then
            return false, "NUL byte in " .. tostring(displayPath)
        end
    end

    local normalized = NormalizeForScanning(content)

    for _, p in ipairs(FORBIDDEN_PATTERNS) do
        if string.find(normalized, p.pat) then
            return false, string.format(
                "forbidden API in skin file %s: %s",
                tostring(displayPath), p.label)
        end
    end

    local hasMarker = false
    for _, m in ipairs(REQUIRED_MARKERS) do
        if string.find(normalized, m) then hasMarker = true break end
    end
    if not hasMarker then
        return false, "missing Metrostroi.Skins/Metrostroi.Masks registration in "
            .. tostring(displayPath)
    end

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

    local files          = {}
    local entries        = {}
    local skinFileCount  = 0
    local maskFileCount  = 0
    local materialsCount = 0
    local luaFileCount   = 0
    local totalBytes     = 0

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

        local isLua      = (ext == "lua")
        local addonPref  = isLua and is_lua_addon_path(lower) or nil
        local isAddonLua = addonPref ~= nil
        local isMaskLua  = addonPref == "lua/metrostroi/masks/"

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
        elseif isAddonLua then
            skinFileCount = skinFileCount + 1
        elseif string.sub(lower, 1, 10) == "materials/" then
            materialsCount = materialsCount + 1
        end

        table.insert(entries, {
            name       = name,
            size       = size,
            isLua      = isLua,
            isAddonLua = isAddonLua,
            isMaskLua  = isMaskLua,
        })
    end

    if skinFileCount == 0 and maskFileCount == 0 then
        f:Close()
        return false,
            "not a Metrostroi train addon (no lua/metrostroi/skins/*.lua "
            .. "or lua/metrostroi/masks/*.lua registration files found; materials="
            .. materialsCount .. ")",
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
            local ok, reason = Trainfitter.ValidateSkinLua(body, e.name)
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
