local TS = Talksmith

local function modalBase(title)
    local T = TS.Editor.Theme
    local screen = vgui.Create("EditablePanel")
    screen:SetSize(ScrW(), ScrH())
    TS.Editor.RegisterModalPanel(screen)
    screen.Paint = function(_, w, h)
        surface.SetDrawColor(0, 0, 0, 185)
        surface.DrawRect(0, 0, w, h)
    end
    screen.Think = function()
        if gui.IsGameUIVisible() and not gui.IsConsoleVisible() then
            gui.HideGameUI()
            screen:Remove()
        end
    end

    local card = screen:Add("DPanel")
    card:SetSize(
        math.min(math.Clamp(ScrW() * 0.68, 600, 980), math.max(ScrW() - 24, 320)),
        math.min(math.Clamp(ScrH() * 0.68, 460, 760), math.max(ScrH() - 24, 320))
    )
    card:Center()
    card:DockPadding(18, 54, 18, 16)
    card.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, T.bar)
        surface.SetDrawColor(T.line)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        surface.DrawLine(0, 52, w, 52)
        draw.SimpleText(title, "Talksmith_E_Title", 20, 26, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local close = card:Add("DButton")
    close:SetPos(card:GetWide() - 48, 10)
    close:SetSize(34, 32)
    TS.Editor.StyleButton(close, { label = "✕" })
    close.DoClick = function()
        screen:Remove()
    end

    return screen, card
end

local function addFooter(card)
    local footer = card:Add("DPanel")
    footer:Dock(BOTTOM)
    footer:SetTall(42)
    footer:DockPadding(0, 8, 0, 0)
    footer.Paint = function() end
    return footer
end

local function footerButton(footer, label, width, fn, accent)
    local button = footer:Add("DButton")
    button:Dock(RIGHT)
    button:SetWide(width)
    button:DockMargin(8, 0, 0, 0)
    TS.Editor.StyleButton(button, { label = label, accent = accent })
    button.DoClick = fn
    return button
end

local function spawnSnippet(doc)
    local settings = doc.settings or {}
    return ([=[Talksmith.Actors.Create({
    dialogue = %q,
    map = %q,
    model = %q,
    pos = Vector(0, 0, 0),
    ang = Angle(0, 0, 0),
})]=]):format(doc.id or "", game.GetMap(), settings.actor_model or "")
end

function TS.Editor.RequestExport(id)
    id = TS.Utils.SafeID(id or "")
    if not id then
        return
    end
    net.Start("ts_editor_export")
    net.WriteString(id)
    net.SendToServer()
end

local function showExport(doc, json)
    local T = TS.Editor.Theme
    file.CreateDir("talksmith/exports")
    local target = "talksmith/exports/" .. doc.id .. ".json"
    local saved = TS.Utils.WriteDataFile(target, json)
    if not saved then
        TS.Runtime.Notify(TS.L("export_failed"), NOTIFY_ERROR, 3)
    end

    local screen, card = modalBase(TS.L("export_title", doc.id))
    local footer = addFooter(card)
    local path = card:Add("DLabel")
    path:Dock(BOTTOM)
    path:SetTall(18)
    path:SetFont("Talksmith_E_Tiny")
    path:SetTextColor(T.dim)
    path:SetText(saved and ("data/" .. target) or TS.L("export_failed"))

    local editor = card:Add("DTextEntry")
    editor:Dock(FILL)
    editor:DockMargin(0, 8, 0, 8)
    editor:SetMultiline(true)
    editor:SetEditable(false)
    editor:SetText(json)
    TS.Editor.StyleEntry(editor)
    editor:SetFont("Talksmith_E_Mono")

    local lua = spawnSnippet(doc)
    footerButton(footer, TS.L("close"), 92, function()
        screen:Remove()
    end)
    footerButton(footer, TS.L("copy_lua"), 150, function()
        SetClipboardText(lua)
        editor:SetEditable(true)
        editor:SetText(lua)
        editor:SetEditable(false)
        TS.Runtime.Notify(TS.L("copied"), NOTIFY_GENERIC, 2)
    end)
    footerButton(footer, TS.L("copy_json"), 130, function()
        SetClipboardText(json)
        editor:SetEditable(true)
        editor:SetText(json)
        editor:SetEditable(false)
        TS.Runtime.Notify(TS.L("copied"), NOTIFY_GENERIC, 2)
    end, true)
end

TS.Editor.Transfer.Handlers.export = function(json)
    local doc = TS.Editor.Transfer.Decode(json, TS.Config.max_document_bytes)
    if not doc or not TS.Utils.SafeID(doc.id or "") then
        TS.Runtime.Notify(TS.L("export_failed"), NOTIFY_ERROR, 3)
        return
    end
    showExport(doc, json)
end

net.Receive("ts_editor_export", function()
    local id = TS.Utils.SafeID(net.ReadString() or "")
    local length = net.ReadUInt(20)
    if not id or length <= 0 or length > TS.Config.max_document_bytes then
        return
    end
    local json = util.Decompress(net.ReadData(length) or "", TS.Config.max_document_bytes)
    local doc = TS.Editor.Transfer.Decode(json, TS.Config.max_document_bytes)
    if not json or not istable(doc) or doc.id ~= id then
        TS.Runtime.Notify(TS.L("export_failed"), NOTIFY_ERROR, 3)
        return
    end
    showExport(doc, json)
end)

function TS.Editor.OpenPresetImporter(onImport)
    local T = TS.Editor.Theme
    local screen, card = modalBase(TS.L("import_title"))
    local footer = addFooter(card)
    local status = card:Add("DLabel")
    status:Dock(BOTTOM)
    status:SetTall(20)
    status:SetFont("Talksmith_E_Small")
    status:SetTextColor(T.dim)
    status:SetText(TS.L("import_review_hint"))

    local idEntry = card:Add("DTextEntry")
    idEntry:Dock(TOP)
    idEntry:SetTall(28)
    idEntry:DockMargin(0, 8, 0, 8)
    idEntry:SetPlaceholderText(TS.L("import_id_hint"))
    TS.Editor.StyleEntry(idEntry)

    local editor = card:Add("DTextEntry")
    editor:Dock(FILL)
    editor:DockMargin(0, 0, 0, 8)
    editor:SetMultiline(true)
    editor:SetPlaceholderText(TS.L("import_json_hint"))
    TS.Editor.StyleEntry(editor)
    editor:SetFont("Talksmith_E_Mono")

    footerButton(footer, TS.L("cancel"), 100, function()
        screen:Remove()
    end)
    footerButton(footer, TS.L("import_open"), 180, function()
        local raw = string.Trim(editor:GetText() or "")
        if raw:sub(1, 3) == "\239\187\191" then
            raw = string.Trim(raw:sub(4))
        end
        if raw == "" then
            status:SetTextColor(T.red)
            status:SetText(TS.L("import_invalid"))
            return
        end
        local parsed, doc = pcall(util.JSONToTable, raw, true, true)
        if not parsed or not istable(doc) then
            status:SetTextColor(T.red)
            status:SetText(TS.L("import_invalid"))
            return
        end
        local override = idEntry:GetText()
        if override ~= "" then
            doc.id = TS.Utils.SafeID(override)
        end
        if not TS.Utils.SafeID(doc.id or "") then
            status:SetTextColor(T.red)
            status:SetText(TS.L("import_bad_id"))
            return
        end
        doc.meta = istable(doc.meta) and doc.meta or {}
        doc.meta.revision = 0
        doc.meta.author = IsValid(LocalPlayer()) and LocalPlayer():SteamID64() or ""
        local ok, issues = TS.Validation.ValidateDialogue(doc)
        if not ok then
            status:SetTextColor(T.red)
            status:SetText(TS.L("import_errors", #issues))
            return
        end
        onImport(doc)
        screen:Remove()
        TS.Runtime.Notify(TS.L("import_ready"), NOTIFY_GENERIC, 3)
    end, true)
end
