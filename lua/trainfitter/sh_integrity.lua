-- Trainfitter — sh_integrity.lua
-- Made by SellingVika.

Trainfitter = Trainfitter or {}

local FILES_TO_CHECK = {
    "lua/autorun/sh_trainfitter.lua",
    "lua/trainfitter/sh_config.lua",
    "lua/trainfitter/sh_lang.lua",
    "lua/trainfitter/sh_banner.lua",
    "lua/trainfitter/sh_gma_scan.lua",
    "lua/trainfitter/sh_integrity.lua",
    "lua/autorun/server/sv_trainfitter.lua",
    "lua/autorun/client/cl_trainfitter.lua",
    "lua/autorun/client/cl_trainfitter_menu.lua",
    "lua/autorun/client/cl_trainfitter_browser.lua",
    "lua/autorun/client/cl_trainfitter_desktop.lua",
}

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
    for _, path in ipairs(FILES_TO_CHECK) do
        local ok, reason = CheckFileHeader(path)
        if not ok then
            table.insert(missing, { path = path, reason = reason })
        end
    end
    return #missing == 0, missing
end

local FORK_PATTERNS = {
    "%-%-%s*Forked%s+and%s+modified%s+by%s+([^\r\n%.]+)",
    "%-%-%s*Forked%s+by%s+([^\r\n%.]+)",
    "%-%-%s*Modified%s+by%s+([^\r\n%.]+)",
}

local function ScanModifiers()
    local seen   = {}
    local order  = {}
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

local ok, missing = Trainfitter.VerifyIntegrity()
Trainfitter.IntegrityFailed = not ok

if not ok then
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
