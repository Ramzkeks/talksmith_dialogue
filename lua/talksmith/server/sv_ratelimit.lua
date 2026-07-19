local TS = Talksmith

TS.Network.Rates = TS.Network.Rates or setmetatable({}, { __mode = "k" })

function TS.Network.Allow(player, key, delay)
    local limits = TS.Network.Rates[player] or {}
    TS.Network.Rates[player] = limits

    local now = CurTime()

    if (limits[key] or 0) > now then
        return false
    end

    limits[key] = now + delay

    return true
end
