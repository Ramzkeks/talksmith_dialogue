local TS = Talksmith
local window, serial = nil, 0
local panels = {}

function TS.Editor.ClosePlayerFlags()
    local closing = panels
    panels = {}
    window = nil
    for panel in pairs(closing) do
        if IsValid(panel) then
            panel:Remove()
        end
    end
end

local function tr(en, ru)
    return TS.Editor.GetSetting("language") == "ru" and ru or en
end

local errors = {
    denied = { "Permission denied (flags.view / flags.manage).", "Нет прав (flags.view / flags.manage)." },
    offline = {
        "Player disconnected. Refresh the player list.",
        "Игрок отключился. Обновите список игроков.",
    },
    storage = {
        "Could not read/save flags. Check storage and flag limits.",
        "Не удалось прочитать/сохранить флаги. Проверьте хранилище и лимиты.",
    },
    busy = {
        "End this player's conversation/combat before editing flags.",
        "Завершите разговор/бой игрока перед изменением флагов.",
    },
    conflict = {
        "Value changed. Refresh flags before editing again.",
        "Значение изменилось. Обновите флаги перед повторным редактированием.",
    },
    invalid = {
        "Invalid key or value. String limit: 256 characters.",
        "Неверное имя или значение. Лимит строки: 256 символов.",
    },
}

-- Use Studio's palette and controls rather than the default Derma skin.
local function styleFrame(frame, title, subtitle)
    local T = TS.Editor.Theme
    panels[frame] = true
    frame:SetDeleteOnClose(true)
    frame:SetDrawOnTop(true)
    frame.OnRemove = function()
        panels[frame] = nil
        if frame == window then
            TS.Editor.ClosePlayerFlags()
        end
    end
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    frame:SetSizable(false)
    frame:SetBackgroundBlur(true)
    frame:DockPadding(18, 88, 18, 16)
    frame.Paint = function(self, w, h)
        Derma_DrawBackgroundBlur(self, self.m_fCreateTime)
        draw.RoundedBox(6, 0, 0, w, h, T.side)
        surface.SetDrawColor(T.line)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        surface.DrawLine(0, 72, w, 72)
        draw.SimpleText(title, "Talksmith_E_Title", 24, 27, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(subtitle, "Talksmith_E_Small", 24, 50, T.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    local close = frame:Add("DButton")
    close:SetSize(38, 38)
    close:SetPos(frame:GetWide() - 52, 17)
    TS.Editor.StyleButton(close, { label = "", quiet = true, icon = "x" })
    close.DoClick = function()
        frame:Close()
    end
    TS.Editor.SetTooltip(close, tr("Close", "Закрыть"))
    TS.Editor.RegisterModalPanel(frame)
end

local function styleLabel(label, font)
    label:SetFont(font or "Talksmith_E_Body")
    label:SetTextColor(TS.Editor.Theme.text)
end

local function styleList(list)
    local T = TS.Editor.Theme
    list:SetDataHeight(34)
    list:SetHeaderHeight(30)
    list.Paint = function(_, w, h)
        surface.SetDrawColor(T.field)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(T.lineSoft)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    for _, column in ipairs(list.Columns) do
        local header = column.Header
        header:SetFont("Talksmith_E_Small")
        header:SetTextColor(T.muted)
        header.Paint = function(_, w, h)
            surface.SetDrawColor(T.bar)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(T.line)
            surface.DrawLine(0, h - 1, w, h - 1)
        end
    end
    local scroll = list.VBar
    scroll:SetWide(4)
    scroll:SetHideButtons(true)
    scroll.Paint = function() end
    scroll.btnGrip.Paint = function(_, w, h)
        draw.RoundedBox(2, 0, 0, w, h, T.line)
    end
    local addLine = list.AddLine
    list.AddLine = function(self, ...)
        local line = addLine(self, ...)
        for _, cell in pairs(line.Columns) do
            cell:SetFont("Talksmith_E_Small")
            cell:SetTextColor(T.text)
            cell:SetTooltip(cell:GetText())
        end
        line.Paint = function(row, w, h)
            if row:IsSelected() or row:IsHovered() then
                surface.SetDrawColor(row:IsSelected() and T.selection or T.hover)
                surface.DrawRect(0, 0, w, h)
            end
            if row:IsSelected() then
                surface.SetDrawColor(T.blue)
                surface.DrawRect(0, 0, 2, h)
            end
            surface.SetDrawColor(T.lineSoft)
            surface.DrawLine(0, h - 1, w, h - 1)
        end
        return line
    end
end

local function confirmDelete(key, callback)
    local message = tr("Delete flag: ", "Удалить флаг: ") .. key .. "?"
    surface.SetFont("Talksmith_E_Body")
    local messageWidth = surface.GetTextSize(message)
    local dialog = vgui.Create("DFrame")
    dialog:SetSize(420, messageWidth > 384 and 210 or 186)
    dialog:Center()
    styleFrame(
        dialog,
        tr("Delete flag", "Удалить флаг"),
        tr(
            "This changes saved quest progress",
            "Это изменит сохранённый прогресс квеста"
        )
    )
    local text = dialog:Add("DLabel")
    text:Dock(TOP)
    text:SetTall(messageWidth > 384 and 48 or 24)
    text:DockMargin(0, 0, 0, 12)
    text:SetWrap(true)
    styleLabel(text)
    text:SetText(message)
    local buttons = dialog:Add("DPanel")
    buttons:Dock(BOTTOM)
    buttons:SetTall(34)
    buttons.Paint = function() end
    local cancel = buttons:Add("DButton")
    cancel:Dock(RIGHT)
    cancel:SetWide(110)
    TS.Editor.StyleButton(cancel, { label = tr("Cancel", "Отмена") })
    cancel.DoClick = function()
        dialog:Close()
    end
    local remove = buttons:Add("DButton")
    remove:Dock(RIGHT)
    remove:DockMargin(0, 0, 8, 0)
    remove:SetWide(120)
    TS.Editor.StyleButton(remove, { label = tr("Delete", "Удалить"), danger = true, icon = "trash" })
    remove.DoClick = function()
        dialog:Close()
        callback()
    end
    TS.Editor.ActivateModalPanel(dialog)
end

function TS.Editor.OpenPlayerFlags()
    if IsValid(window) then
        TS.Editor.ActivateModalPanel(TS.Editor.GetActiveModalPanel() or window)
        return
    end

    local f = vgui.Create("DFrame")
    window = f
    f:SetSize(math.min(980, ScrW() - 32), math.min(680, ScrH() - 32))
    f:Center()
    f:MakePopup()
    styleFrame(
        f,
        TS.L("player_flags"),
        tr(
            "Inspect and manage persistent quest flags",
            "Просмотр и управление сохранёнными флагами квестов"
        )
    )
    local theme = TS.Editor.Theme

    local status = f:Add("DLabel")
    styleLabel(status)
    status:Dock(BOTTOM)
    status:SetTall(44)
    status:SetWrap(true)
    status:SetTextColor(theme.text)
    status:SetText(
        tr(
            "Select an online player. Flags are persistent quest state; deleting a flag differs from setting it to false.",
            "Выберите игрока онлайн. Флаги сохраняются; удаление флага отличается от установки false."
        )
    )

    local left = f:Add("DPanel")
    left:Dock(LEFT)
    left:SetWide(290)
    left:DockMargin(0, 0, 12, 0)
    left:DockPadding(10, 10, 10, 10)
    left.Paint = function(_, w, h)
        surface.SetDrawColor(theme.bar)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(theme.line)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local playerSearch = left:Add("DTextEntry")
    playerSearch:Dock(TOP)
    playerSearch:SetTall(28)
    TS.Editor.StyleEntry(playerSearch)
    playerSearch:DockMargin(0, 0, 0, 8)
    playerSearch:SetPlaceholderText(tr("Search players / SteamID64", "Поиск игроков / SteamID64"))

    local refreshPlayers = left:Add("DButton")
    refreshPlayers:Dock(TOP)
    refreshPlayers:SetTall(30)
    TS.Editor.StyleButton(
        refreshPlayers,
        { label = tr("Refresh players", "Обновить игроков"), quiet = true }
    )

    local players = left:Add("DListView")
    players:Dock(FILL)
    players:SetMultiSelect(false)
    players:AddColumn(tr("Player", "Игрок"))
    players:AddColumn("SteamID64")
    styleList(players)

    local right = f:Add("DPanel")
    right:Dock(FILL)
    right.Paint = function() end
    right:DockPadding(8, 4, 0, 0)

    local heading = right:Add("DLabel")
    styleLabel(heading)
    heading:Dock(TOP)
    heading:SetTall(24)
    heading:SetTextColor(theme.text)
    heading:SetText(tr("No player selected", "Игрок не выбран"))

    local search = right:Add("DTextEntry")
    search:Dock(TOP)
    search:SetTall(28)
    TS.Editor.StyleEntry(search)
    search:DockMargin(0, 0, 0, 8)
    search:SetPlaceholderText(tr("Search flag names (Enter)", "Поиск по имени флага (Enter)"))

    local onlyTrue = TS.Editor.Check(right, {
        label = tr("Only boolean true", "Только boolean true"),
        onChange = function() end,
    })
    onlyTrue.GetChecked = function(self)
        return self.value
    end
    onlyTrue.DoClick = function(self)
        if not self:IsEnabled() then
            return
        end
        self.value = not self.value
        if self.OnChange then
            self:OnChange(self.value)
        end
    end
    onlyTrue:Dock(TOP)
    onlyTrue:SetTall(26)
    onlyTrue:DockMargin(0, 6, 0, 6)

    local bar = right:Add("DPanel")
    bar:Dock(BOTTOM)
    bar:SetTall(34)
    bar.Paint = nil

    local pagination = right:Add("DPanel")
    pagination:Dock(BOTTOM)
    pagination:SetTall(32)
    pagination.Paint = nil

    local rows = right:Add("DListView")
    rows:Dock(FILL)
    rows:SetMultiSelect(false)
    rows:AddColumn(tr("Flag", "Флаг"))
    rows:AddColumn(tr("Type", "Тип")):SetFixedWidth(70)
    rows:AddColumn(tr("Value", "Значение"))
    styleList(rows)
    local state = { page = 1, pages = 1, editable = false }
    local function request(op, extra)
        if f.pending then
            return
        end
        if op ~= "players" and not state.sid then
            return
        end
        serial = serial % 2147483646 + 1
        local data = extra or {}
        data.id, data.op, data.sid = serial, op, state.sid
        data.page, data.query, data.onlyTrue = state.page, search:GetValue(), onlyTrue:GetChecked()
        f.pending, f.started = serial, RealTime()
        status:SetText(tr("Loading…", "Загрузка…"))
        net.Start("ts_flag_editor_request")
        net.WriteString(util.TableToJSON(data))
        net.SendToServer()
    end
    local function button(parent, label, width, callback)
        local b = parent:Add("DButton")
        b:Dock(LEFT)
        b:SetWide(width)
        b:DockMargin(0, 2, 5, 2)
        TS.Editor.StyleButton(b, { label = label })
        b.DoClick = callback
        return b
    end
    local function selected()
        local line = rows:GetSelectedLine()
        return line and rows:GetLine(line).FlagData
    end
    local function edit(entry)
        if not state.editable or not state.sid or f.pending then
            return
        end
        local sid = state.sid

        local dialog = vgui.Create("DFrame")
        dialog:SetSize(490, 340)
        dialog:Center()
        dialog:MakePopup()
        styleFrame(
            dialog,
            entry and tr("Edit flag", "Изменить флаг") or tr("Add flag", "Добавить флаг"),
            tr("Name, type and value", "Имя, тип и значение")
        )

        local key = dialog:Add("DTextEntry")
        key:Dock(TOP)
        key:SetTall(30)
        TS.Editor.StyleEntry(key)
        key:DockMargin(0, 0, 0, 8)
        key:SetPlaceholderText(tr("Flag name", "Имя флага"))
        key:SetValue(entry and entry.key or "")
        key:SetEnabled(not entry)

        local kind = dialog:Add("DComboBox")
        kind:Dock(TOP)
        kind:SetTall(30)
        TS.Editor.StyleCombo(kind)
        kind:DockMargin(0, 0, 0, 8)
        for _, name in ipairs({ "boolean", "number", "string" }) do
            kind:AddChoice(name)
        end
        kind:SetValue(entry and type(entry.value) or "boolean")

        local value = dialog:Add("DTextEntry")
        value:Dock(TOP)
        value:SetTall(30)
        TS.Editor.StyleEntry(value)
        value:DockMargin(0, 0, 0, 8)
        value:SetValue(entry and tostring(entry.value) or "true")

        local hint = dialog:Add("DLabel")
        styleLabel(hint)
        hint:Dock(TOP)
        hint:SetTall(55)
        hint:SetWrap(true)
        hint:SetText(
            tr(
                "boolean: true / false; number: finite number; string: literal text, up to 256 characters.",
                "boolean: true / false; number: конечное число; string: текст без кавычек, до 256 символов."
            )
        )

        local save = dialog:Add("DButton")
        save:Dock(BOTTOM)
        save:SetTall(32)
        TS.Editor.StyleButton(save, { label = tr("Save", "Сохранить"), accent = true, icon = "floppy-disk" })
        save.DoClick = function()
            if not IsValid(f) or sid ~= state.sid or f.pending then
                dialog:Close()
                return
            end
            local v, t = value:GetValue(), kind:GetValue()
            local function invalid()
                hint:SetText(tr(errors.invalid[1], errors.invalid[2]))
                hint:SetTextColor(Color(235, 95, 85))
            end
            if t == "boolean" then
                if v ~= "true" and v ~= "false" then
                    return invalid()
                end
                v = v == "true"
            elseif t == "number" then
                v = tonumber(v)
                if not v or v ~= v or v == math.huge or v == -math.huge then
                    return invalid()
                end
            elseif t ~= "string" or TS.Utils._UTF8Length(v) > 256 then
                return invalid()
            end
            if TS.Utils.SafeID(key:GetValue()) ~= key:GetValue() then
                return invalid()
            end
            request("set", { key = key:GetValue(), value = v, exists = entry ~= nil, previous = entry and entry.value })
            dialog:Close()
        end
    end
    local add = button(bar, tr("Add", "Добавить"), 95, function()
        edit()
    end)
    local change = button(bar, tr("Edit", "Изменить"), 95, function()
        if selected() then
            edit(selected())
        end
    end)
    local remove = button(bar, tr("Delete", "Удалить"), 95, function()
        local entry, sid = selected(), state.sid
        if not entry then
            return
        end
        confirmDelete(entry.key, function()
            if IsValid(f) and state.sid == sid then
                request("delete", { key = entry.key, exists = true, previous = entry.value })
            end
        end)
    end)
    local refresh = button(bar, tr("Refresh", "Обновить"), 100, function()
        request("list")
    end)
    local prev = button(pagination, "<", 35, function()
        state.page = math.max(1, state.page - 1)
        request("list")
    end)
    local nextPage = button(pagination, ">", 35, function()
        state.page = math.min(state.pages, state.page + 1)
        request("list")
    end)

    local count = pagination:Add("DLabel")
    styleLabel(count)
    count:Dock(FILL)
    count:SetText("")
    local function renderPlayers()
        players:Clear()
        local query = string.lower(playerSearch:GetValue())
        for _, p in ipairs(state.players or {}) do
            if string.find(string.lower(p.name .. " " .. p.sid), query, 1, true) then
                local line = players:AddLine(p.name, p.sid)
                line.PlayerData = p
            end
        end
    end
    playerSearch.OnChange = renderPlayers
    players.OnRowSelected = function(_, _, line)
        if f.pending then
            return
        end
        state.sid, state.page = line.PlayerData.sid, 1
        rows:Clear()
        heading:SetText(line.PlayerData.name .. " — " .. state.sid)
        request("list")
    end
    refreshPlayers.DoClick = function()
        request("players")
    end
    search.OnEnter = function()
        state.page = 1
        request("list")
    end
    onlyTrue.OnChange = function()
        state.page = 1
        request("list")
    end
    f.ReceiveFlags = function(data)
        if data.id ~= f.pending then
            return
        end
        f.pending = nil
        if data.error then
            if data.error == "denied" then
                state.editable = false
            end
            local message = errors[data.error] or errors.invalid
            status:SetText(tr(message[1], message[2]))
            return
        end
        state.editable = data.editable == true
        if data.players then
            state.players = data.players
            renderPlayers()
            local present = false
            for _, p in ipairs(data.players) do
                if p.sid == state.sid then
                    present = true
                end
            end
            if not present then
                state.sid = nil
                rows:Clear()
                count:SetText("")
                heading:SetText(tr("No player selected", "Игрок не выбран"))
            end
            status:SetText(
                tr(
                    "Select a player. Refresh to see changes made in game.",
                    "Выберите игрока. Обновляйте список, чтобы видеть изменения из игры."
                )
            )
            return
        end
        if data.sid ~= state.sid then
            return
        end
        state.page, state.pages = data.page, data.pages
        rows:Clear()
        for _, entry in ipairs(data.rows or {}) do
            local line = rows:AddLine(entry.key, type(entry.value), tostring(entry.value))
            line.FlagData = entry
        end
        count:SetText(string.format("%d / %d   ·   %d", data.page, data.pages, data.total))
        status:SetText(
            data.saved and tr("Saved on server.", "Сохранено на сервере.")
                or data.total == 0 and tr("No matching flags.", "Подходящих флагов нет.")
                or tr(
                    "Select a flag to edit. Changes affect quest progress immediately.",
                    "Выберите флаг. Изменения сразу влияют на прогресс квестов."
                )
        )
    end
    local frameThink = f.Think
    f.Think = function(self)
        if frameThink then
            frameThink(self)
        end
        if f.pending and RealTime() - f.started > 8 then
            f.pending = nil
            status:SetText(
                tr(
                    "No reply. Refresh to verify server state before retrying.",
                    "Нет ответа. Обновите данные, чтобы проверить результат перед повтором."
                )
            )
        end
        local idle = not f.pending
        players:SetEnabled(idle)
        search:SetEnabled(idle)
        onlyTrue:SetEnabled(idle)
        add:SetEnabled(idle and state.sid ~= nil and state.editable)
        change:SetEnabled(idle and selected() ~= nil and state.editable)
        remove:SetEnabled(idle and selected() ~= nil and state.editable)
        refresh:SetEnabled(idle and state.sid ~= nil)
        refreshPlayers:SetEnabled(idle)
        prev:SetEnabled(idle and state.sid ~= nil and state.page > 1)
        nextPage:SetEnabled(idle and state.sid ~= nil and state.page < state.pages)
    end
    request("players")
end

net.Receive("ts_flag_editor_reply", function()
    local data = util.JSONToTable(net.ReadString(), false, true)
    if IsValid(window) and istable(data) then
        window.ReceiveFlags(data)
    end
end)
