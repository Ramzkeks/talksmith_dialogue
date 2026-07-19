local TS = Talksmith

TS.Runtime.DialogueLayout = {
    anchorY = 0.505,
    widthRatio = 0.326,
    leftRatio = 0.137,
    optionHeight = 56,
    optionGap = 7,
    panelPadX = 24,
    panelPadY = 20,
}

TS.Runtime.Themes = {
    default = {
        id = "default",
        font = "Manrope",
        nameWeight = 600,
        bodyWeight = 400,
        optionWeight = 500,
        text = Color(241, 239, 233),
        optionText = Color(214, 220, 226),
        muted = Color(145, 153, 162),
        accent = Color(111, 164, 211),
        danger = Color(205, 82, 70),
        backdrop = Color(5, 8, 12, 74),
        panel = Color(10, 14, 19, 204),
        panelBorder = Color(144, 174, 199, 34),
        option = Color(14, 20, 27, 224),
        optionHover = Color(25, 36, 47, 242),
        optionBorder = Color(132, 161, 185, 42),
        optionBorderHover = Color(145, 190, 225, 116),
        shadow = Color(0, 0, 0, 230),
        radius = 2,
        optionStyle = "bar",
        decoration = "cinematic",
        optionAlign = TEXT_ALIGN_LEFT,
        typewriter = true,
        typeInterval = 0.05,
        ruleWidth = 82,
    },
    retro = {
        id = "retro",
        font = "Manrope",
        nameWeight = 600,
        bodyWeight = 400,
        optionWeight = 500,
        text = Color(246, 226, 172),
        optionText = Color(239, 213, 145),
        muted = Color(167, 143, 91),
        accent = Color(238, 171, 54),
        danger = Color(226, 91, 56),
        backdrop = Color(11, 8, 3, 118),
        panel = Color(17, 12, 5, 222),
        panelBorder = Color(238, 171, 54, 100),
        option = Color(20, 14, 5, 240),
        optionHover = Color(238, 171, 54, 235),
        optionBorder = Color(238, 171, 54, 120),
        optionBorderHover = Color(255, 218, 135, 230),
        shadow = Color(0, 0, 0, 245),
        radius = 0,
        optionStyle = "terminal",
        decoration = "terminal",
        optionAlign = TEXT_ALIGN_LEFT,
        typewriter = true,
        typeInterval = 0.042,
        scanlines = true,
        ruleWidth = 124,
    },
    panorama = {
        id = "panorama",
        font = "Manrope",
        nameWeight = 600,
        bodyWeight = 400,
        optionWeight = 500,
        text = Color(244, 244, 241),
        nameText = Color(235, 174, 67),
        optionText = Color(231, 233, 235),
        optionTextHover = Color(235, 174, 67),
        muted = Color(160, 166, 171),
        accent = Color(235, 174, 67),
        danger = Color(210, 104, 89),
        backdrop = Color(4, 6, 8, 68),
        panel = Color(26, 29, 31, 174),
        panelBorder = Color(225, 230, 233, 35),
        option = Color(18, 20, 22, 0),
        optionHover = Color(235, 174, 67, 24),
        optionBorder = Color(255, 255, 255, 0),
        optionBorderHover = Color(235, 174, 67, 72),
        shadow = Color(0, 0, 0, 235),
        radius = 0,
        optionStyle = "plain",
        decoration = "none",
        panelStyle = "split",
        optionAlign = TEXT_ALIGN_RIGHT,
        exitAlign = TEXT_ALIGN_RIGHT,
        showOptionKeys = false,
        typewriter = true,
        typeInterval = 0.048,
        ruleWidth = 78,
        layout = {
            anchorY = 0.65,
            widthRatio = 0.75,
            leftRatio = 0.165,
            leftMax = 460,
            minWidth = 360,
            maxWidth = 1800,
            optionHeight = 38,
            optionGap = 1,
            textOptionGap = 40,
            panelPadX = 10,
            panelPadY = 14,
        },
    },
    openframe = {
        id = "openframe",
        font = "Manrope",
        nameWeight = 600,
        bodyWeight = 400,
        optionWeight = 500,
        text = Color(246, 246, 242),
        nameText = Color(238, 179, 69),
        optionText = Color(235, 237, 239),
        optionTextHover = Color(238, 179, 69),
        muted = Color(164, 169, 175),
        accent = Color(238, 179, 69),
        danger = Color(218, 111, 94),
        backdrop = Color(2, 4, 6, 58),
        panel = Color(0, 0, 0, 0),
        panelBorder = Color(0, 0, 0, 0),
        option = Color(0, 0, 0, 0),
        optionHover = Color(0, 0, 0, 24),
        optionBorder = Color(255, 255, 255, 0),
        optionBorderHover = Color(238, 179, 69, 0),
        shadow = Color(0, 0, 0, 245),
        radius = 0,
        optionStyle = "plain",
        decoration = "none",
        panelStyle = "none",
        optionAlign = TEXT_ALIGN_RIGHT,
        exitAlign = TEXT_ALIGN_RIGHT,
        showOptionKeys = false,
        typewriter = true,
        typeInterval = 0.05,
        ruleWidth = 68,
        layout = {
            anchorY = 0.65,
            widthRatio = 0.75,
            leftRatio = 0.165,
            leftMax = 460,
            minWidth = 360,
            maxWidth = 1800,
            optionHeight = 34,
            optionGap = 0,
            textOptionGap = 72,
            panelPadX = 8,
            panelPadY = 10,
        },
    },
}

function TS.Runtime.GetTheme(id)
    return TS.Runtime.Themes[isstring(id) and id or ""] or TS.Runtime.Themes.default
end

function TS.Runtime.BuildFonts()
    local scale = math.Clamp(ScrH() / 1080, 0.75, 1.6)
    local faces = {
        regular = "Manrope",
        medium = "Manrope Medium",
        semibold = "Manrope SemiBold",
    }
    local roles = {
        Name = { 27, "semibold", "nameWeight" },
        Sub = { 17, "medium", "optionWeight" },
        Body = { 19, "regular", "bodyWeight" },
        Option = { 18, "medium", "optionWeight" },
        Key = { 18, "medium", "optionWeight" },
        Label = { 20, "medium", "optionWeight" },
        Small = { 15, "medium", "optionWeight" },
    }

    for id, theme in pairs(TS.Runtime.Themes) do
        theme.fonts = {}
        for role, spec in pairs(roles) do
            local name = "Talksmith_" .. id .. "_" .. role
            surface.CreateFont(name, {
                font = faces[spec[2]],
                size = math.Round(spec[1] * scale),
                weight = theme[spec[3]],
                extended = true,
                antialias = true,
            })
            theme.fonts[string.lower(role)] = name
        end
    end
end
TS.Runtime.BuildFonts()

TS.Runtime.ActiveNotices = TS.Runtime.ActiveNotices or {}

local function wrapNoticeText(text, font, maxWidth)
    surface.SetFont(font)
    local lines = {}

    for paragraph in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
        local line = ""
        for word in paragraph:gmatch("%S+") do
            local candidate = line == "" and word or (line .. " " .. word)
            if line ~= "" and surface.GetTextSize(candidate) > maxWidth then
                lines[#lines + 1] = line
                line = word
            else
                line = candidate
            end
        end
        lines[#lines + 1] = line
    end

    if #lines == 0 then
        lines[1] = ""
    end
    return table.concat(lines, "\n"), #lines
end

function TS.Runtime.Notify(text, kind, duration)
    local font = TS.Runtime.Themes.default.fonts.small
    local maxTextWidth = math.Clamp(ScrW() * 0.28, 240, 420)
    local wrapped, lineCount = wrapNoticeText(text, font, maxTextWidth)
    surface.SetFont(font)
    local measuredWidth, lineHeight = surface.GetTextSize(wrapped)
    local panelWidth = math.Clamp(measuredWidth + 68, 220, maxTextWidth + 68)
    local panelHeight = math.max(46, lineCount * lineHeight + 22)

    local notices = TS.Runtime.ActiveNotices
    for i = #notices, 1, -1 do
        if not IsValid(notices[i]) then
            table.remove(notices, i)
        end
    end
    while #notices >= 5 do
        local oldest = table.remove(notices, 1)
        if IsValid(oldest) then oldest:Remove() end
    end

    local panel = vgui.Create("DPanel")
    panel:SetSize(panelWidth, panelHeight)
    panel:SetPos(ScrW() + panelWidth, math.floor(ScrH() * 0.78) - panelHeight)
    panel:SetMouseInputEnabled(false)
    panel:SetKeyboardInputEnabled(false)
    panel:SetDrawOnTop(true)
    panel._talksmithCreated = RealTime()
    panel._talksmithExpires = panel._talksmithCreated + math.max(tonumber(duration) or 3, 0.5)
    panel._talksmithKind = tonumber(kind) or 0

    local label = panel:Add("DLabel")
    label:Dock(FILL)
    label:DockMargin(54, 8, 12, 8)
    label:SetFont(font)
    label:SetTextColor(TS.Runtime.Themes.default.text)
    label:SetContentAlignment(4)
    label:SetWrap(true)
    label:SetText(wrapped)

    panel.Paint = function(s, w, h)
        local theme = TS.Runtime.Themes.default
        local accent = s._talksmithKind == 1 and theme.danger or theme.accent
        draw.RoundedBox(4, 0, 0, w, h, Color(theme.panel.r, theme.panel.g, theme.panel.b, 244))
        draw.RoundedBox(2, 0, 0, 4, h, accent)
        surface.SetDrawColor(theme.panelBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.RoundedBox(12, 17, h * 0.5 - 12, 24, 24, Color(accent.r, accent.g, accent.b, 34))
        draw.SimpleText(
            s._talksmithKind == 1 and "!" or (s._talksmithKind == 3 and "i" or "✓"),
            theme.fonts.key,
            29,
            h * 0.5,
            accent,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
    end

    panel.Think = function(s)
        local now = RealTime()
        if now >= s._talksmithExpires then
            s:Remove()
            return
        end

        local below = 0
        for i = #notices, 1, -1 do
            local notice = notices[i]
            if notice == s then break end
            if IsValid(notice) then
                below = below + notice:GetTall() + 8
            end
        end

        local remaining = s._talksmithExpires - now
        local targetX = remaining < 0.28 and (ScrW() + 20) or (ScrW() - s:GetWide() - 24)
        local targetY = math.floor(ScrH() * 0.78) - s:GetTall() - below
        local x, y = s:GetPos()
        local speed = math.min(FrameTime() * 16, 1)
        s:SetPos(Lerp(speed, x, targetX), Lerp(speed, y, targetY))
        s:SetAlpha(math.Clamp(remaining / 0.22, 0, 1) * 255)
        s:MoveToFront()
    end

    notices[#notices + 1] = panel
    return panel
end

function TS.Runtime.RoundBox(r, x, y, w, h, c)
    draw.RoundedBox(r, x, y, w, h, c)
end
