local TS = Talksmith

local function parseValue(rule, s)
    if rule.type == "number" then
        return tonumber(s) or 0
    end
    if rule.type == "boolean" then
        return tobool(s)
    end
    if rule.type == "string" then
        return s
    end
    if s == "true" then
        return true
    elseif s == "false" then
        return false
    end
    return tonumber(s) or s
end

local function displayValue(v)
    if v == nil then
        return ""
    end
    if isbool(v) then
        return v and "true" or "false"
    end
    return tostring(v)
end

local function sortedKeys(t)
    local keys = {}
    for k in pairs(t or {}) do
        keys[#keys + 1] = k
    end
    table.sort(keys)
    return keys
end

local function shortText(value, limit)
    local text = string.gsub(value or "", "%s+", " ")
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

local function fitName(text, font, maxw)
    text = string.gsub(text or "", "%s+", " ")
    surface.SetFont(font)
    if surface.GetTextSize(text) <= maxw then
        return text
    end
    local out, pos = "", 1
    while pos <= #text do
        local byte = string.byte(text, pos)
        local step = byte < 128 and 1 or (byte < 224 and 2 or (byte < 240 and 3 or 4))
        local chunk = string.sub(text, pos, pos + step - 1)
        if surface.GetTextSize(out .. chunk .. "…") > maxw then
            break
        end
        out = out .. chunk
        pos = pos + step
    end
    return out .. "…"
end

local function wrapText(text, font, maxw)
    text = string.gsub(text or "", "%s+", " ")
    surface.SetFont(font)
    if text == "" then
        return { "" }
    end
    local lines, cur = {}, ""
    for word in string.gmatch(text, "%S+") do
        local test = (cur == "") and word or (cur .. " " .. word)
        if cur ~= "" and surface.GetTextSize(test) > maxw then
            lines[#lines + 1] = cur
            cur = word
        else
            cur = test
        end
    end
    lines[#lines + 1] = cur
    return lines
end

local function textField(parent, value, tall, onset, snapshot)
    local e = parent:Add("DTextEntry")
    e:Dock(TOP)
    e:SetTall(tall or 30)
    e:DockMargin(0, 3, 0, 10)
    if (tall or 30) > 36 then
        e:SetMultiline(true)
    end
    TS.Editor.StyleEntry(e)
    e:SetUpdateOnType(true)
    e:SetValue(value or "")
    e.OnGetFocus = function()
        if snapshot then
            snapshot()
        end
    end
    e.OnValueChange = function(_, s)
        onset(s)
    end
    return e
end

local function hint(parent, text, tall)
    local l = parent:Add("DLabel")
    l:Dock(TOP)
    l:DockMargin(0, 0, 0, 10)
    l:SetWrap(true)
    if tall then
        l:SetTall(tall)
    else
        l:SetAutoStretchVertical(true)
    end
    l:SetFont("Talksmith_E_Small")
    l:SetTextColor(TS.Editor.Theme.dim)
    l:SetText(text)
    return l
end

local function sectionTitle(parent, title, subtitle)
    local T = TS.Editor.Theme
    local block = parent:Add("DPanel")
    block:Dock(TOP)
    block:SetTall(subtitle and 62 or 30)
    block:DockMargin(0, 10, 0, 4)
    block.Paint = function()
        draw.SimpleText(title, "Talksmith_E_Head", 0, 12, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    if subtitle then
        local sub = block:Add("DLabel")
        sub:SetPos(0, 27)
        sub:SetTall(34)
        sub:SetWrap(true)
        sub:SetFont("Talksmith_E_Small")
        sub:SetTextColor(T.dim)
        sub:SetText(subtitle)
        block.PerformLayout = function(_, w)
            sub:SetWide(w)
        end
    end
    return block
end

local function emptyInspector(parent, doc, cb)
    local T = TS.Editor.Theme
    TS.Editor.Label(parent, string.upper(TS.L("properties")), "Talksmith_E_Tiny", T.dim)
    local card = parent:Add("DPanel")
    card:Dock(TOP)
    card:SetTall(doc and 204 or 174)
    card:DockMargin(0, 8, 0, 0)
    card:DockPadding(18, 18, 18, 16)
    card.Paint = function(_, w, h)
        draw.RoundedBox(7, 0, 0, w, h, T.field)
        surface.SetDrawColor(T.lineSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.RoundedBox(3, 18, 18, 26, 26, T.accentSoft)
        TS.Editor.DrawIcon(doc and "dots-three" or "plus", 23, 23, 16, T.blue)
    end

    local spacer = card:Add("DPanel")
    spacer:Dock(TOP)
    spacer:SetTall(38)
    spacer.Paint = function() end

    local title = card:Add("DLabel")
    title:Dock(TOP)
    title:SetTall(30)
    title:SetFont("Talksmith_E_Head")
    title:SetTextColor(T.text)
    title:SetText(doc and TS.L("select_node_title") or TS.L("no_document_title"))

    local body = card:Add("DLabel")
    body:Dock(TOP)
    body:SetTall(doc and 68 or 62)
    body:SetWrap(true)
    body:SetFont("Talksmith_E_Small")
    body:SetTextColor(T.muted)
    body:SetText(doc and TS.L("select_node_body") or TS.L("no_document_body"))

    if doc and cb and cb.AddNode then
        local add = card:Add("DButton")
        add:Dock(BOTTOM)
        add:SetTall(34)
        TS.Editor.StyleButton(add, { label = TS.L("add_first_node"), accent = true, icon = "plus" })
        add.DoClick = cb.AddNode
    end
end

local function sortedRefKeys(registry)
    local keys = sortedKeys(registry)
    table.sort(keys, function(a, b)
        local left, right = registry[a] or {}, registry[b] or {}
        local leftAvailable, rightAvailable = left.available ~= false, right.available ~= false
        if leftAvailable ~= rightAvailable then return leftAvailable end
        local leftGroup = tostring(left.category or left.integration or "")
        local rightGroup = tostring(right.category or right.integration or "")
        if leftGroup ~= rightGroup then return leftGroup < rightGroup end
        return a < b
    end)
    return keys
end

local function localizedRefText(id, kind, field, fallback)
    if field == "name" then
        fallback = TS.Localization.ReferenceName(id, fallback)
    end
    if TS.Localization.IntegrationReference then
        local localized = TS.Localization.IntegrationReference(id, kind, field, fallback)
        if field == "description" and fallback == nil and localized == id then
            return nil
        end
        return localized
    end
    return fallback or id
end

local function providerSupports(provider, method)
    return provider.available ~= false
        and (not method or provider.methods == nil or provider.methods[method] == true)
end

local function activeProviderIDs(kind, method)
    local catalog = TS.Editor.Catalog or {}
    local providers = catalog.providers and catalog.providers[kind] or {}
    local ids = sortedKeys(providers)
    local available = {}
    for _, id in ipairs(ids) do
        if providerSupports(providers[id], method) then
            available[#available + 1] = id
        end
    end
    return available
end

local function defaultRefParams(definition)
    local params = {}
    if definition and definition.provider_kind then
        local ids = activeProviderIDs(definition.provider_kind, definition.provider_method)
        if #ids == 1 then
            params.provider = ids[1]
        end
    end
    return params
end

local function providerChoices(kind, current, method)
    local catalog = TS.Editor.Catalog or {}
    local providers = catalog.providers and catalog.providers[kind] or {}
    local integrations = catalog.integrations or {}
    local ids = sortedKeys(providers)
    local availableIDs = activeProviderIDs(kind, method)
    local currentID = tostring(current or "")
    if currentID == "auto" then
        currentID = ""
    end

    local function displayName(id)
        local provider = providers[id] or {}
        local integration = provider.integration and integrations[provider.integration]
        return tostring(integration and integration.name or provider.name or id)
    end

    table.sort(ids, function(a, b)
        local left = string.lower(displayName(a))
        local right = string.lower(displayName(b))
        if left ~= right then return left < right end
        return a < b
    end)

    local choices = {}
    local currentFound = false

    for _, id in ipairs(ids) do
        local provider = providers[id]
        local available = providerSupports(provider, method)
        if available or id == currentID then
            local prefix = not available and TS.Localization.Integration("integration_ref_unavailable_prefix") or ""
            local selected = id == currentID
                or currentID == "" and #availableIDs == 1 and id == availableIDs[1]
            choices[#choices + 1] = {
                label = prefix .. TS.Localization.Integration("integration_provider_choice", displayName(id), id),
                value = id,
                selected = selected,
            }
            currentFound = currentFound or selected
        end
    end

    if currentID ~= "" and not currentFound then
        choices[#choices + 1] = {
            label = TS.Localization.Integration("integration_ref_unavailable_prefix") .. currentID,
            value = currentID,
            selected = true,
        }
    end

    return choices
end

local function refEditor(parent, list, idx, registry, cb, kind)
    local T = TS.Editor.Theme
    local box = parent:Add("DPanel")
    box:Dock(TOP)
    box:DockMargin(0, 0, 0, 8)
    box:DockPadding(10, 8, 10, 10)
    box.Paint = function(_, w, h)
        draw.RoundedBox(5, 0, 0, w, h, T.field)
        surface.SetDrawColor(T.lineSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local head = box:Add("DPanel")
    head:Dock(TOP)
    head:SetTall(30)
    head.Paint = function() end

    local del = head:Add("DButton")
    del:Dock(RIGHT)
    del:SetWide(30)
    TS.Editor.StyleButton(del, { label = "✕", danger = true, quiet = true })
    TS.Editor.SetTooltip(del, TS.L("delete"))
    del.DoClick = function()
        cb.Snapshot()
        table.remove(list, idx)
        cb.Changed(true)
    end

    local combo = head:Add("DComboBox")
    combo:Dock(FILL)
    combo:DockMargin(0, 0, 6, 0)
    TS.Editor.StyleCombo(combo)
    local entry = list[idx]
    for _, id in ipairs(sortedRefKeys(registry)) do
        local definition = registry[id]
        if definition.available ~= false or id == entry.id then
            local prefix = definition.available == false and TS.Localization.Integration("integration_ref_unavailable_prefix") or ""
            local group = definition.integration and (" / " .. definition.integration) or ""
            local name = localizedRefText(id, kind, "name", definition.name)
            combo:AddChoice(prefix .. name .. group .. "   (" .. id .. ")", id, id == entry.id)
        end
    end
    combo.OnSelect = function(_, _, _, id)
        cb.Snapshot()
        entry.id = id
        entry.params = defaultRefParams(registry[id])
        cb.Changed(true)
    end

    local def = registry[entry.id]
    if not def then
        local missing = box:Add("DLabel")
        missing:Dock(TOP)
        missing:SetTall(28)
        missing:SetFont("Talksmith_E_Small")
        missing:SetTextColor(T.red)
        missing:SetText("? " .. tostring(entry.id))
        box:SetTall(76)
        return box
    end

    if def.available == false then
        local unavailable = box:Add("DLabel")
        unavailable:Dock(TOP)
        unavailable:SetTall(24)
        unavailable:DockMargin(0, 5, 0, 0)
        unavailable:SetFont("Talksmith_E_Tiny")
        unavailable:SetTextColor(T.red)
        unavailable:SetText(TS.Localization.Integration("integration_ref_unavailable"))
    end

    local displayName = localizedRefText(entry.id, kind, "name", def.name)
    local displayDescription = localizedRefText(entry.id, kind, "description", def.description)
    local descriptionH = 0
    if displayDescription and displayDescription ~= displayName then
        descriptionH = 38
        local description = box:Add("DLabel")
        description:Dock(TOP)
        description:SetTall(descriptionH)
        description:DockMargin(0, 5, 0, 0)
        description:SetWrap(true)
        description:SetFont("Talksmith_E_Tiny")
        description:SetTextColor(T.dim)
        description:SetText(displayDescription)
    end

    local rows = 0
    entry.params = istable(entry.params) and entry.params or {}
    local paramKeys = sortedKeys(def.params)
    if def.provider_kind then
        table.sort(paramKeys, function(a, b)
            if a == b then return false end
            if a == "provider" then return true end
            if b == "provider" then return false end
            return a < b
        end)
    end
    for _, key in ipairs(paramKeys) do
        local rule = def.params[key]
        local row = box:Add("DPanel")
        row:Dock(TOP)
        row:SetTall(28)
        row:DockMargin(0, 4, 0, 0)
        row.Paint = function() end

        local dynamicProvider = key == "provider" and def.provider_kind ~= nil
        local required = rule.required or dynamicProvider
        local lbl = row:Add("DLabel")
        lbl:Dock(LEFT)
        lbl:SetWide(104)
        lbl:SetFont("Talksmith_E_Small")
        lbl:SetTextColor(required and T.text or T.muted)
        lbl:SetText(TS.Localization.ReferenceParameter(key, rule.label, def.integration) .. (required and " *" or ""))

        local options = dynamicProvider
            and providerChoices(def.provider_kind, entry.params[key], def.provider_method)
            or rule.options
        if dynamicProvider or istable(options) and #options > 0 then
            local selector = row:Add("DComboBox")
            selector:Dock(FILL)
            TS.Editor.StyleCombo(selector)
            local current = entry.params[key]
            local found = false
            for _, option in ipairs(options) do
                local optionLabel = istable(option) and option.label or tostring(option)
                local optionValue = istable(option) and option.value or option
                local selected = istable(option) and option.selected == true or optionValue == current
                selector:AddChoice(optionLabel, optionValue, selected)
                found = found or selected
            end
            if not dynamicProvider and current ~= nil and not found then
                selector:AddChoice(displayValue(current), current, true)
            end
            if dynamicProvider and not found then
                selector:SetValue(TS.Localization.Integration("integration_provider_select"))
            end
            selector.OnSelect = function(_, _, optionLabel, optionValue)
                cb.Snapshot()
                entry.params[key] = optionValue ~= nil and optionValue or parseValue(rule, optionLabel)
                cb.Changed()
            end
        else
            local e = row:Add("DTextEntry")
            e:Dock(FILL)
            TS.Editor.StyleEntry(e)
            e:SetUpdateOnType(true)
            e:SetValue(displayValue(entry.params[key]))
            local ph = TS.Localization.ReferenceHint(key)
            if ph then
                e:SetPlaceholderText(ph)
            end
            if rule.type == "number" then
                e:SetNumeric(true)
            end
            e.OnGetFocus = cb.Snapshot
            e.OnValueChange = function(_, s)
                entry.params[key] = s ~= "" and parseValue(rule, s) or nil
                cb.Changed()
            end
        end
        rows = rows + 1
    end
    box:SetTall(48 + descriptionH + rows * 32 + (def.available == false and 28 or 0))
    return box
end

local function refListBody(parent, addLabel, list, registry, cb, kind)
    local keys = sortedRefKeys(registry)
    local firstAvailable
    for _, id in ipairs(keys) do
        if registry[id].available ~= false then
            firstAvailable = id
            break
        end
    end

    for i = 1, #list do
        refEditor(parent, list, i, registry, cb, kind)
    end
    if not firstAvailable then
        hint(parent, TS.L("unavailable_refs"), 28)
        return
    end
    local add = parent:Add("DButton")
    add:Dock(TOP)
    add:SetTall(32)
    add:DockMargin(0, 0, 0, 6)
    TS.Editor.StyleButton(add, { label = addLabel, quiet = #list > 0, icon = "plus" })
    add.DoClick = function()
        cb.Snapshot()
        list[#list + 1] = { id = firstAvailable, params = defaultRefParams(registry[firstAvailable]) }
        cb.Changed(true)
    end
end

local function disclosure(parent, ui, key, title, addLabel, list, registry, cb, rebuild, subtitle, kind)
    local T = TS.Editor.Theme
    if ui.open[key] == nil then
        ui.open[key] = #list > 0
    end

    local open = ui.open[key]
    local head = parent:Add("DButton")
    head:Dock(TOP)
    head:SetTall(42)
    head:DockMargin(0, 4, 0, open and 8 or 5)
    head:SetText("")
    head.Paint = function(s, w, h)
        draw.RoundedBox(5, 0, 0, w, h, s:IsHovered() and T.card or T.field)
        surface.SetDrawColor(open and T.blue or T.lineSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        TS.Editor.DrawIcon(open and "caret-down" or "caret-right", 10, h / 2 - 8, 16, open and T.blue or T.muted)
        draw.SimpleText(title, "Talksmith_E_Body", 32, h / 2, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local count = tostring(#list)
        surface.SetFont("Talksmith_E_Tiny")
        local tw = surface.GetTextSize(count)
        draw.RoundedBox(3, w - tw - 24, h / 2 - 10, tw + 14, 20, #list > 0 and T.accentSoft or T.card)
        draw.SimpleText(
            count,
            "Talksmith_E_Tiny",
            w - 17,
            h / 2,
            #list > 0 and T.blue or T.dim,
            TEXT_ALIGN_RIGHT,
            TEXT_ALIGN_CENTER
        )
    end
    head.DoClick = function()
        ui.open[key] = not open
        rebuild()
    end

    if subtitle and subtitle ~= "" then
        local sub = parent:Add("DLabel")
        sub:Dock(TOP)
        sub:DockMargin(2, 0, 0, open and 6 or 8)
        sub:SetWrap(true)
        sub:SetAutoStretchVertical(true)
        sub:SetFont("Talksmith_E_Tiny")
        sub:SetTextColor(T.dim)
        sub:SetText(subtitle)
    end

    if open then
        if #list == 0 then
            local empty = parent:Add("DLabel")
            empty:Dock(TOP)
            empty:SetTall(24)
            empty:DockMargin(2, 0, 0, 4)
            empty:SetFont("Talksmith_E_Small")
            empty:SetTextColor(T.dim)
            empty:SetText(TS.L("empty_refs"))
        end
        refListBody(parent, addLabel, list, registry, cb, kind)
    end
end

local function nodeHeader(parent, id, doc, cb)
    local T = TS.Editor.Theme
    local node = doc.nodes[id]
    local head = parent:Add("DPanel")
    head:Dock(TOP)
    head:SetTall(64)
    head:DockMargin(0, 4, 0, 10)
    head:DockPadding(14, 8, 8, 8)
    local start
    head.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, T.field)
        surface.SetDrawColor(T.lineSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        local name, derived = TS.Editor.NodeDisplayName(node, id)
        local caption = string.upper(TS.L("node"))
        if derived then
            caption = caption .. "   " .. id
        end
        local reserve = IsValid(start) and start:GetWide() + 18 or 28
        if doc.start == id then
            surface.SetFont("Talksmith_E_Tiny")
            reserve = surface.GetTextSize(TS.L("is_start")) + 24
            draw.SimpleText(TS.L("is_start"), "Talksmith_E_Tiny", w - 14, 40, T.green, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        local textWidth = math.max(w - 14 - reserve, 0)
        draw.SimpleText(
            fitName(caption, "Talksmith_E_Tiny", textWidth),
            "Talksmith_E_Tiny",
            14,
            16,
            T.dim,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )
        draw.SimpleText(
            fitName(name, "Talksmith_E_Head", textWidth),
            "Talksmith_E_Head",
            14,
            40,
            T.blue,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )
    end

    if doc.start ~= id then
        start = head:Add("DButton")
        start:Dock(RIGHT)
        surface.SetFont("Talksmith_E_Body")
        start:SetWide(math.ceil(surface.GetTextSize(TS.L("make_start_short")) + 25 + 20))
        start:DockMargin(0, 8, 0, 8)
        TS.Editor.StyleButton(start, { label = TS.L("make_start_short"), quiet = true, icon = "flag" })
        TS.Editor.SetTooltip(start, TS.L("make_start"))
        start.DoClick = function()
            cb.Snapshot()
            doc.start = id
            cb.Changed(true)
        end
    end
end

local function nodeTabs(parent, sel, rebuild)
    local T = TS.Editor.Theme
    local tabs = {
        { "line", TS.L("node_tab_line") },
        { "answers", TS.L("node_tab_answers") },
        { "extra", TS.L("node_tab_extra") },
    }
    local row = parent:Add("DPanel")
    row:Dock(TOP)
    row:SetTall(38)
    row:DockMargin(0, 0, 0, 12)
    row.Paint = function(_, w, h)
        draw.RoundedBox(5, 0, 0, w, h, T.field)
    end
    row.buttons = {}
    for _, item in ipairs(tabs) do
        local key, label = item[1], item[2]
        local button = row:Add("DButton")
        button:SetText("")
        button.Paint = function(s, w, h)
            local active = sel.tab == key
            if active or s:IsHovered() then
                draw.RoundedBox(4, 2, 2, w - 4, h - 4, active and T.accentSoft or T.hover)
            end
            if active then
                surface.SetFont("Talksmith_E_Small")
                local tw = surface.GetTextSize(label)
                local uw = math.Round(math.min(w - 16, tw + 16))
                draw.RoundedBox(1, math.Round((w - uw) / 2), h - 4, uw, 2, T.blue)
            end
            draw.SimpleText(
                label,
                "Talksmith_E_Small",
                w / 2,
                h / 2,
                active and T.text or T.muted,
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER
            )
        end
        button.DoClick = function()
            sel.tab = key
            rebuild()
        end
        row.buttons[#row.buttons + 1] = button
    end
    row.PerformLayout = function(s, w, h)
        local bw = math.floor(w / #s.buttons)
        for i, button in ipairs(s.buttons) do
            local x = (i - 1) * bw
            button:SetPos(x, 0)
            button:SetSize(i == #s.buttons and w - x or bw, h)
        end
    end
end

local function addPalette(parent, node, cb)
    local T = TS.Editor.Theme
    local pal = parent:Add("DPanel")
    pal:Dock(TOP)
    pal:SetTall(30)
    pal:DockMargin(0, 3, 0, 10)
    pal.Paint = function() end
    for i, c in ipairs(TS.Editor.NodePalette) do
        local sw = pal:Add("DButton")
        sw:Dock(LEFT)
        sw:SetWide(30)
        sw:DockMargin(0, 0, 8, 0)
        sw:SetText("")
        sw.Paint = function(s, w, h)
            local cur = node.editor.color
            local active = (i == 1 and not cur)
                or (istable(cur) and cur.r == c.r and cur.g == c.g and cur.b == c.b)
            draw.RoundedBox(4, 1, 1, w - 2, h - 2, c)
            surface.SetDrawColor(active and T.text or (s:IsHovered() and T.blue or T.lineSoft))
            surface.DrawOutlinedRect(0, 0, w, h, active and 2 or 1)
        end
        sw.DoClick = function()
            cb.Snapshot()
            node.editor.color = i > 1 and { r = c.r, g = c.g, b = c.b } or nil
            cb.Changed()
        end
    end
end

local function routeSummary(option)
    local T = TS.Editor.Theme
    if #(option.next_random or {}) > 0 then
        return TS.L("random_routes", #option.next_random), T.yellow
    end
    if option.next ~= nil then
        return "→ " .. option.next, T.blue
    end
    return TS.L("ends_here"), T.red
end

local function responseList(parent, node, sel, cb)
    local T = TS.Editor.Theme
    sectionTitle(parent, TS.L("responses"), TS.L("node_answers_hint"))
    node.options = istable(node.options) and node.options or {}

    local count = #node.options
    for i, option in ipairs(node.options) do
        local route, routeColor = routeSummary(option)
        local meta = ""
        if #(option.conditions or {}) > 0 or #(option.actions or {}) > 0 then
            meta = "  ·  " .. TS.L("response_meta", #(option.conditions or {}), #(option.actions or {}))
        end
        local routeText = route .. meta

        local row = parent:Add("DPanel")
        row:Dock(TOP)
        row:SetTall(60)
        row:DockMargin(0, 0, 0, 7)
        row.routeLines = { routeText }

        local openBtn
        row.Paint = function(_, w, h)
            local hov = IsValid(openBtn) and openBtn:IsHovered()
            draw.RoundedBox(5, 0, 0, w, h, hov and T.card or T.field)
            surface.SetDrawColor(hov and T.blue or T.lineSoft)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        local actionSize, actionGap, actionRight = 24, 4, 6
        local titleLeft, titleGap = 44, 8
        local buttons = {}
        openBtn = row:Add("DButton")
        openBtn:SetText("")
        openBtn.Paint = function(_, w, h)
            draw.RoundedBox(3, 10, 8, 24, 24, T.accentSoft)
            draw.SimpleText(i, "Talksmith_E_Small", 22, 20, T.blue, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            local actionWidth = #buttons > 0 and (#buttons * actionSize + (#buttons - 1) * actionGap) or 0
            local titleWidth = math.max(w - titleLeft - actionRight - actionWidth - titleGap, 0)
            draw.SimpleText(
                fitName(option.text, "Talksmith_E_Body", titleWidth),
                "Talksmith_E_Body",
                titleLeft,
                20,
                T.text,
                TEXT_ALIGN_LEFT,
                TEXT_ALIGN_CENTER
            )
            local ly = 38
            for _, line in ipairs(row.routeLines) do
                draw.SimpleText(line, "Talksmith_E_Tiny", 44, ly, routeColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                ly = ly + 14
            end
        end
        openBtn.DoClick = function()
            sel.tab = "answers"
            cb.SelectOpt(i)
        end

        local function act(icon, tip, fn, disabled, danger, confirmMessage)
            local b = row:Add("DButton")
            b:SetSize(actionSize, actionSize)
            TS.Editor.StyleButton(b, { icon = icon, quiet = true, danger = danger, iconSize = 14 })
            TS.Editor.SetTooltip(b, tip)
            b:SetDisabled(disabled or false)
            b.DoClick = function()
                if b:GetDisabled() then
                    return
                end
                local function perform()
                    cb.Snapshot()
                    fn()
                    cb.Changed()
                    cb.SelectOpt(nil)
                end
                if confirmMessage and TS.Editor.GetSetting and TS.Editor.GetSetting("confirm_delete") then
                    TS.Editor.Confirm(TS.L("delete_response_title"), confirmMessage, {
                        { label = TS.L("delete"), callback = perform, danger = true },
                        { label = TS.L("cancel"), quiet = true },
                    })
                else
                    perform()
                end
            end
            return b
        end
        buttons = {
            act("arrow-up", TS.L("move_up"), function()
                node.options[i], node.options[i - 1] = node.options[i - 1], node.options[i]
            end, i == 1),
            act("arrow-down", TS.L("move_down"), function()
                node.options[i], node.options[i + 1] = node.options[i + 1], node.options[i]
            end, i == count),
            act("copy", TS.L("duplicate"), function()
                table.insert(node.options, i + 1, TS.Utils.Copy(option))
            end, count >= TS.Config.max_options),
            act("trash", TS.L("delete"), function()
                table.remove(node.options, i)
            end, count <= 1, true, TS.L("delete_response_confirm", shortText(option.text, 48))),
        }

        row.PerformLayout = function(s, w)
            s.routeLines = wrapText(routeText, "Talksmith_E_Tiny", w - 50)
            local needed = 38 + #s.routeLines * 14 + 8
            if s:GetTall() ~= needed then
                s:SetTall(needed)
            end
            openBtn:SetPos(0, 0)
            openBtn:SetSize(w, s:GetTall())
            local x = w - actionRight - actionSize
            for j = #buttons, 1, -1 do
                buttons[j]:SetPos(x, 8)
                x = x - actionSize - actionGap
            end
        end
    end

    if #node.options < TS.Config.max_options then
        local add = parent:Add("DButton")
        add:Dock(TOP)
        add:SetTall(36)
        add:DockMargin(0, 2, 0, 8)
        TS.Editor.StyleButton(add, { label = TS.L("add_response"), icon = "plus" })
        add.DoClick = function()
            cb.Snapshot()
            node.options[#node.options + 1] = {
                text = TS.L("new_response_text"),
                next = nil,
                next_random = {},
                gesture = "",
                conditions = {},
                actions = {},
            }
            cb.Changed()
            cb.SelectOpt(#node.options)
        end
    end
end

local function buildAnswer(parent, doc, node, id, oi, option, sel, ui, cb, actions, conditions, rebuild)
    local T = TS.Editor.Theme
    local back = parent:Add("DButton")
    back:Dock(TOP)
    back:SetTall(32)
    back:DockMargin(0, 0, 0, 8)
    TS.Editor.StyleButton(back, { label = TS.L("back_to_answers"), quiet = true, alignLeft = true, icon = "caret-left" })
    back.DoClick = function()
        sel.tab = "answers"
        cb.SelectOpt(nil)
    end

    local head = parent:Add("DPanel")
    head:Dock(TOP)
    head:SetTall(66)
    head:DockMargin(0, 0, 0, 12)
    head.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, T.field)
        surface.SetDrawColor(T.lineSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(TS.L("editing_response"), "Talksmith_E_Tiny", 14, 18, T.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(TS.L("response") .. " " .. oi, "Talksmith_E_Head", 14, 43, T.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(shortText(id, 16), "Talksmith_E_Mono", w - 14, 43, T.muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    sectionTitle(parent, TS.L("response_text"), TS.L("response_text_hint"))
    textField(parent, option.text, 74, function(s)
        option.text = s
        cb.Changed()
    end, cb.Snapshot)

    sectionTitle(parent, TS.L("response_route"), TS.L("response_route_hint"))
    option.next_random = istable(option.next_random) and option.next_random or {}
    local randomEnabled = #option.next_random > 0
    local combo = parent:Add("DComboBox")
    combo:Dock(TOP)
    combo:SetTall(32)
    combo:DockMargin(0, 3, 0, 8)
    TS.Editor.StyleCombo(combo)
    combo:AddChoice(randomEnabled and TS.L("random_transition") or TS.L("ends_dialogue"), "", option.next == nil)
    for _, nid in ipairs(sortedKeys(doc.nodes)) do
        combo:AddChoice(nid, nid, option.next == nid)
    end
    combo.OnSelect = function(_, _, _, value)
        cb.Snapshot()
        option.next = value ~= "" and value or nil
        cb.Changed(true)
    end

    combo:SetEnabled(not randomEnabled)
    local randomTargets = {}
    for _, target in ipairs(option.next_random) do
        randomTargets[target] = true
    end
    local randomToggle = TS.Editor.Check(parent, {
        label = TS.L("random_transition"),
        value = randomEnabled,
        tall = 30,
        onChange = function(value)
            cb.Snapshot()
            if value then
                local fallback = option.next and doc.nodes[option.next] and option.next or sortedKeys(doc.nodes)[1]
                option.next_random = fallback and { fallback } or {}
            else
                option.next_random = {}
            end
            cb.Changed(true)
        end,
    })
    randomToggle:Dock(TOP)
    randomToggle:DockMargin(0, 0, 0, randomEnabled and 6 or 10)

    if randomEnabled then
        TS.Editor.Label(parent, TS.L("random_targets"))
        local ids = sortedKeys(doc.nodes)
        for _, target in ipairs(ids) do
            local pick = TS.Editor.Check(parent, {
                label = target,
                value = randomTargets[target] == true,
                onChange = function(value)
                    cb.Snapshot()
                    randomTargets[target] = value or nil
                    option.next_random = {}
                    for _, nid in ipairs(ids) do
                        if randomTargets[nid] then
                            option.next_random[#option.next_random + 1] = nid
                        end
                    end
                    cb.Changed(true)
                end,
            })
            pick:Dock(TOP)
            pick:DockMargin(0, 0, 0, 2)
        end
        hint(parent, TS.L("random_transition_hint"), 42)
    end

    TS.Editor.Label(parent, TS.L("option_gesture"))
    TS.Editor.PickerRow(parent, {
        value = option.gesture or "",
        placeholder = TS.L("gesture_none"),
        tall = 32,
        onOpen = function(row)
            TS.Editor.OpenAnimationBrowser({
                model = doc.settings and doc.settings.actor_model,
                current = option.gesture or "",
                onSelect = function(value)
                    cb.Snapshot()
                    option.gesture = value
                    row:SetValueText(value)
                    cb.Changed()
                end,
            })
        end,
    })

    sectionTitle(parent, TS.L("optional_logic"))
    option.conditions = istable(option.conditions) and option.conditions or {}
    option.actions = istable(option.actions) and option.actions or {}
    disclosure(
        parent,
        ui,
        "conditions_" .. oi,
        TS.L("conditions"),
        TS.L("add_condition"),
        option.conditions,
        conditions,
        cb,
        rebuild,
        TS.L("conditions_hint"),
        "condition"
    )
    disclosure(
        parent,
        ui,
        "actions_" .. oi,
        TS.L("actions"),
        TS.L("add_action"),
        option.actions,
        actions,
        cb,
        rebuild,
        TS.L("actions_hint"),
        "action"
    )
end

function TS.Editor.BuildInspector(parent, doc, sel, cb)
    parent:Clear()
    cb = cb or {}
    sel = sel or {}
    local id = sel.node
    if not doc or not id or not doc.nodes[id] then
        emptyInspector(parent, doc, cb)
        return
    end

    local node = doc.nodes[id]
    node.editor = node.editor or { x = 0, y = 0 }
    node.options = istable(node.options) and node.options or {}
    local actions = TS.Editor.Catalog and TS.Editor.Catalog.actions or {}
    local conditions = TS.Editor.Catalog and TS.Editor.Catalog.conditions or {}

    if sel.uiNode ~= id then
        sel.uiNode = id
        sel.tab = sel.opt and "answers" or "line"
        sel.inspectorOpen = {}
    end
    sel.tab = sel.tab or "line"
    sel.inspectorOpen = sel.inspectorOpen or {}
    local ui = { open = sel.inspectorOpen }

    local function rebuild()
        TS.Editor.BuildInspector(parent, doc, sel, cb)
    end
    local function changed(rebuildNow)
        cb.Changed()
        if rebuildNow then
            rebuild()
        end
    end
    local refCB = { Snapshot = cb.Snapshot, Changed = changed, SelectOpt = cb.SelectOpt }

    local oi = sel.opt
    local option = oi and node.options[oi]
    if option then
        buildAnswer(parent, doc, node, id, oi, option, sel, ui, refCB, actions, conditions, rebuild)
        return
    end

    nodeHeader(parent, id, doc, refCB)
    nodeTabs(parent, sel, rebuild)

    if sel.tab == "answers" then
        responseList(parent, node, sel, cb)
        return
    end

    if sel.tab == "extra" then
        sectionTitle(parent, TS.L("node_appearance"), TS.L("node_extra_hint"))
        TS.Editor.Label(parent, TS.L("node_color"))
        addPalette(parent, node, refCB)
        TS.Editor.Label(parent, TS.L("node_note"))
        hint(parent, TS.L("node_note_hint"))
        local note = textField(parent, node.editor.note, 32, function(value)
            node.editor.note = value ~= "" and value or nil
            changed()
        end, cb.Snapshot)
        note:SetPlaceholderText(TS.L("node_note"))

        sectionTitle(parent, TS.L("node_media"))
        TS.Editor.Label(parent, TS.L("node_gesture"))
        TS.Editor.PickerRow(parent, {
            value = node.gesture or "",
            placeholder = TS.L("gesture_none"),
            tall = 32,
            onOpen = function(row)
                TS.Editor.OpenAnimationBrowser({
                    model = doc.settings and doc.settings.actor_model,
                    current = node.gesture or "",
                    onSelect = function(value)
                        cb.Snapshot()
                        node.gesture = value
                        row:SetValueText(value)
                        changed()
                    end,
                })
            end,
        })
        TS.Editor.Label(parent, TS.L("node_sound_label"))
        local sound = textField(parent, node.sound or "", 32, function(value)
            node.sound = string.Trim(value or "")
            changed()
        end, cb.Snapshot)
        sound:SetPlaceholderText(TS.L("sound_url_hint"))

        node.actions = istable(node.actions) and node.actions or {}
        sectionTitle(parent, TS.L("optional_logic"))
        disclosure(
            parent,
            ui,
            "node_actions",
            TS.L("node_actions"),
            TS.L("add_action"),
            node.actions,
            actions,
            refCB,
            rebuild,
            TS.L("node_actions_hint"),
            "action"
        )
        return
    end

    sectionTitle(parent, TS.L("node_text"), TS.L("node_line_hint"))
    textField(parent, node.text, 132, function(value)
        node.text = value
        changed()
    end, cb.Snapshot)
end
