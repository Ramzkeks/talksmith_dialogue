local TS = Talksmith
local ID = "darkrp_leveling"

TS.Integrations.Register(ID, {
    name = "DarkRP Leveling System",
    category = "progression",
    priority = 80,
    capabilities = { "level", "experience" },
    detect = function()
        local playerMeta = FindMetaTable("Player")
        return istable(LevelSystemConfiguration)
            and isfunction(playerMeta.getLevel)
            and isfunction(playerMeta.getXP)
            and isfunction(playerMeta.getMaxXP)
            and isfunction(playerMeta.addXP)
            and isfunction(playerMeta.addLevels)
            and isfunction(playerMeta.setXP)
            and isfunction(playerMeta.setLevel), "Leveling API"
    end,
})

local amount = { type = "number", required = true, integer = true, min = 0, max = 100000000 }

TS.Integrations.RegisterCondition(ID, "level_at_least", {
    name = "Leveling: level at least",
    params = { amount = amount },
    run = function(context, params)
        return (tonumber(context.player:getLevel()) or 0) >= params.amount
    end,
})

TS.Integrations.RegisterCondition(ID, "level_at_most", {
    name = "Leveling: level at most",
    params = { amount = amount },
    run = function(context, params)
        return (tonumber(context.player:getLevel()) or 0) <= params.amount
    end,
})

TS.Integrations.RegisterCondition(ID, "xp_at_least", {
    name = "Leveling: XP at least",
    params = { amount = amount },
    run = function(context, params)
        return (tonumber(context.player:getXP()) or 0) >= params.amount
    end,
})

TS.Integrations.RegisterCondition(ID, "can_level_up", {
    name = "Leveling: can level up",
    params = {},
    run = function(context)
        return (tonumber(context.player:getXP()) or 0)
            >= (tonumber(context.player:getMaxXP()) or math.huge)
    end,
})

TS.Integrations.RegisterAction(ID, "add_xp", {
    name = "Leveling: add XP",
    permission = "talksmith.actions.progression",
    params = { amount = amount, notify = { type = "boolean" } },
    run = function(context, params)
        return context.player:addXP(params.amount, not params.notify) ~= false
    end,
})

TS.Integrations.RegisterAction(ID, "take_xp", {
    name = "Leveling: take XP",
    dangerous = true,
    permission = "talksmith.actions.progression",
    params = { amount = amount },
    run = function(context, params)
        local value = math.max(0, (tonumber(context.player:getXP()) or 0) - params.amount)
        context.player:setXP(value)
        if DarkRP and DarkRP.storeXPData then
            DarkRP.storeXPData(context.player, tonumber(context.player:getLevel()) or 1, value)
        end
        return true
    end,
})

TS.Integrations.RegisterAction(ID, "add_levels", {
    name = "Leveling: add levels",
    permission = "talksmith.actions.progression",
    params = { amount = amount },
    run = function(context, params)
        return context.player:addLevels(math.floor(params.amount)) ~= false
    end,
})

TS.Integrations.RegisterAction(ID, "set_level", {
    name = "Leveling: set level",
    dangerous = true,
    permission = "talksmith.actions.progression",
    params = { amount = amount },
    run = function(context, params)
        local maximum = tonumber(LevelSystemConfiguration.MaxLevel) or 100000000
        local level = math.Clamp(math.floor(params.amount), 1, maximum)
        context.player:setLevel(level)
        if DarkRP and DarkRP.storeXPData then
            DarkRP.storeXPData(context.player, level, tonumber(context.player:getXP()) or 0)
        end
        return true
    end,
})

TS.Providers.Register("progression", ID, {
    integration = ID,
    priority = 80,
    get_level = function(_, player)
        return tonumber(player:getLevel()) or 0
    end,
    get_xp = function(_, player)
        return tonumber(player:getXP()) or 0
    end,
    add_xp = function(_, player, value)
        return player:addXP(value, true) ~= false
    end,
})

TS.Integrations.RegisterVariable("darkrp_leveling.level", {
    integration = ID,
    resolve = function(context)
        return tonumber(context.player:getLevel()) or 0
    end,
})

TS.Integrations.RegisterVariable("darkrp_leveling.xp", {
    integration = ID,
    resolve = function(context)
        return tonumber(context.player:getXP()) or 0
    end,
})

TS.Integrations.RegisterVariable("darkrp_leveling.max_xp", {
    integration = ID,
    resolve = function(context)
        return tonumber(context.player:getMaxXP()) or 0
    end,
})
