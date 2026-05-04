-- Trainfitter — cl_trainfitter_browser.lua
-- Made by SellingVika.

Trainfitter = Trainfitter or {}

local DEFAULT_URL =
    "https://steamcommunity.com/workshop/browse/?appid=4000&searchtext=metrostroi&childpublishedfileid=0&browsesort=trend&section=readytouseitems"

local C = {
    bg        = Color(22,  22,  26,  250),
    bg_panel  = Color(28,  28,  32),
    bg_item   = Color(34,  34,  40),
    bg_hover  = Color(44,  44,  52),
    border    = Color(48,  48,  54),
    text      = Color(235, 235, 240),
    muted     = Color(140, 140, 150),
    ok        = Color(110, 220, 135),
    err       = Color(220, 100, 100),
    accent    = Color(70,  140, 90),
}

local function ExtractWSID(url)
    if not isstring(url) then return nil end
    return string.match(url, "://steamcommunity%.com/sharedfiles/filedetails/.-[%?%&]id=(%d+)")
        or string.match(url, "://steamcommunity%.com/workshop/filedetails/.-[%?%&]id=(%d+)")
        or string.match(url, "^steamcommunity%.com/sharedfiles/filedetails/.-[%?%&]id=(%d+)")
        or string.match(url, "^steamcommunity%.com/workshop/filedetails/.-[%?%&]id=(%d+)")
end

local INJECT_JS = [[
(function() {
    function bindSelect() {
        var sub = document.getElementById("SubscribeItemBtn") || document.getElementById("SubscribeItemOptionAdd");
        if (sub) {
            sub.innerText = "Select for Trainfitter";
            sub.style.background = "#5a8c4a";
            sub.style.color = "#fff";
            sub.onclick = function(e) {
                if (e && e.preventDefault) e.preventDefault();
                if (window.gmod && gmod.tfselect) gmod.tfselect();
                return false;
            };
        }
    }
    bindSelect();
    setTimeout(bindSelect, 200);
    setTimeout(bindSelect, 800);
    setTimeout(bindSelect, 2000);
    window.SubscribeItem = function() {
        if (window.gmod && gmod.tfselect) gmod.tfselect();
    };
})();
]]

local activeBrowser = nil

local PANEL = {}

function PANEL:Init()
    self:SetSize(math.min(ScrW() - 80, 1100), math.min(ScrH() - 80, 720))
    self:Center()
    self:SetDeleteOnClose(true)
    self:MakePopup()
    self:SetTitle("")
    self:ShowCloseButton(false)
    self:SetDraggable(true)
    self:SetSizable(true)

    self.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, C.bg)
    end

    local top = vgui.Create("DPanel", self)
    top:Dock(TOP); top:SetTall(40); top:DockMargin(0, 0, 0, 0)
    top.Paint = function() end

    local brand = vgui.Create("DLabel", top)
    brand:Dock(LEFT); brand:DockMargin(14, 0, 0, 0); brand:SetWide(220)
    brand:SetFont("Trainfitter.H1")
    brand:SetText("Trainfitter — " .. Trainfitter.L("open_workshop"))
    brand:SetTextColor(C.text)

    local closeBtn = vgui.Create("DButton", top)
    closeBtn:SetText("×")
    closeBtn:SetFont("Trainfitter.H1")
    closeBtn:SetTextColor(C.text)
    closeBtn:Dock(RIGHT); closeBtn:DockMargin(0, 6, 10, 6); closeBtn:SetWide(36)
    closeBtn.Paint = function(s, w, h)
        local hover = s:IsHovered() and C.bg_hover or C.bg_item
        draw.RoundedBox(4, 0, 0, w, h, hover)
    end
    closeBtn.DoClick = function() self:Close() end

    local nav = vgui.Create("DPanel", self)
    nav:Dock(TOP); nav:SetTall(34); nav:DockMargin(8, 0, 8, 4)
    nav.Paint = function() end

    local function NavBtn(label, icon)
        local b = vgui.Create("DButton", nav)
        b:SetText(""); b.label = label
        b.icon = icon and Material(icon) or nil
        b:Dock(LEFT); b:SetWide(34); b:DockMargin(0, 4, 4, 4)
        b.Paint = function(s, w, h)
            local hover = s:IsHovered() and C.bg_hover or C.bg_item
            draw.RoundedBox(4, 0, 0, w, h, hover)
            if s.icon then
                surface.SetMaterial(s.icon)
                surface.SetDrawColor(255, 255, 255, 230)
                surface.DrawTexturedRect(w / 2 - 8, h / 2 - 8, 16, 16)
            end
        end
        b:SetTooltip(label)
        return b
    end

    local backBtn    = NavBtn("Back",    "icon16/arrow_left.png")
    local fwdBtn     = NavBtn("Forward", "icon16/arrow_right.png")
    local refreshBtn = NavBtn(Trainfitter.L("refresh"), "icon16/arrow_refresh.png")
    local homeBtn    = NavBtn("Home",    "icon16/house.png")

    local urlEntry = vgui.Create("DTextEntry", nav)
    urlEntry:Dock(FILL); urlEntry:DockMargin(4, 6, 4, 6)
    urlEntry:SetFont("Trainfitter.Body")
    urlEntry:SetTextColor(C.text)
    urlEntry:SetCursorColor(C.text)
    urlEntry:SetPlaceholderColor(C.muted)
    urlEntry:SetDrawBorder(false)
    urlEntry.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, C.bg_item)
        s:DrawTextEntryText(s:GetTextColor(), s:GetHighlightColor(), s:GetCursorColor())
    end

    local persistBox
    local persistWrap = vgui.Create("DPanel", nav)
    persistWrap:Dock(RIGHT); persistWrap:SetWide(170); persistWrap:DockMargin(4, 4, 0, 4)
    persistWrap.Paint = function() end

    persistBox = vgui.Create("DCheckBox", persistWrap)
    persistBox:SetPos(8, 8); persistBox:SetSize(18, 18)

    local persistLbl = vgui.Create("DLabel", persistWrap)
    persistLbl:SetPos(32, 4); persistLbl:SetSize(140, 26)
    persistLbl:SetFont("Trainfitter.Body")
    persistLbl:SetText(Trainfitter.L("make_persistent"))
    persistLbl:SetTextColor(C.text)
    persistLbl.OnMousePressed = function() persistBox:Toggle() end

    local selectBtn = vgui.Create("DButton", nav)
    selectBtn:SetText("")
    selectBtn:Dock(RIGHT); selectBtn:DockMargin(4, 4, 4, 4); selectBtn:SetWide(180)
    selectBtn:SetEnabled(false)
    selectBtn.label = Trainfitter.L("apply")
    selectBtn.Paint = function(s, w, h)
        local col = s:IsEnabled() and C.accent or C.bg_item
        if s:IsEnabled() and s:IsHovered() then
            col = Color(col.r + 20, col.g + 20, col.b + 20)
        end
        draw.RoundedBox(6, 0, 0, w, h, col)
        if not s:IsEnabled() then
            draw.RoundedBox(6, 0, 0, w, h, Color(0, 0, 0, 100))
        end
        draw.SimpleText(s.label, "Trainfitter.H2",
            w / 2, h / 2, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local browser = vgui.Create("DHTML", self)
    browser:Dock(FILL); browser:DockMargin(8, 0, 8, 4)
    browser.Paint = function() end
    self.browser = browser

    local statusLbl = vgui.Create("DLabel", self)
    statusLbl:Dock(BOTTOM); statusLbl:SetTall(20); statusLbl:DockMargin(12, 0, 12, 6)
    statusLbl:SetFont("Trainfitter.Small")
    statusLbl:SetTextColor(C.muted)
    statusLbl:SetText(Trainfitter.L("paste_and_enter"))

    self.currentWSID = nil

    local function UpdateURL(url)
        if not isstring(url) then url = "" end
        urlEntry:SetText(url)
        local wsid = ExtractWSID(url)
        self.currentWSID = wsid and tonumber(wsid) and tostring(wsid) or nil
        if self.currentWSID then
            selectBtn:SetEnabled(true)
            selectBtn.label = Trainfitter.L("apply") .. " (" .. self.currentWSID .. ")"
            statusLbl:SetTextColor(C.ok)
            statusLbl:SetText(Trainfitter.L("selected", self.currentWSID))
        else
            selectBtn:SetEnabled(false)
            selectBtn.label = Trainfitter.L("apply")
            statusLbl:SetTextColor(C.muted)
            statusLbl:SetText(url)
        end
    end

    backBtn.DoClick    = function() browser:GoBack() end
    fwdBtn.DoClick     = function() browser:GoForward() end
    refreshBtn.DoClick = function() browser:Refresh(true) end
    homeBtn.DoClick    = function() browser:OpenURL(DEFAULT_URL) end

    urlEntry.OnEnter = function(s)
        local v = string.Trim(s:GetValue() or "")
        if v == "" then return end
        if not string.find(v, "^%w+://") then v = "https://" .. v end
        browser:OpenURL(v)
    end

    selectBtn.DoClick = function()
        local wsid = self.currentWSID
        if not wsid then return end

        if steamworks and isfunction(steamworks.Subscribe) then
            pcall(steamworks.Subscribe, wsid)
        end

        if Trainfitter.Request(wsid, persistBox:GetChecked() == true) then
            statusLbl:SetTextColor(C.ok)
            statusLbl:SetText(Trainfitter.L("request_sent") .. " (" .. wsid .. ")")
            surface.PlaySound("ambient/water/drip3.wav")
            timer.Simple(0.6, function() if IsValid(self) then self:Close() end end)
        end
    end

    browser.OnDocumentReady = function(_, url)
        UpdateURL(url)
        browser:QueueJavascript(INJECT_JS)
    end
    browser.OnFinishLoadingDocument = function(_, url) UpdateURL(url) end
    browser.OnBeginLoadingDocument  = function(_, url) UpdateURL(url) end
    browser.OnChangeTargetURL       = function(_, url)
        if isstring(url) and url ~= "" then statusLbl:SetText(url) end
    end

    browser:AddFunction("gmod", "tfselect", function()
        if self.currentWSID then selectBtn:DoClick() end
    end)

    browser:OpenURL(DEFAULT_URL)
end

function PANEL:OnRemove()
    if activeBrowser == self then activeBrowser = nil end
end

vgui.Register("TrainfitterWorkshopBrowser", PANEL, "DFrame")

function Trainfitter.OpenWorkshopBrowser()
    if IsValid(activeBrowser) then
        activeBrowser:Close()
        activeBrowser = nil
    end
    activeBrowser = vgui.Create("TrainfitterWorkshopBrowser")
end

concommand.Add("trainfitter_workshop", function()
    if Trainfitter.OpenWorkshopBrowser then Trainfitter.OpenWorkshopBrowser() end
end)
