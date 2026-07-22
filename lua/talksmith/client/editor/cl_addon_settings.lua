local TS = Talksmith

local MAX_PAYLOAD = 262144
local MAX_NET_PAYLOAD = 60000

local function applyIntegrationCatalog(integrations)
    TS.Editor.Catalog = TS.Editor.Catalog or {}
    TS.Editor.Catalog.integrations = integrations or {}
    local availabilityChanged = false
    local availableProviderKinds = {}
    local availableProviderMethods = {}
    local providerCatalog = TS.Editor.Catalog.providers or {}
    local hasProviderCatalog = next(providerCatalog) ~= nil

    if hasProviderCatalog then
        for kind, providers in pairs(providerCatalog) do
            for _, provider in pairs(providers) do
                local integration = provider.integration
                    and TS.Editor.Catalog.integrations[provider.integration]
                local available = not provider.integration
                    or integration ~= nil and integration.status == "available"
                if provider.available ~= available then
                    availabilityChanged = true
                end
                provider.available = available
                if available then
                    availableProviderKinds[kind] = true
                    availableProviderMethods[kind] = availableProviderMethods[kind] or {}
                    for method, supported in pairs(provider.methods or {}) do
                        if supported == true then
                            availableProviderMethods[kind][method] = true
                        end
                    end
                end
            end
        end
    else
        for _, integration in pairs(TS.Editor.Catalog.integrations) do
            if integration.status == "available" then
                for _, kind in ipairs(integration.provider_kinds or {}) do
                    availableProviderKinds[kind] = true
                end
            end
        end
    end

    for _, group in ipairs({
        TS.Editor.Catalog.actions or {},
        TS.Editor.Catalog.conditions or {},
        TS.Editor.Catalog.variables or {},
    }) do
        for _, definition in pairs(group) do
            local available
            if definition.integration then
                local integration = TS.Editor.Catalog.integrations[definition.integration]
                available = integration ~= nil and integration.status == "available"
            elseif definition.provider_kind then
                available = availableProviderKinds[definition.provider_kind] == true
                if available and definition.provider_method and hasProviderCatalog then
                    local methods = availableProviderMethods[definition.provider_kind] or {}
                    available = methods[definition.provider_method] == true
                end
            end

            if available ~= nil then
                if definition.available ~= available then
                    availabilityChanged = true
                end
                definition.available = available
            end
        end
    end

    return availabilityChanged
end

local function sendServerSetting(key, value)
    local json = util.TableToJSON({ value = value })
    if not json then
        return false
    end
    net.Start("ts_server_setting_update")
    net.WriteString(key or "")
    net.WriteString(json)
    net.SendToServer()
    return true
end

local function queueServerSetting(key, value)
    local timerName = "talksmith_server_setting_" .. tostring(key)
    timer.Create(timerName, 0.3, 1, function()
        sendServerSetting(key, value)
    end)
end

local function sendPermissionSetting(right, group)
    net.Start("ts_permission_setting_update")
    net.WriteString(right or "")
    net.WriteString(group or "")
    net.SendToServer()
end

local function sendWeaponAllowlist(class, allowed)
    net.Start("ts_weapon_allowlist_update")
    net.WriteBool(allowed == true)
    net.WriteString(class or "")
    net.SendToServer()
end

function TS.Editor.RequestSettings()
    net.Start("ts_settings_request")
    net.SendToServer()
end

function TS.Integrations.SetEnabled(id, enabled)
    net.Start("ts_settings_update")
    net.WriteString(id or "")
    net.WriteBool(enabled == true)
    net.SendToServer()
end

function TS.Config.Set(key, value, delayed)
    if delayed then
        queueServerSetting(key, value)
        return true
    end
    return sendServerSetting(key, value)
end

net.Receive("ts_runtime_settings", function()
    TS.Config.dialogue_speed = math.Clamp(net.ReadFloat(), 0.25, 4)
    TS.Config.show_name = net.ReadBool()
    TS.Config.show_description = net.ReadBool()
    TS.Config.show_interaction = net.ReadBool()
    hook.Run("Talksmith.RuntimeSettingsChanged", TS.Config.dialogue_speed, TS.Config.show_name, TS.Config.show_description, TS.Config.show_interaction)
end)

local function applyRuntimeConfig(settings)
    if not istable(settings) then
        return
    end
    TS.Config.dialogue_speed = math.Clamp(tonumber(settings.dialogue_speed) or 1, 0.25, 4)
    TS.Config.show_name = settings.show_name == true
    TS.Config.show_description = settings.show_description == true
    TS.Config.show_interaction = settings.show_interaction == true
    hook.Run("Talksmith.RuntimeSettingsChanged", TS.Config.dialogue_speed, TS.Config.show_name, TS.Config.show_description, TS.Config.show_interaction)
end

local function styleScroll(scroll)
    local bar = scroll:GetVBar()
    bar:SetWide(4)
    bar:SetHideButtons(true)
    bar.Paint = function() end
    bar.btnGrip.Paint = function(_, width, height)
        draw.RoundedBox(2, 0, 0, width, height, TS.Editor.Theme.line)
    end
    scroll:GetCanvas():DockPadding(0, 0, 10, 4)
end

local function addHeading(parent, title, subtitle)
    local T = TS.Editor.Theme
    local heading = parent:Add("DPanel")
    heading:Dock(TOP)
    heading:SetTall(66)
    heading.Paint = function(_, _, height)
        draw.SimpleText(title, "Talksmith_E_Display", 0, 15, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(subtitle, "Talksmith_E_Small", 0, height - 13, T.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    return heading
end

local function addSection(parent, text)
    local T = TS.Editor.Theme
    local label = parent:Add("DLabel")
    label:Dock(TOP)
    label:DockMargin(0, 10, 0, 7)
    label:SetTall(22)
    label:SetFont("Talksmith_E_Head")
    label:SetTextColor(T.blue)
    label:SetText(text)
    return label
end

local function addReadOnly(parent)
    local T = TS.Editor.Theme
    local panel = parent:Add("DPanel")
    panel:Dock(TOP)
    panel:SetTall(42)
    panel:DockMargin(0, 4, 0, 10)
    panel.Paint = function(_, width, height)
        draw.RoundedBox(4, 0, 0, width, height, T.field)
        TS.Editor.DrawIcon("warning", 13, height / 2 - 8, 16, T.yellow)
        draw.SimpleText(TS.L("addon_settings_read_only"), "Talksmith_E_Small", 39, height / 2, T.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    return panel
end

local function addCard(parent, opts)
    local T = TS.Editor.Theme
    local card = parent:Add("DPanel")
    card:Dock(TOP)
    card:DockMargin(0, 0, 0, 8)
    card:SetTall(opts.tall or 106)
    card.Paint = function(_, width, height)
        draw.RoundedBox(5, 0, 0, width, height, T.field)
        surface.SetDrawColor(T.lineSoft)
        surface.DrawOutlinedRect(0, 0, width, height, 1)
    end

    local title = card:Add("DLabel")
    title:SetFont("Talksmith_E_Head")
    title:SetTextColor(T.text)
    title:SetText(opts.title or "")

    local hint = card:Add("DLabel")
    hint:SetFont("Talksmith_E_Small")
    hint:SetTextColor(T.muted)
    hint:SetWrap(true)
    hint:SetText(opts.hint or "")

    local control = opts.build and opts.build(card) or nil
    local controlTall = opts.controlTall or 28
    card.PerformLayout = function(_, width, height)
        title:SetPos(14, 10)
        title:SetSize(math.max(width - 28, 0), 22)
        hint:SetPos(14, 33)
        hint:SetSize(math.max(width - 28, 0), math.max(height - controlTall - 49, 18))
        if IsValid(control) then
            control:SetPos(14, height - controlTall - 12)
            control:SetSize(math.max(width - 28, 0), controlTall)
        end
    end
    return card, control
end

local function addLoading(parent)
    local label = parent:Add("DLabel")
    label:Dock(TOP)
    label:SetTall(48)
    label:SetFont("Talksmith_E_Body")
    label:SetTextColor(TS.Editor.Theme.muted)
    label:SetContentAlignment(5)
    label:SetText(TS.L("addon_settings_loading"))
end

local function pageScroll(parent, title, subtitle)
    local scroll = parent:Add("DScrollPanel")
    scroll:Dock(FILL)
    styleScroll(scroll)
    addHeading(scroll, title, subtitle)
    return scroll
end

local function addCheckCard(parent, opts)
    local control
    local card = addCard(parent, {
        title = opts.title,
        hint = opts.hint,
        tall = opts.tall or 100,
        controlTall = 28,
        build = function(panel)
            control = TS.Editor.Check(panel, {
                label = TS.L("addon_settings_enabled"),
                value = opts.value == true,
                onChange = opts.onChange,
            })
            if opts.enabled == false then
                control:SetDisabled(true)
            end
            return control
        end,
    })
    return card, control
end

local function addSliderCard(parent, opts)
    local control
    local card = addCard(parent, {
        title = opts.title,
        hint = opts.hint,
        tall = opts.tall or 108,
        controlTall = 28,
        build = function(panel)
            control = TS.Editor.Slider(panel, {
                min = opts.min,
                max = opts.max,
                decimals = opts.decimals or 0,
                value = opts.value,
                onChange = opts.onChange,
            })
            if opts.enabled == false then
                control:SetMouseInputEnabled(false)
            end
            return control
        end,
    })
    return card, control
end

local function addComboCard(parent, opts)
    local control
    local card = addCard(parent, {
        title = opts.title,
        hint = opts.hint,
        tall = opts.tall or 108,
        controlTall = 30,
        build = function(panel)
            control = panel:Add("DComboBox")
            TS.Editor.StyleCombo(control)
            for _, choice in ipairs(opts.choices or {}) do
                control:AddChoice(choice.label, choice.value, choice.value == opts.value)
            end
            control.OnSelect = function(_, _, label, value)
                if opts.onSelect then
                    opts.onSelect(value == nil and label or value)
                end
            end
            if opts.enabled == false then
                control:SetEnabled(false)
            end
            return control
        end,
    })
    return card, control
end

local function utf8Length(text)
    if utf8 and utf8.len then
        return utf8.len(text) or #text
    end
    return #text
end

local function utf8Prefix(text, count)
    if count <= 0 then
        return ""
    end
    if utf8 and utf8.offset then
        local nextByte = utf8.offset(text, count + 1)
        if nextByte then
            return string.sub(text, 1, nextByte - 1)
        end
    end
    return text
end

local function addSpeedPreview(parent, speed)
    local T = TS.Editor.Theme
    local sample = TS.L("addon_settings_speed_preview_text")
    local length = utf8Length(sample)
    local preview = parent:Add("DPanel")
    preview:Dock(TOP)
    preview:DockMargin(0, 0, 0, 10)
    preview:SetTall(88)
    preview.speed = speed
    preview.started = RealTime()
    preview.SetSpeed = function(self, value)
        self.speed = math.Clamp(tonumber(value) or 1, 0.25, 4)
        self.started = RealTime()
    end
    preview.Paint = function(self, width, height)
        draw.RoundedBox(5, 0, 0, width, height, T.canvas)
        surface.SetDrawColor(T.lineSoft)
        surface.DrawOutlinedRect(0, 0, width, height, 1)
        draw.SimpleText(TS.L("addon_settings_speed_preview"), "Talksmith_E_Small", 14, 18, T.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        local interval = 0.05 / math.max(self.speed, 0.01)
        local elapsed = RealTime() - self.started
        local count = math.Clamp(math.floor(elapsed / interval), 0, length)
        if elapsed > length * interval + 1.2 then
            self.started = RealTime()
            count = 0
        end
        local shown = utf8Prefix(sample, count)
        if count < length then
            shown = shown .. "▌"
        end
        draw.SimpleText(shown, "Talksmith_E_Body", 14, 55, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    return preview
end

local function clientWeaponClass(value)
    if not isstring(value) then
        return nil
    end
    local class = string.Trim(value)
    if #class <= 0 or #class > 64 or not string.match(class, "^[a-z][a-z0-9_]*$") then
        return nil
    end
    return class
end

local function openWeaponAllowlist(settingsFrame)
    if IsValid(TS.Editor.WeaponAllowlistFrame) then
        local existing = TS.Editor.WeaponAllowlistFrame
        existing:ApplyData(settingsFrame.SettingsData or {})
        existing:MakePopup()
        existing:MoveToFront()
        return
    end

    local T = TS.Editor.Theme
    local modal = vgui.Create("DFrame")
    TS.Editor.WeaponAllowlistFrame = modal
    modal:SetTitle("")
    modal:ShowCloseButton(false)
    modal:SetDraggable(false)
    modal:SetSizable(false)
    modal:SetDeleteOnClose(true)
    modal:SetBackgroundBlur(true)
    modal:SetDrawOnTop(true)
    modal:SetSize(math.min(ScrW() - 40, 680), math.min(ScrH() - 40, 560))
    modal:Center()
    modal:DockPadding(0, 0, 0, 0)
    modal.Paint = function(self, width, height)
        Derma_DrawBackgroundBlur(self, self.m_fCreateTime)
        draw.RoundedBox(7, 0, 0, width, height, T.side)
        surface.SetDrawColor(T.line)
        surface.DrawOutlinedRect(0, 0, width, height, 1)
    end

    local header = modal:Add("DPanel")
    header:Dock(TOP)
    header:SetTall(72)
    header.Paint = function(_, width, height)
        draw.RoundedBox(2, 20, 19, 3, 34, T.blue)
        draw.SimpleText(TS.L("addon_weapons_window_title"), "Talksmith_E_Title", 34, 27, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(TS.L("addon_weapons_window_subtitle"), "Talksmith_E_Small", 34, 50, T.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(T.line)
        surface.DrawRect(0, height - 1, width, 1)
    end

    local close = header:Add("DButton")
    close:Dock(RIGHT)
    close:SetWide(44)
    close:DockMargin(0, 17, 12, 17)
    TS.Editor.StyleButton(close, { label = "", quiet = true, icon = "x" })
    TS.Editor.SetTooltip(close, TS.L("close"))
    close.DoClick = function()
        modal:Remove()
    end

    local body = modal:Add("DPanel")
    body:Dock(FILL)
    body:DockPadding(20, 18, 20, 20)
    body.Paint = function() end

    local status = body:Add("DPanel")
    status:Dock(TOP)
    status:SetTall(58)
    status:DockMargin(0, 0, 0, 12)
    status.Paint = function(self, width, height)
        local locked = modal.AllowlistLocked == true
        local editable = modal.CanEdit == true
        local color = locked and T.yellow or (editable and T.blue or T.muted)
        local icon = locked and "warning" or (editable and "check-circle" or "warning")
        local key = locked and "addon_weapons_lua_override"
            or (editable and "addon_weapons_menu_source" or "addon_weapons_read_only")
        draw.RoundedBox(4, 0, 0, width, height, locked and Color(210, 162, 72, 12) or T.field)
        surface.SetDrawColor(locked and T.yellow or T.lineSoft)
        surface.DrawOutlinedRect(0, 0, width, height, 1)
        TS.Editor.DrawIcon(icon, 14, height / 2 - 9, 18, color)
        draw.SimpleText(TS.L(key), "Talksmith_E_Small", 43, height / 2, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local form = body:Add("DPanel")
    form:Dock(TOP)
    form:SetTall(38)
    form:DockMargin(0, 0, 0, 14)
    form.Paint = function() end

    local addButton = form:Add("DButton")
    addButton:Dock(RIGHT)
    addButton:SetWide(132)
    TS.Editor.StyleButton(addButton, {
        label = TS.L("addon_weapons_add"),
        accent = true,
        icon = "plus",
        font = "Talksmith_E_Small",
    })

    local entry = form:Add("DTextEntry")
    entry:Dock(FILL)
    entry:DockMargin(0, 0, 10, 0)
    entry:SetPlaceholderText(TS.L("addon_weapons_placeholder"))
    entry:SetUpdateOnType(true)
    TS.Editor.StyleEntry(entry)

    local listHeading = body:Add("DLabel")
    listHeading:Dock(TOP)
    listHeading:SetTall(28)
    listHeading:SetFont("Talksmith_E_Head")
    listHeading:SetTextColor(T.text)

    local list = body:Add("DScrollPanel")
    list:Dock(FILL)
    styleScroll(list)

    local function submit()
        if modal.CanEdit ~= true then
            return
        end
        local class = clientWeaponClass(entry:GetValue())
        if not class then
            TS.Runtime.Notify(TS.L("addon_weapons_invalid_class"), NOTIFY_ERROR, 4)
            return
        end
        sendWeaponAllowlist(class, true)
        entry:SetText("")
        entry:RequestFocus()
    end

    addButton.DoClick = submit
    entry.OnEnter = submit

    function modal:ApplyData(data)
        self.SettingsData = data or {}
        self.AllowlistLocked = self.SettingsData.allowed_weapons_source == "lua"
        self.CanEdit = self.SettingsData.can_manage_settings == true and not self.AllowlistLocked
        self.WeaponLimit = math.Clamp(math.floor(tonumber(self.SettingsData.allowed_weapons_limit) or 256), 1, 256)

        local weapons = {}
        for _, class in ipairs(self.SettingsData.allowed_weapons or {}) do
            if isstring(class) then
                weapons[#weapons + 1] = class
            end
        end
        table.sort(weapons)

        entry:SetEnabled(self.CanEdit)
        addButton:SetEnabled(self.CanEdit and #weapons < self.WeaponLimit)
        listHeading:SetText(string.format(TS.L("addon_weapons_list_count"), #weapons, self.WeaponLimit))

        local canvas = list:GetCanvas()
        canvas:Clear()
        if #weapons == 0 then
            local empty = canvas:Add("DLabel")
            empty:Dock(TOP)
            empty:SetTall(74)
            empty:SetFont("Talksmith_E_Body")
            empty:SetTextColor(T.dim)
            empty:SetContentAlignment(5)
            empty:SetText(TS.L("addon_weapons_empty"))
            return
        end

        for _, class in ipairs(weapons) do
            local weaponClass = class
            local row = canvas:Add("DPanel")
            row:Dock(TOP)
            row:DockMargin(0, 0, 0, 6)
            row:SetTall(44)
            row.Paint = function(self, width, height)
                draw.RoundedBox(4, 0, 0, width, height, self:IsHovered() and T.card or T.field)
                surface.SetDrawColor(T.lineSoft)
                surface.DrawOutlinedRect(0, 0, width, height, 1)
                TS.Editor.DrawIcon("crosshair-simple", 13, height / 2 - 8, 16, T.blue)
                draw.SimpleText(weaponClass, "Talksmith_E_Body", 39, height / 2, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            local remove = row:Add("DButton")
            remove:Dock(RIGHT)
            remove:SetWide(40)
            remove:DockMargin(0, 6, 7, 6)
            TS.Editor.StyleButton(remove, { label = "", quiet = true, danger = true, icon = "trash" })
            remove:SetEnabled(self.CanEdit)
            TS.Editor.SetTooltip(remove, TS.L("addon_weapons_remove"))
            remove.DoClick = function()
                if modal.CanEdit ~= true then
                    return
                end
                TS.Editor.Confirm(
                    TS.L("addon_weapons_remove_title"),
                    string.format(TS.L("addon_weapons_remove_confirm"), weaponClass),
                    {
                        {
                            label = TS.L("delete"),
                            danger = true,
                            callback = function()
                                sendWeaponAllowlist(weaponClass, false)
                            end,
                        },
                        { label = TS.L("cancel"), quiet = true },
                    }
                )
            end
        end
    end

    modal.OnKeyCodePressed = function(_, key)
        if key == KEY_ESCAPE then
            modal:Remove()
        end
    end
    modal.Think = function()
        if gui.IsGameUIVisible() and not gui.IsConsoleVisible() then
            gui.HideGameUI()
            modal:Remove()
        end
    end
    modal.OnRemove = function()
        if TS.Editor.WeaponAllowlistFrame == modal then
            TS.Editor.WeaponAllowlistFrame = nil
        end
    end

    modal:ApplyData(settingsFrame.SettingsData or {})
    modal:MakePopup()
    modal:DoModal()
end

local function buildEditorPage(parent, frame)
    local scroll = pageScroll(parent, TS.L("addon_settings_editor"), TS.L("addon_settings_editor_subtitle"))
    addSection(scroll, TS.L("addon_settings_local_section"))

    addSliderCard(scroll, {
        title = TS.L("addon_settings_grid_size"),
        hint = TS.L("addon_settings_grid_size_hint"),
        min = 8,
        max = 64,
        decimals = 0,
        value = TS.Editor.GetSetting("grid_size"),
        onChange = function(value)
            TS.Editor.SetSetting("grid_size", math.floor(value))
        end,
    })

    addCheckCard(scroll, {
        title = TS.L("addon_settings_snap"),
        hint = TS.L("addon_settings_snap_hint"),
        value = TS.Editor.GetSetting("snap_to_grid"),
        onChange = function(value)
            TS.Editor.SetSetting("snap_to_grid", value)
        end,
    })

    addCheckCard(scroll, {
        title = TS.L("addon_settings_confirm_delete"),
        hint = TS.L("addon_settings_confirm_delete_hint"),
        value = TS.Editor.GetSetting("confirm_delete"),
        onChange = function(value)
            TS.Editor.SetSetting("confirm_delete", value)
        end,
    })

    addComboCard(scroll, {
        title = TS.L("addon_settings_language"),
        hint = TS.L("addon_settings_language_hint"),
        value = TS.Editor.GetSetting("language"),
        choices = {
            { label = "Русский", value = "ru" },
            { label = "English", value = "en" },
        },
        onSelect = function(value)
            TS.Editor.SetSetting("language", value)
        end,
    })
end

local function buildDialoguesPage(parent, frame)
    local scroll = pageScroll(parent, TS.L("addon_settings_dialogues"), TS.L("addon_settings_dialogues_subtitle"))
    local data = frame.SettingsData
    if not data or not istable(data.settings) then
        addLoading(scroll)
        return
    end

    local settings = data.settings
    local canEdit = data.can_manage_settings == true
    if not canEdit then
        addReadOnly(scroll)
    end

    addSection(scroll, TS.L("addon_settings_runtime_section"))
    local speed = math.Clamp(tonumber(settings.dialogue_speed) or 1, 0.25, 4)
    local preview
    addSliderCard(scroll, {
        title = TS.L("addon_settings_text_speed"),
        hint = TS.L("addon_settings_text_speed_hint"),
        min = 0.25,
        max = 4,
        decimals = 2,
        value = speed,
        enabled = canEdit,
        onChange = function(value)
            settings.dialogue_speed = value
            TS.Config.dialogue_speed = value
            if IsValid(preview) then
                preview:SetSpeed(value)
            end
            TS.Config.Set("dialogue_speed", value, true)
        end,
    })
    preview = addSpeedPreview(scroll, speed)

    addCheckCard(scroll, {
        title = TS.L("addon_settings_show_name"),
        hint = TS.L("addon_settings_show_name_hint"),
        value = settings.show_name == true,
        enabled = canEdit,
        onChange = function(value)
            settings.show_name = value
            TS.Config.show_name = value
            TS.Config.Set("show_name", value)
        end,
    })

    addCheckCard(scroll, {
        title = TS.L("addon_settings_show_description"),
        hint = TS.L("addon_settings_show_description_hint"),
        value = settings.show_description == true,
        enabled = canEdit,
        onChange = function(value)
            settings.show_description = value
            TS.Config.show_description = value
            TS.Config.Set("show_description", value)
        end,
    })

    addCheckCard(scroll, {
        title = TS.L("addon_settings_show_interaction"),
        hint = TS.L("addon_settings_show_interaction_hint"),
        value = settings.show_interaction == true,
        enabled = canEdit,
        onChange = function(value)
            settings.show_interaction = value
            TS.Config.show_interaction = value
            TS.Config.Set("show_interaction", value)
        end,
    })
end

local function buildServerPage(parent, frame)
    local scroll = pageScroll(parent, TS.L("addon_settings_server"), TS.L("addon_settings_server_subtitle"))
    local data = frame.SettingsData
    if not data or not istable(data.settings) then
        addLoading(scroll)
        return
    end

    local settings = data.settings
    local canEdit = data.can_manage_settings == true
    if not canEdit then
        addReadOnly(scroll)
    end

    addSection(scroll, TS.L("addon_settings_persistence_section"))
    addCheckCard(scroll, {
        title = TS.L("addon_settings_autosave_actors"),
        hint = TS.L("addon_settings_autosave_actors_hint"),
        value = settings.autosave_actors == true,
        enabled = canEdit,
        onChange = function(value)
            settings.autosave_actors = value
            TS.Config.Set("autosave_actors", value)
        end,
    })

    addSliderCard(scroll, {
        title = TS.L("addon_settings_backups"),
        hint = TS.L("addon_settings_backups_hint"),
        min = 0,
        max = 50,
        decimals = 0,
        value = math.Clamp(math.floor(tonumber(settings.backups) or 5), 0, 50),
        enabled = canEdit,
        onChange = function(value)
            value = math.floor(value)
            settings.backups = value
            TS.Config.Set("backups", value, true)
        end,
    })

    addSection(scroll, TS.L("addon_weapons_section"))
    local weaponCount = #(istable(data.allowed_weapons) and data.allowed_weapons or {})
    local luaOverride = data.allowed_weapons_source == "lua"
    addCard(scroll, {
        title = TS.L("addon_weapons_card_title"),
        hint = TS.L(luaOverride and "addon_weapons_card_hint_lua" or "addon_weapons_card_hint"),
        tall = 108,
        controlTall = 30,
        build = function(panel)
            local button = panel:Add("DButton")
            TS.Editor.StyleButton(button, {
                label = string.format(
                    TS.L(luaOverride and "addon_weapons_view" or "addon_weapons_manage"),
                    weaponCount
                ),
                accent = canEdit and not luaOverride,
                icon = luaOverride and "warning" or "crosshair-simple",
                font = "Talksmith_E_Small",
            })
            button.DoClick = function()
                openWeaponAllowlist(frame)
            end
            return button
        end,
    })

    addSection(scroll, TS.L("addon_settings_diagnostics_section"))
    local loggingAvailable = data.logging_available == true
    addComboCard(scroll, {
        title = TS.L("addon_settings_logging"),
        hint = TS.L(loggingAvailable and "addon_settings_logging_hint" or "addon_settings_logging_unavailable_hint"),
        value = loggingAvailable and (tonumber(settings.logging) or -1) or -1,
        enabled = canEdit and loggingAvailable,
        choices = {
            { label = TS.L("addon_settings_logging_off"), value = -1 },
            { label = TS.L("addon_settings_logging_errors"), value = 0 },
            { label = TS.L("addon_settings_logging_all"), value = 1 },
        },
        onSelect = function(value)
            value = tonumber(value)
            if value ~= nil then
                settings.logging = value
                TS.Config.Set("logging", value)
            end
        end,
    })
end

local PERMISSION_PAGES = {
    { right = "talksmith.editor.open", key = "editor_open" },
    { right = "talksmith.dialogues.create", key = "dialogues_create" },
    { right = "talksmith.dialogues.edit", key = "dialogues_edit" },
    { right = "talksmith.dialogues.delete", key = "dialogues_delete" },
    { right = "talksmith.dialogues.publish", key = "dialogues_publish" },
    { right = "talksmith.actors.manage", key = "actors_manage" },
    { right = "talksmith.settings.manage", key = "settings_manage" },
    { right = "talksmith.integrations.manage", key = "integrations_manage" },
    { right = "talksmith.diagnostics.view", key = "diagnostics_view" },
    { right = "talksmith.actions.dangerous", key = "actions_dangerous" },
    { right = "talksmith.actions.economy", key = "actions_economy" },
    { right = "talksmith.actions.inventory", key = "actions_inventory" },
    { right = "talksmith.actions.progression", key = "actions_progression" },
    { right = "talksmith.actions.jobs", key = "actions_jobs" },
    { right = "talksmith.actions.events", key = "actions_events" },
    { right = "talksmith.wire.manage", key = "wire_manage" },
}

local function permissionChoices(data, current)
    local choices = {}
    local seen = {}
    for _, entry in ipairs(data.permission_groups or {}) do
        local id = istable(entry) and tostring(entry.id or "") or ""
        if id ~= "" and not seen[string.lower(id)] then
            seen[string.lower(id)] = true
            choices[#choices + 1] = {
                label = istable(entry) and tostring(entry.name or id) or id,
                value = id,
            }
        end
    end

    if isstring(current) and current ~= "" and not seen[string.lower(current)] then
        choices[#choices + 1] = { label = current, value = current }
    end
    return choices
end

local function buildPermissionsPage(parent, frame)
    local scroll = pageScroll(parent, TS.L("addon_permissions"), TS.L("addon_permissions_subtitle"))
    local data = frame.SettingsData
    if not data then
        addLoading(scroll)
        return scroll
    end
    if data.permissions_available ~= true then
        addReadOnly(scroll)
        return scroll
    end

    local canEdit = data.can_manage_permissions == true
    if not canEdit then
        addReadOnly(scroll)
    end

    addSection(
        scroll,
        string.format(TS.L("addon_permissions_backend"), tostring(data.permission_backend_name or data.permission_backend or ""))
    )

    local permissions = istable(data.permissions) and data.permissions or {}
    for _, definition in ipairs(PERMISSION_PAGES) do
        local right = definition.right
        local current = tostring(permissions[right] or "superadmin")
        addComboCard(scroll, {
            title = TS.L("addon_permission_" .. definition.key),
            hint = TS.L("addon_permission_" .. definition.key .. "_hint"),
            value = current,
            enabled = canEdit,
            choices = permissionChoices(data, current),
            onSelect = function(group)
                if not canEdit or not isstring(group) or group == "" then
                    return
                end
                permissions[right] = group
                sendPermissionSetting(right, group)
            end,
        })
    end

    return scroll
end

local function buildIntegrationsPage(parent, frame)
    local data = frame.SettingsData
    if not data then
        addLoading(parent)
        return
    end
    if TS.Editor.BuildIntegrationSettings then
        return TS.Editor.BuildIntegrationSettings(parent, data.integrations or {}, data.can_manage_integrations == true)
    end
end

local VALID_PAGES = {
    editor = true,
    dialogues = true,
    server = true,
    permissions = true,
    integrations = true,
}

local function restoreIntegrationScroll(frame, list, savedScroll, final)
    if not IsValid(frame) or frame.IntegrationList ~= list or not IsValid(list) then
        return
    end

    local parent = list:GetParent()
    if IsValid(parent) then
        parent:InvalidateLayout(true)
    end
    list:InvalidateLayout(true)

    local bar = list:GetVBar()
    if IsValid(bar) then
        bar:SetScroll(savedScroll)
        list:InvalidateLayout(true)
    end

    if final then
        list._talksmithRestoringScroll = nil
    end
end

function TS.Editor.OpenSettings(pageID)
    local requestedPage = VALID_PAGES[pageID] and pageID or nil
    if IsValid(TS.Editor.AddonSettingsFrame) then
        local frame = TS.Editor.AddonSettingsFrame
        if requestedPage then
            frame.ActivePage = requestedPage
        end
        frame:BuildNavigation()
        frame:BuildPage()
        frame:MakePopup()
        frame:MoveToFront()
        TS.Editor.RequestSettings()
        return
    end

    local T = TS.Editor.Theme
    local frame = vgui.Create("DFrame")
    TS.Editor.AddonSettingsFrame = frame
    TS.Editor.AddonSettingsOpen = true
    frame.ActivePage = requestedPage or "editor"
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    frame:SetSizable(false)
    frame:SetDeleteOnClose(true)
    frame:SetBackgroundBlur(true)
    frame:SetDrawOnTop(true)
    frame:SetSize(math.min(ScrW() - 48, 1040), math.min(ScrH() - 48, 720))
    frame:Center()
    frame:DockPadding(0, 0, 0, 0)
    frame.Paint = function(self, width, height)
        Derma_DrawBackgroundBlur(self, self.m_fCreateTime)
        draw.RoundedBox(6, 0, 0, width, height, T.side)
        surface.SetDrawColor(T.line)
        surface.DrawOutlinedRect(0, 0, width, height, 1)
    end

    local header = frame:Add("DPanel")
    header:Dock(TOP)
    header:SetTall(72)
    header:DockPadding(22, 0, 14, 0)
    header.Paint = function(_, width, height)
        draw.SimpleText(TS.L("addon_settings_title"), "Talksmith_E_Title", 24, 27, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(TS.L("addon_settings_subtitle"), "Talksmith_E_Small", 24, 50, T.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(T.line)
        surface.DrawRect(0, height - 1, width, 1)
    end

    local close = header:Add("DButton")
    close:Dock(RIGHT)
    close:SetWide(38)
    close:DockMargin(0, 17, 0, 17)
    TS.Editor.StyleButton(close, { label = "", quiet = true, icon = "x" })
    TS.Editor.SetTooltip(close, TS.L("addon_settings_close"))
    close.DoClick = function()
        frame:Remove()
    end

    local navigation = frame:Add("DPanel")
    navigation:Dock(LEFT)
    navigation:SetWide(228)
    navigation:DockPadding(14, 18, 14, 18)
    navigation.Paint = function(_, width, height)
        surface.SetDrawColor(T.bar)
        surface.DrawRect(0, 0, width, height)
        surface.SetDrawColor(T.line)
        surface.DrawRect(width - 1, 0, 1, height)
    end

    local content = frame:Add("DPanel")
    content:Dock(FILL)
    content:DockPadding(24, 22, 24, 22)
    content.Paint = function() end

    function frame:BuildNavigation()
        navigation:Clear()
        local pages = {
            { id = "editor", label = TS.L("addon_settings_editor"), icon = "pencil-simple" },
            { id = "dialogues", label = TS.L("addon_settings_dialogues"), icon = "play" },
            { id = "server", label = TS.L("addon_settings_server"), icon = "gear-six" },
        }
        if self.SettingsData and self.SettingsData.permissions_available == true then
            pages[#pages + 1] = {
                id = "permissions",
                label = TS.L("addon_permissions"),
                icon = "user-focus",
            }
        end
        pages[#pages + 1] = {
            id = "integrations",
            label = TS.Localization.Integration("integrations"),
            icon = "link-break",
        }
        for _, page in ipairs(pages) do
            local pageID = page.id
            local button = navigation:Add("DButton")
            button:Dock(TOP)
            button:SetTall(42)
            button:DockMargin(0, 0, 0, 6)
            TS.Editor.StyleButton(button, {
                label = page.label,
                active = self.ActivePage == pageID,
                alignLeft = true,
                icon = page.icon,
            })
            button.DoClick = function()
                if self.ActivePage ~= pageID then
                    self.ActivePage = pageID
                    self:BuildNavigation()
                    self:BuildPage()
                end
            end
        end
    end

    function frame:BuildPage()
        TS.Editor.ClosePopupMenu()
        if self.ActivePage == "permissions"
            and (not self.SettingsData or self.SettingsData.permissions_available ~= true)
        then
            self.ActivePage = "server"
            self:BuildNavigation()
        end
        if IsValid(self.IntegrationList) and not self.IntegrationList._talksmithRestoringScroll then
            self.IntegrationScroll = self.IntegrationList:GetVBar():GetScroll()
        end
        if IsValid(self.PermissionList) then
            self.PermissionScroll = self.PermissionList:GetVBar():GetScroll()
        end
        self.IntegrationList = nil
        self.PermissionList = nil
        content:Clear()
        if self.ActivePage == "dialogues" then
            buildDialoguesPage(content, self)
        elseif self.ActivePage == "server" then
            buildServerPage(content, self)
        elseif self.ActivePage == "permissions" then
            local list = buildPermissionsPage(content, self)
            self.PermissionList = list
            local savedScroll = self.PermissionScroll or 0
            if IsValid(list) and savedScroll > 0 then
                timer.Simple(0, function()
                    if IsValid(self) and self.PermissionList == list and IsValid(list) then
                        list:GetVBar():SetScroll(savedScroll)
                        list:InvalidateLayout(true)
                    end
                end)
            end
        elseif self.ActivePage == "integrations" then
            local list = buildIntegrationsPage(content, self)
            self.IntegrationList = list
            local savedScroll = self.IntegrationScroll or 0
            if IsValid(list) and savedScroll > 0 then
                list._talksmithRestoringScroll = true
                restoreIntegrationScroll(self, list, savedScroll, false)
                timer.Simple(0, function()
                    restoreIntegrationScroll(self, list, savedScroll, true)
                end)
            end
        else
            buildEditorPage(content, self)
        end
    end

    function frame:ApplySettings(data)
        local permissionsWereAvailable = self.SettingsData and self.SettingsData.permissions_available == true
        self.SettingsData = data
        if IsValid(TS.Editor.WeaponAllowlistFrame) and TS.Editor.WeaponAllowlistFrame.ApplyData then
            TS.Editor.WeaponAllowlistFrame:ApplyData(data)
        end
        local permissionsAreAvailable = data.permissions_available == true
        if self.ActivePage == "permissions" and not permissionsAreAvailable then
            self.ActivePage = "server"
        end
        if permissionsWereAvailable ~= permissionsAreAvailable then
            self:BuildNavigation()
        end
        if
            self.ActivePage == "integrations"
            and IsValid(self.IntegrationList)
            and self.IntegrationList.ApplyIntegrationData
            and self.IntegrationList:ApplyIntegrationData(data.integrations or {}, data.can_manage_integrations == true)
        then
            return
        end
        self:BuildPage()
    end

    frame.OnKeyCodePressed = function(_, key)
        if key == KEY_ESCAPE then
            if IsValid(TS.Editor.PopupMenu) then
                TS.Editor.ClosePopupMenu()
                return
            end
            frame:Remove()
        end
    end
    frame.Think = function()
        if gui.IsGameUIVisible() and not gui.IsConsoleVisible() then
            gui.HideGameUI()
            frame:Remove()
        end
    end
    frame.OnRemove = function()
        TS.Editor.ClosePopupMenu()
        if IsValid(TS.Editor.WeaponAllowlistFrame) then
            TS.Editor.WeaponAllowlistFrame:Remove()
        end
        TS.Editor.AddonSettingsOpen = false
        if TS.Editor.AddonSettingsFrame == frame then
            TS.Editor.AddonSettingsFrame = nil
        end
    end

    frame:BuildNavigation()
    frame:BuildPage()
    frame:MakePopup()
    TS.Editor.RequestSettings()
end

net.Receive("ts_settings_data", function()
    local length = net.ReadUInt(19)
    if length <= 0 or length > MAX_NET_PAYLOAD then
        return
    end

    local raw = util.Decompress(net.ReadData(length) or "", MAX_PAYLOAD)
    if not raw then
        return
    end
    local data = util.JSONToTable(raw or "")
    if not istable(data) then
        return
    end

    local catalogChanged = applyIntegrationCatalog(data.integrations)
    applyRuntimeConfig(data.settings)
    if data.result == false then
        local errorKeys = {
            invalid_weapon_class = "addon_weapons_invalid_class",
            weapon_limit_reached = "addon_weapons_limit_reached",
            weapon_lua_override = "addon_weapons_lua_override_error",
        }
        TS.Runtime.Notify(TS.L(errorKeys[data.code] or "addon_settings_save_failed"), NOTIFY_ERROR, 4)
    end
    if IsValid(TS.Editor.AddonSettingsFrame) and TS.Editor.AddonSettingsFrame.ApplySettings then
        TS.Editor.AddonSettingsFrame:ApplySettings(data)
    end
    if catalogChanged then
        hook.Run("Talksmith.EditorCatalogChanged")
    end
end)

hook.Add("Talksmith.EditorSettingChanged", "Talksmith.ApplyLanguageLive", function(key)
    if key ~= "language" then
        return
    end

    timer.Simple(0, function()
        local page = IsValid(TS.Editor.AddonSettingsFrame) and TS.Editor.AddonSettingsFrame.ActivePage or nil

        if IsValid(TS.Editor.Frame) and TS.Editor.Frame.CaptureState then
            TS.Editor.RestoreState = TS.Editor.Frame:CaptureState()
            TS.Editor.Open()
        end

        if page then
            TS.Editor.OpenSettings(page)
        end
    end)
end)
