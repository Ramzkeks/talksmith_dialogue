local TS = Talksmith
local DEFAULT_GRID = 16

local function gridSize()
    if TS.Editor.GetSetting then
        return math.Clamp(math.floor(tonumber(TS.Editor.GetSetting("grid_size")) or DEFAULT_GRID), 8, 64)
    end
    return DEFAULT_GRID
end

local function snapCoordinate(value)
    if TS.Editor.GetSetting and TS.Editor.GetSetting("snap_to_grid") == false then
        return math.Round(value)
    end
    local grid = gridSize()
    return math.Round(value / grid) * grid
end
local PANEL = {}

function PANEL:Init()
    self.Zoom = 1
    self.OX = 60
    self.OY = 40
    self.Sel = {}
    self.Primary = nil
    self.SelOpt = nil
    self.Errors = {}
    self.Mode = nil
    self.SortedNodeIDs = nil
    self.SortedNodeSource = nil
    self.GraphNodeCount = nil
    self.GraphConnectionCount = nil
    self:SetMouseInputEnabled(true)
    self:SetKeyboardInputEnabled(true)
end

function PANEL:SetDocument(doc, keepView)
    self.Doc = doc
    self.SortedNodeIDs = nil
    self.SortedNodeSource = nil
    self:InvalidateGraphStats()
    self.Sel = {}
    self.Primary = nil
    self.SelOpt = nil
    self.Mode = nil
    if not keepView then
        self:CenterStart()
    end
end
function PANEL:SetErrors(map)
    self.Errors = map or {}
end

function PANEL:ToScreen(wx, wy)
    return wx * self.Zoom + self.OX, wy * self.Zoom + self.OY
end
function PANEL:ToWorld(sx, sy)
    return (sx - self.OX) / self.Zoom, (sy - self.OY) / self.Zoom
end
function PANEL:ViewCenterWorld()
    return self:ToWorld(self:GetWide() / 2, self:GetTall() / 2)
end

function PANEL:SortedIDs()
    local nodes = self.Doc and self.Doc.nodes or nil
    if self.SortedNodeSource == nodes and self.SortedNodeIDs then
        return self.SortedNodeIDs
    end
    local t = {}
    for id in pairs(nodes or {}) do
        t[#t + 1] = id
    end
    table.sort(t)
    self.SortedNodeSource = nodes
    self.SortedNodeIDs = t
    return t
end

function PANEL:InvalidateSortedIDs()
    self.SortedNodeIDs = nil
    self:InvalidateGraphStats()
end

function PANEL:InvalidateGraphStats()
    self.GraphNodeCount = nil
    self.GraphConnectionCount = nil
end

function PANEL:Select(id, opt, additive)
    if additive and id then
        if self.Sel[id] and self.Primary == id then
            self.Sel[id] = nil
            id = next(self.Sel)
        else
            self.Sel[id] = true
        end
    elseif id then
        if not self.Sel[id] then
            self.Sel = { [id] = true }
        end
    else
        if not additive then
            self.Sel = {}
        end
    end
    self.Primary = id
    self.SelOpt = opt
    if self.OnSelection then
        self:OnSelection(id, opt)
    end
end

function PANEL:CenterOn(id)
    local node = self.Doc and self.Doc.nodes[id]
    if not node then
        return
    end
    local x, y, w, h = TS.Editor.NodeRect(node)
    self.OX = self:GetWide() / 2 - (x + w / 2) * self.Zoom
    self.OY = self:GetTall() / 2 - (y + h / 2) * self.Zoom
    self:Select(id, nil, false)
end
function PANEL:CenterStart()
    if self.Doc then
        self:CenterOn(self.Doc.start)
    end
end

function PANEL:GraphStats()
    if self.GraphNodeCount ~= nil and self.GraphConnectionCount ~= nil then
        return self.GraphNodeCount, self.GraphConnectionCount
    end
    local nodes = self.Doc and self.Doc.nodes or {}
    local nodeCount = 0
    local connectionCount = 0
    for _, node in pairs(nodes) do
        nodeCount = nodeCount + 1
        for _, option in ipairs(node.options or {}) do
            for _, target in ipairs(option.next_random or {}) do
                if nodes[target] then
                    connectionCount = connectionCount + 1
                end
            end
            if #(option.next_random or {}) == 0 and option.next and nodes[option.next] then
                connectionCount = connectionCount + 1
            end
        end
    end
    self.GraphNodeCount = nodeCount
    self.GraphConnectionCount = connectionCount
    return nodeCount, connectionCount
end

function PANEL:ConnectionCount()
    local _, connectionCount = self:GraphStats()
    return connectionCount
end

function PANEL:HitTest(mx, my, visibleIDs)
    local ids = visibleIDs or self:SortedIDs()
    local wx, wy = self:ToWorld(mx, my)
    for k = #ids, 1, -1 do
        local id = ids[k]
        local node = self.Doc.nodes[id]
        for i = 1, #(node.options or {}) do
            local px, py = TS.Editor.OptionPortPos(node, i)
            local sx, sy = self:ToScreen(px, py)
            if (mx - sx) ^ 2 + (my - sy) ^ 2 <= 81 then
                return "port", id, i
            end
        end
        local x, y, w, h = TS.Editor.NodeRect(node)
        if wx >= x and wx <= x + w and wy >= y and wy <= y + h then
            for i = 1, #(node.options or {}) do
                local rx, ry, rw, rh = TS.Editor.OptionRowRect(node, i)
                if wy >= ry and wy <= ry + rh then
                    return "node", id, i
                end
            end
            return "node", id, nil
        end
    end
end

local function bezier(x0, y0, x1, y1, col, viewW, viewH)
    local dx = math.Clamp(math.abs(x1 - x0) * 0.5, 40, 140)
    local control0 = x0 + dx
    local control1 = x1 - dx
    if viewW and viewH then
        local margin = 24
        if math.max(x0, x1, control0, control1) < -margin
            or math.min(x0, x1, control0, control1) > viewW + margin
            or math.max(y0, y1) < -margin
            or math.min(y0, y1) > viewH + margin
        then
            return
        end
    end
    local distance = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
    local segments = math.Clamp(math.ceil(distance / 36), 12, 20)
    surface.SetDrawColor(col)
    local lx, ly = x0, y0
    for i = 1, segments do
        local t = i / segments
        local it = 1 - t
        local x = it ^ 3 * x0 + 3 * it ^ 2 * t * control0 + 3 * it * t ^ 2 * control1 + t ^ 3 * x1
        local y = it ^ 3 * y0 + 3 * it ^ 2 * t * y0 + 3 * it * t ^ 2 * y1 + t ^ 3 * y1
        surface.DrawLine(lx, ly, x, y)
        lx, ly = x, y
    end
end

function PANEL:Paint(w, h)
    local T = TS.Editor.Theme
    surface.SetDrawColor(T.canvas)
    surface.DrawRect(0, 0, w, h)

    local g = gridSize() * 2 * self.Zoom
    if g >= 8 then
        for x = self.OX % g, w, g do
            surface.SetDrawColor(math.floor((x - self.OX) / g + 0.5) % 5 == 0 and T.gridMajor or T.gridMinor)
            surface.DrawLine(x, 0, x, h)
        end
        for y = self.OY % g, h, g do
            surface.SetDrawColor(math.floor((y - self.OY) / g + 0.5) % 5 == 0 and T.gridMajor or T.gridMinor)
            surface.DrawLine(0, y, w, y)
        end
    end

    local function drawControlsHint()
        surface.SetFont("Talksmith_E_Tiny")
        local hint = TS.L("canvas_controls")
        local tw = surface.GetTextSize(hint)
        draw.RoundedBox(4, 14, 14, tw + 20, 26, Color(T.bar.r, T.bar.g, T.bar.b, 230))
        draw.SimpleText(hint, "Talksmith_E_Tiny", 24, 27, T.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    if not self.Doc then
        surface.SetFont("Talksmith_E_Small")
        local bodyW = surface.GetTextSize(TS.L("canvas_welcome_body"))
        local cw = math.min(math.max(520, bodyW + 80), w - 48)
        local ch = 132
        local cx, cy = math.Round((w - cw) / 2), math.Round((h - ch) / 2)
        draw.RoundedBox(8, cx, cy, cw, ch, T.side)
        surface.SetDrawColor(T.lineSoft)
        surface.DrawOutlinedRect(cx, cy, cw, ch, 1)
        draw.SimpleText(
            TS.L("canvas_welcome_title"),
            "Talksmith_E_Display",
            math.Round(w / 2),
            cy + 35,
            T.text,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
        draw.SimpleText(
            TS.L("canvas_welcome_body"),
            "Talksmith_E_Small",
            math.Round(w / 2),
            cy + 72,
            T.muted,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
        draw.SimpleText(
            TS.L("canvas_no_doc"),
            "Talksmith_E_Small",
            math.Round(w / 2),
            cy + 101,
            T.blue,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
        drawControlsHint()
        return
    end

    if not next(self.Doc.nodes or {}) then
        draw.SimpleText(
            TS.L("canvas_empty_title"),
            "Talksmith_E_Display",
            math.Round(w / 2),
            math.Round(h / 2 - 14),
            T.text,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
        draw.SimpleText(
            TS.L("canvas_empty_body"),
            "Talksmith_E_Small",
            math.Round(w / 2),
            math.Round(h / 2 + 18),
            T.muted,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
        drawControlsHint()
        return
    end

    local worldLeft, worldTop = self:ToWorld(-32, -32)
    local worldRight, worldBottom = self:ToWorld(w + 32, h + 32)
    local visibleIDs = {}
    for _, id in ipairs(self:SortedIDs()) do
        local node = self.Doc.nodes[id]
        local x, y, nodeW, nodeH = TS.Editor.NodeRect(node)
        if x <= worldRight and x + nodeW >= worldLeft and y <= worldBottom and y + nodeH >= worldTop then
            visibleIDs[#visibleIDs + 1] = id
        end
    end

    for id, node in pairs(self.Doc.nodes) do
        for i, o in ipairs(node.options or {}) do
            for _, targetID in ipairs(o.next_random or {}) do
                local target = self.Doc.nodes[targetID]
                if target then
                    local x0, y0 = self:ToScreen(TS.Editor.OptionPortPos(node, i))
                    local x1, y1 = self:ToScreen(TS.Editor.NodeInputPos(target))
                    local hot = self.Sel[id] or self.Sel[targetID]
                    bezier(x0, y0, x1, y1, hot and T.yellow or Color(T.yellow.r, T.yellow.g, T.yellow.b, 75), w, h)
                end
            end
            local target = #(o.next_random or {}) == 0 and o.next and self.Doc.nodes[o.next]
            if target then
                local x0, y0 = self:ToScreen(TS.Editor.OptionPortPos(node, i))
                local x1, y1 = self:ToScreen(TS.Editor.NodeInputPos(target))
                local hot = self.Sel[id] or self.Sel[o.next]
                bezier(x0, y0, x1, y1, hot and T.blue or Color(T.blue.r, T.blue.g, T.blue.b, 90), w, h)
            end
        end
    end

    if self.Mode and self.Mode.type == "connect" then
        local node = self.Doc.nodes[self.Mode.from]
        if node then
            local x0, y0 = self:ToScreen(TS.Editor.OptionPortPos(node, self.Mode.opt))
            local mx, my = self:CursorPos()
            bezier(x0, y0, mx, my, T.yellow, w, h)
        end
    end

    local hotPortId, hotPortIdx
    if not self.Mode then
        local mx, my = self:CursorPos()
        local kind, id, i = self:HitTest(mx, my, visibleIDs)
        if kind == "port" then
            hotPortId, hotPortIdx = id, i
        end
    end

    for _, id in ipairs(visibleIDs) do
        local node = self.Doc.nodes[id]
        local sx, sy = self:ToScreen(TS.Editor.NodeRect(node))
        TS.Editor.DrawNode(id, node, sx, sy, self.Zoom, {
            selected = self.Sel[id] == true,
            isStart = self.Doc.start == id,
            hasError = self.Errors[id] == true,
            selectedOpt = self.Primary == id and self.SelOpt or nil,
            hotPort = hotPortId == id and hotPortIdx or nil,
        })
    end

    if self.Mode and self.Mode.type == "box" then
        local mx, my = self:CursorPos()
        local x0, y0 = math.min(mx, self.Mode.x), math.min(my, self.Mode.y)
        local bw, bh = math.abs(mx - self.Mode.x), math.abs(my - self.Mode.y)
        surface.SetDrawColor(T.selection)
        surface.DrawRect(x0, y0, bw, bh)
        surface.SetDrawColor(T.blue)
        surface.DrawOutlinedRect(x0, y0, bw, bh, 1)
    end

    drawControlsHint()
end

function PANEL:OnMousePressed(code)
    self:RequestFocus()
    if not self.Doc then
        return
    end
    local mx, my = self:CursorPos()
    local ctrl = input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL)

    if code == MOUSE_MIDDLE then
        self.Mode = { type = "pan", x = mx, y = my, ox = self.OX, oy = self.OY }
        return
    end

    local kind, id, opt = self:HitTest(mx, my)

    if code == MOUSE_LEFT then
        if kind == "port" then
            self.Mode = { type = "connect", from = id, opt = opt }
        elseif kind == "node" then
            self:Select(id, opt, ctrl)
            local starts = {}
            for sid in pairs(self.Sel) do
                local e = self.Doc.nodes[sid].editor or { x = 0, y = 0 }
                self.Doc.nodes[sid].editor = e
                starts[sid] = { x = e.x or 0, y = e.y or 0 }
            end
            self.Mode = { type = "move", x = mx, y = my, starts = starts, moved = false }
        else
            self.Mode = { type = "box", x = mx, y = my, additive = ctrl }
        end
    elseif code == MOUSE_RIGHT then
        if kind == "port" then
            local o = self.Doc.nodes[id].options[opt]
            local m = TS.Editor.CreateMenu(240)
            TS.Editor.AddMenuOption(m, TS.L("break_link") .. " / " .. TS.L("end_here"), function()
                if o.next ~= nil or #(o.next_random or {}) > 0 then
                    self.Snapshot()
                    o.next = nil
                    o.next_random = {}
                    self.OnGraphChanged()
                end
            end, { icon = "link-break", danger = true })
            m:Open()
        elseif kind == "node" then
            if not self.Sel[id] then
                self:Select(id, opt, false)
            end
            local m = TS.Editor.CreateMenu(240)
            TS.Editor.AddMenuOption(m, TS.L("make_start"), function()
                self.Snapshot()
                self.Doc.start = id
                self.OnGraphChanged()
            end, { icon = "flag", accent = true })
            TS.Editor.AddMenuOption(m, TS.L("duplicate") .. " (Ctrl+D)", function()
                self:DuplicateSelected()
            end, { icon = "copy" })
            TS.Editor.AddMenuOption(m, TS.L("delete") .. " (Del)", function()
                self:DeleteSelected()
            end, { icon = "trash", danger = true })
            m:Open()
        else
            local wx, wy = self:ToWorld(mx, my)
            local m = TS.Editor.CreateMenu(240)
            TS.Editor.AddMenuOption(m, TS.L("add_node_here"), function()
                self:AddNode(wx, wy)
            end, { icon = "plus", accent = true })
            if TS.Editor.Clipboard then
                TS.Editor.AddMenuOption(m, TS.L("paste") .. " (Ctrl+V)", function()
                    self:Paste(wx, wy)
                end, { icon = "clipboard-text" })
            end
            TS.Editor.AddMenuOption(m, TS.L("select_all") .. " (Ctrl+A)", function()
                self:SelectAll()
            end)
            TS.Editor.AddMenuOption(m, TS.L("center_start"), function()
                self:CenterStart()
            end, { icon = "crosshair" })
            m:Open()
        end
    end
end

function PANEL:OnMouseReleased(code)
    local mode = self.Mode
    self.Mode = nil
    if not mode or not self.Doc then
        return
    end
    local mx, my = self:CursorPos()

    if mode.type == "connect" then
        local kind, id = self:HitTest(mx, my)
        local o = self.Doc.nodes[mode.from] and self.Doc.nodes[mode.from].options[mode.opt]
        if not o then
            return
        end
        if kind == "node" or kind == "port" then
            if o.next ~= id then
                self.Snapshot()
                o.next = id
                o.next_random = {}
                self.OnGraphChanged()
            end
        else
            local m = TS.Editor.CreateMenu(240)
            TS.Editor.AddMenuOption(m, TS.L("end_here"), function()
                if o.next ~= nil or #(o.next_random or {}) > 0 then
                    self.Snapshot()
                    o.next = nil
                    o.next_random = {}
                    self.OnGraphChanged()
                end
            end, { icon = "stop", danger = true })
            TS.Editor.AddMenuOption(m, TS.L("add_node_here"), function()
                local wx, wy = self:ToWorld(mx, my)
                local nid = self:AddNode(wx, wy, true)
                if nid then
                    o.next = nid
                    o.next_random = {}
                    self.OnGraphChanged()
                end
            end, { icon = "plus", accent = true })
            TS.Editor.AddMenuOption(m, TS.L("cancel"), function() end)
            m:Open()
        end
    elseif mode.type == "box" then
        local wx0, wy0 = self:ToWorld(math.min(mx, mode.x), math.min(my, mode.y))
        local wx1, wy1 = self:ToWorld(math.max(mx, mode.x), math.max(my, mode.y))
        if not mode.additive then
            self.Sel = {}
        end
        for id, node in pairs(self.Doc.nodes) do
            local x, y, w, h = TS.Editor.NodeRect(node)
            if x < wx1 and x + w > wx0 and y < wy1 and y + h > wy0 then
                self.Sel[id] = true
            end
        end
        self.Primary = next(self.Sel)
        self.SelOpt = nil
        if self.OnSelection then
            self:OnSelection(self.Primary, nil)
        end
    elseif mode.type == "move" and mode.moved then
        self.OnGraphChanged()
    end
end

function PANEL:Think()
    local mode = self.Mode
    if not mode then
        return
    end
    if not input.IsMouseDown(MOUSE_LEFT) and not input.IsMouseDown(MOUSE_MIDDLE) then
        if mode.type == "move" or mode.type == "pan" then
            self.Mode = nil
        else
            self:OnMouseReleased(MOUSE_LEFT)
        end
        return
    end
    local mx, my = self:CursorPos()
    if mode.type == "pan" then
        self.OX = mode.ox + (mx - mode.x)
        self.OY = mode.oy + (my - mode.y)
    elseif mode.type == "move" then
        local dx, dy = (mx - mode.x) / self.Zoom, (my - mode.y) / self.Zoom
        if not mode.moved and (math.abs(dx) > 2 or math.abs(dy) > 2) then
            mode.moved = true
            self.Snapshot()
        end
        if mode.moved then
            for id, s in pairs(mode.starts) do
                local node = self.Doc.nodes[id]
                if node then
                    node.editor.x = snapCoordinate(s.x + dx)
                    node.editor.y = snapCoordinate(s.y + dy)
                end
            end
        end
    end
end

function PANEL:OnMouseWheeled(delta)
    local mx, my = self:CursorPos()
    local wx, wy = self:ToWorld(mx, my)
    self.Zoom = math.Clamp(self.Zoom * (delta > 0 and 1.12 or 1 / 1.12), 0.35, 2)
    self.OX = mx - wx * self.Zoom
    self.OY = my - wy * self.Zoom
    return true
end

function PANEL:FreeNodeID(base)
    base = base or "node"
    local i = 1
    while self.Doc.nodes[base .. "_" .. i] do
        i = i + 1
        if i > TS.Config.max_nodes * 2 then
            return
        end
    end
    return base .. "_" .. i
end

function PANEL:AddNode(wx, wy, silent)
    if not self.Doc or table.Count(self.Doc.nodes) >= TS.Config.max_nodes then
        return
    end
    if not wx then
        wx, wy = self:ViewCenterWorld()
        wx = wx - TS.Editor.NODE_WIDTH / 2
        while true do
            local busy = false
            for _, n in pairs(self.Doc.nodes) do
                local x, y = TS.Editor.NodeRect(n)
                if math.abs(x - wx) < 24 and math.abs(y - wy) < 24 then
                    busy = true
                    break
                end
            end
            if not busy then
                break
            end
            wx, wy = wx + 32, wy + 32
        end
    end
    self.Snapshot()
    local id = self:FreeNodeID()
    if not id then
        return
    end
    self.Doc.nodes[id] = {
        editor = { x = snapCoordinate(wx), y = snapCoordinate(wy) },
        text = TS.L("new_node_text"),
        sound = "",
        gesture = "",
        actions = {},
        options = {
            {
                text = TS.L("new_response_text"),
                next = nil,
                next_random = {},
                gesture = "",
                conditions = {},
                actions = {},
            },
        },
    }
    self:InvalidateSortedIDs()
    if not silent then
        self:Select(id, nil, false)
    end
    self.OnGraphChanged()
    return id
end

function PANEL:DeleteSelected(confirmed)
    if not self.Doc or not next(self.Sel) then
        return
    end
    if self.Sel[self.Doc.start] then
        TS.Runtime.Notify(TS.L("cant_delete_start"), NOTIFY_ERROR, 4)
        return
    end
    if not confirmed and TS.Editor.GetSetting and TS.Editor.GetSetting("confirm_delete") then
        TS.Editor.Confirm(TS.L("delete_nodes_title"), TS.L("delete_nodes_confirm", table.Count(self.Sel)), {
            {
                label = TS.L("delete"),
                danger = true,
                callback = function()
                    if IsValid(self) then
                        self:DeleteSelected(true)
                    end
                end,
            },
            { label = TS.L("cancel"), quiet = true },
        })
        return
    end
    self.Snapshot()
    self:InvalidateSortedIDs()
    for id in pairs(self.Sel) do
        self.Doc.nodes[id] = nil
    end
    for _, node in pairs(self.Doc.nodes) do
        for _, o in ipairs(node.options or {}) do
            if o.next and self.Sel[o.next] then
                o.next = nil
            end
            local kept = {}
            for _, target in ipairs(o.next_random or {}) do
                if not self.Sel[target] then
                    kept[#kept + 1] = target
                end
            end
            o.next_random = kept
        end
    end
    local starts = {}
    for _, id in ipairs(self.Doc.settings and self.Doc.settings.start_random or {}) do
        if not self.Sel[id] then
            starts[#starts + 1] = id
        end
    end
    if self.Doc.settings then
        self.Doc.settings.start_random = starts
    end
    self:Select(nil, nil, false)
    self.OnGraphChanged()
end

function PANEL:CopySelected()
    if not next(self.Sel) then
        return
    end
    local nodes = {}
    for id in pairs(self.Sel) do
        nodes[id] = TS.Utils.Copy(self.Doc.nodes[id])
    end
    TS.Editor.Clipboard = { nodes = nodes }
end

function PANEL:Paste(wx, wy)
    local clip = TS.Editor.Clipboard
    if not clip or not self.Doc then
        return
    end
    if table.Count(self.Doc.nodes) + table.Count(clip.nodes) > TS.Config.max_nodes then
        return
    end
    self.Snapshot()
    self:InvalidateSortedIDs()
    local map = {}
    for id in pairs(clip.nodes) do
        map[id] = self:FreeNodeID(string.match(id, "^(.-)_%d+$") or id)
        if not map[id] then
            return
        end
        self.Doc.nodes[map[id]] = {}
    end
    local minx, miny
    for _, n in pairs(clip.nodes) do
        local e = n.editor or {}
        minx = math.min(minx or e.x or 0, e.x or 0)
        miny = math.min(miny or e.y or 0, e.y or 0)
    end
    local bx, by
    if wx then
        bx, by = wx, wy
    else
        bx, by = (minx or 0) + 32, (miny or 0) + 32
    end
    self.Sel = {}
    for id, src in pairs(clip.nodes) do
        local copy = TS.Utils.Copy(src)
        copy.editor = copy.editor or {}
        copy.editor.x = snapCoordinate(bx + ((src.editor and src.editor.x or 0) - (minx or 0)))
        copy.editor.y = snapCoordinate(by + ((src.editor and src.editor.y or 0) - (miny or 0)))
        for _, o in ipairs(copy.options or {}) do
            if o.next then
                o.next = map[o.next] or (self.Doc.nodes[o.next] and o.next or nil)
            end
            for i, target in ipairs(o.next_random or {}) do
                o.next_random[i] = map[target] or target
            end
        end
        self.Doc.nodes[map[id]] = copy
        self.Sel[map[id]] = true
    end
    self.Primary = next(self.Sel)
    self.SelOpt = nil
    if self.OnSelection then
        self:OnSelection(self.Primary, nil)
    end
    self.OnGraphChanged()
end

function PANEL:DuplicateSelected()
    self:CopySelected()
    self:Paste()
end

function PANEL:SelectAll()
    self.Sel = {}
    for id in pairs(self.Doc and self.Doc.nodes or {}) do
        self.Sel[id] = true
    end
    self.Primary = next(self.Sel)
    self.SelOpt = nil
    if self.OnSelection then
        self:OnSelection(self.Primary, nil)
    end
end

function PANEL:OnKeyCodePressed(key)
    if not self.Doc then
        return
    end
    local ctrl = input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL)
    if key == KEY_DELETE then
        self:DeleteSelected()
    elseif key == KEY_F and self.Primary then
        self:CenterOn(self.Primary)
    elseif ctrl and key == KEY_A then
        self:SelectAll()
    elseif ctrl and key == KEY_C then
        self:CopySelected()
    elseif ctrl and key == KEY_V then
        self:Paste()
    elseif ctrl and key == KEY_D then
        self:DuplicateSelected()
    elseif ctrl and key == KEY_Z then
        if self.OnUndo then
            self.OnUndo()
        end
    elseif ctrl and key == KEY_Y then
        if self.OnRedo then
            self.OnRedo()
        end
    elseif ctrl and key == KEY_S then
        if self.OnSave then
            self.OnSave()
        end
    end
end

vgui.Register("TalksmithCanvas", PANEL, "DPanel")
