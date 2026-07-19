local TS = Talksmith
local ID = "gws"

TS.Integrations.Register(ID, {
    name = "GWS Inventory System",
    category = "inventory",
    priority = 70,
    capabilities = { "inventory", "weapons", "ammo" },
    detect = function()
        local playerMeta = FindMetaTable("Player")
        return istable(GWS)
            and isfunction(playerMeta.GWSInvAddItem)
            and isfunction(playerMeta.GWSRemoveItemClient)
            and isfunction(playerMeta.ShowInventory)
            and isfunction(CheckItemWhitelist), "GWS API"
    end,
})

local item = { type = "string", required = true, max = 128 }
local amount = { type = "number", required = true, integer = true, min = 1, max = 64 }

local function count(player, class)
    local result = 0
    for _, value in ipairs(player.Inv or {}) do
        if value.class == class then
            result = result + 1
        end
    end

    return result
end

local function capacity(player)
    local limit = GetConVar("sv_gws_invlimit")
    return limit and limit:GetInt() or 0, #(player.Inv or {})
end

local function createAllowed(class)
    if not isstring(class) or #class > 128 then
        return nil
    end

    local nativeAllowed = (isfunction(CheckItemWhitelist) and CheckItemWhitelist(class) == true)
        or weapons.GetStored(class) ~= nil
    if not TS.Utils.IsInventoryEntityAllowed(ID, class, nativeAllowed) then
        return nil
    end

    local entity = ents.Create(class)
    if not IsValid(entity) then
        return nil
    end

    entity:Spawn()

    return entity
end

local function give(player, class, countToGive)
    local maximum, used = capacity(player)
    if maximum <= 0 or used + countToGive > maximum then
        return false
    end

    local initialCount = #(player.Inv or {})
    local expectedCount = initialCount
    local function rollback()
        player.Inv = player.Inv or {}
        for index = #player.Inv, initialCount + 1, -1 do
            table.remove(player.Inv, index)
            player:GWSRemoveItemClient(index)
        end
        return false
    end

    for _ = 1, countToGive do
        local entity = createAllowed(class)
        if not entity then
            return rollback()
        end

        player:GWSInvAddItem(entity)
        entity:Remove()
        if #(player.Inv or {}) <= expectedCount then
            return rollback()
        end
        expectedCount = #(player.Inv or {})
    end

    return true
end

local function take(player, class, countToTake)
    if count(player, class) < countToTake then
        return false
    end

    for index = #player.Inv, 1, -1 do
        if countToTake <= 0 then
            break
        end

        if player.Inv[index].class == class then
            table.remove(player.Inv, index)
            player:GWSRemoveItemClient(index)
            countToTake = countToTake - 1
        end
    end

    return true
end

TS.Integrations.RegisterCondition(ID, "has_item", {
    name = "GWS: has item",
    params = { item = item, amount = amount },
    run = function(context, params)
        return count(context.player, params.item) >= params.amount
    end,
})

TS.Integrations.RegisterCondition(ID, "has_space", {
    name = "GWS: has space",
    params = { amount = amount },
    run = function(context, params)
        local maximum, used = capacity(context.player)
        return used + params.amount <= maximum
    end,
})

TS.Integrations.RegisterCondition(ID, "item_allowed", {
    name = "GWS: item allowed",
    params = { item = item },
    run = function(_, params)
        local nativeAllowed = (isfunction(CheckItemWhitelist) and CheckItemWhitelist(params.item) == true)
            or weapons.GetStored(params.item) ~= nil
        return TS.Utils.IsInventoryEntityAllowed(ID, params.item, nativeAllowed)
    end,
})

TS.Integrations.RegisterCondition(ID, "has_weapon", {
    name = "GWS: has weapon",
    params = { item = item },
    run = function(context, params)
        return context.player:HasWeapon(params.item)
    end,
})

TS.Integrations.RegisterCondition(ID, "has_ammo", {
    name = "GWS: has ammo",
    params = { ammo = item, amount = amount },
    run = function(context, params)
        return context.player:GetAmmoCount(params.ammo) >= params.amount
    end,
})

TS.Integrations.RegisterAction(ID, "give_item", {
    name = "GWS: give item",
    permission = "talksmith.actions.inventory",
    cost_param = "amount",
    params = { item = item, amount = amount },
    preflight = function(context, params)
        local maximum, used = capacity(context.player)
        local nativeAllowed = (isfunction(CheckItemWhitelist) and CheckItemWhitelist(params.item) == true)
            or weapons.GetStored(params.item) ~= nil
        return TS.Utils.IsInventoryEntityAllowed(ID, params.item, nativeAllowed)
            and maximum > 0
            and used + params.amount <= maximum
    end,
    run = function(context, params)
        return give(context.player, params.item, params.amount)
    end,
})

TS.Integrations.RegisterAction(ID, "take_item", {
    name = "GWS: take item",
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

TS.Integrations.RegisterAction(ID, "give_weapon", {
    name = "GWS: give weapon",
    permission = "talksmith.actions.inventory",
    params = { item = item },
    run = function(context, params)
        if not TS.Utils.InList(TS.Config.allowed_weapons, params.item) then
            return false
        end

        return IsValid(context.player:Give(params.item))
    end,
})

TS.Integrations.RegisterAction(ID, "strip_weapon", {
    name = "GWS: strip weapon",
    dangerous = true,
    permission = "talksmith.actions.inventory",
    params = { item = item },
    run = function(context, params)
        context.player:StripWeapon(params.item)
        return true
    end,
})

TS.Integrations.RegisterAction(ID, "give_ammo", {
    name = "GWS: give ammo",
    permission = "talksmith.actions.inventory",
    params = { ammo = item, amount = amount },
    run = function(context, params)
        context.player:GiveAmmo(params.amount, params.ammo, true)
        return true
    end,
})

TS.Integrations.RegisterAction(ID, "take_ammo", {
    name = "GWS: take ammo",
    dangerous = true,
    permission = "talksmith.actions.inventory",
    params = { ammo = item, amount = amount },
    run = function(context, params)
        context.player:RemoveAmmo(params.amount, params.ammo)
        return true
    end,
})

TS.Integrations.RegisterAction(ID, "open_inventory", {
    name = "GWS: open inventory",
    safe = true,
    params = {},
    run = function(context)
        context.player:ShowInventory()
        return true
    end,
})

TS.Providers.Register("inventory", ID, {
    integration = ID,
    priority = 70,
    get_item_count = function(_, player, class)
        return count(player, class)
    end,
    can_receive = function(_, player, class, countToAdd)
        local maximum, used = capacity(player)
        local nativeAllowed = (isfunction(CheckItemWhitelist) and CheckItemWhitelist(class) == true)
            or weapons.GetStored(class) ~= nil
        return TS.Utils.IsInventoryEntityAllowed(ID, class, nativeAllowed)
            and used + countToAdd <= maximum
    end,
    give_item = function(_, player, class, countToGive)
        return give(player, class, countToGive)
    end,
    take_item = function(_, player, class, countToTake)
        return take(player, class, countToTake)
    end,
    open = function(_, player)
        player:ShowInventory()
        return true
    end,
})

TS.Integrations.RegisterVariable("gws.item_count", {
    integration = ID,
    resolve = function(context, argument)
        return count(context.player, argument)
    end,
})

TS.Integrations.RegisterVariable("gws.free_slots", {
    integration = ID,
    resolve = function(context)
        local maximum, used = capacity(context.player)
        return math.max(0, maximum - used)
    end,
})
