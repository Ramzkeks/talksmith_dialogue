local TS = Talksmith

TS.Editor.NODE_WIDTH = 252
local HEAD, TEXT, ROW, PAD = 32, 38, 26, 8

function TS.Editor.NodeHeight(node)
    return HEAD + TEXT + #(node.options or {}) * ROW + PAD
end
function TS.Editor.NodeRect(node)
    local e = node.editor or {}
    return e.x or 0, e.y or 0, TS.Editor.NODE_WIDTH, TS.Editor.NodeHeight(node)
end
function TS.Editor.NodeInputPos(node)
    local x, y = TS.Editor.NodeRect(node)
    return x, y + HEAD / 2
end
function TS.Editor.OptionPortPos(node, i)
    local x, y, w = TS.Editor.NodeRect(node)
    return x + w, y + HEAD + TEXT + (i - 0.5) * ROW
end
function TS.Editor.OptionRowRect(node, i)
    local x, y, w = TS.Editor.NodeRect(node)
    return x, y + HEAD + TEXT + (i - 1) * ROW, w, ROW
end

local function ellipsis(s, n)
    s = string.gsub(s or "", "%s+", " ")
    if n <= 0 or s == "" then
        return ""
    end

    local pos, chars = 1, 0
    while pos <= #s do
        local byte = string.byte(s, pos)
        local step = byte < 128 and 1 or (byte < 224 and 2 or (byte < 240 and 3 or 4))
        chars = chars + 1

        local nextPos = pos + step
        if chars == n then
            return nextPos <= #s and string.sub(s, 1, pos - 1) .. "…" or s
        end
        pos = nextPos
    end
    return s
end

function TS.Editor.NodeDisplayName(node, id)
    local note = node and node.editor and node.editor.note
    if isstring(note) and string.Trim(note) ~= "" then
        return string.Trim(note), true
    end
    local text = node and node.text
    if isstring(text) and string.Trim(text) ~= "" then
        return string.Trim(text), true
    end
    return id, false
end

local function ntext(s, font, x, y, col, ax, ay)
    return draw.SimpleText(s, font, math.Round(x), math.Round(y), col, ax, ay)
end

local function zoomLevel(zoom)
    if zoom < 0.48 then return "Micro" end
    if zoom < 0.68 then return "Compact" end
    if zoom < 0.86 then return "Medium" end
    if zoom < 1.18 then return "Normal" end
    if zoom < 1.5 then return "Large" end
    if zoom < 1.8 then return "XLarge" end
    return "XXLarge"
end

local function zoomFont(role, level)
    return "Talksmith_E_Node" .. role .. "_" .. level
end

function TS.Editor.DrawNode(id, node, sx, sy, zoom, state)
    local T = TS.Editor.Theme
    local w = TS.Editor.NODE_WIDTH * zoom
    local head, textH, row = HEAD * zoom, TEXT * zoom, ROW * zoom
    local h = TS.Editor.NodeHeight(node) * zoom
    local level = zoomLevel(zoom)
    local fBody = zoomFont("Body", level)
    local fSmall = zoomFont("Small", level)
    local fTiny = zoomFont("Tiny", level)
    local showDetails = zoom >= 0.6

    draw.RoundedBox(6, sx + 3, sy + 5, w, h, Color(3, 9, 10, 145))
    draw.RoundedBox(6, sx, sy, w, h, T.card)

    local hc = node.editor and node.editor.color
    local headCol = istable(hc) and Color(hc.r or 43, hc.g or 48, hc.b or 51) or T.cardHead
    draw.RoundedBoxEx(6, sx, sy, w, head, headCol, true, true, false, false)

    surface.SetDrawColor(state.hasError and T.red or (state.selected and T.blue or T.line))
    surface.DrawOutlinedRect(sx, sy, w, h, state.selected and 2 or 1)
    if state.selected then
        surface.SetDrawColor(T.blue)
        surface.DrawRect(sx, sy + 6 * zoom, 3 * zoom, h - 12 * zoom)
    end

    local tx = sx + 8 * zoom
    if state.isStart then
        local showStartLabel = showDetails
        local cw = (showStartLabel and 46 or 14) * zoom
        draw.RoundedBox(3, tx, sy + head / 2 - 8 * zoom, cw, 16 * zoom, Color(T.green.r, T.green.g, T.green.b, 60))
        if showStartLabel then
            ntext(
                "START",
                fTiny,
                tx + cw / 2,
                sy + head / 2,
                T.green,
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER
            )
        end
        tx = tx + cw + 6 * zoom
    end
    local hasNote = node.editor and isstring(node.editor.note) and string.Trim(node.editor.note) ~= ""
    local display = hasNote and node.editor.note or id
    ntext(
        ellipsis(display, state.isStart and 18 or 25),
        fBody,
        tx,
        sy + head / 2,
        state.selected and T.blue or T.text,
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_CENTER
    )
    if #(node.actions or {}) > 0 then
        local gs = math.min(14, 16 * zoom)
        TS.Editor.DrawIcon(
            "gear-six",
            math.Round(sx + w - (state.hasError and 26 or 12) * zoom - gs / 2),
            math.Round(sy + head / 2 - gs / 2),
            gs,
            T.teal
        )
    end
    if state.hasError then
        draw.RoundedBox(4, sx + w - 16 * zoom, sy + head / 2 - 4 * zoom, 8 * zoom, 8 * zoom, T.red)
    end

    if showDetails then
        ntext(
            ellipsis(node.text, 35),
            fSmall,
            sx + 8 * zoom,
            sy + head + textH / 2,
            T.muted,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )
    end

    for i, o in ipairs(node.options or {}) do
        local ry = sy + head + textH + (i - 1) * row
        if state.selectedOpt == i and state.selected then
            surface.SetDrawColor(T.selection)
            surface.DrawRect(sx + 1, ry, w - 2, row)
        end
        local ix = sx + 8 * zoom
        local ms = math.min(12, row * 0.5)
        if #(o.conditions or {}) > 0 then
            TS.Editor.DrawIcon("diamond-fill", math.Round(ix + 3 * zoom - ms / 2), math.Round(ry + row / 2 - ms / 2), ms, T.yellow)
            ix = ix + 10 * zoom
        end
        if #(o.actions or {}) > 0 then
            TS.Editor.DrawIcon("circle-fill", math.Round(ix + 3 * zoom - ms / 2), math.Round(ry + row / 2 - ms / 2), ms, T.teal)
            ix = ix + 10 * zoom
        end
        if showDetails then
            ntext(
                i .. ". " .. ellipsis(o.text, 28),
                fSmall,
                ix,
                ry + row / 2,
                T.text,
                TEXT_ALIGN_LEFT,
                TEXT_ALIGN_CENTER
            )
        end
        local px, py = sx + w, ry + row / 2
        local hot = state.hotPort == i
        if #(o.next_random or {}) > 0 then
            draw.RoundedBox(3, px - 5, py - 5, 10, 10, hot and T.text or T.yellow)
            if zoom >= 0.7 then
                ntext("⁂", fTiny, px, py, T.card, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        elseif o.next ~= nil then
            draw.RoundedBox(3, px - 4, py - 4, 8, 8, hot and T.text or T.blue)
        else
            draw.RoundedBox(1, px - 4, py - 4, 8, 8, hot and T.text or T.red)
        end
    end

    local ipx, ipy = sx, sy + head / 2
    draw.RoundedBox(3, ipx - 4, ipy - 4, 8, 8, T.green)
end
