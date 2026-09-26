local TS = Talksmith

net.Receive("ts_dialogue_node", function()
    local d = {
        token = net.ReadString(),
        name = net.ReadString(),
        subtitle = net.ReadString(),
        text = net.ReadString(),
        theme = net.ReadString(),
        dialogue = net.ReadString(),
        node = net.ReadString(),
        sound = net.ReadString(),
        actor = net.ReadEntity(),
        options = {},
    }
    local n = net.ReadUInt(3)
    for i = 1, n do
        d.options[i] = net.ReadString()
    end
    TS.Runtime.Show(d)
    hook.Run("Talksmith.ClientNodeShown", d)
end)
net.Receive("ts_dialogue_close", function()
    net.ReadString()
    TS.Runtime.Close(false)
end)
net.Receive("ts_notice", function()
    local code = net.ReadString()
    if code == "busy" then
        TS.Runtime.Notify(TS.L("actor_busy_notice"), NOTIFY_ERROR, 3)
        surface.PlaySound("buttons/button10.wav")
    end
end)
hook.Add("OnScreenSizeChanged", "Talksmith.Rescale", function()
    TS.Runtime.BuildFonts()
    if TS.Runtime.IsActive() then
        TS.Runtime.Close(true)
    end
end)

hook.Add("HUDPaint", "Talksmith.ActorLabel", function()
    local TS = Talksmith
    if (not TS.Config.show_name and not TS.Config.show_description and not TS.Config.show_interaction)
        or (TS.Runtime.IsActive and TS.Runtime.IsActive())
    then
        return
    end
    local player = LocalPlayer()
    if not IsValid(player) then
        return
    end
    local actor = player:GetEyeTrace().Entity
    if not TS.Speakers.IsSpeaker(actor) then
        return
    end
    local dist = player:GetPos():DistToSqr(actor:GetPos())
    if dist > 65536 then
        return
    end
    local alpha = math.Clamp(255 * (1 - dist / 65536) + 80, 0, 255)
    local pos = (actor:GetPos() + Vector(0, 0, TS.Speakers.GetNameOffset(actor))):ToScreen()
    local T = TS.Runtime.GetTheme(TS.Speakers.GetTheme(actor))
    local outline = Color(0, 0, 0, alpha * 0.8)
    if TS.Config.show_name then
        draw.SimpleTextOutlined(
            TS.Speakers.GetName(actor),
            T.fonts.label,
            pos.x,
            pos.y - 20,
            Color(T.text.r, T.text.g, T.text.b, alpha),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_BOTTOM,
            1,
            outline
        )
    end
    local subtitle = TS.Speakers.GetSubtitle(actor)
    if TS.Config.show_description and subtitle ~= "" then
        draw.SimpleTextOutlined(
            subtitle,
            T.fonts.small,
            pos.x,
            pos.y,
            Color(T.muted.r, T.muted.g, T.muted.b, alpha),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_BOTTOM,
            1,
            outline
        )
    end
    if TS.Config.show_interaction then
        local busy = TS.Speakers.GetBusy(actor)
        draw.SimpleTextOutlined(
            busy and TS.L("actor_busy_label") or ("[E] " .. TS.L("talk_hint")),
            T.fonts.small,
            pos.x,
            pos.y + 18,
            Color(busy and T.danger.r or T.accent.r, busy and T.danger.g or T.accent.g, busy and T.danger.b or T.accent.b, alpha),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_BOTTOM,
            1,
            outline
        )
    end
end)
