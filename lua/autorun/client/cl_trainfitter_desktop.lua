-- Trainfitter — cl_trainfitter_desktop.lua
-- Made by SellingVika.

local ICON = "icon64/trainfitter.png"

list.Set("DesktopWindows", "TrainfitterDesktopWindow", {
    title = "Trainfitter",
    icon  = ICON,
    init  = function(icon, window)
        if IsValid(window) then window:Close() end
        if Trainfitter.OpenMenu then
            Trainfitter.OpenMenu()
        end
    end,
})

concommand.Add("trainfitter", function()
    if Trainfitter.OpenMenu then Trainfitter.OpenMenu() end
end)
