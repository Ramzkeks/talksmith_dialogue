local TS = Talksmith

util.AddNetworkString("ts_option_select")
util.AddNetworkString("ts_dialogue_leave")
util.AddNetworkString("ts_dialogue_node")
util.AddNetworkString("ts_dialogue_close")
util.AddNetworkString("ts_notice")

net.Receive("ts_option_select", function(len, player)
    if len > 600 or not TS.Network.Allow(player, "choice_ingress", 0.05) then
        return
    end
    local token = net.ReadString()
    if #token ~= 64 or not token:match("^[0-9a-f]+$") then
        return
    end
    TS.Runtime.SelectOption(player, token, net.ReadUInt(3))
end)

net.Receive("ts_dialogue_leave", function(len, player)
    if len > 8 or not TS.Network.Allow(player, "leave", 0.1) then
        return
    end
    TS.Runtime.Stop(player, "left")
end)
