-- Trainfitter — sh_banner.lua
-- Made by SellingVika.

Trainfitter = Trainfitter or {}

local EYE_ART = [[
⡰⢈⠆⡹⢀⠆⡔⠒⡂⠤⡈⢍⠰⢨⢉⡍⢬⠱⡌⢦⣍⢮⣕⡓⢾⡰⣉⣦⠱⡜⣢⠖⡰⢂⡔⢠⠂⠤⡀⠄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⡐⣁⠂⡁⠎⡐⢌⠱⡘⠤⢱⢈⡖⡡⢖⡘⣆⢳⣭⣿⣼⣮⣿⣿⣷⣷⣯⣽⣿⣶⣥⣾⣴⣥⣮⣱⣘⣤⣱⣌⣤⣁⣆⣁⠂⠠⠐⠀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠐⣀⠣⢌⠱⢈⠤⢃⠴⣊⠕⣢⢒⡱⣎⣶⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣾⣧⣤⣅⣆⡀⢠⣀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⡄⠢⢌⡒⣌⢒⡏⢶⣡⣾⢶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣮⣛⡓⢂⠠⣄⠀⠀⠀
⠐⡌⣱⢊⡴⢊⡼⣎⣯⣷⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⢫⡝⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡖⠩⠝⢻⣿⣿⣿⣿⣿⣿⣯⠿⠿⣦⣬⡆⠀⠀
⡜⢲⢡⡟⡰⣏⣷⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣻⠹⢆⡍⠥⣼⣿⣿⣿⣿⣿⢿⡿⣿⣿⣿⣿⣿⣿⣿⣿⣿⢻⡙⣿⣿⣿⣿⠀⠀⠀⠉⢻⣿⣿⣿⣿⣿⣿⣵⡋⣵⣦⠀⠀
⠌⣇⢚⡴⣹⣾⣿⣿⣿⣿⣿⣿⣿⣿⢯⡻⣝⠣⢍⠠⠐⠀⣿⣿⣿⣿⣏⣱⣮⣟⣷⣿⣿⣿⣿⣿⣿⣿⣿⡦⣝⢆⠻⢻⣿⣆⠀⠀⠀⠀⠛⢿⣿⣿⣿⣿⣿⣥⢿⣧⢀⠀
⠊⡔⢫⡼⣿⣿⢟⣼⣿⣿⣿⣿⣿⣿⣷⠑⢎⠑⡀⠀⠀⠑⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⣀⢃⣿⠀⠀⠀⠀⠀⠀⠁⣻⣿⣯⣿⣽⣿⣉⢏⠣⡀
⠡⢌⡑⢎⠵⣹⣿⣿⣿⣿⣿⣿⣟⣿⣽⣿⡠⠀⠀⠀⠀⠀⠉⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠡⢄⣿⠏⠀⠀⠀⠀⠀⠀⠀⣸⣿⣟⠀⠉⠙⣿⡀⠡⠐
⠐⢂⡘⢈⡒⢿⣿⣿⣿⣿⣟⣿⣿⣿⣯⢿⣏⠳⣦⠀⠀⠀⠀⠹⣿⣿⣿⣷⢯⡿⣿⣿⣿⡿⠋⣿⣿⡿⣿⣿⣷⣆⢻⠋⠀⠀⠀⠀⠀⠀⢀⣴⡿⢻⡿⠆⠀⠀⠙⠉⠀⠀
⠈⠤⠐⠤⡸⡙⣿⣿⣿⣿⣿⣿⢿⣿⡟⣾⣿⢷⡹⣧⡀⠀⠀⠀⠈⠻⣿⣿⣯⣿⣷⣾⣶⣷⣶⣿⣿⣿⣿⣿⣿⡿⠁⠀⠀⠀⠀⠀⣀⣴⠟⣡⠴⠋⠁⠀⠀⠀⠀⠀⠀⠀
⠈⢆⢁⠂⡑⠈⠄⡈⠉⠃⠟⡘⣛⢫⠿⢛⠱⢊⠙⡛⠻⠷⢦⣤⣀⡀⠈⠛⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠟⠋⠀⠀⠀⢀⣠⣴⡾⠟⠃⠀⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⢂⠂⠆⡈⢁⠄⠐⠀⠁⠠⠐⠠⠄⠠⢁⠉⠐⠈⢀⠀⠈⠀⠀⠉⠙⠓⠶⠾⣥⣏⡛⢻⡟⢿⣿⣭⣁⣠⡦⣤⢶⡾⠻⠋⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠆⠰⠀⠁⠠⠁⠄⢈⠠⢐⠠⢄⣡⣈⠢⠑⢌⡀⠄⡀⠀⣀⠀⠀⠀⣀⡀⠀⠀⢉⣈⣉⣀⠀⠁]]

local function PrintBanner(side)
    local accent = Color(120, 220, 255)
    local soft   = Color(180, 200, 220)
    local muted  = Color(120, 130, 140)

    for line in string.gmatch(EYE_ART, "([^\n]+)") do
        MsgC(soft, line, "\n")
    end

    local ver = Trainfitter.Version or "?"
    MsgC(accent, "Trainfitter ", soft, "v" .. ver, muted, " (" .. side .. ")\n")

    local mods = Trainfitter.Modifiers
    if istable(mods) and #mods > 0 then
        MsgC(muted,  "by SellingVika, ", soft, "modified by " .. table.concat(mods, ", ") .. "\n\n")
    else
        MsgC(muted,  "by SellingVika\n\n")
    end
end

if SERVER then
    hook.Add("Initialize", "Trainfitter.ServerBanner", function()
        hook.Remove("Initialize", "Trainfitter.ServerBanner")
        PrintBanner("server")
    end)
else
    hook.Add("InitPostEntity", "Trainfitter.ClientBanner", function()
        hook.Remove("InitPostEntity", "Trainfitter.ClientBanner")
        PrintBanner("client")
    end)
end

Trainfitter.PrintBanner = PrintBanner
