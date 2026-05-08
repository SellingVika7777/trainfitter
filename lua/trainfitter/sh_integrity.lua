-- Trainfitter — sh_integrity.lua
-- Made by SellingVika.

-- Раньше тут жил integrity check который читал собственные .lua файлы и
-- проверял что в них остался авторский тег. На серверах с анти-лик
-- защитой (lenofag, ULib protect и т.п.) это давало:
--   1. Спам алертов «SOMETHING IS TRYING TO READ LUA FILES» по 11 штук
--      при каждом старте — топило в консоли реальные логи (кто что
--      поставил, кто что удалил).
--   2. Ложные срабатывания integrity-проверки потому что детур file.Open
--      возвращал изменённый контент → аддон отказывался работать.
--
-- Снято полностью. Заглушки оставлены чтобы не ломать include-цепочку
-- и существующие IntegrityGuard() вызовы в sv/cl коде.

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
