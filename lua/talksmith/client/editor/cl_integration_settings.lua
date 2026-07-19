local TS = Talksmith

local function statusColor(status)
    local T = TS.Editor.Theme
    return status == "available" and T.green
        or status == "loading" and T.yellow
        or status == "disabled" and T.dim
        or T.red
end

local function statusLabel(status)
    return TS.Localization.Integration("integration_status_" .. tostring(status or "unavailable"))
end

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

local function sortedIDs(integrations)
    local ids = {}
    for id in pairs(integrations) do
        ids[#ids + 1] = id
    end

    table.sort(ids, function(left, right)
        local a = integrations[left]
        local b = integrations[right]
        local leftName = string.lower(tostring(a.name or left))
        local rightName = string.lower(tostring(b.name or right))
        if leftName == rightName then
            return string.lower(tostring(left)) < string.lower(tostring(right))
        end
        return leftName < rightName
    end)

    return ids
end

local function capabilityText(capabilities)
    local labels = {}
    for _, capability in ipairs(capabilities or {}) do
        labels[#labels + 1] = TS.Localization.IntegrationCapability(capability)
    end

    return table.concat(labels, "  ·  ")
end

local function countText(data)
    local labels = {}
    for _, item in ipairs({
        { key = "integration_actions", value = data.actions or 0 },
        { key = "integration_conditions", value = data.conditions or 0 },
        { key = "integration_variables", value = data.variables or 0 },
        { key = "integration_providers", value = data.providers or 0 },
    }) do
        if item.value > 0 then
            labels[#labels + 1] = TS.Localization.Integration(item.key, item.value)
        end
    end

    return table.concat(labels, "  ·  ")
end

local function createCheckbox(parent, data, canEdit)
    local checkbox
    checkbox = TS.Editor.Check(parent, {
        label = TS.L("addon_settings_enabled"),
        value = data.automatic == true and data.status == "available" or data.enabled == true,
        onChange = function(value)
            checkbox:SetDisabled(true)
            TS.Integrations.SetEnabled(checkbox.IntegrationID, value)
        end,
    })
    checkbox.IntegrationID = data.id
    checkbox:SetSize(124, 28)
    checkbox:SetDisabled(not canEdit or data.automatic == true)
    TS.Editor.SetTooltip(
        checkbox,
        data.automatic == true and TS.Localization.Integration("integration_automatic")
            or data.enabled and TS.Localization.Integration("integration_disable")
            or TS.Localization.Integration("integration_enable")
    )
    return checkbox
end

local function addIntegrationRow(list, data, canEdit)
    local T = TS.Editor.Theme
    local color = statusColor(data.status)
    local row = list:Add("DPanel")
    row:Dock(TOP)
    row:SetTall(174)
    row:DockMargin(0, 0, 10, 10)
    row:DockPadding(20, 14, 18, 14)
    row.IntegrationID = data.id
    row.IntegrationStatusColor = color
    row.Paint = function(_, width, height)
        draw.RoundedBox(5, 0, 0, width, height, T.card)
        draw.RoundedBox(2, 0, 0, 3, height, row.IntegrationStatusColor or T.dim)
        surface.SetDrawColor(T.lineSoft)
        surface.DrawOutlinedRect(0, 0, width, height, 1)
    end

    local controls = row:Add("DPanel")
    controls:Dock(RIGHT)
    controls:SetWide(172)
    controls.Paint = function() end

    local checkbox = createCheckbox(controls, data, canEdit)
    local controlX = controls:GetWide() - checkbox:GetWide()
    checkbox:SetPos(controlX, 0)

    local status = controls:Add("DLabel")
    status:SetPos(controlX, 37)
    status:SetSize(checkbox:GetWide(), 24)
    status:SetFont("Talksmith_E_Small")
    status:SetContentAlignment(4)

    local details = row:Add("DPanel")
    details:Dock(FILL)
    details:DockMargin(0, 0, 22, 0)
    details.Paint = function() end

    local title = details:Add("DLabel")
    title:Dock(TOP)
    title:SetTall(24)
    title:SetFont("Talksmith_E_Head")
    title:SetTextColor(T.text)
    title:SetText(data.name or data.id)

    local meta = details:Add("DLabel")
    meta:Dock(TOP)
    meta:SetTall(20)
    meta:SetFont("Talksmith_E_Tiny")
    meta:SetTextColor(T.blue)
    meta:SetText(TS.Localization.IntegrationCategory(data.category or "other") .. "  ·  " .. data.id)

    local required = details:Add("DLabel")
    required:Dock(TOP)
    required:DockMargin(0, 6, 0, 0)
    required:SetTall(20)
    required:SetFont("Talksmith_E_Small")
    required:SetTextColor(data.status == "unavailable" and T.red or T.muted)
    required:SetText(TS.Localization.Integration("integration_required"))

    local counts = details:Add("DLabel")
    counts:Dock(TOP)
    counts:SetTall(36)
    counts:SetFont("Talksmith_E_Tiny")
    counts:SetTextColor(T.muted)
    counts:SetWrap(true)
    counts:SetText(countText(data))

    local capabilities = details:Add("DLabel")
    capabilities:Dock(TOP)
    capabilities:SetTall(34)
    capabilities:SetFont("Talksmith_E_Tiny")
    capabilities:SetTextColor(T.dim)
    capabilities:SetWrap(true)

    function row:ApplyIntegrationData(nextData, editable)
        if not istable(nextData) or nextData.id ~= self.IntegrationID then
            return false
        end

        local nextColor = statusColor(nextData.status)
        self.IntegrationStatusColor = nextColor

        checkbox.IntegrationID = nextData.id
        checkbox.value = nextData.automatic == true and nextData.status == "available" or nextData.enabled == true
        checkbox:SetDisabled(not editable or nextData.automatic == true)
        TS.Editor.SetTooltip(
            checkbox,
            nextData.automatic == true and TS.Localization.Integration("integration_automatic")
                or nextData.enabled and TS.Localization.Integration("integration_disable")
                or TS.Localization.Integration("integration_enable")
        )

        local showStatus = nextData.status ~= "disabled"
        status:SetVisible(showStatus)
        status:SetTextColor(nextColor)
        status:SetText(showStatus and statusLabel(nextData.status) or "")

        title:SetText(nextData.name or nextData.id)
        meta:SetText(TS.Localization.IntegrationCategory(nextData.category or "other") .. "  ·  " .. nextData.id)
        required:SetTextColor(nextData.status == "unavailable" and T.red or T.muted)
        required:SetText(TS.Localization.Integration("integration_required"))
        counts:SetText(countText(nextData))
        capabilities:SetText(TS.Localization.Integration("integration_capabilities") .. ": " .. capabilityText(nextData.capabilities))
        return true
    end

    row:ApplyIntegrationData(data, canEdit)
    return row
end

function TS.Editor.BuildIntegrationSettings(parent, integrations, canEdit)
    local T = TS.Editor.Theme

    local heading = parent:Add("DPanel")
    heading:Dock(TOP)
    heading:SetTall(58)
    heading.Paint = function(_, _, height)
        draw.SimpleText(TS.Localization.Integration("integrations"), "Talksmith_E_Display", 0, 14, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(TS.Localization.Integration("integrations_subtitle"), "Talksmith_E_Small", 0, height - 12, T.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local warning = parent:Add("DPanel")
    warning:Dock(TOP)
    warning:SetTall(104)
    warning:DockMargin(0, 6, 0, 14)
    warning.Paint = function(_, width, height)
        draw.RoundedBox(5, 0, 0, width, height, Color(T.yellow.r, T.yellow.g, T.yellow.b, 14))
        surface.SetDrawColor(T.yellow)
        surface.DrawRect(0, 0, 3, height)
        TS.Editor.DrawIcon("warning", 16, 17, 19, T.yellow)
    end

    local warningTitle = warning:Add("DLabel")
    warningTitle:SetFont("Talksmith_E_Head")
    warningTitle:SetTextColor(T.text)
    warningTitle:SetText(TS.Localization.Integration("integrations_warning_title"))

    local warningBody = warning:Add("DLabel")
    warningBody:SetFont("Talksmith_E_Small")
    warningBody:SetTextColor(T.muted)
    warningBody:SetWrap(true)
    warningBody:SetText(TS.Localization.Integration("integrations_warning"))

    warning.PerformLayout = function(_, width)
        warningTitle:SetPos(46, 10)
        warningTitle:SetSize(math.max(width - 60, 0), 24)
        warningBody:SetPos(46, 36)
        warningBody:SetSize(math.max(width - 60, 0), 60)
    end

    if not canEdit then
        local readOnly = parent:Add("DPanel")
        readOnly:Dock(TOP)
        readOnly:SetTall(40)
        readOnly:DockMargin(0, 0, 0, 12)
        readOnly.Paint = function(_, width, height)
            draw.RoundedBox(4, 0, 0, width, height, T.field)
            draw.SimpleText(TS.Localization.Integration("integrations_read_only"), "Talksmith_E_Small", 14, height / 2, T.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    local list = parent:Add("DScrollPanel")
    list:Dock(FILL)
    styleScroll(list)

    local ids = sortedIDs(integrations)
    list.IntegrationOrder = ids
    list.IntegrationRows = {}
    for _, id in ipairs(ids) do
        list.IntegrationRows[id] = addIntegrationRow(list, integrations[id], canEdit)
    end

    if #ids == 0 then
        local empty = list:Add("DLabel")
        empty:Dock(TOP)
        empty:SetTall(54)
        empty:SetFont("Talksmith_E_Body")
        empty:SetTextColor(T.muted)
        empty:SetContentAlignment(5)
        empty:SetText(TS.Localization.Integration("integrations_empty"))
    end

    function list:ApplyIntegrationData(nextIntegrations, editable)
        if not istable(nextIntegrations) then
            return false
        end

        local nextIDs = sortedIDs(nextIntegrations)
        if #nextIDs ~= #self.IntegrationOrder then
            return false
        end

        for index, id in ipairs(nextIDs) do
            local row = self.IntegrationRows[id]
            if self.IntegrationOrder[index] ~= id or not IsValid(row) then
                return false
            end
        end

        for _, id in ipairs(nextIDs) do
            if not self.IntegrationRows[id]:ApplyIntegrationData(nextIntegrations[id], editable) then
                return false
            end
        end

        return true
    end

    return list
end

function TS.Editor.OpenIntegrations()
    TS.Editor.OpenSettings("integrations")
end
