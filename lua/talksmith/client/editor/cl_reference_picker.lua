local TS = Talksmith

local function lowerText(value)
    value = tostring(value or "")
    if utf8 and utf8.lower then
        return utf8.lower(value)
    end
    return string.lower(value)
end

local function fitText(text, font, maxWidth)
    text = string.gsub(tostring(text or ""), "%s+", " ")
    surface.SetFont(font)
    if surface.GetTextSize(text) <= maxWidth then
        return text
    end

    local out, pos = "", 1
    while pos <= #text do
        local byte = string.byte(text, pos)
        local step = byte < 128 and 1 or (byte < 224 and 2 or (byte < 240 and 3 or 4))
        local chunk = string.sub(text, pos, pos + step - 1)
        if surface.GetTextSize(out .. chunk .. "...") > maxWidth then
            break
        end
        out = out .. chunk
        pos = pos + step
    end
    return out .. "..."
end

function TS.Editor.OpenReferencePicker(opts)
    opts = opts or {}
    local T = TS.Editor.Theme

    if IsValid(TS.Editor.ReferencePicker) then
        TS.Editor.ReferencePicker:Remove()
    end

    local items = {}
    for _, source in ipairs(opts.items or {}) do
        local item = {
            id = tostring(source.id or ""),
            name = tostring(source.name or source.id or ""),
            description = tostring(source.description or ""),
            group = tostring(source.group or "Core"),
        }
        item.search = lowerText(table.concat({
            item.name,
            item.id,
            item.group,
            tostring(source.keywords or ""),
        }, " "))
        items[#items + 1] = item
    end

    table.sort(items, function(a, b)
        local leftGroup, rightGroup = lowerText(a.group), lowerText(b.group)
        if leftGroup ~= rightGroup then return leftGroup < rightGroup end
        local leftName, rightName = lowerText(a.name), lowerText(b.name)
        if leftName ~= rightName then return leftName < rightName end
        return a.id < b.id
    end)

    local screen = vgui.Create("EditablePanel")
    TS.Editor.ReferencePicker = screen
    screen:SetSize(ScrW(), ScrH())
    screen:SetDrawOnTop(true)
    screen:MakePopup()
    TS.Editor.PickerDepth = (TS.Editor.PickerDepth or 0) + 1
    screen.Paint = function(_, w, h)
        surface.SetDrawColor(0, 0, 0, 180)
        surface.DrawRect(0, 0, w, h)
    end

    local card = screen:Add("DPanel")
    card:SetSize(
        math.min(math.Clamp(ScrW() * 0.52, 580, 820), math.max(ScrW() - 24, 320)),
        math.min(math.Clamp(ScrH() * 0.72, 460, 760), math.max(ScrH() - 24, 320))
    )
    card:Center()
    card.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, T.bar)
        surface.SetDrawColor(T.line)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local header = card:Add("DPanel")
    header:Dock(TOP)
    header:SetTall(52)
    header:DockPadding(20, 0, 10, 0)
    header.Paint = function(_, w, h)
        draw.SimpleText(opts.title or "", "Talksmith_E_Title", 20, h / 2, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(T.line)
        surface.DrawLine(0, h - 1, w, h - 1)
    end

    local close = header:Add("DButton")
    close:Dock(RIGHT)
    close:SetWide(36)
    close:DockMargin(0, 8, 0, 8)
    TS.Editor.StyleButton(close, { label = "X" })
    close.DoClick = function()
        screen:Remove()
    end

    local content = card:Add("DPanel")
    content:Dock(FILL)
    content:DockPadding(16, 12, 14, 14)
    content.Paint = function() end

    local search = content:Add("DTextEntry")
    search:Dock(TOP)
    search:SetTall(34)
    search:DockMargin(0, 0, 0, 10)
    search:SetUpdateOnType(true)
    search:SetPlaceholderText(opts.placeholder or TS.L("search"))
    TS.Editor.StyleEntry(search)

    local scroll = content:Add("DScrollPanel")
    scroll:Dock(FILL)
    local bar = scroll:GetVBar()
    bar:SetWide(7)
    bar:SetHideButtons(true)
    bar.Paint = function(_, w, h)
        draw.RoundedBox(3, 1, 0, math.max(w - 2, 1), h, T.field)
    end
    bar.btnGrip.Paint = function(_, w, h)
        draw.RoundedBox(3, 1, 0, math.max(w - 2, 1), h, T.line)
    end

    local firstMatch
    local function choose(id)
        if not id then return end
        if IsValid(screen) then
            screen:Remove()
        end
        if opts.onSelect then
            opts.onSelect(id)
        end
    end

    local function rebuild(filter)
        scroll:Clear()
        filter = string.Trim(lowerText(filter))
        firstMatch = nil
        local shown = 0
        local currentGroup

        for _, item in ipairs(items) do
            if filter == "" or string.find(item.search, filter, 1, true) then
                local itemData = item
                if not firstMatch then
                    firstMatch = itemData.id
                end
                shown = shown + 1

                if currentGroup ~= itemData.group then
                    currentGroup = itemData.group
                    local group = scroll:Add("DLabel")
                    group:Dock(TOP)
                    group:SetTall(27)
                    group:DockMargin(2, shown == 1 and 0 or 8, 8, 2)
                    group:SetFont("Talksmith_E_Tiny")
                    group:SetTextColor(T.blue)
                    group:SetText(itemData.group)
                end

                local row = scroll:Add("DButton")
                row:Dock(TOP)
                row:SetTall(itemData.description ~= "" and 58 or 42)
                row:DockMargin(0, 0, 8, 4)
                row:SetText("")
                row.Paint = function(s, w, h)
                    local selected = itemData.id == opts.current
                    draw.RoundedBox(4, 0, 0, w, h, selected and T.accentSoft or (s:IsHovered() and T.card or T.field))
                    surface.SetDrawColor(selected and T.blue or T.lineSoft)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                    if selected then
                        draw.RoundedBox(1, 0, 8, 3, h - 16, T.blue)
                    end

                    surface.SetFont("Talksmith_E_Tiny")
                    local idWidth = surface.GetTextSize(itemData.id)
                    draw.SimpleText(
                        fitText(itemData.name, "Talksmith_E_Body", math.max(w - idWidth - 42, 80)),
                        "Talksmith_E_Body",
                        12,
                        itemData.description ~= "" and 17 or h / 2,
                        T.text,
                        TEXT_ALIGN_LEFT,
                        TEXT_ALIGN_CENTER
                    )
                    draw.SimpleText(
                        itemData.id,
                        "Talksmith_E_Tiny",
                        w - 12,
                        itemData.description ~= "" and 17 or h / 2,
                        T.dim,
                        TEXT_ALIGN_RIGHT,
                        TEXT_ALIGN_CENTER
                    )
                    if itemData.description ~= "" then
                        draw.SimpleText(
                            fitText(itemData.description, "Talksmith_E_Tiny", math.max(w - 24, 80)),
                            "Talksmith_E_Tiny",
                            12,
                            40,
                            T.muted,
                            TEXT_ALIGN_LEFT,
                            TEXT_ALIGN_CENTER
                        )
                    end
                end
                row.DoClick = function()
                    choose(itemData.id)
                end
                TS.Editor.SetTooltip(
                    row,
                    itemData.description ~= ""
                        and (itemData.name .. "\n" .. itemData.description .. "\n" .. itemData.id)
                        or (itemData.name .. "\n" .. itemData.id)
                )
            end
        end

        if shown == 0 then
            local empty = scroll:Add("DLabel")
            empty:Dock(TOP)
            empty:SetTall(80)
            empty:SetFont("Talksmith_E_Body")
            empty:SetTextColor(T.dim)
            empty:SetContentAlignment(5)
            empty:SetText(opts.emptyText or TS.L("search_no_results"))
        end
    end

    search.OnValueChange = function(_, value)
        rebuild(value)
    end
    search.OnEnter = function()
        choose(firstMatch)
    end
    local baseOnKeyCodeTyped = search.OnKeyCodeTyped
    search.OnKeyCodeTyped = function(self, key)
        if key == KEY_ESCAPE then
            screen:Remove()
            return
        end
        return baseOnKeyCodeTyped(self, key)
    end
    screen.OnKeyCodePressed = function(_, key)
        if key == KEY_ESCAPE then
            screen:Remove()
        end
    end
    screen.Think = function()
        if not IsValid(TS.Editor.Frame) then
            screen:Remove()
            return
        end
        if gui.IsGameUIVisible() and not gui.IsConsoleVisible() then
            gui.HideGameUI()
            screen:Remove()
        end
    end
    screen.OnRemove = function()
        TS.Editor.PickerDepth = math.max((TS.Editor.PickerDepth or 1) - 1, 0)
        if TS.Editor.ReferencePicker == screen then
            TS.Editor.ReferencePicker = nil
        end
    end

    TS.Editor.RegisterModalPanel(screen)
    rebuild("")
    search:RequestFocus()
    return screen
end