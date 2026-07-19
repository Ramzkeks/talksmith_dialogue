local TS = Talksmith

function TS.Editor.ProblemSummary(doc)
    local ok, issues = TS.Validation.ValidateDialogue(doc)
    local errors, warnings = 0, 0
    for _, v in ipairs(issues) do
        if v.severity == "error" then
            errors = errors + 1
        else
            warnings = warnings + 1
        end
    end
    return ok, issues, errors, warnings
end

function TS.Editor.ProblemNodeMap(issues)
    local map = {}
    for _, v in ipairs(issues or {}) do
        if v.severity == "error" then
            local id = string.match(v.path or "", "^nodes%.([^%.]+)")
            if id then
                map[id] = true
            end
        end
    end
    return map
end

function TS.Editor.BuildProblems(parent, cb)
    local T = TS.Editor.Theme
    local panel = parent:Add("DPanel")
    panel:Dock(BOTTOM)
    panel:SetTall(0)
    panel.expanded = false
    panel.Paint = function(_, w, h)
        surface.SetDrawColor(T.side)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(T.line)
        surface.DrawLine(0, 0, w, 0)
    end

    local scroll = panel:Add("DScrollPanel")
    scroll:Dock(FILL)
    scroll:DockMargin(8, 6, 8, 6)
    local sbar = scroll:GetVBar()
    sbar:SetWide(4)
    sbar:SetHideButtons(true)
    sbar.Paint = function() end
    sbar.btnGrip.Paint = function(_, w, h)
        draw.RoundedBox(2, 0, 0, w, h, T.line)
    end

    function panel:SetExpanded(on)
        self.expanded = on
        self:SizeTo(-1, on and 140 or 0, 0.15)
    end

    function panel:SetIssues(issues)
        scroll:Clear()
        if #(issues or {}) == 0 then
            local l = scroll:Add("DPanel")
            l:Dock(TOP)
            l:SetTall(24)
            l.Paint = function(_, w, h)
                TS.Editor.DrawIcon("check", 8, h / 2 - 7, 14, T.green)
                draw.SimpleText(TS.L("no_problems"), "Talksmith_E_Small", 28, h / 2, T.green, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            return
        end
        table.sort(issues, function(a, b)
            if a.severity ~= b.severity then
                return a.severity == "error"
            end
            return (a.path or "") < (b.path or "")
        end)
        for _, v in ipairs(issues) do
            local row = scroll:Add("DButton")
            row:Dock(TOP)
            row:SetTall(22)
            row:SetText("")
            local nodeId = string.match(v.path or "", "^nodes%.([^%.]+)")
            row.Paint = function(s, w, h)
                if s:IsHovered() then
                    surface.SetDrawColor(T.hover)
                    surface.DrawRect(0, 0, w, h)
                end
                local err = v.severity == "error"
                TS.Editor.DrawIcon(err and "x-circle" or "warning", 8, h / 2 - 7, 14, err and T.red or T.yellow)
                draw.SimpleText(
                    string.sub(v.path or "", 1, 38),
                    "Talksmith_E_Mono",
                    28,
                    h / 2,
                    T.muted,
                    TEXT_ALIGN_LEFT,
                    TEXT_ALIGN_CENTER
                )
                draw.SimpleText(v.message or "", "Talksmith_E_Small", 300, h / 2, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            row.DoClick = function()
                if nodeId and cb.OnFocusNode then
                    cb.OnFocusNode(nodeId)
                end
            end
        end
    end

    return panel
end
