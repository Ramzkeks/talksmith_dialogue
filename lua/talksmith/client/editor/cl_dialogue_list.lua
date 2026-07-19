local TS = Talksmith

local function fitText(text, font, maxw)
    text = tostring(text or "")
    maxw = math.max(maxw or 0, 0)
    surface.SetFont(font)
    if surface.GetTextSize(text) <= maxw then
        return text
    end

    local suffix = "…"
    if surface.GetTextSize(suffix) > maxw then
        return ""
    end

    local out, pos = "", 1
    while pos <= #text do
        local byte = string.byte(text, pos)
        local step = byte < 128 and 1 or (byte < 224 and 2 or (byte < 240 and 3 or 4))
        local chunk = string.sub(text, pos, pos + step - 1)
        if surface.GetTextSize(out .. chunk .. suffix) > maxw then
            break
        end
        out = out .. chunk
        pos = pos + step
    end
    return out .. suffix
end

function TS.Editor.BuildDialogueList(parent, cb)
    local T = TS.Editor.Theme
    local panel = parent:Add("DPanel")
    panel:Dock(LEFT)
    panel:SetWide(240)
    panel.Paint = function(_, w, h)
        surface.SetDrawColor(T.side)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(T.line)
        surface.DrawLine(w - 1, 0, w - 1, h)
    end
    panel.docs = {}
    panel.drafts = {}
    panel.active = nil
    panel.dirty = false
    panel.filter = ""

    local header = panel:Add("DPanel")
    header:Dock(TOP)
    header:SetTall(48)
    header:DockPadding(12, 9, 10, 9)
    header.Paint = function(_, w, h)
        draw.SimpleText(TS.L("dialogues"), "Talksmith_E_Head", 12, h / 2, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    local newBtn = header:Add("DButton")
    newBtn:Dock(RIGHT)
    surface.SetFont("Talksmith_E_Body")
    newBtn:SetWide(math.ceil(surface.GetTextSize(TS.L("new")) + 25 + 22))
    TS.Editor.StyleButton(newBtn, { label = TS.L("new"), accent = true, icon = "plus" })
    newBtn.DoClick = function()
        cb.OnNew()
    end

    local searchRow = panel:Add("DPanel")
    searchRow:Dock(TOP)
    searchRow:SetTall(42)
    searchRow:DockPadding(8, 4, 8, 6)
    searchRow.Paint = function(_, w, h)
        surface.SetDrawColor(T.lineSoft)
        surface.DrawLine(8, h - 1, w - 8, h - 1)
    end
    local refresh = searchRow:Add("DButton")
    refresh:Dock(RIGHT)
    refresh:SetWide(32)
    refresh:DockMargin(0, 0, 6, 0)
    TS.Editor.StyleButton(refresh, { quiet = true, icon = "arrows-clockwise", iconSize = 16 })
    TS.Editor.SetTooltip(refresh, TS.L("refresh"))
    refresh.DoClick = function()
        TS.Editor.RequestDocuments()
    end

    local searchIcon = searchRow:Add("DPanel")
    searchIcon:Dock(LEFT)
    searchIcon:SetWide(24)
    searchIcon.Paint = function(_, w, h)
        TS.Editor.DrawIcon("magnifying-glass", (w - 15) / 2, (h - 15) / 2, 15, TS.Editor.Theme.dim)
    end

    local search = searchRow:Add("DTextEntry")
    search:Dock(FILL)
    search:DockMargin(0, 0, 4, 0)
    TS.Editor.StyleEntry(search)
    search:SetUpdateOnType(true)
    search:SetPlaceholderText(TS.L("search"))
    search.OnValueChange = function(_, s)
        panel.filter = string.lower(s or "")
        panel:Rebuild()
    end

    local portable = panel:Add("DPanel")
    portable:Dock(BOTTOM)
    portable:SetTall(46)
    portable:DockPadding(8, 8, 8, 8)
    portable.Paint = function(_, w)
        surface.SetDrawColor(T.line)
        surface.DrawLine(0, 0, w, 0)
    end
    local import = portable:Add("DButton")
    import:Dock(FILL)
    TS.Editor.StyleButton(import, { label = TS.L("import_preset"), quiet = true, icon = "upload-simple" })
    import.DoClick = function()
        if cb.OnImport then
            cb.OnImport()
        end
    end

    local scroll = panel:Add("DScrollPanel")
    scroll:Dock(FILL)
    scroll:DockMargin(0, 6, 0, 0)
    local sbar = scroll:GetVBar()
    sbar:SetWide(4)
    sbar:SetHideButtons(true)
    sbar.Paint = function() end
    sbar.btnGrip.Paint = function(_, w, h)
        draw.RoundedBox(2, 0, 0, w, h, T.line)
    end

    function panel:Rebuild()
        scroll:Clear()
        local shown = 0
        local sorted = table.Copy(self.docs)
        local savedIDs = {}
        for _, metadata in ipairs(sorted) do
            savedIDs[metadata.id] = true
        end
        for id, document in pairs(self.drafts) do
            if not savedIDs[id] and istable(document) then
                local meta = istable(document.meta) and document.meta or {}
                sorted[#sorted + 1] = {
                    id = id,
                    title = meta.title or id,
                    author = meta.author or "",
                    modified = meta.modified or 0,
                    revision = 0,
                    draft = true,
                }
            end
        end
        table.sort(sorted, function(a, b)
            return (a.modified or 0) > (b.modified or 0)
        end)
        for _, m in ipairs(sorted) do
            local hay = string.lower((m.title or "") .. " " .. (m.id or ""))
            if self.filter == "" or string.find(hay, self.filter, 1, true) then
                shown = shown + 1
                local it = scroll:Add("DButton")
                it:Dock(TOP)
                it:SetTall(66)
                it:DockMargin(7, 0, 7, 5)
                it:SetText("")
                if not m.draft then
                    local export = it:Add("DButton")
                    export:Dock(RIGHT)
                    export:SetWide(30)
                    export:DockMargin(0, 18, 7, 18)
                    TS.Editor.StyleButton(export, { quiet = true, icon = "download-simple", iconSize = 16 })
                    TS.Editor.SetTooltip(export, TS.L("export_preset"))
                    export.DoClick = function()
                        if cb.OnExport then
                            cb.OnExport(m.id)
                        end
                    end
                end
                local cachedTextWidth, cachedDirty, displayTitle, displayId, titleW, titleH
                it.Paint = function(s, w, h)
                    local active = self.active == m.id
                    draw.RoundedBox(
                        5,
                        0,
                        0,
                        w,
                        h,
                        active and T.accentSoft
                            or (s:IsHovered() and T.card or Color(0, 0, 0, 0))
                    )
                    if active then
                        surface.SetDrawColor(T.blue)
                        surface.DrawRect(0, 7, 3, h - 14)
                    end
                    local showDirty = m.draft or (active and self.dirty)
                    local textMaxW = math.max(w - (m.draft and 24 or 57), 0)
                    if cachedTextWidth ~= textMaxW or cachedDirty ~= showDirty then
                        displayTitle = fitText(
                            m.title or m.id,
                            "Talksmith_E_Body",
                            textMaxW - (showDirty and 14 or 0)
                        )
                        surface.SetFont("Talksmith_E_Body")
                        titleW, titleH = surface.GetTextSize(displayTitle)
                        displayId = fitText(m.id, "Talksmith_E_Mono", textMaxW)
                        cachedTextWidth = textMaxW
                        cachedDirty = showDirty
                    end
                    draw.SimpleText(displayTitle, "Talksmith_E_Body", 12, 10, T.text)
                    if showDirty then
                        draw.RoundedBox(3, 12 + titleW + 8, 10 + math.floor(titleH / 2) - 3, 6, 6, T.yellow)
                    end
                    draw.SimpleText(displayId, "Talksmith_E_Mono", 12, 30, active and T.blue or T.muted)
                    local when = m.draft
                            and TS.L("preset_draft")
                        or (m.modified and os.date("%d.%m.%Y %H:%M", m.modified) or "")
                    local author = not m.draft and isstring(m.author) and TS.Utils.ClampString(m.author, 10) or ""
                    draw.SimpleText(
                        when .. (author ~= "" and ("  ·  " .. author) or ""),
                        "Talksmith_E_Tiny",
                        12,
                        51,
                        T.dim
                    )
                end
                it.DoClick = function()
                    cb.OnOpen(m.id, m.draft == true)
                end
                it.DoRightClick = function()
                    local menu = TS.Editor.CreateMenu(230)
                    TS.Editor.AddMenuOption(menu, TS.L("open"), function()
                        cb.OnOpen(m.id, m.draft == true)
                    end, { icon = "folder-open", accent = true })
                    if m.draft then
                        TS.Editor.AddMenuSpacer(menu)
                        TS.Editor.AddMenuOption(menu, TS.L("delete"), function()
                            if cb.OnDeleteDraft then
                                cb.OnDeleteDraft(m.id, m.title or m.id)
                            end
                        end, { icon = "trash", danger = true })
                    else
                        TS.Editor.AddMenuOption(menu, TS.L("rename"), function()
                            cb.OnRename(m.id)
                        end, { icon = "pencil-simple" })
                        TS.Editor.AddMenuOption(menu, TS.L("duplicate"), function()
                            cb.OnDuplicate(m.id)
                        end, { icon = "copy" })
                        TS.Editor.AddMenuSpacer(menu)
                        TS.Editor.AddMenuOption(menu, TS.L("export_preset"), function()
                            if cb.OnExport then
                                cb.OnExport(m.id)
                            end
                        end, { icon = "download-simple" })
                        TS.Editor.AddMenuSpacer(menu)
                        TS.Editor.AddMenuOption(menu, TS.L("delete"), function()
                            cb.OnDelete(m.id, m.title or m.id)
                        end, { icon = "trash", danger = true })
                    end
                    menu:Open()
                end
            end
        end
        if shown == 0 then
            local l = scroll:Add("DLabel")
            l:Dock(TOP)
            l:DockMargin(16, 18, 16, 0)
            l:SetTall(72)
            l:SetContentAlignment(5)
            l:SetFont("Talksmith_E_Small")
            l:SetTextColor(T.dim)
            l:SetWrap(true)
            l:SetText(TS.L("no_dialogues"))
        end
        scroll:InvalidateLayout(true)
    end

    function panel:SetDocuments(list)
        self.docs = istable(list) and list or {}
        self:Rebuild()
    end
    function panel:SetDrafts(drafts)
        self.drafts = istable(drafts) and drafts or {}
        self:Rebuild()
    end
    function panel:SetActive(id, dirty)
        self.active = id
        self.dirty = dirty and true or false
    end

    panel:Rebuild()
    return panel
end

function TS.Editor.RequestDocuments(id)
    net.Start("ts_editor_docs")
    net.WriteString(id or "")
    net.SendToServer()
end
