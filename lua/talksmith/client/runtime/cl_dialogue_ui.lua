local TS = Talksmith
local frame

TS.Runtime.States = TS.Runtime.States or {
    START = "DIALOGUE_START",
    ACTOR_CAMERA = "ACTOR_CAMERA",
    ACTOR_TYPING = "ACTOR_TYPING",
    ACTOR_POST_DELAY = "ACTOR_POST_DELAY",
    PLAYER_CAMERA = "PLAYER_CAMERA",
    PLAYER_CHOICES = "PLAYER_CHOICES",
    ANSWER_SELECTED = "ANSWER_SELECTED",
    NEXT_NODE = "NEXT_NODE",
    ENDING = "DIALOGUE_END",
}

local STATE = TS.Runtime.States

local function setDialogueState(f, state)
    if not IsValid(f) or f.dialogueState == state then
        return
    end
    local previous = f.dialogueState
    f.dialogueState = state
    hook.Run("Talksmith.ClientStateChanged", previous, state, f.data)
end

local function choicesActive(f)
    return IsValid(f) and f.dialogueState == STATE.PLAYER_CHOICES
end

local function stopDialogueAudio(f)
    if not f then
        return
    end
    f.audioRequestToken = (f.audioRequestToken or 0) + 1
    if IsValid(f.audioChannel) then
        f.audioChannel:Stop()
    end
    f.audioChannel = nil
    f.audioURL = nil
end

local function playDialogueAudio(f, data)
    stopDialogueAudio(f)
    local url = data and data.sound or ""
    if not TS.Utils.IsRemoteAudioAllowed(url) then
        return
    end

    local requestToken = f.audioRequestToken
    f.audioURL = url
    sound.PlayURL(url, "noplay", function(channel, errorID, errorName)
        if not IsValid(channel) then
            if IsValid(f) and f.audioRequestToken == requestToken then
                TS.Logging.Log(0, "Remote audio failed (" .. tostring(errorID) .. "): " .. tostring(errorName))
                hook.Run("Talksmith.ClientAudioError", url, errorID, errorName, data)
            end
            return
        end
        if not IsValid(f) or f.audioRequestToken ~= requestToken or f.audioURL ~= url then
            channel:Stop()
            return
        end
        f.audioChannel = channel
        channel:Play()
        hook.Run("Talksmith.ClientAudioStarted", url, data)
    end)
end

function TS.Runtime.IsActive()
    return IsValid(frame)
end

local function leave()
    if IsValid(frame) then
        local f = frame
        stopDialogueAudio(f)
        setDialogueState(f, STATE.ENDING)
        f:SetMouseInputEnabled(false)
        f:SetKeyboardInputEnabled(false)
        f:AlphaTo(0, 0.15, 0, function()
            if IsValid(f) then
                f:Remove()
            end
        end)
    end
    frame = nil
end

function TS.Runtime.Close(send)
    if send and IsValid(frame) and not frame.preview then
        net.Start("ts_dialogue_leave")
        net.SendToServer()
    end
    leave()
end

local function choose(f, data, i)
    if not choicesActive(f) or CurTime() < (f.lockUntil or 0) then
        return
    end
    f.lockUntil = math.huge
    f.answerTimeoutAt = RealTime() + 2.5
    stopDialogueAudio(f)
    setDialogueState(f, STATE.ANSWER_SELECTED)
    f.scrollOffset = math.min(f.scrollOffset or 0, f.layout and f.layout.actorMaxScroll or 0)
    for _, button in ipairs(f.optionButtons or {}) do
        if IsValid(button) then
            button:SetMouseInputEnabled(false)
            button:AlphaTo(0, 0.1, 0, function()
                if IsValid(button) then
                    button:SetVisible(false)
                end
            end)
        end
    end
    if not f.preview then
        TS.Runtime.SetCameraSpeaker("actor")
    end
    hook.Run("Talksmith.ClientOptionSelected", i, data)
    if data.previewChoose then
        data.previewChoose(i)
    else
        net.Start("ts_option_select")
        net.WriteString(data.token)
        net.WriteUInt(i, 3)
        net.SendToServer()
    end
end

local function forceUTF8(value)
    local text = isstring(value) and value or tostring(value or "")
    if utf8 and utf8.force then
        return utf8.force(text)
    end
    return text
end

local function utf8Slice(text, first, last)
    if utf8 and utf8.sub then
        return utf8.sub(text, first, last)
    end
    return string.sub(text, first, last)
end

local function utf8Characters(text)
    local characters = {}
    local count = utf8 and utf8.len and utf8.len(text)
    if count and utf8 and utf8.sub then
        for index = 1, count do
            characters[index] = utf8.sub(text, index, index)
        end
        return characters
    end
    for index = 1, #text do
        characters[index] = string.sub(text, index, index)
    end
    return characters
end

local function splitWideToken(token, maxw)
    local count = utf8 and utf8.len and utf8.len(token) or #token
    if not count or count < 1 then
        return { token }
    end
    local chunks = {}
    local first = 1
    while first <= count do
        local low, high, best = first, count, first
        while low <= high do
            local middle = math.floor((low + high) / 2)
            if surface.GetTextSize(utf8Slice(token, first, middle)) <= maxw then
                best = middle
                low = middle + 1
            else
                high = middle - 1
            end
        end
        chunks[#chunks + 1] = utf8Slice(token, first, best)
        first = best + 1
    end
    return chunks
end

local function appendWrappedWord(lines, current, word, maxw)
    if surface.GetTextSize(word) <= maxw then
        local candidate = current == "" and word or (current .. " " .. word)
        if current ~= "" and surface.GetTextSize(candidate) > maxw then
            lines[#lines + 1] = current
            return word
        end
        return candidate
    end
    if current ~= "" then
        lines[#lines + 1] = current
    end
    local chunks = splitWideToken(word, maxw)
    for index = 1, #chunks - 1 do
        lines[#lines + 1] = chunks[index]
    end
    return chunks[#chunks] or ""
end

local function wrapLines(text, font, maxw)
    surface.SetFont(font)
    local lines = {}
    for _, para in ipairs(string.Explode("\n", forceUTF8(text))) do
        if para == "" then
            lines[#lines + 1] = ""
        else
            local cur = ""
            for _, word in ipairs(string.Explode(" ", para)) do
                cur = appendWrappedWord(lines, cur, word, maxw)
            end
            lines[#lines + 1] = cur
        end
    end
    return lines
end

local function buildRevealPlan(lines)
    local plan = {}
    local length = math.max(#lines - 1, 0)
    for index, line in ipairs(lines) do
        local characters = utf8Characters(line)
        plan[index] = { text = line, characters = characters }
        length = length + #characters
    end
    return plan, length
end

local function refreshRevealLines(f)
    local plan = f.revealPlan or {}
    local remaining = math.max(tonumber(f.revealPos) or 0, 0)
    local lines = {}
    for index, entry in ipairs(plan) do
        local count = math.min(remaining, #entry.characters)
        lines[#lines + 1] = count >= #entry.characters
            and entry.text
            or table.concat(entry.characters, "", 1, count)
        remaining = remaining - count
        if count < #entry.characters then
            break
        end
        if index < #plan then
            if remaining <= 0 then
                break
            end
            remaining = remaining - 1
        end
    end
    if #lines == 0 then
        lines[1] = ""
    end
    f.revealLines = lines
end

local function updateScrollChildren(f)
    local layout = f.layout
    if not layout then
        return
    end
    local offset = f.scrollOffset or 0
    local viewportBottom = math.min(layout.viewportBottom, layout.boxY + (f.displayBoxH or layout.boxH))
    for _, button in ipairs(f.optionButtons or {}) do
        if IsValid(button) then
            local screenY = button.baseY - offset
            local y = screenY - layout.viewportTop
            button:SetPos(layout.leftX, y)
            local visible = choicesActive(f)
                and screenY + button:GetTall() > layout.viewportTop
                and screenY < viewportBottom
            button:SetVisible(visible)
            button:SetMouseInputEnabled(visible)
        end
    end
    if IsValid(f.exitButton) then
        local screenY = f.exitButton.baseY - offset
        local y = screenY - layout.viewportTop
        f.exitButton:SetPos(layout.leftX, y)
        local visible = choicesActive(f)
            and screenY + f.exitButton:GetTall() > layout.viewportTop
            and screenY < viewportBottom
        f.exitButton:SetVisible(visible)
        f.exitButton:SetMouseInputEnabled(visible)
    end
end

local function buildContent(f, data)
    f:Clear()
    local T = TS.Runtime.GetTheme(data.theme)
    local F = T.fonts
    local geometry = T.layout or TS.Runtime.DialogueLayout or TS.Runtime.Themes.default
    f.theme = T
    f.lockUntil = 0
    f.revealSource = forceUTF8(data.text)
    f.revealLength = 0
    f.revealPos = 0
    f.revealNext = RealTime() + 0.2
    f.revealDone = false
    f.postDelayUntil = nil
    f.choicesAt = nil
    f.answerTimeoutAt = nil
    f.optionButtons = {}
    f.exitButton = nil
    f.cameraSpeaker = "actor"
    f.scrollOffset = 0
    setDialogueState(f, STATE.ACTOR_CAMERA)
    setDialogueState(f, STATE.ACTOR_TYPING)

    local sw, sh = ScrW(), ScrH()
    local scale = math.Clamp(sh / 1080, 0.8, 1.5)
    local leftX = math.Clamp(sw * geometry.leftRatio, geometry.leftMin or 72, geometry.leftMax or 360)
    local availableWidth = math.max(sw - leftX - math.Round(24 * scale), 240)
    local minWidth = math.min(geometry.minWidth or 360, availableWidth)
    local maxWidth = math.max(minWidth, math.min(geometry.maxWidth or 700, availableWidth))
    local optW = math.Clamp(sw * geometry.widthRatio, minWidth, maxWidth)

    local optH = math.Round(geometry.optionHeight * scale)
    local optGap = math.Round(geometry.optionGap * scale)
    local gapNameSub = math.Round(3 * scale)
    local gapHeadText = math.Round(30 * scale)
    local gapTextOpts = math.Round((geometry.textOptionGap or 24) * scale)

    surface.SetFont(F.name)
    local _, nameH = surface.GetTextSize("Ay")
    surface.SetFont(F.sub)
    local _, subH = surface.GetTextSize("Ay")
    surface.SetFont(F.body)
    local _, lineH = surface.GetTextSize("Ay")
    surface.SetFont(F.option)
    local _, optionLineH = surface.GetTextSize("Ay")

    local hasSub = (data.subtitle or "") ~= ""
    local lines = wrapLines(f.revealSource, F.body, optW)
    f.revealPlan, f.revealLength = buildRevealPlan(lines)
    local textH = #lines * lineH

    local opts = data.options or {}
    local n = #opts
    local optionLayouts = {}
    local optionsH = 0
    local optionTextWidth = optW - math.Round(76 * scale)
    for i = 1, n do
        local optionLines = wrapLines(opts[i], F.option, optionTextWidth)
        local height = math.max(optH, #optionLines * optionLineH + math.Round(16 * scale))
        optionLayouts[i] = { lines = optionLines, height = height }
        optionsH = optionsH + height + (i > 1 and optGap or 0)
    end

    local headH = nameH + (hasSub and (gapNameSub + subH) or 0)
    local exitH = math.Round(24 * scale)

    local padX = math.Round(geometry.panelPadX * scale)
    local padY = math.Round(geometry.panelPadY * scale)
    local safeTop = math.Round(sh * 0.04)
    local safeBottom = math.Round(sh * 0.96)
    local startY = math.Clamp(sh * geometry.anchorY, safeTop + padY, safeBottom - padY)

    local nameY = startY
    local subY = nameY + nameH + gapNameSub
    local textY = startY + headH + gapHeadText
    local optsY = textY + textH + gapTextOpts
    local boxY = startY - padY
    local headerH = textY - boxY
    local contentH = textH + gapTextOpts + optionsH + math.Round(14 * scale) + exitH + padY
    local fullBoxH = headerH + contentH
    local boxH = math.min(fullBoxH, math.max(safeBottom - boxY, headerH + 1))
    local viewportTop = textY
    local viewportBottom = boxY + boxH
    local viewportH = math.max(viewportBottom - viewportTop, 1)
    local maxScroll = math.max(contentH - viewportH, 0)
    local actorMaxScroll = math.max(textH + padY - viewportH, 0)

    f.layout = {
        name = data.name or "",
        sub = data.subtitle or "",
        hasSub = hasSub,
        lines = lines,
        leftX = leftX,
        nameY = nameY,
        subY = subY,
        textY = textY,
        lineH = lineH,
        ruleY = startY + headH + math.Round(10 * scale),
        ruleW = math.Round(T.ruleWidth * scale),
        boxX = leftX - padX,
        boxY = boxY,
        boxW = optW + padX * 2,
        boxH = boxH,
        actorBoxH = math.min(headerH + textH + padY, boxH),
        headerH = headerH,
        viewportTop = viewportTop,
        viewportBottom = viewportBottom,
        maxScroll = maxScroll,
        actorMaxScroll = actorMaxScroll,
        optionsY = optsY,
        optionsH = optionsH,
        optionsPanelY = optsY - math.Round(8 * scale),
        fonts = F,
    }
    refreshRevealLines(f)
    f.displayBoxH = f.layout.actorBoxH

    f.scrollViewport = vgui.Create("DPanel", f)
    f.scrollViewport:SetPos(0, f.layout.viewportTop)
    f.scrollViewport:SetSize(sw, f.layout.viewportBottom - f.layout.viewportTop)
    f.scrollViewport:SetMouseInputEnabled(true)
    f.scrollViewport.Paint = function() end

    local optionY = optsY
    for i = 1, n do
        local optionLayout = optionLayouts[i]
        local b = vgui.Create("DButton", f.scrollViewport)
        b.baseY = optionY
        b:SetPos(leftX, optionY)
        b:SetSize(optW, optionLayout.height)
        b:SetText("")
        b:SetAlpha(0)
        b:SetVisible(false)
        b:SetMouseInputEnabled(false)
        b.hover = 0
        b.Paint = function(s, w, h)
            s.hover = Lerp(FrameTime() * 12, s.hover, s:IsHovered() and 1 or 0)
            local hv = s.hover
            local fill = Color(
                Lerp(hv, T.option.r, T.optionHover.r),
                Lerp(hv, T.option.g, T.optionHover.g),
                Lerp(hv, T.option.b, T.optionHover.b),
                Lerp(hv, T.option.a, T.optionHover.a)
            )
            draw.RoundedBox(T.radius, 0, 0, w, h, fill)
            local border = Color(
                Lerp(hv, T.optionBorder.r, T.optionBorderHover.r),
                Lerp(hv, T.optionBorder.g, T.optionBorderHover.g),
                Lerp(hv, T.optionBorder.b, T.optionBorderHover.b),
                Lerp(hv, T.optionBorder.a, T.optionBorderHover.a)
            )
            surface.SetDrawColor(border)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            if T.optionStyle == "minimal" then
                surface.SetDrawColor(T.accent.r, T.accent.g, T.accent.b, 35 + 115 * hv)
                surface.DrawLine(math.Round(w * 0.55), h - 1, w, h - 1)
            elseif T.optionStyle == "bar" and hv > 0.01 then
                surface.SetDrawColor(T.accent.r, T.accent.g, T.accent.b, 255 * hv)
                surface.DrawRect(0, 0, math.Round(3 * scale), h)
            elseif T.optionStyle == "terminal" then
                surface.SetDrawColor(T.accent.r, T.accent.g, T.accent.b, 130 + 125 * hv)
                surface.DrawRect(0, 0, math.Round(4 * scale), h)
                surface.DrawRect(math.Round(10 * scale), h - 2, math.Round(22 * scale), 1)
            end

            local showOptionKeys = T.showOptionKeys ~= false
            local numX = math.Round(18 * scale)
            local leftInset = showOptionKeys and math.Round(52 * scale) or math.Round(16 * scale)
            local labelX = T.optionAlign == TEXT_ALIGN_LEFT and leftInset
                or (T.optionAlign == TEXT_ALIGN_RIGHT and w - math.Round(14 * scale) or w / 2)
            if showOptionKeys then
                if TS.Config.number_hotkeys and i <= 6 then
                    draw.SimpleText(i, F.key, numX, h / 2, T.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                else
                    draw.SimpleText("•", F.key, numX, h / 2, T.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end
            end
            local tc = hv > 0.5 and (T.optionTextHover or (T.optionStyle == "terminal" and T.panel or T.text)) or T.optionText
            local textH = #optionLayout.lines * optionLineH
            local firstY = (h - textH) / 2
            for lineIndex, line in ipairs(optionLayout.lines) do
                draw.SimpleText(
                    line,
                    F.option,
                    labelX,
                    firstY + (lineIndex - 1) * optionLineH,
                    tc,
                    T.optionAlign,
                    TEXT_ALIGN_TOP
                )
            end
        end
        b.DoClick = function()
            choose(f, data, i)
        end
        f.optionButtons[#f.optionButtons + 1] = b
        optionY = optionY + optionLayout.height + optGap
    end

    local exit = vgui.Create("DButton", f.scrollViewport)
    exit.baseY = optsY + optionsH + math.Round(14 * scale)
    exit:SetPos(leftX, exit.baseY)
    exit:SetSize(optW, exitH)
    exit:SetText("")
    exit.hover = 0
    exit.Paint = function(s, w, h)
        s.hover = Lerp(FrameTime() * 10, s.hover, s:IsHovered() and 1 or 0)
        local c = Color(Lerp(s.hover, 150, T.danger.r), Lerp(s.hover, 152, T.danger.g), Lerp(s.hover, 158, T.danger.b))
        local align = T.exitAlign or TEXT_ALIGN_LEFT
        local x = align == TEXT_ALIGN_RIGHT and w or 0
        draw.SimpleTextOutlined(
            "[Esc]  " .. TS.L("exit"),
            F.small,
            x,
            h / 2,
            c,
            align,
            TEXT_ALIGN_CENTER,
            1,
            T.shadow
        )
    end
    exit.DoClick = function()
        TS.Runtime.Close(true)
    end
    f.exitButton = exit
    f.OnMouseWheeled = function(_, delta)
        local layout = f.layout
        local maxScroll = layout and (choicesActive(f) and layout.maxScroll or layout.actorMaxScroll) or 0
        if maxScroll <= 0 then
            return false
        end
        f.scrollOffset = math.Clamp((f.scrollOffset or 0) - delta * math.Round(64 * scale), 0, maxScroll)
        updateScrollChildren(f)
        return true
    end
    f.scrollViewport.OnMouseWheeled = function(_, delta)
        return f:OnMouseWheeled(delta)
    end
    for _, button in ipairs(f.optionButtons) do
        button.OnMouseWheeled = function(_, delta)
            return f:OnMouseWheeled(delta)
        end
    end
    exit.OnMouseWheeled = function(_, delta)
        return f:OnMouseWheeled(delta)
    end
    updateScrollChildren(f)
end

local function finishReveal(f)
    if not IsValid(f) or f.revealDone then
        return
    end
    f.revealDone = true
    f.revealPos = f.revealLength or 0
    refreshRevealLines(f)
    f.postDelayUntil = RealTime() + (TS.Config.dialogue_post_delay or 0.2)
    setDialogueState(f, STATE.ACTOR_POST_DELAY)
end

local function showChoices(f)
    if not IsValid(f) then
        return
    end
    setDialogueState(f, STATE.PLAYER_CHOICES)
    for index, button in ipairs(f.optionButtons or {}) do
        if IsValid(button) then
            button:SetVisible(true)
            button:SetMouseInputEnabled(true)
            button:AlphaTo(255, 0.2, math.min((index - 1) * 0.035, 0.14))
        end
    end
    updateScrollChildren(f)
end

local function drawThemePanel(theme, x, y, w, h)
    if h <= 0 or theme.panel.a <= 0 then
        return
    end
    draw.RoundedBox(theme.radius, x, y, w, h, theme.panel)
    if theme.panelBorder.a > 0 then
        surface.SetDrawColor(theme.panelBorder)
        surface.DrawOutlinedRect(x, y, w, h, 1)
    end
end

function TS.Runtime.Show(data)
    local sw, sh = ScrW(), ScrH()

    if not IsValid(frame) then
        frame = vgui.Create("EditablePanel")
        frame:SetSize(sw, sh)
        frame:SetPos(0, 0)
        frame:SetAlpha(0)
        frame:MakePopup()
        frame:SetKeyboardInputEnabled(true)
        frame:AlphaTo(255, 0.2)
        frame.keyState = {}
        frame.cameraInitialized = false
        frame.Paint = function(s, pw, ph)
            local L = s.layout
            if not L then
                return
            end
            local T = s.theme or TS.Runtime.Themes.default
            local F = L.fonts or T.fonts
            surface.SetDrawColor(T.backdrop)
            surface.DrawRect(0, 0, pw, ph)

            if T.scanlines then
                surface.SetDrawColor(T.accent.r, T.accent.g, T.accent.b, 7)
                for y = 0, ph, 4 do
                    surface.DrawLine(0, y, pw, y)
                end
            end

            local offset = s.scrollOffset or 0
            local scrollMax = choicesActive(s) and L.maxScroll or L.actorMaxScroll
            local clipped = scrollMax > 0
            local choicesVisible = choicesActive(s)
            s.displayBoxH = Lerp(1 - math.exp(-FrameTime() * 12), s.displayBoxH or L.actorBoxH, choicesVisible and L.boxH or L.actorBoxH)
            if T.panelStyle == "split" then
                drawThemePanel(T, L.boxX, L.boxY, L.boxW, math.min(s.displayBoxH, L.actorBoxH))
                if choicesVisible then
                    drawThemePanel(T, L.boxX, L.optionsPanelY, L.boxW, L.boxY + s.displayBoxH - L.optionsPanelY)
                end
            elseif T.panelStyle ~= "none" then
                drawThemePanel(T, L.boxX, L.boxY, L.boxW, s.displayBoxH)
            end

            if T.decoration == "cinematic" then
                surface.SetDrawColor(T.accent.r, T.accent.g, T.accent.b, 180)
                surface.DrawRect(L.boxX, L.boxY, 3, math.min(s.displayBoxH, L.headerH))
            elseif T.decoration == "terminal" then
                surface.SetDrawColor(T.accent.r, T.accent.g, T.accent.b, 110)
                surface.DrawOutlinedRect(L.boxX + 6, L.boxY + 6, L.boxW - 12, math.max(1, s.displayBoxH - 12), 1)
                draw.SimpleText("// " .. string.lower(s.dialogueState or ""), F.small, L.boxX + L.boxW - 12, L.boxY + 10, T.muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            end

            draw.SimpleTextOutlined(
                L.name,
                F.name,
                L.leftX,
                L.nameY,
                T.nameText or T.text,
                TEXT_ALIGN_LEFT,
                TEXT_ALIGN_TOP,
                1,
                T.shadow
            )
            if L.hasSub then
                draw.SimpleTextOutlined(
                    L.sub,
                    F.sub,
                    L.leftX,
                    L.subY,
                    T.accent,
                    TEXT_ALIGN_LEFT,
                    TEXT_ALIGN_TOP,
                    1,
                    T.shadow
                )
            end
            if T.showRule ~= false then
                surface.SetDrawColor(T.accent)
                surface.DrawRect(L.leftX, L.ruleY, L.ruleW, math.max(2, math.Round(ph / 540)))
            end

            local contentBottom = math.min(L.viewportBottom, L.boxY + s.displayBoxH)
            if contentBottom > L.viewportTop then
                render.SetScissorRect(L.boxX, L.viewportTop, L.boxX + L.boxW, contentBottom, true)
                local visibleLines = s.revealLines or {}
                for idx, line in ipairs(visibleLines) do
                    draw.SimpleTextOutlined(
                        line,
                        F.body,
                        L.leftX,
                        L.textY + (idx - 1) * L.lineH - offset,
                        T.text,
                        TEXT_ALIGN_LEFT,
                        TEXT_ALIGN_TOP,
                        1,
                        T.shadow
                    )
                end
                render.SetScissorRect(0, 0, 0, 0, false)
            end
            if clipped then
                draw.SimpleTextOutlined(
                    "↕ " .. math.Round(offset / math.max(scrollMax, 1) * 100) .. "%",
                    F.small,
                    L.boxX + L.boxW,
                    L.viewportBottom + 4,
                    T.muted,
                    TEXT_ALIGN_RIGHT,
                    TEXT_ALIGN_TOP,
                    1,
                    T.shadow
                )
            end
        end
        frame.Think = function(s)
            if gui.IsGameUIVisible() then
                gui.HideGameUI()
                TS.Runtime.Close(not s.preview)
                return
            end
            if s.dialogueState == STATE.ACTOR_TYPING then
                if RealTime() >= (s.revealNext or 0) then
                    s.revealPos = math.min((s.revealPos or 0) + 1, s.revealLength or 0)
                    refreshRevealLines(s)
                    local baseInterval = s.theme.typeInterval or TS.Config.dialogue_type_interval or 0.05
                    local speed = math.Clamp(tonumber(TS.Config.dialogue_speed) or 1, 0.25, 4)
                    s.revealNext = RealTime() + baseInterval / speed
                    if s.revealPos >= (s.revealLength or 0) then
                        finishReveal(s)
                    end
                end
            elseif s.dialogueState == STATE.ACTOR_POST_DELAY and RealTime() >= (s.postDelayUntil or math.huge) then
                setDialogueState(s, STATE.PLAYER_CAMERA)
                if not s.preview then
                    TS.Runtime.SetCameraSpeaker("player")
                end
                s.choicesAt = RealTime() + (TS.Config.dialogue_camera_settle or 0.2)
            elseif s.dialogueState == STATE.PLAYER_CAMERA and RealTime() >= (s.choicesAt or math.huge) then
                showChoices(s)
            elseif s.dialogueState == STATE.ANSWER_SELECTED and RealTime() >= (s.answerTimeoutAt or math.huge) then
                s.lockUntil = 0
                setDialogueState(s, STATE.PLAYER_CAMERA)
                if not s.preview then
                    TS.Runtime.SetCameraSpeaker("player")
                end
                s.choicesAt = RealTime() + (TS.Config.dialogue_camera_settle or 0.2)
            end
            s.mouseWasDown = input.IsMouseDown(MOUSE_LEFT)
            if TS.Config.number_hotkeys and choicesActive(s) then
                for i = 1, math.min(6, #(s.data and s.data.options or {})) do
                    local down = input.IsKeyDown(KEY_1 + i - 1)
                    if down and not s.keyState[i] then
                        choose(s, s.data, i)
                    end
                    s.keyState[i] = down
                end
            end
            updateScrollChildren(s)
        end
        frame.OnRemove = function(s)
            stopDialogueAudio(s)
            if frame == s then
                frame = nil
            end
        end
    end

    frame.data = data
    frame.preview = tobool(data.previewChoose)
    frame.mouseWasDown = input.IsMouseDown(MOUSE_LEFT)
    if not frame.dialogueState then
        setDialogueState(frame, STATE.START)
    end

    if not frame.preview and not frame.cameraInitialized then
        TS.Runtime.Camera.Actor = TS.Speakers.IsSpeaker(data.actor) and data.actor or TS.Runtime.FindTalkTarget()
        TS.Runtime.Camera.ShotDirty = true
        TS.Runtime.Camera.ShotPosition = nil
        TS.Runtime.Camera.ShotAngle = nil
        frame.cameraInitialized = true
    elseif frame.preview then
        TS.Runtime.Camera.Actor = nil
    end

    if not frame.preview then
        TS.Runtime.SetCameraSpeaker("actor")
    end

    if frame.dialogueState == STATE.ANSWER_SELECTED then
        setDialogueState(frame, STATE.NEXT_NODE)
    end
    buildContent(frame, data)
    playDialogueAudio(frame, data)
end

function TS.Runtime.FindTalkTarget()
    local ply = LocalPlayer()
    if not IsValid(ply) then
        return
    end
    local tr = ply:GetEyeTrace()
    if TS.Speakers.IsSpeaker(tr.Entity) then
        return tr.Entity
    end
    local best, bestd
    for _, e in ipairs(TS.Actors.GetAll()) do
        local d = ply:GetPos():DistToSqr(e:GetPos())
        if not bestd or d < bestd then
            best, bestd = e, d
        end
    end
    if best and bestd and bestd < 250000 then
        return best
    end
end

local function getFacePos(entity)
    local attachmentID = entity:LookupAttachment("eyes")
    if attachmentID and attachmentID > 0 then
        local attachment = entity:GetAttachment(attachmentID)
        if attachment and attachment.Pos then
            return attachment.Pos
        end
    end

    local headBone = entity:LookupBone("ValveBiped.Bip01_Head1")
    if headBone then
        local bonePos = entity:GetBonePosition(headBone)
        if bonePos then
            return bonePos
        end
    end

    if entity.EyePos then
        return entity:EyePos()
    end
    local mins, maxs = entity:GetRenderBounds()
    return entity:GetPos() + Vector(0, 0, mins.z + (maxs.z - mins.z) * 0.91)
end

local function buildFaceShot(subject, other, shoulder)
    if not IsValid(subject) then
        return
    end
    local focus = getFacePos(subject)
    local toward = IsValid(other) and (getFacePos(other) - focus) or subject:GetForward()
    toward.z = 0
    if toward:LengthSqr() < 1 then
        toward = subject:GetForward()
        toward.z = 0
    end
    toward:Normalize()

    local right = toward:Cross(Vector(0, 0, 1))
    right:Normalize()
    local wanted = focus + toward * 48 + right * shoulder + Vector(0, 0, 1.5)
    local trace = util.TraceHull({
        start = focus,
        endpos = wanted,
        mins = Vector(-4, -4, -4),
        maxs = Vector(4, 4, 4),
        filter = { subject, other },
        mask = MASK_SOLID,
    })
    local position = trace.Hit and (trace.HitPos + trace.HitNormal * 5) or wanted
    return position, (focus - position):Angle()
end

function TS.Runtime.SetCameraSpeaker(speaker)
    speaker = speaker == "player" and "player" or "actor"
    if TS.Runtime.Camera.Speaker ~= speaker then
        TS.Runtime.Camera.Speaker = speaker
        TS.Runtime.Camera.ShotDirty = true
    end
end

if not TS.Runtime.Camera.Hooked then
    TS.Runtime.Camera.Hooked = true
    TS.Runtime.Camera.Blend = 0
    TS.Runtime.Camera.Speaker = "actor"

    hook.Add("CalcView", "Talksmith.CamFocus", function(ply, pos, ang, fov)
        local open = TS.Runtime.IsActive() and IsValid(TS.Runtime.Camera.Actor)
        local blendTarget = open and 1 or 0
        local blendSpeed = open and 5.2 or 7.5
        TS.Runtime.Camera.Blend = Lerp(1 - math.exp(-FrameTime() * blendSpeed), TS.Runtime.Camera.Blend or 0, blendTarget)
        local blend = TS.Runtime.Camera.Blend

        if blend < 0.003 then
            if not open then
                TS.Runtime.Camera.Actor = nil
                TS.Runtime.Camera.ShotPosition = nil
                TS.Runtime.Camera.ShotAngle = nil
                TS.Runtime.Camera.ShotDirty = true
            end
            return
        end

        local actor = TS.Runtime.Camera.Actor
        if not IsValid(actor) then
            return
        end

        local subject = TS.Runtime.Camera.Speaker == "player" and ply or actor
        local other = subject == ply and actor or ply
        if TS.Runtime.Camera.ShotDirty or not TS.Runtime.Camera.TargetPosition or not TS.Runtime.Camera.TargetAngle then
            local shoulder = subject == ply and -11 or 11
            TS.Runtime.Camera.TargetPosition, TS.Runtime.Camera.TargetAngle = buildFaceShot(subject, other, shoulder)
            TS.Runtime.Camera.ShotDirty = false
        end

        if not TS.Runtime.Camera.TargetPosition or not TS.Runtime.Camera.TargetAngle then
            return
        end

        if not TS.Runtime.Camera.ShotPosition or not TS.Runtime.Camera.ShotAngle then
            TS.Runtime.Camera.ShotPosition = pos
            TS.Runtime.Camera.ShotAngle = ang
        end

        local shotSpeed = TS.Runtime.Camera.Speaker == "player" and 4.3 or 5.6
        local step = 1 - math.exp(-FrameTime() * shotSpeed)
        TS.Runtime.Camera.ShotPosition = LerpVector(step, TS.Runtime.Camera.ShotPosition, TS.Runtime.Camera.TargetPosition)
        TS.Runtime.Camera.ShotAngle = LerpAngle(step, TS.Runtime.Camera.ShotAngle, TS.Runtime.Camera.TargetAngle)

        local e = blend * blend * (3 - 2 * blend)
        return {
            origin = LerpVector(e, pos, TS.Runtime.Camera.ShotPosition),
            angles = LerpAngle(e, ang, TS.Runtime.Camera.ShotAngle),
            fov = Lerp(e, fov, TS.Runtime.Camera.Speaker == "player" and 68 or 56),
            drawviewer = TS.Runtime.Camera.Speaker == "player",
        }
    end)

    hook.Add("PreDrawViewModel", "Talksmith.HideVM", function()
        if (TS.Runtime.Camera.Blend or 0) > 0.35 then
            return true
        end
    end)
end

local hiddenHUD = {
    CHudHealth = true,
    CHudBattery = true,
    CHudAmmo = true,
    CHudSecondaryAmmo = true,
    CHudCrosshair = true,
    CHudWeaponSelection = true,
    CHudDamageIndicator = true,
}

hook.Add("HUDShouldDraw", "Talksmith.CinematicHUD", function(name)
    if TS.Runtime.IsActive() and hiddenHUD[name] then
        return false
    end
end)
