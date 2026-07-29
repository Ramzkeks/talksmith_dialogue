local TS = Talksmith
TS.Editor.Theme = {
    bar = Color(18, 21, 24),
    side = Color(22, 26, 29),
    canvas = Color(13, 17, 19),
    gridMinor = Color(24, 30, 32),
    gridMajor = Color(31, 39, 42),
    card = Color(31, 37, 40),
    cardHead = Color(39, 47, 50),
    field = Color(16, 20, 22),
    fieldFocus = Color(21, 29, 31),
    line = Color(55, 66, 69),
    lineSoft = Color(40, 49, 52),
    blue = Color(78, 164, 176),
    green = Color(91, 170, 120),
    red = Color(205, 91, 82),
    yellow = Color(210, 162, 72),
    teal = Color(78, 164, 176),
    purple = Color(145, 122, 188),
    text = Color(235, 239, 237),
    muted = Color(169, 180, 178),
    dim = Color(125, 138, 137),
    hover = Color(255, 255, 255, 8),
    selection = Color(78, 164, 176, 34),
    accentSoft = Color(78, 164, 176, 22),
    dangerSoft = Color(205, 91, 82, 20),
}
TS.Editor.NodePalette = {
    Color(39, 47, 50),
    Color(47, 67, 76),
    Color(47, 72, 58),
    Color(80, 55, 52),
    Color(80, 69, 47),
    Color(68, 57, 82),
}

TS.Editor.ModalPanelStack = TS.Editor.ModalPanelStack or {}

local function cleanModalPanelStack()
    local stack = TS.Editor.ModalPanelStack
    local cleaned = {}
    for _, panel in ipairs(stack) do
        if IsValid(panel) and panel:IsVisible() then
            cleaned[#cleaned + 1] = panel
        end
    end
    TS.Editor.ModalPanelStack = cleaned
    return cleaned
end

function TS.Editor.GetActiveModalPanel()
    local stack = cleanModalPanelStack()
    return stack[#stack]
end

function TS.Editor.SyncModalPanels(forceFocus)
    local stack = cleanModalPanelStack()
    local top = stack[#stack]
    local changed = TS.Editor.ActiveModalPanel ~= top
    TS.Editor.ActiveModalPanel = top

    local restoreCursorX = changed and not forceFocus and TS.Editor.ModalCursorX or nil
    local restoreCursorY = changed and not forceFocus and TS.Editor.ModalCursorY or nil
    if IsValid(top) and not changed and system.HasFocus() ~= false then
        TS.Editor.ModalCursorX, TS.Editor.ModalCursorY = input.GetCursorPos()
    end

    for _, panel in ipairs(stack) do
        local active = panel == top
        panel:SetMouseInputEnabled(active)
        panel:SetKeyboardInputEnabled(active)
    end

    local editor = TS.Editor.Frame
    if IsValid(editor) and editor ~= top then
        local enabled = not IsValid(top)
        editor:SetMouseInputEnabled(enabled)
        editor:SetKeyboardInputEnabled(enabled)
    end

    if IsValid(top) then
        top:SetMouseInputEnabled(true)
        top:SetKeyboardInputEnabled(true)
        if forceFocus then
            top:MakePopup()
            if top._talksmithDermaModal and top.DoModal then
                top:DoModal()
            end
        end
        if changed or forceFocus then
            top:MoveToFront()
        end
    elseif changed and IsValid(editor) then
        editor:SetMouseInputEnabled(true)
        editor:SetKeyboardInputEnabled(true)
        editor:MoveToFront()
    end

    if isnumber(restoreCursorX) and isnumber(restoreCursorY)
        and system.HasFocus() ~= false
        and not gui.IsConsoleVisible()
        and not gui.IsGameUIVisible()
    then
        input.SetCursorPos(restoreCursorX, restoreCursorY)
        timer.Simple(0, function()
            if system.HasFocus() ~= false and not gui.IsConsoleVisible() and not gui.IsGameUIVisible() then
                input.SetCursorPos(restoreCursorX, restoreCursorY)
            end
        end)
    end

    return top
end

function TS.Editor.ActivateModalPanel(panel, dermaModal)
    if not IsValid(panel) then
        return
    end

    local stack = cleanModalPanelStack()
    for index = #stack, 1, -1 do
        if stack[index] == panel then
            table.remove(stack, index)
        end
    end
    stack[#stack + 1] = panel
    TS.Editor.ModalPanelStack = stack
    if dermaModal ~= nil then
        panel._talksmithDermaModal = dermaModal == true
    end
    TS.Editor.SyncModalPanels(true)
end

function TS.Editor.RegisterModalPanel(panel, dermaModal)
    if not IsValid(panel) then
        return panel
    end
    panel._talksmithManagedModal = true
    TS.Editor.ActivateModalPanel(panel, dermaModal)
    return panel
end

hook.Add('Think', 'Talksmith.SyncModalPanels', function()
    TS.Editor.SyncModalPanels(false)
end)
local iconCache = {}
function TS.Editor.IconMaterial(name)
    if not isstring(name) or name == "" then
        return nil
    end
    local mat = iconCache[name]
    if mat == nil then
        mat = Material("talksmith/ui/" .. name .. ".png", "smooth mips")
        iconCache[name] = mat
    end
    return mat
end

function TS.Editor.DrawIcon(name, x, y, size, color)
    local mat = TS.Editor.IconMaterial(name)
    if not mat or mat:IsError() then
        return false
    end
    surface.SetMaterial(mat)
    if color then
        surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
    else
        surface.SetDrawColor(255, 255, 255, 255)
    end
    surface.DrawTexturedRect(x, y, size, size)
    return true
end

function TS.Editor.BuildFonts()
    local s = math.Clamp(ScrH() / 1080, 0.85, 1.7)
    local nodeScale = math.Clamp(ScrH() / 1080, 0.85, 1)
    local faces = {
        regular = "Manrope",
        medium = "Manrope Medium",
        semibold = "Manrope SemiBold",
        bold = "Manrope",
    }
    local function f(name, face, size, weight)
        surface.CreateFont(name, {
            font = faces[face],
            size = math.Round(size * s),
            weight = weight,
            extended = true,
            antialias = true,
        })
    end
    local function nodeFont(name, face, size, weight)
        surface.CreateFont(name, {
            font = faces[face],
            size = math.max(5, math.Round(size * nodeScale)),
            weight = weight,
            extended = true,
            antialias = true,
        })
    end
    f("Talksmith_E_Display", "bold", 22, 700)
    f("Talksmith_E_Title", "bold", 19, 700)
    f("Talksmith_E_Head", "semibold", 16, 600)
    f("Talksmith_E_Body", "regular", 15, 400)
    f("Talksmith_E_Small", "medium", 14, 500)
    f("Talksmith_E_Tiny", "semibold", 12, 600)
    f("Talksmith_E_Mono", "medium", 14, 500)
    f("Talksmith_E_HelpTitle", "bold", 27, 700)
    f("Talksmith_E_HelpHead", "semibold", 19, 600)
    f("Talksmith_E_HelpBody", "regular", 17, 400)
    f("Talksmith_E_HelpKey", "semibold", 16, 600)

    local nodeFonts = {
        Micro = { body = 8, small = 8, tiny = 7 },
        Compact = { body = 14, small = 13, tiny = 9 },
        Medium = { body = 16, small = 14, tiny = 11 },
        Normal = { body = 18, small = 16, tiny = 13 },
        Large = { body = 21, small = 19, tiny = 15 },
        XLarge = { body = 24, small = 22, tiny = 17 },
        XXLarge = { body = 27, small = 25, tiny = 19 },
    }
    for level, sizes in pairs(nodeFonts) do
        nodeFont("Talksmith_E_NodeBody_" .. level, "regular", sizes.body, 400)
        nodeFont("Talksmith_E_NodeSmall_" .. level, "medium", sizes.small, 500)
        nodeFont("Talksmith_E_NodeTiny_" .. level, "semibold", sizes.tiny, 600)
    end
end
TS.Editor.BuildFonts()

hook.Add("OnScreenSizeChanged", "Talksmith.EditorRefont", function()
    TS.Editor.BuildFonts()
end)

local TOOLTIP = {}

function TOOLTIP:Init()
    self:SetDrawOnTop(true)
    self.DeleteContentsOnClose = false
    self:SetText("")
    self:SetFont("Talksmith_E_Small")
    self:SetTextColor(TS.Editor.Theme.text)
    self:SetContentAlignment(5)
end

function TOOLTIP:UpdateColours()
    self:SetTextColor(TS.Editor.Theme.text)
end

function TOOLTIP:Paint(w, h)
    self:PositionTooltip()
    draw.RoundedBox(4, 0, 0, w, h, TS.Editor.Theme.bar)
    surface.SetDrawColor(TS.Editor.Theme.line)
    surface.DrawOutlinedRect(0, 0, w, h, 1)
end

vgui.Register("TalksmithTooltip", TOOLTIP, "DTooltip")

function TS.Editor.SetTooltip(panel, text)
    if not IsValid(panel) then return panel end
    panel:SetTooltip(text)
    panel:SetTooltipPanelOverride("TalksmithTooltip")
    return panel
end

function TS.Editor.StyleButton(b, opts)
    opts = opts or {}
    local T = TS.Editor.Theme
    b:SetText("")
    b._talksmithStyleOptions = opts
    b.SetStyleLabel = function(s, label)
        s._talksmithStyleOptions.label = label or ""
        return s
    end
    b.hover = 0
    b.Paint = function(s, w, h)
        local disabled = s:GetDisabled()
        s.hover = Lerp(FrameTime() * 12, s.hover, (s:IsHovered() and not disabled) and 1 or 0)
        local base = T.card
        if disabled and opts.accent then
            base = T.card
        elseif opts.accent then
            base = T.blue
        elseif opts.danger then
            base = T.dangerSoft
        elseif opts.quiet then
            base = (s:IsHovered() and not disabled) and T.card or Color(0, 0, 0, 0)
        elseif opts.active then
            base = T.accentSoft
        end
        draw.RoundedBox(opts.square and 3 or 4, 0, 0, w, h, base)
        if s.hover > 0 then
            draw.RoundedBox(opts.square and 3 or 4, 0, 0, w, h, Color(255, 255, 255, 9 * s.hover))
        end
        if not opts.quiet or opts.active then
            local outline = (not disabled and (opts.accent or opts.active)) and T.blue or T.line
            surface.SetDrawColor(outline)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
        if s:HasFocus() then
            surface.SetDrawColor(T.blue)
            surface.DrawOutlinedRect(1, 1, w - 2, h - 2, 1)
        end
        local col
        if disabled then
            col = T.dim
        elseif opts.danger then
            col = T.red
        elseif opts.accent then
            col = T.canvas
        else
            col = T.text
        end
        local label = opts.label or ""
        local hasIcon = opts.icon and opts.icon ~= ""
        local hasIconR = opts.iconRight and opts.iconRight ~= ""
        if hasIcon or hasIconR then
            local isize = math.min(opts.iconSize or 18, h - 6)
            local iy = math.floor((h - isize) / 2)
            local gap = 7
            if label == "" then
                TS.Editor.DrawIcon(hasIcon and opts.icon or opts.iconRight, math.floor((w - isize) / 2), iy, isize, col)
            elseif opts.alignLeft then
                local x = 10
                if hasIcon then
                    TS.Editor.DrawIcon(opts.icon, x, iy, isize, col)
                    x = x + isize + gap
                end
                draw.SimpleText(label, opts.font or "Talksmith_E_Body", x, h / 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                if hasIconR then
                    TS.Editor.DrawIcon(opts.iconRight, w - 10 - isize, iy, isize, col)
                end
            else
                surface.SetFont(opts.font or "Talksmith_E_Body")
                local tw = surface.GetTextSize(label)
                local groupW = tw
                if hasIcon then groupW = groupW + isize + gap end
                if hasIconR then groupW = groupW + isize + gap end
                local x = math.floor((w - groupW) / 2)
                if hasIcon then
                    TS.Editor.DrawIcon(opts.icon, x, iy, isize, col)
                    x = x + isize + gap
                end
                draw.SimpleText(label, opts.font or "Talksmith_E_Body", x, h / 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                x = x + tw + gap
                if hasIconR then
                    TS.Editor.DrawIcon(opts.iconRight, x, iy, isize, col)
                end
            end
        else
            draw.SimpleText(
                label,
                opts.font or "Talksmith_E_Body",
                opts.alignLeft and 10 or w / 2,
                h / 2,
                col,
                opts.alignLeft and TEXT_ALIGN_LEFT or TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER
            )
        end
    end
    return b
end

function TS.Editor.StyleEntry(e)
    local T = TS.Editor.Theme
    e:SetFont("Talksmith_E_Body")
    e:SetTextColor(T.text)
    e:SetCursorColor(T.text)
    e:SetPaintBackground(false)
    local old = e.Paint
    e.Paint = function(s, w, h)
        draw.RoundedBox(3, 0, 0, w, h, s:HasFocus() and T.fieldFocus or T.field)
        surface.SetDrawColor(s:HasFocus() and T.blue or T.lineSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        s:DrawTextEntryText(T.text, T.blue, T.text)
    end
    return e
end

function TS.Editor.StyleMenuOption(option, opts)
    if not IsValid(option) then return option end

    opts = opts or {}
    option._talksmithMenuLabel = opts.label or option._talksmithMenuLabel or option:GetText()
    option._talksmithMenuStyled = true
    option._talksmithMenuIcon = opts.icon or option._talksmithMenuIcon
    option._talksmithMenuDanger = opts.danger or false
    option._talksmithMenuAccent = opts.accent or false
    option._talksmithMenuHover = option._talksmithMenuHover or 0
    option._talksmithMenuTall = opts.tall or 32
    option:SetTall(option._talksmithMenuTall)
    option:SetFont("Talksmith_E_Small")
    option:SetTextColor(TS.Editor.Theme.text)
    option:SetText("")

    option.Paint = function(s, w, h)
        local T = TS.Editor.Theme
        local disabled = s.GetDisabled and s:GetDisabled()
        local target = (not disabled and s:IsHovered()) and 1 or 0
        s._talksmithMenuHover = Lerp(math.min(FrameTime() * 18, 1), s._talksmithMenuHover or 0, target)

        if s._talksmithMenuHover > 0.01 then
            local col = s._talksmithMenuDanger and T.dangerSoft or T.accentSoft
            draw.RoundedBox(4, 4, 2, w - 8, h - 4, Color(col.r, col.g, col.b, math.floor(col.a * s._talksmithMenuHover)))
        end

        if s:IsDown() and not disabled then
            local col = s._talksmithMenuDanger and T.red or T.blue
            draw.RoundedBox(4, 4, 2, w - 8, h - 4, Color(col.r, col.g, col.b, 28))
        end

        if s._talksmithMenuAccent and not disabled then
            draw.RoundedBox(1, 7, 8, 2, h - 16, T.blue)
        end

        local textColor = T.text
        if disabled then
            textColor = T.dim
        elseif s._talksmithMenuDanger then
            textColor = T.red
        elseif s._talksmithMenuAccent then
            textColor = T.blue
        end

        if s._talksmithMenuIcon then
            TS.Editor.DrawIcon(s._talksmithMenuIcon, 12, math.floor(h * 0.5 - 8), 16, textColor)
        end
        draw.SimpleText(s._talksmithMenuLabel or "", "Talksmith_E_Small", 34, h * 0.5, textColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    return option
end

function TS.Editor.StyleMenu(menu, minWidth)
    if not IsValid(menu) then return menu end

    local T = TS.Editor.Theme
    menu._talksmithMenuStyled = true
    menu._talksmithMenuMinWidth = minWidth or menu._talksmithMenuMinWidth or 220

    menu.Paint = function(_, w, h)
        draw.RoundedBox(5, 0, 0, w, h, T.bar)
        surface.SetDrawColor(T.line)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    return menu
end

function TS.Editor.ClosePopupMenu()
    local menu = TS.Editor.PopupMenu
    TS.Editor.PopupMenu = nil
    if IsValid(menu) and menu.Close then
        menu:Close()
    end
end

function TS.Editor.CreateMenu(minWidth)
    local overlay = vgui.Create("EditablePanel")
    overlay:SetSize(ScrW(), ScrH())
    overlay:SetPos(0, 0)
    overlay:SetVisible(false)
    overlay:SetDrawOnTop(true)
    overlay.Paint = function() end

    local menu = overlay:Add("DPanel")
    menu:SetVisible(false)
    menu:SetMouseInputEnabled(true)
    menu.Items = {}
    menu._talksmithMenuMinWidth = minWidth or 220
    TS.Editor.StyleMenu(menu, minWidth)

    menu:DockPadding(0, 6, 0, 6)
    local scroll = menu:Add("DScrollPanel")
    scroll:Dock(FILL)
    menu._talksmithScroll = scroll
    do
        local bar = scroll:GetVBar()
        bar:SetWide(4)
        bar:SetHideButtons(true)
        bar.Paint = function() end
        bar.btnGrip.Paint = function(_, w, h)
            draw.RoundedBox(2, 0, 0, w, h, TS.Editor.Theme.line)
        end
    end

    local closing = false
    local function closeMenu()
        if closing then return end
        closing = true
        if TS.Editor.PopupMenu == menu then
            TS.Editor.PopupMenu = nil
        end
        if IsValid(overlay) then
            overlay:Remove()
        end
    end

    menu.Close = closeMenu
    menu.AddOption = function(s, label, callback)
        local option = scroll:Add("DButton")
        option._talksmithMenuLabel = label or ""
        option:Dock(TOP)
        option:DockMargin(5, 0, 6, 2)
        option:SetTall(32)
        option.DoClick = function()
            closeMenu()
            if callback then callback() end
        end
        TS.Editor.StyleMenuOption(option, { label = label })
        s.Items[#s.Items + 1] = option

        surface.SetFont("Talksmith_E_Small")
        s._talksmithMenuContentWidth = math.max(s._talksmithMenuContentWidth or 0, surface.GetTextSize(label or "") + 58)
        return option
    end
    menu.AddSpacer = function(s)
        local spacer = scroll:Add("DPanel")
        spacer:Dock(TOP)
        spacer:DockMargin(5, 0, 6, 2)
        spacer:SetTall(9)
        spacer.Paint = function(_, w, h)
            surface.SetDrawColor(TS.Editor.Theme.lineSoft)
            surface.DrawRect(9, math.floor(h * 0.5), math.max(w - 18, 0), 1)
        end
        s.Items[#s.Items + 1] = spacer
        return spacer
    end
    menu.Open = function(s, x, y)
        if TS.Editor.PopupMenu ~= s then
            TS.Editor.ClosePopupMenu()
        end
        TS.Editor.PopupMenu = s

        local content = 12
        for _, item in ipairs(s.Items) do
            if IsValid(item) then
                content = content + item:GetTall() + 2
            end
        end
        local height = math.min(content, ScrH() - 16)

        local width = math.max(s._talksmithMenuMinWidth or 220, s._talksmithMenuContentWidth or 0)
        x = x or gui.MouseX()
        y = y or gui.MouseY()
        x = math.Clamp(x, 8, math.max(ScrW() - width - 8, 8))
        y = math.Clamp(y, 8, math.max(ScrH() - height - 8, 8))

        overlay:SetVisible(true)
        TS.Editor.RegisterModalPanel(overlay)
        s:SetPos(x, y)
        s:SetSize(width, height)
        s:SetVisible(true)
        s:InvalidateLayout(true)
        s:MoveToFront()
    end

    overlay.OnMousePressed = function()
        closeMenu()
    end
    overlay.OnKeyCodePressed = function(_, key)
        if key == KEY_ESCAPE then
            closeMenu()
        end
    end
    overlay.Think = function()
        if gui.IsGameUIVisible() and not gui.IsConsoleVisible() then
            gui.HideGameUI()
            closeMenu()
        end
    end
    overlay.OnRemove = function()
        if TS.Editor.PopupMenu == menu then
            TS.Editor.PopupMenu = nil
        end
    end

    return menu
end

function TS.Editor.AddMenuOption(menu, label, callback, opts)
    opts = opts or {}

    opts.label = label
    local option = menu:AddOption(label, callback)
    if opts.enabled == false then option:SetEnabled(false) end
    TS.Editor.StyleMenuOption(option, opts)
    return option
end

function TS.Editor.AddMenuSpacer(menu)
    local spacer = menu:AddSpacer()
    spacer:SetTall(9)
    spacer.Paint = function(_, w, h)
        surface.SetDrawColor(TS.Editor.Theme.lineSoft)
        surface.DrawRect(9, math.floor(h * 0.5), math.max(w - 18, 0), 1)
    end
    return spacer
end

function TS.Editor.OpenModal(opts)
    opts = opts or {}
    local T = TS.Editor.Theme
    local actions = opts.actions or {}

    if IsValid(TS.Editor.Modal) then
        TS.Editor.Modal:Remove()
    end

    local frame = vgui.Create("DFrame")
    TS.Editor.Modal = frame
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    frame:SetSizable(false)
    frame:SetDeleteOnClose(true)
    frame:SetBackgroundBlur(true)
    frame:SetDrawOnTop(true)
    frame:DockPadding(0, 0, 0, 0)

    local hasEntry = opts.entry ~= nil
    local minWidth = #actions >= 3 and 520 or 460
    local width = math.min(math.Clamp(ScrW() * 0.38, minWidth, 560), ScrW() - 32)
    frame:SetSize(width, hasEntry and 226 or 184)
    frame:Center()
    frame.Paint = function(s, w, h)
        Derma_DrawBackgroundBlur(s, s.m_fCreateTime)
        draw.RoundedBox(7, 0, 0, w, h, T.side)
        surface.SetDrawColor(T.line)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local header = frame:Add("DPanel")
    header:Dock(TOP)
    header:SetTall(54)
    header.Paint = function(_, w, h)
        local danger = opts.danger or (actions[1] and actions[1].danger)
        draw.RoundedBox(2, 18, 15, 3, 24, danger and T.red or T.blue)
        draw.SimpleText(opts.title or "", "Talksmith_E_Head", 32, h * 0.5, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(T.lineSoft)
        surface.DrawRect(0, h - 1, w, 1)
    end

    local footer = frame:Add("DPanel")
    footer:Dock(BOTTOM)
    footer:SetTall(60)
    footer:DockPadding(12, 12, 12, 12)
    footer.Paint = function(_, w)
        surface.SetDrawColor(T.lineSoft)
        surface.DrawRect(0, 0, w, 1)
    end

    local body = frame:Add("DPanel")
    body:Dock(FILL)
    body:DockPadding(20, 14, 20, 14)
    body.Paint = function() end

    local message = body:Add("DLabel")
    message:Dock(hasEntry and TOP or FILL)
    message:SetTall(hasEntry and 38 or 0)
    message:SetFont("Talksmith_E_Body")
    message:SetTextColor(T.muted)
    message:SetWrap(true)
    message:SetContentAlignment(hasEntry and 4 or 5)
    message:SetText(opts.message or "")

    local entry
    if hasEntry then
        entry = body:Add("DTextEntry")
        entry:Dock(BOTTOM)
        entry:SetTall(36)
        entry:SetText(opts.entry or "")
        entry:SetUpdateOnType(true)
        TS.Editor.StyleEntry(entry)
    end

    local finished = false
    local function finish(action)
        if finished then return end
        finished = true

        local value = IsValid(entry) and entry:GetValue() or nil
        if IsValid(frame) then
            frame:Remove()
        end
        if action and action.callback then
            action.callback(value)
        end
    end

    for i, action in ipairs(actions) do
        surface.SetFont("Talksmith_E_Small")
        local textWidth = surface.GetTextSize(action.label or "")
        local button = footer:Add("DButton")
        button:Dock(RIGHT)
        button:SetWide(math.Clamp(textWidth + 34, 104, 210))
        button:DockMargin(8, 0, 0, 0)
        TS.Editor.StyleButton(button, {
            label = action.label or "",
            accent = action.accent or (i == 1 and not action.danger),
            danger = action.danger,
            quiet = action.quiet or i > 1,
            font = "Talksmith_E_Small",
        })
        button.DoClick = function()
            finish(action)
        end
    end

    local cancelAction = actions[opts.cancelIndex or #actions]
    frame.OnKeyCodePressed = function(_, key)
        if key == KEY_ESCAPE then
            finish(cancelAction)
        end
    end
    frame.Think = function()
        if gui.IsGameUIVisible() and not gui.IsConsoleVisible() then
            gui.HideGameUI()
            finish(cancelAction)
        end
    end
    frame.OnRemove = function()
        if TS.Editor.Modal == frame then
            TS.Editor.Modal = nil
        end
    end

    if IsValid(entry) and actions[1] then
        entry.OnEnter = function()
            finish(actions[1])
        end
    end

    TS.Editor.RegisterModalPanel(frame, true)
    if IsValid(entry) then
        entry:RequestFocus()
        entry:SelectAllText(true)
    end
    return frame
end

function TS.Editor.Confirm(title, message, actions)
    return TS.Editor.OpenModal({
        title = title,
        message = message,
        actions = actions,
        cancelIndex = #actions,
        danger = actions[1] and actions[1].danger,
    })
end

function TS.Editor.StringRequest(title, message, defaultValue, onAccept, onCancel, acceptLabel, cancelLabel)
    return TS.Editor.OpenModal({
        title = title,
        message = message,
        entry = defaultValue or "",
        cancelIndex = 2,
        actions = {
            {
                label = acceptLabel or "OK",
                accent = true,
                callback = function(value)
                    if onAccept then onAccept(value) end
                end,
            },
            {
                label = cancelLabel or "Cancel",
                quiet = true,
                callback = function(value)
                    if onCancel then onCancel(value) end
                end,
            },
        },
    })
end

function TS.Editor.StyleCombo(c)
    local T = TS.Editor.Theme
    c:SetFont("Talksmith_E_Body")
    c:SetTextColor(T.text)
    if IsValid(c.DropButton) then
        c.DropButton:SetVisible(false)
    end
    c.Paint = function(s, w, h)
        draw.RoundedBox(3, 0, 0, w, h, T.field)
        surface.SetDrawColor(T.lineSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("▾", "Talksmith_E_Body", w - 12, h / 2, T.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    if not c._talksmithUsesCustomMenu then
        c._talksmithUsesCustomMenu = true
        c.CloseMenu = function(s)
            if IsValid(s.Menu) and s.Menu.Close then
                s.Menu:Close()
            end
            s.Menu = nil
        end
        c.OpenMenu = function(s, controlOpener)
            if controlOpener and controlOpener == s.TextEntry then return end
            if #s.Choices == 0 then return end
            s:CloseMenu()

            local items = {}
            for id, value in ipairs(s.Choices) do
                local label = tostring(value)
                if #label > 1 and not tonumber(label) and string.StartWith(label, "#") then
                    label = language.GetPhrase(string.sub(label, 2))
                end
                items[#items + 1] = { id = id, value = value, label = label }
            end
            if s:GetSortItems() then
                table.sort(items, function(a, b)
                    return string.lower(a.label) < string.lower(b.label)
                end)
            end

            local menu = TS.Editor.CreateMenu(math.max(s:GetWide(), 220))
            s.Menu = menu
            for _, item in ipairs(items) do
                local choiceID, choiceValue = item.id, item.value
                TS.Editor.AddMenuOption(menu, item.label, function()
                    if IsValid(s) then
                        s:ChooseOption(choiceValue, choiceID)
                    end
                end, { icon = s.ChoiceIcons[choiceID] })
                if s.Spacers[choiceID] then
                    TS.Editor.AddMenuSpacer(menu)
                end
            end

            local x, y = s:LocalToScreen(0, s:GetTall())
            menu:Open(x, y)
            s:OnMenuOpened(menu)
        end
    end
    return c
end

function TS.Editor.Label(parent, txt, font, col)
    local T = TS.Editor.Theme
    local l = parent:Add("DLabel")
    l:Dock(TOP)
    l:SetTall(20)
    l:SetFont(font or "Talksmith_E_Small")
    l:SetTextColor(col or T.muted)
    l:SetText(txt)
    return l
end

function TS.Editor.Slider(parent, opts)
    local T = TS.Editor.Theme
    local minv, maxv = opts.min or 0, opts.max or 1
    local dec = opts.decimals or 0
    local readout = 58
    local s = parent:Add("DPanel")
    s:SetTall(opts.tall or 26)
    s:SetMouseInputEnabled(true)
    s.value = math.Clamp(tonumber(opts.value) or minv, minv, maxv)

    local function fmt()
        return string.format("%." .. dec .. "f", s.value)
    end
    local function snap(v)
        local step = 1 / (10 ^ dec)
        return math.Clamp(math.Round(v / step) * step, minv, maxv)
    end
    local function set(v, fire)
        v = snap(v)
        local changed = v ~= s.value
        s.value = v
        if fire and changed and opts.onChange then
            opts.onChange(v)
        end
    end
    s.SetValue = function(_, v)
        set(v, false)
    end
    local function trackW()
        return s:GetWide() - readout
    end
    local function dragTo(mx)
        set(minv + math.Clamp(mx / math.max(trackW(), 1), 0, 1) * (maxv - minv), true)
    end

    s.Paint = function(_, w, h)
        local tw = w - readout
        local cy = h / 2
        local frac = maxv > minv and (s.value - minv) / (maxv - minv) or 0
        draw.RoundedBox(3, 0, cy - 3, tw, 6, T.field)
        surface.SetDrawColor(T.lineSoft)
        surface.DrawOutlinedRect(0, cy - 3, tw, 6, 1)
        draw.RoundedBox(3, 0, cy - 3, frac * tw, 6, T.blue)
        local kx = math.Clamp(frac * tw - 5, 0, tw - 10)
        draw.RoundedBox(3, kx, cy - 9, 10, 18, T.text)
        if not IsValid(s.entry) then
            local hot = s:IsHovered() and select(1, s:CursorPos()) >= tw
            draw.SimpleText(fmt(), "Talksmith_E_Body", w, cy, hot and T.blue or T.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end

    local function openEditor()
        if IsValid(s.entry) then
            return
        end
        local e = vgui.Create("DTextEntry", s)
        s.entry = e
        e:SetPos(trackW() + 2, 1)
        e:SetSize(readout - 2, s:GetTall() - 2)
        e:SetFont("Talksmith_E_Body")
        e:SetNumeric(true)
        e:SetText(fmt())
        e:SetPaintBackground(false)
        e:SelectAllOnFocus(true)
        e.Paint = function(en, w, h)
            draw.RoundedBox(3, 0, 0, w, h, T.fieldFocus)
            surface.SetDrawColor(T.blue)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            en:DrawTextEntryText(T.text, T.blue, T.text)
        end
        local committed = false
        local function commit()
            if committed then
                return
            end
            committed = true
            local v = tonumber((e:GetValue():gsub(",", ".")))
            if v then
                set(v, true)
            end
            if IsValid(e) then
                e:Remove()
            end
            s.entry = nil
        end
        e.OnEnter = commit
        e.OnLoseFocus = commit
        e:RequestFocus()
    end

    s.OnMousePressed = function(_, code)
        if code ~= MOUSE_LEFT then
            return
        end
        local mx = select(1, s:CursorPos())
        if mx >= trackW() then
            openEditor()
        else
            s.dragging = true
            dragTo(mx)
        end
    end
    s.OnMouseReleased = function()
        s.dragging = false
    end
    s.Think = function()
        if s.dragging then
            if not input.IsMouseDown(MOUSE_LEFT) then
                s.dragging = false
                return
            end
            dragTo(select(1, s:CursorPos()))
        end
    end
    return s
end

function TS.Editor.Check(parent, opts)
    local T = TS.Editor.Theme
    local b = parent:Add("DButton")
    b:SetTall(opts.tall or 26)
    b:SetText("")
    b.value = opts.value == true
    b.Paint = function(_, w, h)
        local box = 18
        local by = h / 2 - box / 2
        draw.RoundedBox(3, 0, by, box, box, b.value and T.blue or T.field)
        surface.SetDrawColor(b.value and T.blue or T.lineSoft)
        surface.DrawOutlinedRect(0, by, box, box, 1)
        if b.value then
            TS.Editor.DrawIcon("check", box / 2 - 6, by + 3, 12, T.text)
        end
        if opts.label then
            draw.SimpleText(opts.label, "Talksmith_E_Body", box + 10, h / 2, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
    b.DoClick = function()
        b.value = not b.value
        if opts.onChange then
            opts.onChange(b.value)
        end
    end
    return b
end

local function fitText(text, font, maxw)
    surface.SetFont(font)
    if surface.GetTextSize(text) <= maxw then
        return text
    end
    local s = utf8.force(text)
    while utf8.len(s) > 1 and surface.GetTextSize("…" .. s) > maxw do
        s = utf8.sub(s, 2)
    end
    return "…" .. s
end

function TS.Editor.PickerRow(parent, opts)
    local T = TS.Editor.Theme
    local b = parent:Add("DButton")
    b:Dock(TOP)
    b:SetTall(opts.tall or 28)
    b:DockMargin(0, 2, 0, 6)
    b:SetText("")
    b.value = opts.value or ""
    b.Paint = function(s, w, h)
        draw.RoundedBox(3, 0, 0, w, h, s:IsHovered() and T.fieldFocus or T.field)
        surface.SetDrawColor(s:IsHovered() and T.blue or T.lineSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        local shown = b.value ~= "" and b.value or (opts.placeholder or "")
        draw.SimpleText(
            fitText(shown, "Talksmith_E_Body", w - 30),
            "Talksmith_E_Body",
            8,
            h / 2,
            b.value ~= "" and T.text or T.dim,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )
        draw.SimpleText("⋯", "Talksmith_E_Head", w - 15, h / 2, T.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    b.DoClick = function()
        opts.onOpen(b)
    end
    b.SetValueText = function(_, v)
        b.value = v or ""
    end
    return b
end
