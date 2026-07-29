local TS = Talksmith

local function clipText(text, limit)
    text = string.gsub(text or "", "%s+", " ")
    local chars, pos = 0, 1
    while pos <= #text and chars < limit do
        local byte = string.byte(text, pos)
        local step = byte < 128 and 1 or (byte < 224 and 2 or (byte < 240 and 3 or 4))
        pos = pos + step
        chars = chars + 1
    end
    if pos > #text then
        return text
    end
    return string.sub(text, 1, pos - 1) .. "…"
end

function TS.Editor.BuildModelPreview(parent)
    local T = TS.Editor.Theme
    local mp = parent:Add("DModelPanel")
    mp:SetModel("models/error.mdl")
    mp:SetFOV(38)
    mp.rotYaw = 0
    mp.zoom = 1.1
    mp.scale = 1
    mp.previewSkin = 0
    mp.previewBodygroups = {}
    mp:SetAnimated(true)

    mp.PaintOver = function(self, w, h)
        surface.SetDrawColor(T.line)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(TS.L("s_preview_hint"), "Talksmith_E_Tiny", w / 2, h - 8, T.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
        if self.previewError then
            draw.RoundedBox(3, 10, 10, w - 20, 28, Color(T.red.r, T.red.g, T.red.b, 35))
            draw.SimpleText(self.previewError, "Talksmith_E_Small", w / 2, 24, T.red, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    function mp:Reframe()
        local ent = self.Entity
        if not IsValid(ent) then
            return
        end
        local mins, maxs = ent:GetRenderBounds()
        local center = (mins + maxs) * 0.5
        local radius = math.max((maxs - mins):Length() * 0.5, 8) * (self.scale or 1)
        local dist = radius / math.tan(math.rad(self:GetFOV()) * 0.5) * (self.zoom or 1.1)
        self:SetCamPos(center + Vector(dist, 0, 0))
        self:SetLookAt(center)
    end

    function mp:LayoutEntity(ent)
        if self.bAnimated then
            self:RunAnimation()
            if self.previewSeq and self.previewSeq ~= "" and ent:GetCycle() >= 0.99 then
                ent:SetCycle(0)
            end
        end
        ent:SetAngles(Angle(0, self.rotYaw or 0, 0))
    end

    function mp:SetPreviewSequence(name)
        self.previewSeq = name
        local ent = self.Entity
        if not IsValid(ent) then
            return
        end
        local seq = isstring(name) and name ~= "" and ent:LookupSequence(name) or -1
        if not seq or seq < 0 then
            seq = ent:LookupSequence("idle_all_01")
            if seq < 0 then
                seq = ent:SelectWeightedSequence(ACT_IDLE)
            end
        end
        if seq and seq >= 0 then
            ent:ResetSequence(seq)
            ent:SetCycle(0)
        end
    end

    function mp:SetPreviewModel(model)
        if not isstring(model) or model == "" then
            return
        end
        if not (util.IsValidModel(model) or file.Exists(model, "GAME")) then
            self.previewError = TS.L("preview_invalid_model")
            return false
        end
        self.previewError = nil
        self:SetModel(model)
        local ent = self.Entity
        if IsValid(ent) then
            ent:SetModelScale(self.scale or 1, 0)
            ent:SetSkin(math.Clamp(self.previewSkin or 0, 0, math.max(ent:SkinCount() - 1, 0)))
            for id, value in pairs(self.previewBodygroups or {}) do
                local count = ent:GetBodygroupCount(id)
                if count and count > 0 then
                    ent:SetBodygroup(id, math.Clamp(value, 0, count - 1))
                end
            end
            self:SetPreviewSequence(self.previewSeq or "")
        end
        self:Reframe()
        return true
    end
    function mp:SetPreviewScale(scale)
        self.scale = math.Clamp(tonumber(scale) or 1, 0.25, 4)
        if IsValid(self.Entity) then
            self.Entity:SetModelScale(self.scale, 0)
        end
        self:Reframe()
    end
    function mp:SetPreviewSkin(skin)
        self.previewSkin = math.max(math.floor(tonumber(skin) or 0), 0)
        if IsValid(self.Entity) then
            self.Entity:SetSkin(math.Clamp(self.previewSkin, 0, math.max(self.Entity:SkinCount() - 1, 0)))
        end
    end
    function mp:SetPreviewBodygroup(id, value)
        id = math.max(math.floor(tonumber(id) or 0), 0)
        value = math.max(math.floor(tonumber(value) or 0), 0)
        self.previewBodygroups[id] = value
        if IsValid(self.Entity) then
            local count = self.Entity:GetBodygroupCount(id) or 0
            self.Entity:SetBodygroup(id, math.Clamp(value, 0, math.max(count - 1, 0)))
        end
    end
    function mp:GetEnt()
        return self.Entity
    end

    function mp:ResetView()
        self.rotYaw = 0
        self.zoom = 1.1
        self:Reframe()
    end

    mp.OnMousePressed = function(self2, code)
        if code ~= MOUSE_LEFT then
            return
        end
        local now = SysTime()
        if self2.lastClickTime and (now - self2.lastClickTime) < 0.25 then
            self2.lastClickTime = nil
            self2.drag = false
            self2:MouseCapture(false)
            self2:ResetView()
            return
        end
        self2.lastClickTime = now
        self2.drag = true
        self2.lastX = select(1, self2:CursorPos())
        self2:MouseCapture(true)
    end
    mp.OnMouseReleased = function(self2)
        self2.drag = false
        self2:MouseCapture(false)
    end
    mp.Think = function(self2)
        if self2.drag then
            if not input.IsMouseDown(MOUSE_LEFT) then
                self2.drag = false
                return
            end
            local mx = select(1, self2:CursorPos())
            self2.rotYaw = (self2.rotYaw or 0) + (mx - (self2.lastX or mx)) * 0.5
            self2.lastX = mx
        end
    end
    mp.OnMouseWheeled = function(self2, delta)
        self2.zoom = math.Clamp((self2.zoom or 1.1) * (delta > 0 and 0.9 or 1.1), 0.5, 3)
        self2:Reframe()
        return true
    end
    mp.DoDoubleClick = function(self2)
        self2:ResetView()
    end
    return mp
end

local function pickerModal(cfg)
    local T = TS.Editor.Theme

    local scr = vgui.Create("EditablePanel")
    scr:SetSize(ScrW(), ScrH())
    TS.Editor.PickerDepth = (TS.Editor.PickerDepth or 0) + 1
    scr.Paint = function(_, w, h)
        surface.SetDrawColor(0, 0, 0, 180)
        surface.DrawRect(0, 0, w, h)
    end
    scr.Think = function()
        if gui.IsGameUIVisible() and not gui.IsConsoleVisible() then
            gui.HideGameUI()
            scr:Remove()
        end
    end
    scr.OnRemove = function()
        TS.Editor.PickerDepth = math.max((TS.Editor.PickerDepth or 1) - 1, 0)
    end

    local card = scr:Add("DPanel")
    card:SetSize(
        math.min(math.Clamp(ScrW() * 0.68, 620, 960), math.max(ScrW() - 24, 320)),
        math.min(math.Clamp(ScrH() * 0.66, 460, 740), math.max(ScrH() - 24, 320))
    )
    card:Center()
    card.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, T.bar)
        surface.SetDrawColor(T.line)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local header = card:Add("DPanel")
    header:Dock(TOP)
    header:SetTall(48)
    header:DockPadding(20, 0, 10, 0)
    header.Paint = function(_, w, h)
        draw.SimpleText(cfg.title, "Talksmith_E_Title", 20, h / 2, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(T.line)
        surface.DrawLine(0, h - 1, w, h - 1)
    end
    local hx = header:Add("DButton")
    hx:Dock(RIGHT)
    hx:SetWide(36)
    hx:DockMargin(0, 8, 0, 8)
    TS.Editor.StyleButton(hx, { label = "✕" })
    hx.DoClick = function()
        scr:Remove()
    end

    local selected = cfg.current or ""

    local footer = card:Add("DPanel")
    footer:Dock(BOTTOM)
    footer:SetTall(50)
    footer:DockPadding(16, 9, 16, 9)
    footer.Paint = function(_, w, h)
        surface.SetDrawColor(T.line)
        surface.DrawLine(0, 0, w, 0)
    end
    local pick = footer:Add("DButton")
    pick:Dock(RIGHT)
    pick:SetWide(120)
    TS.Editor.StyleButton(pick, { label = TS.L("pick_choose"), accent = true })
    pick.DoClick = function()
        cfg.onSelect(selected)
        scr:Remove()
    end
    local cancel = footer:Add("DButton")
    cancel:Dock(RIGHT)
    cancel:SetWide(100)
    cancel:DockMargin(0, 0, 8, 0)
    TS.Editor.StyleButton(cancel, { label = TS.L("pick_cancel") })
    cancel.DoClick = function()
        scr:Remove()
    end
    if cfg.allowClear then
        local clear = footer:Add("DButton")
        clear:Dock(LEFT)
        clear:SetWide(150)
        TS.Editor.StyleButton(clear, { label = TS.L("pick_clear") })
        clear.DoClick = function()
            cfg.onSelect("")
            scr:Remove()
        end
    end

    local content = card:Add("DPanel")
    content:Dock(FILL)
    content:DockPadding(16, 12, 14, 12)
    content.Paint = function() end

    local preview = TS.Editor.BuildModelPreview(content)
    preview:Dock(LEFT)
    preview:SetWide(math.Clamp(card:GetWide() * 0.4, 300, 400))
    preview:DockMargin(0, 0, 14, 0)
    if cfg.previewModel then
        preview:SetPreviewModel(cfg.previewModel)
    end
    cfg.applyPreview(preview, selected)

    local right = content:Add("DPanel")
    right:Dock(FILL)
    right.Paint = function() end

    local search = right:Add("DTextEntry")
    search:Dock(TOP)
    search:SetTall(28)
    search:DockMargin(0, 0, 0, 8)
    TS.Editor.StyleEntry(search)
    search:SetUpdateOnType(true)
    search:SetPlaceholderText(cfg.placeholder or TS.L("search"))
    search:SetText(selected)

    local scroll = right:Add("DScrollPanel")
    scroll:Dock(FILL)
    local sb = scroll:GetVBar()
    sb:SetWide(4)
    sb:SetHideButtons(true)
    sb.Paint = function() end
    sb.btnGrip.Paint = function(_, w, h)
        draw.RoundedBox(2, 0, 0, w, h, T.line)
    end

    local LIST_CAP = 300
    local function rebuild(filter)
        scroll:Clear()
        filter = string.lower(filter or "")
        local shown, hidden = 0, 0
        for _, item in ipairs(cfg.items or {}) do
            if filter == "" or string.find(string.lower(item), filter, 1, true) then
                if shown >= LIST_CAP then
                    hidden = hidden + 1
                else
                    shown = shown + 1
                    local row = scroll:Add("DButton")
                    row:Dock(TOP)
                    row:SetTall(26)
                    row:DockMargin(0, 0, 4, 3)
                    row:SetText("")
                    row.Paint = function(s, w, h)
                        local active = item == selected
                        draw.RoundedBox(
                            3,
                            0,
                            0,
                            w,
                            h,
                            active and Color(T.blue.r, T.blue.g, T.blue.b, 40) or (s:IsHovered() and T.card or T.field)
                        )
                        surface.SetDrawColor(active and T.blue or T.lineSoft)
                        surface.DrawOutlinedRect(0, 0, w, h, 1)
                        draw.SimpleText(item, "Talksmith_E_Small", 8, h / 2, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    end
                    row.DoClick = function()
                        selected = item
                        search:SetText(item)
                        cfg.applyPreview(preview, item)
                    end
                end
            end
        end
        if hidden > 0 then
            local note = scroll:Add("DLabel")
            note:Dock(TOP)
            note:SetTall(24)
            note:DockMargin(0, 2, 4, 3)
            note:SetFont("Talksmith_E_Tiny")
            note:SetTextColor(T.dim)
            note:SetContentAlignment(5)
            note:SetText(TS.L("picker_more", hidden))
        end
    end

    search.OnValueChange = function(_, v)
        selected = v or ""
        rebuild(v)
    end
    search.OnEnter = function()
        cfg.applyPreview(preview, selected)
    end

    TS.Editor.RegisterModalPanel(scr)
    rebuild("")
    return scr
end

local function modelSequences(model)
    local names = {}
    if not isstring(model) or model == "" then
        return names
    end
    local ent = ClientsideModel(model, RENDERGROUP_OTHER)
    if IsValid(ent) then
        for i = 0, ent:GetSequenceCount() - 1 do
            local n = ent:GetSequenceName(i)
            if isstring(n) and n ~= "" and n ~= "unknown" then
                names[#names + 1] = n
            end
        end
        ent:Remove()
    end
    table.sort(names)
    return names
end

local modelListCache
local function collectModels()
    if modelListCache then
        return modelListCache
    end
    local seen, out = {}, {}
    local function add(list, path)
        if not isstring(path) or path == "" then
            return
        end
        if not string.EndsWith(string.lower(path), ".mdl") then
            return
        end
        local key = string.lower(path)
        if seen[key] then
            return
        end
        seen[key] = true
        list[#list + 1] = path
    end

    for _, path in ipairs(TS.Config.model_suggestions or {}) do
        add(out, path)
    end

    local installed = {}
    if player_manager and player_manager.AllValidModels then
        for _, path in pairs(player_manager.AllValidModels() or {}) do
            add(installed, path)
        end
    end
    for _, name in ipairs(file.Find("models/player/*.mdl", "GAME") or {}) do
        add(installed, "models/player/" .. name)
    end
    table.sort(installed)
    for _, path in ipairs(installed) do
        out[#out + 1] = path
    end

    modelListCache = out
    return out
end

function TS.Editor.OpenModelPicker(opts)
    return pickerModal({
        title = TS.L("model_picker_title"),
        previewModel = (opts.current ~= "" and opts.current) or "models/Humans/Group01/male_02.mdl",
        items = collectModels(),
        current = opts.current or "",
        placeholder = TS.L("model_search"),
        applyPreview = function(preview, value)
            preview:SetPreviewModel(value)
        end,
        onSelect = opts.onSelect,
    })
end

function TS.Editor.OpenAnimationBrowser(opts)
    return pickerModal({
        title = TS.L("anim_picker_title"),
        previewModel = opts.model,
        items = modelSequences(opts.model),
        current = opts.current or "",
        placeholder = TS.L("anim_search"),
        allowClear = true,
        applyPreview = function(preview, value)
            preview:SetPreviewSequence(value)
        end,
        onSelect = opts.onSelect,
    })
end

function TS.Editor.OpenDialogueSettings(doc, cb)
    if not doc then
        return
    end
    if IsValid(TS.Editor.DialogueSettingsFrame) then
        TS.Editor.DialogueSettingsFrame:Remove()
    end
    local T = TS.Editor.Theme
    local s = doc.settings
    cb = cb or {}

    local snapped = false
    local function touch()
        if not snapped then
            snapped = true
            if cb.Snapshot then
                cb.Snapshot()
            end
        end
        if cb.Changed then
            cb.Changed()
        end
    end

    local scr = vgui.Create("EditablePanel")
    TS.Editor.DialogueSettingsFrame = scr
    TS.Editor.DialogueSettingsOpen = true
    scr:SetSize(ScrW(), ScrH())
    scr.Paint = function(_, w, h)
        surface.SetDrawColor(0, 0, 0, 170)
        surface.DrawRect(0, 0, w, h)
    end
    scr.Think = function()
        if TS.Editor.PickerDepth and TS.Editor.PickerDepth > 0 then
            return
        end
        if gui.IsGameUIVisible() and not gui.IsConsoleVisible() then
            gui.HideGameUI()
            scr:Remove()
        end
    end
    scr.OnRemove = function()
        TS.Editor.DialogueSettingsOpen = false
        if TS.Editor.DialogueSettingsFrame == scr then
            TS.Editor.DialogueSettingsFrame = nil
        end
    end

    local card = scr:Add("DPanel")
    card:SetSize(
        math.min(math.Clamp(ScrW() * 0.74, 620, 1000), math.max(ScrW() - 24, 320)),
        math.min(math.Clamp(ScrH() * 0.7, 480, 780), math.max(ScrH() - 24, 320))
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
    header:DockPadding(22, 0, 10, 0)
    header.Paint = function(_, w, h)
        draw.SimpleText(TS.L("settings_title"), "Talksmith_E_Title", 22, h / 2, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(T.line)
        surface.DrawLine(0, h - 1, w, h - 1)
    end
    local close = header:Add("DButton")
    close:Dock(RIGHT)
    close:SetWide(38)
    close:DockMargin(0, 9, 0, 9)
    TS.Editor.StyleButton(close, { label = "✕" })
    close.DoClick = function()
        scr:Remove()
    end

    local content = card:Add("DPanel")
    content:Dock(FILL)
    content:DockPadding(18, 14, 14, 16)
    content.Paint = function() end

    local preview = TS.Editor.BuildModelPreview(content)
    preview:Dock(LEFT)
    preview:SetWide(math.Clamp(card:GetWide() * 0.4, 220, 420))
    preview:DockMargin(0, 0, 16, 0)

    local rightCol = content:Add("DPanel")
    rightCol:Dock(FILL)
    rightCol.Paint = function() end

    local activeTab = "identity"
    local rebuild

    local tabDefs = {
        { "identity", TS.L("s_identity") },
        { "appearance", TS.L("s_appearance") },
        { "behavior", TS.L("s_behavior") },
    }
    local tabRow = rightCol:Add("DPanel")
    tabRow:Dock(TOP)
    tabRow:SetTall(36)
    tabRow:DockMargin(0, 0, 0, 12)
    tabRow.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, T.field)
    end
    tabRow.buttons = {}
    for _, t in ipairs(tabDefs) do
        local key, lbl = t[1], t[2]
        local tb = tabRow:Add("DButton")
        tb:SetText("")
        tb.Paint = function(s2, w, h)
            local active = activeTab == key
            if active or s2:IsHovered() then
                draw.RoundedBox(4, 3, 3, w - 6, h - 6, active and T.accentSoft or T.hover)
            end
            if active then
                surface.SetFont("Talksmith_E_Small")
                local tw = surface.GetTextSize(lbl)
                local uw = math.Round(math.min(w - 14, tw + 16))
                draw.RoundedBox(1, math.Round((w - uw) / 2), h - 6, uw, 2, T.blue)
            end
            draw.SimpleText(lbl, "Talksmith_E_Small", w / 2, h / 2, active and T.text or T.muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        tb.DoClick = function()
            if activeTab ~= key then
                activeTab = key
                rebuild()
            end
        end
        tabRow.buttons[#tabRow.buttons + 1] = tb
    end
    tabRow.PerformLayout = function(s2, w, h)
        local bw = math.floor(w / #s2.buttons)
        for i, tb in ipairs(s2.buttons) do
            local x = (i - 1) * bw
            tb:SetPos(x, 0)
            tb:SetSize(i == #s2.buttons and w - x or bw, h)
        end
    end

    local body = rightCol:Add("DScrollPanel")
    body:Dock(FILL)
    local vb = body:GetVBar()
    vb:SetWide(4)
    vb:SetHideButtons(true)
    vb.Paint = function() end
    vb.btnGrip.Paint = function(_, w, h)
        draw.RoundedBox(2, 0, 0, w, h, T.line)
    end
    body:GetCanvas():DockPadding(0, 0, 12, 0)

    local function section(key)
        local l = body:Add("DLabel")
        l:Dock(TOP)
        l:DockMargin(0, 14, 0, 6)
        l:SetTall(22)
        l:SetFont("Talksmith_E_Head")
        l:SetTextColor(T.blue)
        l:SetText(TS.L(key))
    end
    local function label(text)
        local l = body:Add("DLabel")
        l:Dock(TOP)
        l:DockMargin(0, 8, 0, 3)
        l:SetTall(18)
        l:SetFont("Talksmith_E_Small")
        l:SetTextColor(T.muted)
        l:SetText(text)
    end
    local function hint(text)
        local l = body:Add("DLabel")
        l:Dock(TOP)
        l:DockMargin(0, 2, 0, 0)
        l:SetTall(16)
        l:SetFont("Talksmith_E_Tiny")
        l:SetTextColor(T.dim)
        l:SetWrap(true)
        l:SetAutoStretchVertical(true)
        l:SetText(text)
    end
    local function entry(value, onChange)
        local e = body:Add("DTextEntry")
        e:Dock(TOP)
        e:SetTall(28)
        TS.Editor.StyleEntry(e)
        e:SetText(value or "")
        e.OnValueChange = function(_, v)
            onChange(v or "")
            touch()
        end
        return e
    end
    local function combo(choices, current, onSelect)
        local c = body:Add("DComboBox")
        c:Dock(TOP)
        c:SetTall(28)
        TS.Editor.StyleCombo(c)
        local found = false
        for _, choice in ipairs(choices) do
            local labelText = istable(choice) and choice.label or choice
            local value = istable(choice) and choice.value or choice
            c:AddChoice(labelText, value, value == current)
            found = found or value == current
        end
        if not found and current and current ~= "" then
            c:AddChoice(current, current, true)
        end
        c.OnSelect = function(_, _, labelText, value)
            onSelect(value or labelText)
            touch()
        end
        return c
    end
    local function slider(cfg)
        local sl = TS.Editor.Slider(body, cfg)
        sl:Dock(TOP)
        sl:DockMargin(0, 2, 0, 0)
        return sl
    end

    local function refreshPreview()
        preview:SetPreviewScale(tonumber(s.actor_scale) or 1)
        preview:SetPreviewSkin(math.floor(tonumber(s.actor_skin) or 0))
        for id, val in pairs(istable(s.actor_bodygroups) and s.actor_bodygroups or {}) do
            preview:SetPreviewBodygroup(tonumber(id) or 0, tonumber(val) or 0)
        end
        preview:SetPreviewSequence(s.idle_sequence or "")
    end

    local function buildBodygroups()
        local ent = preview:GetEnt()
        section("s_bodygroups")
        local parts = {}
        if IsValid(ent) then
            for i = 0, ent:GetNumBodyGroups() - 1 do
                if ent:GetBodygroupCount(i) > 1 then
                    parts[#parts + 1] = i
                end
            end
        end
        if #parts == 0 then
            hint(TS.L("no_bodygroups"))
            return
        end
        for _, i in ipairs(parts) do
            local count = ent:GetBodygroupCount(i)
            local name = ent:GetBodygroupName(i)
            if not name or name == "" then
                name = TS.L("s_part") .. " " .. i
            end
            label(name)
            local key = tostring(i)
            local cur = math.floor(tonumber(istable(s.actor_bodygroups) and s.actor_bodygroups[key]) or 0)
            slider({
                min = 0,
                max = count - 1,
                decimals = 0,
                value = math.Clamp(cur, 0, count - 1),
                onChange = function(v)
                    s.actor_bodygroups = istable(s.actor_bodygroups) and s.actor_bodygroups or {}
                    s.actor_bodygroups[key] = math.floor(v)
                    preview:SetPreviewBodygroup(i, math.floor(v))
                    touch()
                end,
            })
        end
    end

    local function buildIdentity()
        label(TS.L("s_name"))
        entry(s.actor_name, function(v)
            s.actor_name = v
        end)
        label(TS.L("s_subtitle"))
        entry(s.actor_subtitle, function(v)
            s.actor_subtitle = v
        end)
        label(TS.L("s_model"))
        local modelRow = TS.Editor.PickerRow(body, {
            value = s.actor_model,
            placeholder = "models/...",
            onOpen = function(row)
                TS.Editor.OpenModelPicker({
                    current = s.actor_model,
                    onSelect = function(v)
                        if v == "" then
                            return
                        end
                        s.actor_model = v
                        row:SetValueText(v)
                        preview:SetPreviewModel(v)
                        refreshPreview()
                        touch()
                        timer.Simple(0, function()
                            if IsValid(scr) then
                                rebuild()
                            end
                        end)
                    end,
                })
            end,
        })
        local copyModel = body:Add("DButton")
        copyModel:Dock(TOP)
        copyModel:SetTall(26)
        copyModel:DockMargin(0, 0, 0, 4)
        TS.Editor.StyleButton(copyModel, { label = TS.L("copy_aim_model") })
        copyModel.DoClick = function()
            local player = LocalPlayer()
            local target = IsValid(player) and player:GetEyeTrace().Entity
            local model = IsValid(target) and target:GetModel() or ""
            if not isstring(model) or model == "" or not util.IsValidModel(model) then
                TS.Runtime.Notify(TS.L("copy_aim_invalid"), NOTIFY_ERROR, 3)
                return
            end
            s.actor_model = model
            modelRow:SetValueText(model)
            preview:SetPreviewModel(model)
            refreshPreview()
            touch()
            TS.Runtime.Notify(TS.L("copy_model_done"), NOTIFY_GENERIC, 2)
            timer.Simple(0, function()
                if IsValid(scr) then
                    rebuild()
                end
            end)
        end
    end

    local function buildAppearance()
        local ent = preview:GetEnt()
        local skinCount = IsValid(ent) and ent:SkinCount() or 1
        if skinCount > 1 then
            label(TS.L("s_skin"))
            slider({
                min = 0,
                max = skinCount - 1,
                decimals = 0,
                value = math.Clamp(math.floor(tonumber(s.actor_skin) or 0), 0, skinCount - 1),
                onChange = function(v)
                    s.actor_skin = math.floor(v)
                    preview:SetPreviewSkin(math.floor(v))
                    touch()
                end,
            })
        end

        label(TS.L("s_name_offset"))
        slider({
            min = 20,
            max = 160,
            decimals = 0,
            value = tonumber(s.name_offset) or 82,
            onChange = function(v)
                s.name_offset = math.floor(v)
                touch()
            end,
        })
        label(TS.L("s_idle"))
        TS.Editor.PickerRow(body, {
            value = s.idle_sequence,
            placeholder = TS.L("idle_auto"),
            onOpen = function(row)
                TS.Editor.OpenAnimationBrowser({
                    model = s.actor_model,
                    current = s.idle_sequence,
                    onSelect = function(v)
                        s.idle_sequence = v
                        row:SetValueText(v ~= "" and v or "")
                        preview:SetPreviewSequence(v)
                        touch()
                    end,
                })
            end,
        })
        hint(TS.L("s_idle_hint"))

        label(TS.L("random_idle"))
        s.idle_sequences = istable(s.idle_sequences) and s.idle_sequences or {}
        for i, seqName in ipairs(s.idle_sequences) do
            local rrow = body:Add("DPanel")
            rrow:Dock(TOP)
            rrow:SetTall(24)
            rrow:DockMargin(0, 0, 0, 3)
            rrow.Paint = function(_, w, h)
                draw.RoundedBox(3, 0, 0, w, h, T.field)
                surface.SetDrawColor(T.lineSoft)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                draw.SimpleText(seqName, "Talksmith_E_Small", 8, h / 2, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            local rem = rrow:Add("DButton")
            rem:Dock(RIGHT)
            rem:SetWide(24)
            TS.Editor.StyleButton(rem, { label = "✕", danger = true })
            rem.DoClick = function()
                table.remove(s.idle_sequences, i)
                touch()
                timer.Simple(0, function()
                    if IsValid(scr) then
                        rebuild()
                    end
                end)
            end
        end
        local addRnd = body:Add("DButton")
        addRnd:Dock(TOP)
        addRnd:SetTall(24)
        addRnd:DockMargin(0, 0, 0, 6)
        TS.Editor.StyleButton(addRnd, { label = TS.L("add"), icon = "plus" })
        addRnd.DoClick = function()
            TS.Editor.OpenAnimationBrowser({
                model = s.actor_model,
                current = "",
                onSelect = function(v)
                    if v == "" then
                        return
                    end
                    s.idle_sequences = istable(s.idle_sequences) and s.idle_sequences or {}
                    s.idle_sequences[#s.idle_sequences + 1] = v
                    touch()
                    timer.Simple(0, function()
                        if IsValid(scr) then
                            rebuild()
                        end
                    end)
                end,
            })
        end

        label(TS.L("s_theme"))
        local themeChoices = {}
        for _, id in ipairs(TS.Config.allowed_themes) do
            themeChoices[#themeChoices + 1] = { label = TS.L("theme_" .. id), value = id }
        end
        combo(themeChoices, s.theme, function(v)
            s.theme = v
        end)
        hint(TS.L("s_theme_hint"))
        buildBodygroups()
    end

    local function buildBehavior()
        s.start_random = istable(s.start_random) and s.start_random or {}
        local selectedStarts = {}
        for _, id in ipairs(s.start_random) do
            selectedStarts[id] = true
        end
        local nodeIDs = {}
        for id in pairs(doc.nodes or {}) do
            nodeIDs[#nodeIDs + 1] = id
        end
        table.sort(nodeIDs)
        if #nodeIDs >= 2 then
            label(TS.L("random_start"))
            hint(TS.L("random_start_hint"))

            local function commitStarts()
                s.start_random = {}
                for _, nodeID in ipairs(nodeIDs) do
                    if selectedStarts[nodeID] then
                        s.start_random[#s.start_random + 1] = nodeID
                    end
                end
                touch()
            end

            local rowH = 30
            local group = body:Add("DPanel")
            group:Dock(TOP)
            group:DockMargin(0, 4, 0, 12)
            group:DockPadding(6, 6, 6, 6)
            group:SetTall(12 + #nodeIDs * rowH + (#nodeIDs - 1) * 2)
            group.Paint = function(_, w, h)
                draw.RoundedBox(6, 0, 0, w, h, T.field)
                surface.SetDrawColor(T.lineSoft)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
            end

            for i, id in ipairs(nodeIDs) do
                local name, derived = TS.Editor.NodeDisplayName(doc.nodes[id], id)
                local row = group:Add("DButton")
                row:Dock(TOP)
                row:SetTall(rowH)
                row:DockMargin(0, i > 1 and 2 or 0, 0, 0)
                row:SetText("")
                row.on = selectedStarts[id] == true
                row.Paint = function(s2, w, h)
                    if s2.on or s2:IsHovered() then
                        draw.RoundedBox(4, 0, 0, w, h, s2.on and T.accentSoft or T.hover)
                    end
                    local box = 16
                    local by = math.floor(h / 2 - box / 2)
                    draw.RoundedBox(3, 6, by, box, box, s2.on and T.blue or T.card)
                    surface.SetDrawColor(s2.on and T.blue or T.lineSoft)
                    surface.DrawOutlinedRect(6, by, box, box, 1)
                    if s2.on then
                        TS.Editor.DrawIcon("check", 6 + box / 2 - 6, by + 2, 12, T.canvas)
                    end
                    local tx = 6 + box + 10
                    surface.SetFont("Talksmith_E_Small")
                    local nm = clipText(name, 32)
                    draw.SimpleText(nm, "Talksmith_E_Small", tx, h / 2, s2.on and T.text or T.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    if derived then
                        local nw = surface.GetTextSize(nm)
                        draw.SimpleText(id, "Talksmith_E_Tiny", tx + nw + 8, h / 2 + 1, T.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    end
                end
                row.DoClick = function(s2)
                    s2.on = not s2.on
                    selectedStarts[id] = s2.on or nil
                    commitStarts()
                end
            end
        end
        local uc = TS.Editor.Check(body, {
            label = TS.L("s_use_limit"),
            value = s.use_limit == true,
            onChange = function(v)
                s.use_limit = v
                touch()
            end,
        })
        uc:Dock(TOP)
        uc:DockMargin(0, 2, 0, 0)
        label(TS.L("s_distance"))
        slider({
            min = 64,
            max = 512,
            decimals = 0,
            value = tonumber(s.interact_distance) or 160,
            onChange = function(v)
                s.interact_distance = math.floor(v)
                touch()
            end,
        })
    end

    rebuild = function()
        body:Clear()
        if activeTab == "appearance" then
            buildAppearance()
        elseif activeTab == "behavior" then
            buildBehavior()
        else
            buildIdentity()
        end
    end

    TS.Editor.RegisterModalPanel(scr)
    preview:SetPreviewModel(s.actor_model)
    refreshPreview()
    rebuild()
end
