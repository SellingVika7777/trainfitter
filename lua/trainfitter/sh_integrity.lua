-- Trainfitter — sh_integrity.lua
-- Made by SellingVika.

Trainfitter = Trainfitter or {}

local SHARED_FILES = {
    "lua/autorun/sh_trainfitter.lua",
    "lua/trainfitter/sh_config.lua",
    "lua/trainfitter/sh_lang.lua",
    "lua/trainfitter/sh_banner.lua",
    "lua/trainfitter/sh_gma_scan.lua",
    "lua/trainfitter/sh_integrity.lua",
}

local CLIENT_FILES = {
    "lua/autorun/client/cl_trainfitter.lua",
    "lua/autorun/client/cl_trainfitter_menu.lua",
    "lua/autorun/client/cl_trainfitter_browser.lua",
    "lua/autorun/client/cl_trainfitter_desktop.lua",
}

local SERVER_FILES = {
    "lua/autorun/server/sv_trainfitter.lua",
}

local FILES_TO_CHECK = {}
for _, f in ipairs(SHARED_FILES) do table.insert(FILES_TO_CHECK, f) end
if CLIENT then
    for _, f in ipairs(CLIENT_FILES) do table.insert(FILES_TO_CHECK, f) end
end
if SERVER then
    for _, f in ipairs(CLIENT_FILES) do table.insert(FILES_TO_CHECK, f) end
    for _, f in ipairs(SERVER_FILES) do table.insert(FILES_TO_CHECK, f) end
end

local REQUIRED_AUTHOR_TAG  = "Made by SellingVika"
local REQUIRED_PROJECT_TAG = "Trainfitter"

local function CheckFileHeader(path)
    local content = file.Read(path, "GAME")
    if not isstring(content) or content == "" then
        return false, "missing or empty"
    end
    local head = string.sub(content, 1, 2048)
    if not string.find(head, REQUIRED_AUTHOR_TAG, 1, true) then
        return false, "missing 'Made by SellingVika' tag"
    end
    if not string.find(head, REQUIRED_PROJECT_TAG, 1, true) then
        return false, "missing 'Trainfitter' project tag"
    end
    return true
end

function Trainfitter.VerifyIntegrity()
    local missing = {}
    local idx     = 0
    for _, path in ipairs(FILES_TO_CHECK) do
        idx = idx + 1
        local ok, reason = CheckFileHeader(path)
        if not ok then
            table.insert(missing, { path = path, reason = reason })
        end

        if idx == 2 and #missing == 2 then
            return true, missing, "interference"
        end
    end
    return #missing == 0, missing
end

local FORK_PATTERNS = {
    "%-%-%s*Forked%s+and%s+modified%s+by%s+([^\r\n%.]+)",
    "%-%-%s*Forked%s+by%s+([^\r\n%.]+)",
    "%-%-%s*Modified%s+by%s+([^\r\n%.]+)",
}

local ok, missing, status = Trainfitter.VerifyIntegrity()
Trainfitter.IntegrityFailed       = not ok
Trainfitter.IntegrityInterference = status == "interference"

local function ScanModifiers()
    if Trainfitter.IntegrityInterference then return {} end

    local seen  = {}
    local order = {}
    for _, path in ipairs(FILES_TO_CHECK) do
        local content = file.Read(path, "GAME")
        if isstring(content) and content ~= "" then
            local head = string.sub(content, 1, 2048)
            for _, pat in ipairs(FORK_PATTERNS) do
                for name in string.gmatch(head, pat) do
                    name = string.Trim(name)
                    name = string.gsub(name, "[%c]", "")
                    if #name > 0 and #name <= 64 and not seen[name] then
                        seen[name] = true
                        table.insert(order, name)
                    end
                end
            end
        end
    end
    return order
end

Trainfitter.Modifiers = ScanModifiers()

if status == "interference" then
    MsgC(Color(255, 200,  80),
        "[Trainfitter] file.Read returned unexpected content for our own files.\n")
    MsgC(Color(255, 200,  80),
        "[Trainfitter] Likely a third-party file protection / anti-leak addon\n")
    MsgC(Color(255, 200,  80),
        "[Trainfitter] (e.g. lenofag) detoured file.Open. Strict integrity check\n")
    MsgC(Color(255, 200,  80),
        "[Trainfitter] skipped — operating normally.\n")
elseif not ok then
    MsgC(Color(255, 100, 100),
        "[Trainfitter] INTEGRITY FAIL — addon refuses to operate.\n")
    MsgC(Color(255, 100, 100),
        "[Trainfitter] Required tags ('Trainfitter' + 'Made by SellingVika') missing in:\n")
    for _, m in ipairs(missing) do
        MsgC(Color(255, 180, 180),
            "  - " .. m.path .. "  (" .. m.reason .. ")\n")
    end
    MsgC(Color(255, 100, 100),
        "[Trainfitter] If you forked the addon, KEEP the original 'Made by SellingVika' tag\n")
    MsgC(Color(255, 100, 100),
        "[Trainfitter] and add your own line below it (e.g. '-- Forked by YourName.').\n")
end

function Trainfitter.IntegrityGuard()
    return Trainfitter.IntegrityFailed == true
end
