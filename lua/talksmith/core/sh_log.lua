local TS = Talksmith

function TS.Logging.Log(level, message, context)
    level = math.Clamp(math.floor(tonumber(level) or 0), 0, 1)
    if level > (tonumber(TS.Config.logging) or -1) then
        return
    end

    if SERVER then
        if isfunction(TS.Logging.WriteUltimateLog) then
            TS.Logging.WriteUltimateLog(level, message, context)
        end
        return
    end

    local color = level == 0 and Color(230, 90, 80) or Color(213, 151, 54)

    MsgC(color, "[Talksmith] ", color_white, tostring(message) .. "\n")
end
