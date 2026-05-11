-- Trainfitter — sh_integrity.lua
-- Made by SellingVika.

Trainfitter = Trainfitter or {}

Trainfitter.IntegrityFailed       = false
Trainfitter.IntegrityInterference = false
Trainfitter.Modifiers             = {}

local CRITICAL = {
    "ScanGMA", "ExecSandboxed",
    "ValidateSkinLua", "ValidateMaskLua",
    "ShouldScanGMA", "ShouldContentScan",
    "IsValidWSID",
}

local _snapshot

function Trainfitter.VerifyIntegrity()
    if not _snapshot then return true, {} end
    local issues = {}
    for _, name in ipairs(CRITICAL) do
        local cur  = Trainfitter[name]
        local snap = _snapshot[name]
        if snap and cur ~= snap then
            issues[#issues + 1] = "tampered: " .. name
        end
    end
    return #issues == 0, issues
end

function Trainfitter.IntegrityGuard()
    local ok = Trainfitter.VerifyIntegrity()
    return not ok
end

timer.Simple(0, function()
    local s = {}
    for _, name in ipairs(CRITICAL) do
        if isfunction(Trainfitter[name]) then
            s[name] = Trainfitter[name]
        end
    end
    _snapshot = s
end)
