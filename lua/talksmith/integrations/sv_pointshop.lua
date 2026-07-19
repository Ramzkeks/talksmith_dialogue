local TS = Talksmith
local ID = "pointshop"

TS.Integrations.Register(ID, {
    name = "PointShop 1",
    category = "economy",
    priority = 80,
    capabilities = { "currency", "inventory", "equipment", "shop" },
    detect = function()
        local playerMeta = FindMetaTable("Player")
        return istable(PS)
            and isfunction(playerMeta.PS_GetPoints)
            and isfunction(playerMeta.PS_GivePoints)
            and isfunction(playerMeta.PS_TakePoints)
            and isfunction(playerMeta.PS_HasItem)
            and isfunction(playerMeta.PS_HasItemEquipped)
            and isfunction(playerMeta.PS_GiveItem)
            and isfunction(playerMeta.PS_TakeItem)
            and isfunction(playerMeta.PS_ToggleMenu), "PointShop 1 API"
    end,
})

local amount = { type = "number", required = true, integer = true, min = 1, max = 1000000 }
local item = { type = "string", required = true, max = 128 }

TS.Integrations.RegisterCondition(ID, "points_at_least", {
    name = "PointShop 1: points at least",
    params = { amount = amount },
    run = function(context, params)
        return context.player:PS_GetPoints() >= params.amount
    end,
})

TS.Integrations.RegisterCondition(ID, "has_item", {
    name = "PointShop 1: owns item",
    params = { item = item },
    run = function(context, params)
        return not not context.player:PS_HasItem(params.item)
    end,
})

TS.Integrations.RegisterCondition(ID, "item_equipped", {
    name = "PointShop 1: item equipped",
    params = { item = item },
    run = function(context, params)
        return context.player:PS_HasItemEquipped(params.item) == true
    end,
})

TS.Integrations.RegisterAction(ID, "add_points", {
    name = "PointShop 1: add points",
    permission = "talksmith.actions.economy",
    params = { amount = amount },
    run = function(context, params)
        context.player:PS_GivePoints(params.amount)
        return true
    end,
})

TS.Integrations.RegisterAction(ID, "take_points", {
    name = "PointShop 1: take points",
    dangerous = true,
    permission = "talksmith.actions.economy",
    params = { amount = amount },
    run = function(context, params)
        context.player:PS_TakePoints(params.amount)
        return true
    end,
})

TS.Integrations.RegisterAction(ID, "give_item", {
    name = "PointShop 1: give item",
    permission = "talksmith.actions.inventory",
    params = { item = item },
    preflight = function(context, params)
        return PS.Items and PS.Items[params.item] ~= nil and not context.player:PS_HasItem(params.item)
    end,
    run = function(context, params)
        if context.player:PS_HasItem(params.item) then
            return false
        end

        return context.player:PS_GiveItem(params.item) ~= false
    end,
})

TS.Integrations.RegisterAction(ID, "take_item", {
    name = "PointShop 1: take item",
    dangerous = true,
    permission = "talksmith.actions.inventory",
    params = { item = item },
    run = function(context, params)
        return context.player:PS_TakeItem(params.item) ~= false
    end,
})

TS.Integrations.RegisterAction(ID, "open_shop", {
    name = "PointShop 1: open shop",
    safe = true,
    params = {},
    run = function(context)
        context.player:PS_ToggleMenu(true)
        return true
    end,
})

TS.Providers.Register("inventory", ID, {
    integration = ID,
    priority = 80,
    get_item_count = function(_, player, name)
        return player:PS_HasItem(name) and 1 or 0
    end,
    can_receive = function(_, player, name, count)
        return count == 1 and PS.Items and PS.Items[name] ~= nil and not player:PS_HasItem(name)
    end,
    give_item = function(_, player, name, count)
        if count ~= 1 or player:PS_HasItem(name) then
            return false
        end

        return player:PS_GiveItem(name) ~= false
    end,
    take_item = function(_, player, name, count)
        if count > 1 or not player:PS_HasItem(name) then
            return false
        end
        return player:PS_TakeItem(name) ~= false
    end,
    open = function(_, player)
        player:PS_ToggleMenu(true)
        return true
    end,
})

TS.Providers.Register("currency", ID, {
    integration = ID,
    priority = 80,
    get_balance = function(_, player)
        return player:PS_GetPoints()
    end,
    add = function(_, player, _, value)
        player:PS_GivePoints(value)
        return true
    end,
    take = function(_, player, _, value)
        player:PS_TakePoints(value)
        return true
    end,
})

TS.Integrations.RegisterVariable("pointshop.points", {
    integration = ID,
    resolve = function(context)
        return context.player:PS_GetPoints()
    end,
})
