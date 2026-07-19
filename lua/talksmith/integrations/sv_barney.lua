local TS = Talksmith
local ID = "barney"

TS.Integrations.Register(ID, {
    name = "Barney Inventory 2.0",
    category = "inventory",
    priority = 60,
    capabilities = { "inventory", "weight", "ammo" },
    detect = function()
        local playerMeta = FindMetaTable("Player")
        return istable(BI)
            and istable(BI_ItemWeight)
            and isfunction(playerMeta.BI_AddInventoryItem)
            and isfunction(playerMeta.BI_ValidateInventory)
            and isfunction(playerMeta.BI_SaveInventory)
            and isfunction(BI_OpenInventory)
            and isfunction(BI_GetPlayerWeight), "Barney Inventory API"
    end,
})

local item = { type = "string", required = true, max = 128 }
local amount = { type = "number", required = true, integer = true, min = 1, max = 64 }

local function prepare(player)
    player:BI_ValidateInventory()
    return player.BI.Inventory
end

local function count(player, class)
    local result = 0
    for _, value in ipairs(prepare(player)) do
        if value.Class == class then
            result = result + 1
        end
    end

    return result
end

local function allowed(class)
    local nativeAllowed = istable(BI_ItemWeight) and BI_ItemWeight[class] ~= nil
    if not TS.Utils.IsInventoryEntityAllowed(ID, class, nativeAllowed) then
        return false
    end
    if (BI.DisallowPickup or {})[class] then
        return false
    end

    for _, prefix in ipairs(BI.DisallowPickupForEntityGroup or {}) do
        if string.find(class, prefix, 1, true) then
            return false
        end
    end

    return true
end

local function freeWeight(player)
    player:BI_ValidateInventory()
    return math.max(0, (player.BI.Backpack.Capacity or 0) - BI_GetPlayerWeight(player))
end

local function give(player, class, countToGive)
    if not allowed(class) or freeWeight(player) < (BI_ItemWeight[class] or 0) * countToGive then
        return false
    end

    local inventory = prepare(player)
    local initialCount = #inventory
    local expectedCount = initialCount
    local function rollback()
        while #inventory > initialCount do
            table.remove(inventory)
        end
        player:BI_SaveInventory()
        return false
    end

    for _ = 1, countToGive do
        local entity = ents.Create(class)
        if not IsValid(entity) then
            return rollback()
        end

        entity:Spawn()
        local data = duplicator.CopyEntTable(entity)
        entity:Remove()
        if not data then
            return rollback()
        end

        player:BI_AddInventoryItem(data)
        if #inventory <= expectedCount then
            return rollback()
        end
        expectedCount = #inventory
    end

    if isfunction(BI_UpdatePlayerSpeed) then
        BI_UpdatePlayerSpeed(player)
    end

    return true
end

local function take(player, class, countToTake)
    local inventory = prepare(player)
    if count(player, class) < countToTake then
        return false
    end

    for index = #inventory, 1, -1 do
        if countToTake > 0 and inventory[index].Class == class then
            table.remove(inventory, index)
            countToTake = countToTake - 1
        end
    end

    player:BI_SaveInventory()
    if isfunction(BI_UpdatePlayerSpeed) then
        BI_UpdatePlayerSpeed(player)
    end

    return true
end

TS.Integrations.RegisterCondition(ID, "has_item", {
    name = "Barney Inventory: has item",
    params = { item = item, amount = amount },
    run = function(context, params)
        return count(context.player, params.item) >= params.amount
    end,
})

TS.Integrations.RegisterCondition(ID, "has_free_weight", {
    name = "Barney Inventory: has free weight",
    params = { amount = amount },
    run = function(context, params)
        return freeWeight(context.player) >= params.amount
    end,
})

TS.Integrations.RegisterCondition(ID, "item_allowed", {
    name = "Barney Inventory: item allowed",
    params = { item = item },
    run = function(_, params)
        return allowed(params.item)
    end,
})

TS.Integrations.RegisterCondition(ID, "has_ammo", {
    name = "Barney Inventory: has ammo",
    params = { ammo = item, amount = amount },
    run = function(context, params)
        return context.player:GetAmmoCount(params.ammo) >= params.amount
    end,
})

TS.Integrations.RegisterAction(ID, "give_item", {
    name = "Barney Inventory: give item",
    permission = "talksmith.actions.inventory",
    cost_param = "amount",
    params = { item = item, amount = amount },
    preflight = function(context, params)
        return allowed(params.item)
            and freeWeight(context.player) >= (BI_ItemWeight[params.item] or 0) * params.amount
    end,
    run = function(context, params)
        return give(context.player, params.item, params.amount)
    end,
})

TS.Integrations.RegisterAction(ID, "take_item", {
    name = "Barney Inventory: take item",
    dangerous = true,
    permission = "talksmith.actions.inventory",
    cost_param = "amount",
    params = { item = item, amount = amount },
    preflight = function(context, params)
        return count(context.player, params.item) >= params.amount
    end,
    run = function(context, params)
        return take(context.player, params.item, params.amount)
    end,
})

TS.Integrations.RegisterAction(ID, "give_ammo", {
    name = "Barney Inventory: give ammo",
    permission = "talksmith.actions.inventory",
    params = { ammo = item, amount = amount },
    run = function(context, params)
        context.player:GiveAmmo(params.amount, params.ammo, true)
        return true
    end,
})

TS.Integrations.RegisterAction(ID, "take_ammo", {
    name = "Barney Inventory: take ammo",
    dangerous = true,
    permission = "talksmith.actions.inventory",
    params = { ammo = item, amount = amount },
    run = function(context, params)
        context.player:RemoveAmmo(params.amount, params.ammo)
        return true
    end,
})

TS.Integrations.RegisterAction(ID, "open_inventory", {
    name = "Barney Inventory: open inventory",
    safe = true,
    params = {},
    run = function(context)
        BI_OpenInventory(context.player)
        return true
    end,
})

TS.Providers.Register("inventory", ID, {
    integration = ID,
    priority = 60,
    get_item_count = function(_, player, class)
        return count(player, class)
    end,
    can_receive = function(_, player, class, countToGive)
        return allowed(class) and freeWeight(player) >= (BI_ItemWeight[class] or 0) * countToGive
    end,
    give_item = function(_, player, class, countToGive)
        return give(player, class, countToGive)
    end,
    take_item = function(_, player, class, countToTake)
        return take(player, class, countToTake)
    end,
    open = function(_, player)
        BI_OpenInventory(player)
        return true
    end,
})

TS.Integrations.RegisterVariable("barney.item_count", {
    integration = ID,
    resolve = function(context, argument)
        return count(context.player, argument)
    end,
})

TS.Integrations.RegisterVariable("barney.free_weight", {
    integration = ID,
    resolve = function(context)
        return freeWeight(context.player)
    end,
})
