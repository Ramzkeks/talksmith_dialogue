local TS = Talksmith
local MAX_NET_PAYLOAD = 60000
local REQUEST_TIMER = "talksmith_example_request_timeout"

TS.Editor.ExampleDrafts = TS.Editor.ExampleDrafts or {}

local function language()
    return TS.Config.language == "ru" and "ru" or "en"
end

local function documentIDExists(id)
    for _, metadata in ipairs(TS.Editor.DocumentList or {}) do
        if metadata.id == id then
            return true
        end
    end
    return TS.Editor.ExampleDrafts[id] ~= nil
end

local function uniqueDraftID(base)
    base = TS.Utils.SafeID(base or "") or "talksmith_example"
    if not documentIDExists(base) then
        return base
    end
    for index = 2, 999 do
        local suffix = "_" .. index
        local candidate = string.sub(base, 1, 64 - #suffix) .. suffix
        if not documentIDExists(candidate) then
            return candidate
        end
    end
end

function TS.Editor.RefreshExampleDrafts()
    if IsValid(TS.Editor.Frame) and TS.Editor.Frame.RefreshExampleDrafts then
        TS.Editor.Frame:RefreshExampleDrafts()
    end
end

function TS.Editor.AddExampleDraft(document, exampleID)
    if not istable(document) then
        return nil
    end
    local id = uniqueDraftID(document.id or exampleID)
    if not id then
        return nil
    end

    document.id = id
    document.meta = istable(document.meta) and document.meta or {}
    document.meta.revision = 0
    document.meta.modified = os.time()
    TS.Editor.ExampleDrafts[id] = document
    TS.Editor.RefreshExampleDrafts()
    hook.Run("Talksmith.ExampleDraftAdded", id, document, exampleID)
    return id
end

function TS.Editor.RemoveExampleDraft(id)
    if not TS.Editor.ExampleDrafts[id] then
        return false
    end
    TS.Editor.ExampleDrafts[id] = nil
    TS.Editor.RefreshExampleDrafts()
    return true
end

local function finishRequest(ok, idOrReason)
    timer.Remove(REQUEST_TIMER)
    local pending = TS.Editor.ExampleRequestPending
    TS.Editor.ExampleRequestPending = nil
    if pending and pending.callback then
        pending.callback(ok, idOrReason)
    end
end

function TS.Editor.RequestExample(exampleID, callback)
    if TS.Editor.ExampleRequestPending then
        TS.Runtime.Notify(TS.L("preset_request_busy"), NOTIFY_HINT, 2)
        if callback then
            callback(false, "busy")
        end
        return false
    end
    if not TS.Examples.Get(exampleID) then
        TS.Runtime.Notify(TS.L("preset_load_failed", "not_found"), NOTIFY_ERROR, 4)
        if callback then
            callback(false, "not_found")
        end
        return false
    end

    TS.Editor.ExampleRequestPending = { key = exampleID, callback = callback }
    net.Start("ts_editor_example")
    net.WriteString(exampleID)
    net.WriteString(language())
    net.SendToServer()

    timer.Create(REQUEST_TIMER, 6, 1, function()
        if not TS.Editor.ExampleRequestPending then
            return
        end
        TS.Runtime.Notify(TS.L("preset_load_failed", "timeout"), NOTIFY_ERROR, 4)
        finishRequest(false, "timeout")
    end)
    return true
end

net.Receive("ts_editor_example", function()
    local ok = net.ReadBool()
    local exampleID = net.ReadString()
    local pending = TS.Editor.ExampleRequestPending
    if not pending or pending.key ~= exampleID then
        return
    end
    if not ok then
        local reason = net.ReadString()
        TS.Runtime.Notify(TS.L("preset_load_failed", reason), NOTIFY_ERROR, 4)
        return finishRequest(false, reason)
    end

    local length = net.ReadUInt(20)
    if length <= 0 or length > MAX_NET_PAYLOAD then
        TS.Runtime.Notify(TS.L("preset_load_failed", "too_large"), NOTIFY_ERROR, 4)
        return finishRequest(false, "too_large")
    end
    local raw = util.Decompress(net.ReadData(length) or "", TS.Config.max_document_bytes)
    local decoded, document = pcall(util.JSONToTable, raw or "", false, true)
    if not decoded or not istable(document) then
        TS.Runtime.Notify(TS.L("preset_load_failed", "invalid_json"), NOTIFY_ERROR, 4)
        return finishRequest(false, "invalid_json")
    end

    local valid = TS.Validation.ValidateDialogue(document)
    if not valid then
        TS.Runtime.Notify(TS.L("preset_load_failed", "invalid_document"), NOTIFY_ERROR, 4)
        return finishRequest(false, "invalid_document")
    end

    local id = TS.Editor.AddExampleDraft(document, exampleID)
    if not id then
        TS.Runtime.Notify(TS.L("preset_load_failed", "id_exhausted"), NOTIFY_ERROR, 4)
        return finishRequest(false, "id_exhausted")
    end
    TS.Runtime.Notify(TS.L("preset_added", id), NOTIFY_GENERIC, 5)
    finishRequest(true, id)
end)

local function styleScroll(panel)
    local T = TS.Editor.Theme
    local bar = panel:GetVBar()
    bar:SetWide(4)
    bar:SetHideButtons(true)
    bar.Paint = function() end
    bar.btnGrip.Paint = function(_, width, height)
        draw.RoundedBox(2, 0, 0, width, height, T.line)
    end
end

local function integrationState(entry)
    if not entry.integration then
        return nil, nil
    end
    local data = TS.Editor.Catalog
        and TS.Editor.Catalog.integrations
        and TS.Editor.Catalog.integrations[entry.integration]
    local status = data and data.status or "unavailable"
    return data, status
end

function TS.Editor.OpenExamples(category)
    if IsValid(TS.Editor.ExamplesFrame) then
        TS.Editor.ActivateModalPanel(TS.Editor.ExamplesFrame)
        return
    end

    local T = TS.Editor.Theme
    local activeCategory = category == "integration" and "integration" or "standard"
    local screen = vgui.Create("EditablePanel")
    TS.Editor.ExamplesFrame = screen
    TS.Editor.ExamplesOpen = true
    screen:SetSize(ScrW(), ScrH())
    screen:SetPos(0, 0)
    screen:MakePopup()
    screen.Paint = function(_, width, height)
        surface.SetDrawColor(0, 0, 0, 180)
        surface.DrawRect(0, 0, width, height)
    end

    local card = screen:Add("DPanel")
    card:SetSize(
        math.min(math.Clamp(ScrW() * 0.72, 700, 1040), math.max(ScrW() - 24, 320)),
        math.min(math.Clamp(ScrH() * 0.76, 520, 820), math.max(ScrH() - 24, 360))
    )
    card:Center()
    card:DockPadding(20, 68, 20, 18)
    card.Paint = function(_, width, height)
        draw.RoundedBox(8, 0, 0, width, height, T.bar)
        surface.SetDrawColor(T.line)
        surface.DrawOutlinedRect(0, 0, width, height, 1)
        surface.DrawLine(0, 66, width, 66)
        draw.SimpleText(TS.L("presets_title"), "Talksmith_E_Title", 22, 24, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(TS.L("presets_subtitle"), "Talksmith_E_Small", 22, 47, T.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local close = card:Add("DButton")
    close:SetPos(card:GetWide() - 48, 16)
    close:SetSize(34, 32)
    TS.Editor.StyleButton(close, { label = "✕", quiet = true })
    close.DoClick = function()
        screen:Remove()
    end

    local tabs = card:Add("DPanel")
    tabs:Dock(TOP)
    tabs:SetTall(44)
    tabs:DockMargin(0, 8, 0, 10)
    tabs.Paint = function() end

    local list = card:Add("DScrollPanel")
    list:Dock(FILL)
    styleScroll(list)

    local tabButtons = {}
    local rebuild
    local function setCategory(nextCategory)
        activeCategory = nextCategory
        for id, button in pairs(tabButtons) do
            button._talksmithStyleOptions.active = id == activeCategory
        end
        rebuild()
    end

    local function addTab(id, label)
        local button = tabs:Add("DButton")
        button:Dock(LEFT)
        button:SetWide(190)
        button:DockMargin(0, 0, 8, 0)
        TS.Editor.StyleButton(button, { label = label, active = id == activeCategory })
        button.DoClick = function()
            setCategory(id)
        end
        tabButtons[id] = button
    end
    addTab("standard", TS.L("presets_standard"))
    addTab("integration", TS.L("presets_integrations"))

    rebuild = function()
        list:Clear()
        local shown = 0
        for _, entry in ipairs(TS.Examples.Catalog) do
            if entry.category == activeCategory then
                shown = shown + 1
                local integration, status = integrationState(entry)
                local row = list:Add("DButton")
                row:Dock(TOP)
                row:SetTall(118)
                row:DockMargin(0, 0, 8, 9)
                row:DockPadding(18, 13, 16, 13)
                row:SetText("")
                row.Paint = function(_, width, height)
                    draw.RoundedBox(5, 0, 0, width, height, T.card)
                    surface.SetDrawColor(T.lineSoft)
                    surface.DrawOutlinedRect(0, 0, width, height, 1)
                    if status then
                        local color = status == "available" and T.green or status == "loading" and T.yellow or T.red
                        surface.SetDrawColor(color)
                        surface.DrawRect(0, 0, 3, height)
                    end
                end

                local add = row:Add("DButton")
                add:Dock(RIGHT)
                add:SetWide(142)
                add:DockMargin(18, 25, 0, 25)
                TS.Editor.StyleButton(add, { label = TS.L("preset_add"), accent = true, icon = "plus" })
                local function request(button)
                    if IsValid(button) then
                        button:SetDisabled(true)
                    end
                    TS.Editor.RequestExample(entry.id, function(ok)
                        if IsValid(button) and not ok then
                            button:SetDisabled(false)
                        end
                        if ok and IsValid(screen) then
                            screen:Remove()
                        end
                    end)
                end
                add.DoClick = request
                row.DoClick = request

                local details = row:Add("DPanel")
                details:Dock(FILL)
                details:SetMouseInputEnabled(false)
                details.Paint = function() end

                local title = details:Add("DLabel")
                title:Dock(TOP)
                title:SetTall(24)
                title:SetFont("Talksmith_E_Head")
                title:SetTextColor(T.text)
                title:SetText(TS.Examples.Text(entry, "title", language()))

                local description = details:Add("DLabel")
                description:Dock(TOP)
                description:SetTall(48)
                description:SetFont("Talksmith_E_Small")
                description:SetTextColor(T.muted)
                description:SetWrap(true)
                description:SetText(TS.Examples.Text(entry, "description", language()))

                local meta = details:Add("DLabel")
                meta:Dock(TOP)
                meta:SetTall(20)
                meta:SetFont("Talksmith_E_Tiny")
                if entry.integration then
                    local statusText = TS.Localization.Integration("integration_status_" .. status)
                    local statusColor = status == "available" and T.green
                        or status == "loading" and T.yellow
                        or T.red
                    meta:SetTextColor(statusColor)
                    meta:SetText(TS.L("preset_requires", integration and integration.name or entry.integration, statusText))
                else
                    meta:SetTextColor(T.blue)
                    meta:SetText(TS.L("preset_standard_ready"))
                end
            end
        end

        if shown == 0 then
            local empty = list:Add("DLabel")
            empty:Dock(TOP)
            empty:SetTall(64)
            empty:SetFont("Talksmith_E_Body")
            empty:SetTextColor(T.muted)
            empty:SetContentAlignment(5)
            empty:SetText(TS.L("presets_empty"))
        end
    end

    screen.Think = function()
        if gui.IsGameUIVisible() and not gui.IsConsoleVisible() then
            gui.HideGameUI()
            screen:Remove()
        end
    end
    screen.OnKeyCodePressed = function(_, key)
        if key == KEY_ESCAPE then
            screen:Remove()
        end
    end
    screen.OnRemove = function()
        TS.Editor.ExamplesOpen = false
        if TS.Editor.ExamplesFrame == screen then
            TS.Editor.ExamplesFrame = nil
        end
    end

    TS.Editor.RegisterModalPanel(screen)
    rebuild()
end
