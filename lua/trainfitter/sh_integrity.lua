-- Trainfitter — sh_integrity.lua
-- Made by SellingVika.

Trainfitter = Trainfitter or {}

Trainfitter.IntegrityFailed       = false
Trainfitter.IntegrityInterference = false
Trainfitter.Modifiers             = {}

function Trainfitter.VerifyIntegrity()
    return true, {}
end

function Trainfitter.IntegrityGuard()
    return false
end
