-- Trainfitter — cl_trainfitter_menu.lua
-- Made by SellingVika.

local WORKSHOP_HOME =
    "https://steamcommunity.com/workshop/browse/?appid=4000&browsesort=trend&section=readytouseitems&requiredtags%5B%5D=Addon"

local C = {
    bg          = Color( 20,  22,  28, 252),
    bg_panel    = Color( 28,  30,  36),
    bg_item     = Color( 36,  38,  46),
    bg_hover    = Color( 50,  54,  64),
    bg_active   = Color( 60, 110, 180),
    border      = Color( 52,  56,  66),
    border_soft = Color( 44,  48,  56),
    text        = Color(240, 242, 246),
    text_dim    = Color(200, 204, 212),
    muted       = Color(150, 156, 168),
    ok          = Color(110, 215, 135),
    warn        = Color(240, 180,  80),
    err         = Color(235,  95, 100),
    accent      = Color( 95, 175, 255),
    accent_bg   = Color( 70, 145,  95),
    accent_hi   = Color( 95, 175, 120),
    danger_bg   = Color(160,  64,  68),
    danger_hi   = Color(190,  86,  90),
    shadow      = Color(  0,   0,   0, 90),
}

surface.CreateFont("Trainfitter.H1",      { font = "Roboto",   size = 24, weight = 700 })
surface.CreateFont("Trainfitter.H2",      { font = "Roboto",   size = 17, weight = 600 })
surface.CreateFont("Trainfitter.Body",    { font = "Roboto",   size = 14, weight = 400 })
surface.CreateFont("Trainfitter.BodyB",   { font = "Roboto",   size = 14, weight = 600 })
surface.CreateFont("Trainfitter.Small",   { font = "Roboto",   size = 12, weight = 400 })
surface.CreateFont("Trainfitter.Caption", { font = "Roboto",   size = 11, weight = 400 })
surface.CreateFont("Trainfitter.Mono",    { font = "Consolas", size = 13 })

local function ExtractWSID(url)
    if not isstring(url) then return nil end
    return string.match(url, "://steamcommunity%.com/sharedfiles/filedetails/.-[%?%&]id=(%d+)")
        or string.match(url, "://steamcommunity%.com/workshop/filedetails/.-[%?%&]id=(%d+)")
        or string.match(url, "^steamcommunity%.com/sharedfiles/filedetails/.-[%?%&]id=(%d+)")
        or string.match(url, "^steamcommunity%.com/workshop/filedetails/.-[%?%&]id=(%d+)")
end

local function ParseDirectWSID(text)
    if not isstring(text) then return nil end
    local t = string.Trim(text)
    if string.match(t, "^%d+$") and #t >= 4 and #t <= 20 then return t end
end

local function FmtSize(bytes)
    if not bytes or bytes <= 0 then return "?" end
    local mb = bytes / (1024 * 1024)
    if mb >= 1024 then return string.format("%.2f ГБ", mb / 1024) end
    return string.format("%.1f МБ", mb)
end

local function FmtTime(ts)
    if not ts or ts <= 0 then return "—" end
    return os.date("%d.%m %H:%M", ts)
end

local function SafeSetImage(img, path)
    if not IsValid(img) then return end
    if not path or path == "" then img:SetVisible(false); return end
    img:SetVisible(true)
    pcall(img.SetImage, img, path)
end

local PREVIEW_DIR = "trainfitter/previews"
local function LoadPreviewImage(dimage, url, wsid)
    if not IsValid(dimage) or not isstring(url) or url == "" then return end
    if not file.IsDir(PREVIEW_DIR, "DATA") then file.CreateDir(PREVIEW_DIR) end
    local localPath = PREVIEW_DIR .. "/" .. wsid .. ".png"
    if file.Exists(localPath, "DATA") then
        SafeSetImage(dimage, "../data/" .. localPath); return
    end
    http.Fetch(url, function(body, _, _, code)
        if not IsValid(dimage) then return end
        if code and code >= 400 then return end
        if not body or #body < 64 then return end
        if #body > 2 * 1024 * 1024 then return end
        file.Write(localPath, body)
        SafeSetImage(dimage, "../data/" .. localPath)
    end, function() end)
end

local function MakePreviewPanel(parent)
    local p = vgui.Create("DPanel", parent)
    p.material = nil
    p.loading  = false

    p.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, C.bg_item)

        local mat = self.material
        if not mat or mat:IsError() then
            draw.SimpleText(self.loading and "Загружаю превью..." or "Нет превью",
                "Trainfitter.Body", w / 2, h / 2,
                C.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return
        end

        local iw, ih = mat:Width(), mat:Height()
        if iw <= 0 or ih <= 0 then return end

        local cAspect = w / h
        local iAspect = iw / ih
        local sx, sy, sw, sh = 0, 0, iw, ih
        if iAspect > cAspect then
            sw = ih * cAspect
            sx = (iw - sw) / 2
        else
            sh = iw / cAspect
            sy = (ih - sh) / 2
        end

        render.ClearStencil()
        render.SetStencilEnable(true)
        render.SetStencilWriteMask(0xFF)
        render.SetStencilTestMask(0xFF)
        render.SetStencilReferenceValue(1)
        render.SetStencilFailOperation(STENCILOPERATION_KEEP)
        render.SetStencilZFailOperation(STENCILOPERATION_KEEP)
        render.SetStencilPassOperation(STENCILOPERATION_REPLACE)
        render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_ALWAYS)
        draw.NoTexture()
        draw.RoundedBox(6, 0, 0, w, h, color_white)
        render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)

        surface.SetMaterial(mat)
        surface.SetDrawColor(255, 255, 255)
        surface.DrawTexturedRectUV(0, 0, w, h,
            sx / iw, sy / ih, (sx + sw) / iw, (sy + sh) / ih)

        render.SetStencilEnable(false)
    end

    function p:SetLocalImage(localPath)
        self.loading = false
        if not localPath or localPath == "" then self.material = nil; return end
        self.material = Material(localPath, "smooth mips")
    end

    function p:Clear()  self.material = nil; self.loading = false end
    function p:SetLoading(f) self.loading = f and true or false; self.material = nil end

    return p
end

local function LoadPreviewIntoPanel(panel, url, wsid)
    if not IsValid(panel) or not isstring(url) or url == "" then return end
    if not file.IsDir(PREVIEW_DIR, "DATA") then file.CreateDir(PREVIEW_DIR) end
    local localPath = PREVIEW_DIR .. "/" .. wsid .. ".png"

    if file.Exists(localPath, "DATA") then
        panel:SetLocalImage("../data/" .. localPath); return
    end

    panel:SetLoading(true)
    http.Fetch(url, function(body, _, _, code)
        if not IsValid(panel) then return end
        if code and code >= 400 then panel:Clear() return end
        if not body or #body < 64 then panel:Clear() return end
        if #body > 2 * 1024 * 1024 then panel:Clear() return end
        file.Write(localPath, body)
        panel:SetLocalImage("../data/" .. localPath)
    end, function() if IsValid(panel) then panel:Clear() end end)
end

local function LerpColor(t, a, b)
    return Color(
        Lerp(t, a.r, b.r),
        Lerp(t, a.g, b.g),
        Lerp(t, a.b, b.b),
        Lerp(t, a.a or 255, b.a or 255))
end

local function MakeFlatButton(parent, text, icon)
    local b = vgui.Create("DButton", parent)
    b:SetText("")
    b.hoverFrac = 0
    b.bgNormal  = C.bg_item
    b.bgHover   = C.bg_hover
    b.label     = text or ""
    b.icon      = icon

    b.Paint = function(self, w, h)
        self.hoverFrac = Lerp(FrameTime() * 10, self.hoverFrac, self:IsHovered() and 1 or 0)
        local col = LerpColor(self.hoverFrac, self.bgNormal, self.bgHover)
        draw.RoundedBox(6, 0, 0, w, h, col)
        if self.hoverFrac > 0.05 then
            surface.SetDrawColor(C.accent.r, C.accent.g, C.accent.b, 30 * self.hoverFrac)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
        if not self:IsEnabled() then
            draw.RoundedBox(6, 0, 0, w, h, Color(0, 0, 0, 100))
        end

        local tx = 14
        if self.icon then
            surface.SetMaterial(self.icon)
            surface.SetDrawColor(255, 255, 255, 230)
            surface.DrawTexturedRect(12, h / 2 - 8, 16, 16)
            tx = 36
        end
        draw.SimpleText(self.label, "Trainfitter.Body",
            tx, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    return b
end

local function MakeAccentButton(parent, text)
    local b = vgui.Create("DButton", parent)
    b:SetText("")
    b.label = text or ""
    b.hoverFrac = 0
    b.Paint = function(self, w, h)
        self.hoverFrac = Lerp(FrameTime() * 10, self.hoverFrac, self:IsHovered() and 1 or 0)
        local col = LerpColor(self.hoverFrac, C.accent_bg, C.accent_hi)
        draw.RoundedBox(8, 0, 0, w, h, col)
        if self.hoverFrac > 0.05 then
            surface.SetDrawColor(255, 255, 255, 35 * self.hoverFrac)
            draw.RoundedBox(8, 0, 0, w, h * 0.45, Color(255, 255, 255, 12 * self.hoverFrac))
        end
        if not self:IsEnabled() then
            draw.RoundedBox(8, 0, 0, w, h, Color(0, 0, 0, 130))
        end
        draw.SimpleText(self.label, "Trainfitter.H2",
            w / 2, h / 2 + 1, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    return b
end

local function MakeDangerButton(parent, text, icon)
    local b = vgui.Create("DButton", parent)
    b:SetText("")
    b.label = text or ""
    b.icon  = icon
    b.hoverFrac = 0
    b.Paint = function(self, w, h)
        self.hoverFrac = Lerp(FrameTime() * 10, self.hoverFrac, self:IsHovered() and 1 or 0)
        local col = LerpColor(self.hoverFrac, C.danger_bg, C.danger_hi)
        draw.RoundedBox(6, 0, 0, w, h, col)
        if not self:IsEnabled() then
            draw.RoundedBox(6, 0, 0, w, h, Color(0, 0, 0, 130))
        end
        local tx = 14
        if self.icon then
            surface.SetMaterial(self.icon)
            surface.SetDrawColor(255, 255, 255, 235)
            surface.DrawTexturedRect(12, h / 2 - 8, 16, 16)
            tx = 36
        end
        draw.SimpleText(self.label, "Trainfitter.BodyB",
            tx, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    return b
end

local function MakeNavItem(parent, text, icon, isActive)
    local b = vgui.Create("DButton", parent)
    b:SetText("")
    b:SetTall(42)
    b.label    = text
    b.icon     = icon and Material(icon) or nil
    b.active   = isActive == true
    b.hoverFrac  = 0
    b.activeFrac = isActive and 1 or 0
    b.Paint = function(self, w, h)
        self.hoverFrac  = Lerp(FrameTime() * 10, self.hoverFrac,  self:IsHovered() and 1 or 0)
        self.activeFrac = Lerp(FrameTime() * 14, self.activeFrac, self.active and 1 or 0)

        local hoverCol  = LerpColor(self.hoverFrac, C.bg_panel, C.bg_hover)
        local bgCol     = LerpColor(self.activeFrac, hoverCol,  C.bg_active)
        draw.RoundedBox(6, 0, 0, w, h, bgCol)

        if self.activeFrac > 0.05 then
            surface.SetDrawColor(255, 255, 255, 230 * self.activeFrac)
            surface.DrawRect(0, 8, 3, h - 16)
        end

        local tx = 14
        if self.icon then
            surface.SetMaterial(self.icon)
            surface.SetDrawColor(255, 255, 255, 230)
            surface.DrawTexturedRect(10, h / 2 - 8, 16, 16)
            tx = 34
        end
        draw.SimpleText(self.label, "Trainfitter.Body",
            tx, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    return b
end

local function MakeEntry(parent, placeholder)
    local e = vgui.Create("DTextEntry", parent)
    e:SetPlaceholderText(placeholder or "")
    e:SetFont("Trainfitter.Body")
    e:SetTextColor(C.text)
    e:SetCursorColor(C.text)
    e:SetPlaceholderColor(C.muted)
    e:SetDrawBorder(false)
    e.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, C.bg_item)
        if self:HasFocus() then
            surface.SetDrawColor(C.accent.r, C.accent.g, C.accent.b, 80)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
        self:DrawTextEntryText(self:GetTextColor(), self:GetHighlightColor(), self:GetCursorColor())
    end
    return e
end

local function MakeListView(parent)
    local list = vgui.Create("DListView", parent)
    list:SetMultiSelect(false)
    list.Paint = function(_, w, h) draw.RoundedBox(8, 0, 0, w, h, C.bg_panel) end
    return list
end

local function MakeCloseButton(parent)
    local b = vgui.Create("DButton", parent)
    b:SetText("")
    b:SetSize(28, 28)
    b.hoverFrac = 0
    b.Paint = function(self, w, h)
        self.hoverFrac = Lerp(FrameTime() * 10, self.hoverFrac, self:IsHovered() and 1 or 0)
        local col = LerpColor(self.hoverFrac, C.bg_item, C.danger_bg)
        draw.RoundedBox(6, 0, 0, w, h, col)
        draw.SimpleText("×", "Trainfitter.H1", w / 2, h / 2 - 2,
            C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    return b
end

local function BuildInstallView(parent)
    local view = vgui.Create("DPanel", parent)
    view.Paint = function() end
    view:DockPadding(12, 12, 12, 12)

    local h = vgui.Create("DLabel", view)
    h:Dock(TOP); h:DockMargin(0, 0, 0, 8)
    h:SetFont("Trainfitter.H1"); h:SetText(Trainfitter.L("install_title")); h:SetTextColor(C.text)
    h:SetTall(28)

    local addrRow = vgui.Create("DPanel", view)
    addrRow:Dock(TOP); addrRow:SetTall(34); addrRow:DockMargin(0, 0, 0, 10)
    addrRow.Paint = function() end

    local addressEntry = MakeEntry(addrRow, Trainfitter.L("address_placeholder"))
    addressEntry:Dock(FILL)

    local openWSBtn = MakeFlatButton(addrRow, Trainfitter.L("open_workshop"), Material("icon16/world_go.png"))
    openWSBtn:Dock(RIGHT); openWSBtn:SetWide(230); openWSBtn:DockMargin(8, 0, 0, 0)

    local preview = vgui.Create("DPanel", view)
    preview:Dock(FILL)
    preview.Paint = function(_, w, ht)
        draw.RoundedBox(10, 0, 0, w, ht, C.bg_panel)
        surface.SetDrawColor(C.border_soft)
        surface.DrawOutlinedRect(0, 0, w, ht, 1)
    end
    preview:DockPadding(18, 16, 18, 16)

    local pvImage = MakePreviewPanel(preview)
    pvImage:Dock(TOP); pvImage:SetTall(200); pvImage:DockMargin(0, 0, 0, 10)

    local pvTitle = vgui.Create("DLabel", preview)
    pvTitle:Dock(TOP); pvTitle:DockMargin(0, 0, 0, 4); pvTitle:SetTall(22)
    pvTitle:SetFont("Trainfitter.H2"); pvTitle:SetText(Trainfitter.L("select_addon_above"))
    pvTitle:SetTextColor(C.text); pvTitle:SetWrap(false)

    local pvMeta = vgui.Create("DLabel", preview)
    pvMeta:Dock(TOP); pvMeta:DockMargin(0, 0, 0, 8); pvMeta:SetTall(16)
    pvMeta:SetFont("Trainfitter.Small"); pvMeta:SetText("")
    pvMeta:SetTextColor(C.muted)

    local pvDesc = vgui.Create("DLabel", preview)
    pvDesc:Dock(FILL)
    pvDesc:SetFont("Trainfitter.Body"); pvDesc:SetText("")
    pvDesc:SetTextColor(C.muted); pvDesc:SetWrap(true); pvDesc:SetContentAlignment(7)

    local bottom = vgui.Create("DPanel", view)
    bottom:Dock(BOTTOM); bottom:SetTall(42); bottom:DockMargin(0, 10, 0, 0)
    bottom.Paint = function() end

    local status = vgui.Create("DLabel", bottom)
    status:Dock(FILL); status:SetFont("Trainfitter.Small")
    status:SetText(Trainfitter.L("paste_and_enter"))
    status:SetTextColor(C.muted)

    local persistWrap = vgui.Create("DPanel", bottom)
    persistWrap:Dock(RIGHT); persistWrap:SetWide(200); persistWrap:DockMargin(6, 6, 0, 6)
    persistWrap.Paint = function() end

    local persistBox = vgui.Create("DCheckBox", persistWrap)
    persistBox:SetPos(8, 8); persistBox:SetSize(18, 18)

    local persistLbl = vgui.Create("DLabel", persistWrap)
    persistLbl:SetPos(32, 4); persistLbl:SetSize(160, 26)
    persistLbl:SetFont("Trainfitter.Body")
    persistLbl:SetText(Trainfitter.L("make_persistent"))
    persistLbl:SetTextColor(C.text)
    persistLbl.OnMousePressed = function() persistBox:Toggle() end

    local favBtn = MakeFlatButton(bottom, Trainfitter.L("add_to_favorites"), Material("icon16/star.png"))
    favBtn:Dock(RIGHT); favBtn:SetWide(170); favBtn:DockMargin(6, 6, 0, 6)
    favBtn:SetEnabled(false)

    local confirmBtn = MakeAccentButton(bottom, Trainfitter.L("confirm"))
    confirmBtn:Dock(RIGHT); confirmBtn:SetWide(160); confirmBtn:DockMargin(6, 6, 0, 6)
    confirmBtn:SetEnabled(false)

    local selectedWSID = nil

    local function IsWsidPersistent(wsid)
        for _, w in ipairs(Trainfitter.PersistentList or {}) do
            if w == wsid then return true end
        end
        return false
    end

    local function UpdateFavBtn(wsid)
        if wsid and IsWsidPersistent(wsid) then
            favBtn.label = Trainfitter.L("in_favorites")
        else
            favBtn.label = Trainfitter.L("add_to_favorites")
        end
    end

    local function SetSelected(wsid, source)
        selectedWSID = wsid
        if not wsid then
            status:SetTextColor(C.muted)
            status:SetText(Trainfitter.L("paste_and_enter"))
            confirmBtn:SetEnabled(false)
            favBtn:SetEnabled(false)
            persistBox:SetChecked(false); persistBox:SetEnabled(false)
            pvTitle:SetText("—"); pvMeta:SetText(""); pvDesc:SetText("")
            pvImage:Clear(); return
        end
        status:SetTextColor(C.ok); status:SetText(Trainfitter.L("selected", wsid))
        confirmBtn:SetEnabled(true)
        favBtn:SetEnabled(true)
        UpdateFavBtn(wsid)
        persistBox:SetEnabled(true)
        persistBox:SetChecked(IsWsidPersistent(wsid))

        pvTitle:SetText(Trainfitter.L("loading_preview"))
        pvMeta:SetText("WSID " .. wsid); pvDesc:SetText("")
        pvImage:SetLoading(true)

        Trainfitter.SafeFetchWorkshopInfo(wsid, function(info, err)
            if not IsValid(pvTitle) or selectedWSID ~= wsid then return end
            if not info then pvTitle:SetText(Trainfitter.L("no_data")); return end

            local title = isstring(info.title) and info.title ~= "" and info.title or wsid
            pvTitle:SetText(title)

            local meta = {}
            if tonumber(info.size) and info.size > 0 then table.insert(meta, FmtSize(info.size)) end
            pvMeta:SetText(table.concat(meta, "   •   "))

            local desc = isstring(info.description) and info.description or ""
            desc = string.gsub(desc, "%[[^%]]+%]", "")
            desc = string.sub(desc, 1, 400)
            pvDesc:SetText(desc)

            if isstring(info.previewurl) and info.previewurl ~= "" then
                LoadPreviewIntoPanel(pvImage, info.previewurl, wsid)
            else
                pvImage:Clear()
            end
        end)
    end

    addressEntry.OnEnter = function(s)
        local v = string.Trim(s:GetValue() or "")
        local wsid = ExtractWSID(v) or ParseDirectWSID(v)
        if wsid then SetSelected(wsid, "ввод")
        else
            status:SetTextColor(C.err)
            status:SetText(Trainfitter.L("need_url_or_wsid"))
        end
    end

    openWSBtn.DoClick = function()
        if Trainfitter.OpenWorkshopBrowser then
            Trainfitter.OpenWorkshopBrowser()
        else
            gui.OpenURL(WORKSHOP_HOME)
        end
    end

    confirmBtn.DoClick = function()
        if not selectedWSID then return end
        if Trainfitter.Request(selectedWSID, false) then
            status:SetTextColor(C.ok); status:SetText(Trainfitter.L("request_sent"))
        end
    end

    favBtn.DoClick = function()
        if not selectedWSID then return end
        if IsWsidPersistent(selectedWSID) then
            if Trainfitter.RemovePersistent(selectedWSID) then
                status:SetTextColor(C.muted)
                status:SetText(Trainfitter.L("removed_persistent", selectedWSID))
            end
        else
            if Trainfitter.Request(selectedWSID, true) then
                status:SetTextColor(C.ok)
                status:SetText(Trainfitter.L("saving_persistent", selectedWSID))
            end
        end
    end

    persistBox.OnChange = function(_, val)
        if not selectedWSID then return end
        if val then
            if Trainfitter.Request(selectedWSID, true) then
                status:SetTextColor(C.ok)
                status:SetText(Trainfitter.L("saving_persistent", selectedWSID))
            end
        else
            if Trainfitter.RemovePersistent(selectedWSID) then
                status:SetTextColor(C.muted)
                status:SetText(Trainfitter.L("removed_persistent", selectedWSID))
            end
        end
    end

    hook.Add("Trainfitter.PersistentUpdated", view, function()
        if selectedWSID then
            persistBox:SetChecked(IsWsidPersistent(selectedWSID))
            UpdateFavBtn(selectedWSID)
        end
    end)

    timer.Simple(0.1, function()
        if not IsValid(addressEntry) then return end
        local persistentWsid = (Trainfitter.PersistentList or {})[1]
        if persistentWsid then
            addressEntry:SetText("https://steamcommunity.com/sharedfiles/filedetails/?id=" .. persistentWsid)
            SetSelected(persistentWsid, "избранное")
            return
        end
        local cb = (system and system.GetClipboardText and system.GetClipboardText()) or ""
        local wsid = ExtractWSID(cb)
        if wsid then addressEntry:SetText(cb); SetSelected(wsid, "clipboard") end
    end)

    return view
end

local function BuildFavoritesView(parent)
    local view = vgui.Create("DPanel", parent)
    view.Paint = function() end
    view:DockPadding(12, 12, 12, 12)

    local h = vgui.Create("DLabel", view)
    h:Dock(TOP); h:DockMargin(0, 0, 0, 8)
    h:SetFont("Trainfitter.H1"); h:SetText(Trainfitter.L("favorites_title")); h:SetTextColor(C.text)
    h:SetTall(28)

    local top = vgui.Create("DPanel", view)
    top:Dock(TOP); top:SetTall(32); top:DockMargin(0, 0, 0, 8)
    top.Paint = function() end

    local searchEntry = MakeEntry(top, Trainfitter.L("address_placeholder"))
    searchEntry:Dock(FILL)

    local refreshBtn = MakeFlatButton(top, Trainfitter.L("refresh"), Material("icon16/arrow_refresh.png"))
    refreshBtn:Dock(RIGHT); refreshBtn:SetWide(130); refreshBtn:DockMargin(8, 0, 0, 0)

    local list = MakeListView(view)
    list:Dock(FILL)
    list:AddColumn("WSID"):SetFixedWidth(110)
    list:AddColumn(Trainfitter.L("no_title") == "(no title)" and "Title" or "Название")
    list:AddColumn(Trainfitter.GetLang() == "ru" and "Размер" or (Trainfitter.GetLang() == "da" and "Størrelse" or "Size")):SetFixedWidth(100)

    local bottom = vgui.Create("DPanel", view)
    bottom:Dock(BOTTOM); bottom:SetTall(36); bottom:DockMargin(0, 8, 0, 0)
    bottom.Paint = function() end

    local removeBtn = MakeFlatButton(bottom, Trainfitter.L("remove"), Material("icon16/delete.png"))
    removeBtn:Dock(RIGHT); removeBtn:SetWide(120); removeBtn:DockMargin(6, 3, 0, 3)

    local openBtn = MakeFlatButton(bottom, Trainfitter.L("open_browser"), Material("icon16/world_go.png"))
    openBtn:Dock(RIGHT); openBtn:SetWide(140); openBtn:DockMargin(6, 3, 6, 3)

    local installBtn = MakeAccentButton(bottom, Trainfitter.L("apply"))
    installBtn:Dock(RIGHT); installBtn:SetWide(130); installBtn:DockMargin(6, 3, 6, 3)

    local function Refresh()
        local q = string.lower(searchEntry:GetValue() or "")
        list:Clear()
        for _, wsid in ipairs(Trainfitter.PersistentList or {}) do
            local info  = Trainfitter.LastMountInfo[wsid]
            local title = (info and info.title) or Trainfitter.L("not_downloaded_yet")
            local size  = info and info.size or 0
            local hay   = string.lower(wsid .. " " .. title)
            if q == "" or string.find(hay, q, 1, true) then
                list:AddLine(wsid, title, FmtSize(size)).wsid = wsid
            end
        end
    end

    searchEntry.OnChange = Refresh
    refreshBtn.DoClick   = function() Trainfitter.RequestList() end

    installBtn.DoClick = function()
        local _, line = list:GetSelectedLine()
        if not line or not line.wsid then return end
        Trainfitter.Request(line.wsid, false)
    end
    removeBtn.DoClick = function()
        local _, line = list:GetSelectedLine()
        if not line or not line.wsid then return end
        Trainfitter.RemovePersistent(line.wsid)
    end
    openBtn.DoClick = function()
        local _, line = list:GetSelectedLine()
        if not line or not line.wsid then return end
        gui.OpenURL("https://steamcommunity.com/sharedfiles/filedetails/?id=" .. line.wsid)
    end

    hook.Add("Trainfitter.PersistentUpdated", view, Refresh)
    hook.Add("Trainfitter.AddonMounted",      view, Refresh)

    Refresh()
    return view
end

local function MakeHistoryCard(parent, entry)
    local card = vgui.Create("DPanel", parent)
    card:SetTall(86)
    card:DockMargin(0, 0, 0, 8)
    card.hoverFrac = 0
    card.Paint = function(self, w, h)
        self.hoverFrac = Lerp(FrameTime() * 10, self.hoverFrac, self:IsHovered() and 1 or 0)
        local c = LerpColor(self.hoverFrac, C.bg_item, C.bg_hover)
        draw.RoundedBox(8, 0, 0, w, h, c)
        local statusCol = entry.ok and C.ok or C.err
        surface.SetDrawColor(statusCol.r, statusCol.g, statusCol.b, 220)
        surface.DrawRect(0, 10, 3, h - 20)
        if self.hoverFrac > 0.05 then
            surface.SetDrawColor(C.accent.r, C.accent.g, C.accent.b, 24 * self.hoverFrac)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
    end

    local delBtn = MakeFlatButton(card, "")
    delBtn.icon = Material("icon16/delete.png")
    delBtn:Dock(RIGHT); delBtn:SetWide(36); delBtn:DockMargin(4, 14, 12, 14)
    delBtn:SetTooltip(Trainfitter.L("delete_history"))
    delBtn.DoClick = function()
        if Trainfitter.RemoveFromHistory then
            Trainfitter.RemoveFromHistory(entry.wsid)
        end
    end

    local openBtn = MakeFlatButton(card, "")
    openBtn.icon = Material("icon16/world_go.png")
    openBtn:Dock(RIGHT); openBtn:SetWide(36); openBtn:DockMargin(4, 14, 4, 14)
    openBtn:SetTooltip(Trainfitter.L("open_browser"))
    openBtn.DoClick = function()
        gui.OpenURL("https://steamcommunity.com/sharedfiles/filedetails/?id=" .. entry.wsid)
    end

    local installBtn = MakeAccentButton(card, Trainfitter.L("apply"))
    installBtn:Dock(RIGHT); installBtn:SetWide(120); installBtn:DockMargin(4, 14, 4, 14)
    installBtn.DoClick = function() Trainfitter.Request(entry.wsid, false) end

    local img = vgui.Create("DImage", card)
    img:Dock(LEFT); img:SetWide(72); img:DockMargin(12, 12, 8, 12)
    local localPath = PREVIEW_DIR .. "/" .. entry.wsid .. ".png"
    if file.Exists(localPath, "DATA") then
        SafeSetImage(img, "../data/" .. localPath)
    else
        img:SetVisible(false)
        img:SetWide(0); img:DockMargin(0, 0, 0, 0)
    end

    local middle = vgui.Create("DPanel", card)
    middle:Dock(FILL); middle:DockMargin(6, 10, 6, 10)
    middle.Paint = function() end

    local lbl = vgui.Create("DLabel", middle)
    lbl:Dock(TOP); lbl:SetTall(22)
    lbl:SetFont("Trainfitter.H2")
    lbl:SetText(entry.title ~= "" and entry.title or Trainfitter.L("no_title"))
    lbl:SetTextColor(C.text)

    local meta = vgui.Create("DLabel", middle)
    meta:Dock(TOP); meta:SetTall(16)
    meta:SetFont("Trainfitter.Small")
    meta:SetText(string.format("WSID %s  •  %s  •  %s",
        entry.wsid, FmtTime(entry.time), FmtSize(entry.size)))
    meta:SetTextColor(C.muted)

    local chip = vgui.Create("DLabel", middle)
    chip:Dock(TOP); chip:SetTall(16)
    chip:SetFont("Trainfitter.Small")
    chip:SetText(entry.ok and Trainfitter.L("history_ok") or Trainfitter.L("history_err"))
    chip:SetTextColor(entry.ok and C.ok or C.err)

    return card
end

local function BuildHistoryView(parent)
    local view = vgui.Create("DPanel", parent)
    view.Paint = function() end
    view:DockPadding(12, 12, 12, 12)

    local headerRow = vgui.Create("DPanel", view)
    headerRow:Dock(TOP); headerRow:SetTall(32); headerRow:DockMargin(0, 0, 0, 4)
    headerRow.Paint = function() end

    local h = vgui.Create("DLabel", headerRow)
    h:Dock(FILL); h:SetFont("Trainfitter.H1"); h:SetText(Trainfitter.L("history_title"))
    h:SetTextColor(C.text)

    local clearBtn = MakeFlatButton(headerRow, Trainfitter.L("clear_history"), Material("icon16/bin_empty.png"))
    clearBtn:Dock(RIGHT); clearBtn:SetWide(180); clearBtn:DockMargin(4, 0, 0, 0)
    clearBtn.DoClick = function()
        local count = #(Trainfitter.History or {})
        if count == 0 then return end
        Derma_Query(
            Trainfitter.L("clear_history_confirm", count),
            Trainfitter.L("clear_history"),
            Trainfitter.L("clear_history"), function()
                if Trainfitter.ClearHistory then Trainfitter.ClearHistory() end
            end,
            Trainfitter.L("cancel"), function() end
        )
    end

    local hint = vgui.Create("DLabel", view)
    hint:Dock(TOP); hint:DockMargin(0, 0, 0, 10); hint:SetTall(16)
    hint:SetFont("Trainfitter.Small")
    hint:SetText(Trainfitter.L("history_hint"))
    hint:SetTextColor(C.muted)

    local scroll = vgui.Create("DScrollPanel", view)
    scroll:Dock(FILL)
    scroll:GetCanvas():DockPadding(0, 0, 12, 0)

    local emptyLbl = vgui.Create("DLabel", scroll)
    emptyLbl:SetFont("Trainfitter.Body")
    emptyLbl:SetText(Trainfitter.L("history_empty"))
    emptyLbl:SetTextColor(C.muted)
    emptyLbl:SetContentAlignment(5)
    emptyLbl:Dock(TOP); emptyLbl:SetTall(60)

    local cards = {}

    local function Refresh()
        for _, c in ipairs(cards) do if IsValid(c) then c:Remove() end end
        cards = {}

        local history = Trainfitter.History or {}
        emptyLbl:SetVisible(#history == 0)

        for _, entry in ipairs(history) do
            local card = MakeHistoryCard(scroll, entry)
            card:Dock(TOP)
            cards[#cards + 1] = card
        end
        scroll:InvalidateLayout(true)
    end

    hook.Add("Trainfitter.AddonMounted", view, Refresh)
    hook.Add("Trainfitter.HistoryUpdated", view, Refresh)
    timer.Create("Trainfitter.HistoryRefresh." .. tostring(view), 2, 0, function()
        if not IsValid(view) then timer.Remove("Trainfitter.HistoryRefresh." .. tostring(view)); return end
        if view:IsVisible() then Refresh() end
    end)

    Refresh()
    return view
end

local CVAR_LABELS = {
    trainfitter_max_mb               = "Лимит размера аддона, МБ",
    trainfitter_require_admin        = "Только админы могут качать",
    trainfitter_request_cooldown     = "Кулдаун запроса, сек",
    trainfitter_max_persistent       = "Макс. в избранном",
    trainfitter_audit_log            = "Вести audit.log",
    trainfitter_use_whitelist        = "Использовать whitelist",
    trainfitter_stats_enabled        = "Вести статистику",
    trainfitter_server_premount      = "Сервер сам маунтит избранное",
}

local function BuildSettingsView(parent)
    local view = vgui.Create("DPanel", parent)
    view.Paint = function() end
    view:DockPadding(12, 12, 12, 12)

    local h = vgui.Create("DLabel", view)
    h:Dock(TOP); h:DockMargin(0, 0, 0, 4)
    h:SetFont("Trainfitter.H1"); h:SetText(Trainfitter.L("settings_title")); h:SetTextColor(C.text)
    h:SetTall(28)

    local hint = vgui.Create("DLabel", view)
    hint:Dock(TOP); hint:DockMargin(0, 0, 0, 10)
    hint:SetFont("Trainfitter.Small")
    hint:SetText(Trainfitter.L("settings_hint"))
    hint:SetTextColor(C.muted); hint:SetTall(16)

    local scroll = vgui.Create("DScrollPanel", view)
    scroll:Dock(FILL)
    scroll:GetCanvas():DockPadding(0, 0, 8, 0)

    local loading = vgui.Create("DLabel", scroll)
    loading:Dock(TOP); loading:SetTall(24)
    loading:SetFont("Trainfitter.Body"); loading:SetText(Trainfitter.L("settings_loading"))
    loading:SetTextColor(C.muted)

    local rows = {}

    local function ClearRows()
        for _, r in ipairs(rows) do if IsValid(r) then r:Remove() end end
        rows = {}
    end

    local function MakeRow(c)
        local row = vgui.Create("DPanel", scroll)
        row:Dock(TOP); row:SetTall(46); row:DockMargin(0, 0, 0, 6)
        row.Paint = function(_, w, hh) draw.RoundedBox(8, 0, 0, w, hh, C.bg_item) end

        local wrap = vgui.Create("DPanel", row)
        wrap:Dock(FILL); wrap:DockMargin(14, 6, 8, 6); wrap.Paint = function() end

        local pretty = vgui.Create("DLabel", wrap)
        pretty:Dock(TOP); pretty:SetTall(18)
        pretty:SetFont("Trainfitter.Body")
        pretty:SetText(CVAR_LABELS[c.name] or c.name)
        pretty:SetTextColor(C.text)

        local cvarLbl = vgui.Create("DLabel", wrap)
        cvarLbl:Dock(TOP); cvarLbl:SetTall(14)
        cvarLbl:SetFont("Trainfitter.Small")
        cvarLbl:SetText(c.name)
        cvarLbl:SetTextColor(C.muted)

        if c.kind == "bool" then
            local cb = vgui.Create("DCheckBox", row)
            cb:Dock(RIGHT); cb:DockMargin(8, 14, 16, 14); cb:SetWide(18)
            cb:SetChecked(c.value == "1")
            cb.OnChange = function(_, val)
                Trainfitter.AdminSetConVar(c.name, val and "1" or "0")
            end
        else
            local entry = MakeEntry(row)
            entry:Dock(RIGHT); entry:DockMargin(8, 10, 14, 10); entry:SetWide(130)
            entry:SetNumeric(true); entry:SetText(c.value or "")
            entry.OnEnter = function(s) Trainfitter.AdminSetConVar(c.name, s:GetValue()) end
            entry.OnFocusChanged = function(s, gained)
                if not gained then Trainfitter.AdminSetConVar(c.name, s:GetValue()) end
            end
        end

        return row
    end

    local function MakeSkinRow(wsid, info, tag)
        local row = vgui.Create("DPanel", scroll)
        row:Dock(TOP); row:SetTall(54); row:DockMargin(0, 0, 0, 6)
        row.Paint = function(_, w, hh) draw.RoundedBox(8, 0, 0, w, hh, C.bg_item) end

        local wrap = vgui.Create("DPanel", row)
        wrap:Dock(FILL); wrap:DockMargin(14, 6, 8, 6); wrap.Paint = function() end

        local title = vgui.Create("DLabel", wrap)
        title:Dock(TOP); title:SetTall(20)
        title:SetFont("Trainfitter.Body")
        title:SetText((info and info.title and info.title ~= "") and info.title or Trainfitter.L("no_title"))
        title:SetTextColor(C.text)

        local meta = vgui.Create("DLabel", wrap)
        meta:Dock(TOP); meta:SetTall(14)
        meta:SetFont("Trainfitter.Small")
        local sizeStr = info and info.size and FmtSize(info.size) or "?"
        meta:SetText(string.format("WSID %s  •  %s  •  %s", wsid, tag, sizeStr))
        meta:SetTextColor(C.muted)

        local delBtn = MakeFlatButton(row, Trainfitter.L("remove"), Material("icon16/delete.png"))
        delBtn:Dock(RIGHT); delBtn:DockMargin(8, 12, 14, 12); delBtn:SetWide(120)
        delBtn.DoClick = function()
            Derma_Query(
                Trainfitter.L("delete_confirm", wsid),
                Trainfitter.L("delete_title"),
                Trainfitter.L("remove"), function() Trainfitter.DeleteSkin(wsid) end,
                Trainfitter.L("cancel"),  function() end
            )
        end
        return row
    end

    local function CollectSkins()
        local seen = {}
        local list = {}

        local function add(wsid, tag)
            if not wsid or wsid == "" or seen[wsid] then return end
            seen[wsid] = true
            table.insert(list, {
                wsid = wsid,
                info = Trainfitter.LastMountInfo[wsid],
                tag  = tag,
            })
        end

        local a = Trainfitter.ActiveSkin
        if a and a.wsid then add(a.wsid, Trainfitter.L("chip_active")) end
        for _, w in ipairs(Trainfitter.PersistentList or {}) do add(w, Trainfitter.L("chip_persistent")) end
        for _, h in ipairs(Trainfitter.History or {}) do
            if h.ok then add(h.wsid, Trainfitter.L("chip_downloaded")) end
        end
        for w in pairs(Trainfitter.Mounted or {}) do add(w, Trainfitter.L("chip_mounted")) end

        return list
    end

    local function Rebuild(cfg)
        ClearRows()

        if not cfg or not cfg.cvars or #cfg.cvars == 0 then
            loading:SetVisible(true)
            loading:SetText(cfg and not cfg.canManage
                and Trainfitter.L("settings_no_perm")
                or  Trainfitter.L("settings_loading"))
        else
            loading:SetVisible(false)
            for _, c in ipairs(cfg.cvars) do
                rows[#rows + 1] = MakeRow(c)
            end
        end

        local skins = CollectSkins()

        local sep = vgui.Create("DLabel", scroll)
        sep:Dock(TOP); sep:SetTall(30); sep:DockMargin(0, 14, 0, 4)
        sep:SetFont("Trainfitter.H2")
        sep:SetText(Trainfitter.L("active_skins", #skins))
        sep:SetTextColor(C.text)
        rows[#rows + 1] = sep

        if #skins == 0 then
            local empty = vgui.Create("DLabel", scroll)
            empty:Dock(TOP); empty:SetTall(24); empty:DockMargin(0, 0, 0, 6)
            empty:SetFont("Trainfitter.Small")
            empty:SetText(Trainfitter.L("no_active_skins"))
            empty:SetTextColor(C.muted)
            rows[#rows + 1] = empty
        else
            for _, s in ipairs(skins) do
                rows[#rows + 1] = MakeSkinRow(s.wsid, s.info, s.tag)
            end
        end

        scroll:InvalidateLayout(true)
    end

    Rebuild(Trainfitter.AdminConfig)
    hook.Add("Trainfitter.AdminConfigUpdated", view, function(cfg) Rebuild(cfg) end)
    hook.Add("Trainfitter.SkinForgotten",      view, function() Rebuild(Trainfitter.AdminConfig) end)
    hook.Add("Trainfitter.ActiveSkinChanged",  view, function() Rebuild(Trainfitter.AdminConfig) end)
    hook.Add("Trainfitter.PersistentUpdated",  view, function() Rebuild(Trainfitter.AdminConfig) end)
    hook.Add("Trainfitter.AddonMounted",       view, function() Rebuild(Trainfitter.AdminConfig) end)

    view.OnShowView = function()
        if Trainfitter.AdminGetConfig then Trainfitter.AdminGetConfig() end
    end

    return view
end

local activeFrame = nil

function Trainfitter.OpenMenu()
    if IsValid(activeFrame) then activeFrame:Close() activeFrame = nil end

    Trainfitter.AdminConfig = nil

    local frame = vgui.Create("DFrame")
    frame:SetSize(math.min(ScrW() - 80, 960), math.min(ScrH() - 80, 620))
    frame:Center(); frame:SetDeleteOnClose(true); frame:MakePopup()
    frame:ShowCloseButton(false)
    frame:SetTitle("")
    frame:SetDraggable(true)
    activeFrame = frame

    frame.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, C.bg)
        surface.SetDrawColor(C.border_soft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local topBar = vgui.Create("DPanel", frame)
    topBar:Dock(TOP); topBar:SetTall(48); topBar:DockMargin(0, 0, 0, 0)
    topBar.Paint = function() end

    local brandLbl = vgui.Create("DLabel", topBar)
    brandLbl:Dock(LEFT); brandLbl:DockMargin(16, 0, 0, 0); brandLbl:SetWide(220)
    brandLbl:SetFont("Trainfitter.H1")
    brandLbl:SetText("Trainfitter v" .. (Trainfitter.Version or ""))
    brandLbl:SetTextColor(C.text)

    local langCombo = vgui.Create("DComboBox", topBar)
    langCombo:Dock(RIGHT); langCombo:DockMargin(0, 10, 10, 10); langCombo:SetWide(140)
    langCombo:SetFont("Trainfitter.Body")
    langCombo:SetSortItems(false)
    for _, code in ipairs(Trainfitter.SupportedLanguages or {}) do
        local tbl = Trainfitter.Lang[code]
        if tbl then langCombo:AddChoice(tbl.label or code, code, code == Trainfitter.GetLang()) end
    end
    langCombo.OnSelect = function(_, _, _, data)
        if not isstring(data) or data == Trainfitter.GetLang() then return end
        RunConsoleCommand("trainfitter_lang", data)
        timer.Simple(0.1, function()
            if IsValid(frame) then frame:Close() end
            timer.Simple(0.05, function()
                if Trainfitter.OpenMenu then Trainfitter.OpenMenu() end
            end)
        end)
    end

    local activeLbl = vgui.Create("DLabel", topBar)
    activeLbl:Dock(FILL); activeLbl:DockMargin(0, 0, 10, 0)
    activeLbl:SetFont("Trainfitter.Body"); activeLbl:SetTextColor(C.muted)
    activeLbl:SetContentAlignment(5)

    local function RefreshActive()
        if not IsValid(activeLbl) then return end
        local a = Trainfitter.ActiveSkin
        if a then
            local t = a.title ~= "" and a.title or a.wsid
            activeLbl:SetText(Trainfitter.L("active_label", t))
            activeLbl:SetTextColor(C.ok)
        else
            activeLbl:SetText(Trainfitter.L("no_active_label"))
            activeLbl:SetTextColor(C.muted)
        end
    end
    RefreshActive()
    hook.Add("Trainfitter.ActiveSkinChanged", frame, RefreshActive)

    local closeBtn = MakeCloseButton(topBar)
    closeBtn:Dock(RIGHT); closeBtn:DockMargin(0, 8, 10, 8)
    closeBtn.DoClick = function() frame:Close() end

    local sep = vgui.Create("DPanel", frame)
    sep:Dock(TOP); sep:SetTall(1)
    sep.Paint = function(_, w, h) surface.SetDrawColor(C.border); surface.DrawRect(0, 0, w, h) end

    local body = vgui.Create("DPanel", frame)
    body:Dock(FILL); body:DockPadding(10, 10, 10, 10)
    body.Paint = function() end

    local nav = vgui.Create("DPanel", body)
    nav:Dock(LEFT); nav:SetWide(184); nav:DockMargin(0, 0, 10, 0)
    nav.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, C.bg_panel)
        surface.SetDrawColor(C.border_soft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    nav:DockPadding(8, 8, 8, 8)

    local content = vgui.Create("DPanel", body)
    content:Dock(FILL)
    content.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, C.bg_panel)
        surface.SetDrawColor(C.border_soft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local views = {}
    local navItems = {}
    local currentView = nil

    local function ShowView(name)
        if currentView then currentView:SetVisible(false) end
        currentView = views[name]
        if currentView then
            currentView:SetVisible(true)
            if isfunction(currentView.OnShowView) then
                currentView:OnShowView()
            end
            content:InvalidateLayout(true)
        end
        for n, item in pairs(navItems) do
            item.active = (n == name)
        end
    end

    views.install   = BuildInstallView(content);   views.install:Dock(FILL);   views.install:SetVisible(false)
    views.favorites = BuildFavoritesView(content); views.favorites:Dock(FILL); views.favorites:SetVisible(false)
    views.history   = BuildHistoryView(content);   views.history:Dock(FILL);   views.history:SetVisible(false)
    views.settings  = BuildSettingsView(content);  views.settings:Dock(FILL);  views.settings:SetVisible(false)

    local function AddNav(name, label, iconPath)
        local item = MakeNavItem(nav, label, iconPath, name == "install")
        item:Dock(TOP); item:DockMargin(0, 0, 0, 4)
        item.DoClick = function() ShowView(name) end
        navItems[name] = item
        return item
    end

    AddNav("install",   Trainfitter.L("nav_install"),   "icon16/accept.png")
    AddNav("favorites", Trainfitter.L("nav_favorites"), "icon16/star.png")
    AddNav("history",   Trainfitter.L("nav_history"),   "icon16/clock.png")

    local settingsItem = AddNav("settings", Trainfitter.L("nav_settings"), "icon16/cog.png")
    settingsItem:SetVisible(false)

    if views.settings then
        views.settings.Reopen = function()
            if IsValid(frame) then
                frame:Close()
                Trainfitter.OpenMenu()
            end
        end
    end

    local function RefreshAdminVis()
        if not IsValid(settingsItem) then return end
        local cfg = Trainfitter.AdminConfig
        settingsItem:SetVisible(cfg and cfg.canManage == true)
    end
    RefreshAdminVis()
    hook.Add("Trainfitter.AdminConfigUpdated", frame, RefreshAdminVis)

    if Trainfitter.AdminGetConfig then Trainfitter.AdminGetConfig() end
    if Trainfitter.RequestList        then Trainfitter.RequestList()        end
    if Trainfitter.RequestServerStatus then Trainfitter.RequestServerStatus() end

    ShowView("install")
end