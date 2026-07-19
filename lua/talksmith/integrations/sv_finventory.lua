local TS = Talksmith
local ID = "finventory"

TS.Integrations.Register(ID, {
    name = "Finventory",
    category = "inventory",
    priority = 90,
    capabilities = { "inventory", "capacity", "illegal-items" },
    detect = function()
        local playerMeta = FindMetaTable("Player")
        return istable(finventoryConfig)
            and isfunction(playerMeta.retrieveInventory)
            and isfunction(playerMeta.showInventoryOf)
            and isfunction(createItem), "Finventory API"
    end,
})

local item = { type = "string", required = true, max = 128 }
local amount = { type = "number", required = true, integer = true, min = 1, max = 64 }

local function inventory(player)
    return IsValid(player) and player:retrieveInventory() or nil
end

local function count(player, class)
    local playerInventory = inventory(player)
    local result = 0

    for _, value in ipairs(playerInventory and playerInventory.content or {}) do
        if value:getClass() == class then
            result = result + 1
        end
    end

    return result
end

local function allowed(class)
    local nativeAllowed = istable(finventoryConfig.acceptedEntities)
        and finventoryConfig.acceptedEntities[class] == true
    if finventoryConfig.weaponsCanBeTaken and weapons.GetStored(class) ~= nil then
        nativeAllowed = true
    end
    return not (finventoryConfig.illegalEntities or {})[class]
        and TS.Utils.IsInventoryEntityAllowed(ID, class, nativeAllowed)
end

local function give(player, class, countToGive)
    local playerInventory = inventory(player)
    if not playerInventory
        or playerInventory:getRemainingPlace() < countToGive
        or not allowed(class)
    then
        return false
    end

    local initialCount = #playerInventory.content
    local function rollback()
        while #playerInventory.content > initialCount do
            playerInventory:remove(#playerInventory.content)
        end
        return false
    end

    for _ = 1, countToGive do
        local entity = ents.Create(class)
        if not IsValid(entity) then
            return rollback()
        end

        entity:Spawn()
        local wrapped = createItem(entity)
        local added = wrapped and playerInventory:add(wrapped)
        entity:Remove()
        if not added then
            return rollback()
        end
    end

    return true
end

local function take(player, class, countToTake)
    local playerInventory = inventory(player)
    if not playerInventory or count(player, class) < countToTake then
        return false
    end

    for index = #playerInventory.content, 1, -1 do
        if countToTake <= 0 then
            break
        end

        if playerInventory.content[index]:getClass() == class then
            playerInventory:remove(index)
            countToTake = countToTake - 1
        end
    end

    return true
end

TS.Integrations.RegisterCondition(ID, "has_item", {
    name = "Finventory: has item",
    params = { item = item, amount = amount },
    run = function(context, params)
        return count(context.player, params.item) >= params.amount
    end,
})

TS.Integrations.RegisterCondition(ID, "has_space", {
    name = "Finventory: has space",
    params = { amount = amount },
    run = function(context, params)
        local playerInventory = inventory(context.player)
        return playerInventory and playerInventory:getRemainingPlace() >= params.amount
    end,
})

TS.Integrations.RegisterCondition(ID, "item_allowed", {
    name = "Finventory: item allowed",
    params = { item = item },
    run = function(_, params)
        return allowed(params.item)
    end,
})

TS.Integrations.RegisterCondition(ID, "is_full", {
    name = "Finventory: is full",
    params = {},
    run = function(context)
        local playerInventory = inventory(context.player)
        return playerInventory and playerInventory:isFull()
    end,
})

TS.Integrations.RegisterAction(ID, "give_item", {
    name = "Finventory: give item",
    permission = "talksmith.actions.inventory",
    cost_param = "amount",
    params = { item = item, amount = amount },
    preflight = function(context, params)
        local playerInventory = inventory(context.player)
        return playerInventory
            and allowed(params.item)
            and playerInventory:getRemainingPlace() >= params.amount
    end,
    run = function(context, params)
        return give(context.player, params.item, params.amount)
    end,
})

TS.Integrations.RegisterAction(ID, "take_item", {
    name = "Finventory: take item",
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

TS.Integrations.RegisterAction(ID, "open_inventory", {
    name = "Finventory: open inventory",
    safe = true,
    params = {},
    run = function(context)
        context.player:showInventoryOf(context.player)
        return true
    end,
})

TS.Providers.Register("inventory", ID, {
    integration = ID,
    priority = 90,
    get_item_count = function(_, player, class)
        return count(player, class)
    end,
    can_receive = function(_, player, class, countToGive)
        local playerInventory = inventory(player)
        return playerInventory
            and allowed(class)
            and playerInventory:getRemainingPlace() >= countToGive
    end,
    give_item = function(_, player, class, countToGive)
        return give(player, class, countToGive)
    end,
    take_item = function(_, player, class, countToTake)
        return take(player, class, countToTake)
    end,
    open = function(_, player)
        player:showInventoryOf(player)
        return true
    end,
})

TS.Integrations.RegisterVariable("finventory.item_count", {
    integration = ID,
    resolve = function(context, argument)
        return count(context.player, argument)
    end,
})

TS.Integrations.RegisterVariable("finventory.free_slots", {
    integration = ID,
    resolve = function(context)
        local playerInventory = inventory(context.player)
        return playerInventory and playerInventory:getRemainingPlace() or 0
    end,
})
