local TS = Talksmith

local providerParam = { type = "string", max = 64 }
local itemParam = { type = "string", required = true, max = 128 }
local amountParam = { type = "number", required = true, integer = true, min = 1, max = 1000000 }
local countParam = { type = "number", required = true, integer = true, min = 1, max = 64 }

local function provider(context, params, kind, method)
    return IsValid(context.player) and TS.Providers.Get(kind or "inventory", params.provider, method) or nil
end

local function invoke(p, method, ...)
    if not p or not isfunction(p[method]) then
        return false
    end

    local ok, result = TS.Utils.SafeCall("provider " .. p.id .. "." .. method, p[method], p, ...)
    return ok and result
end

TS.Conditions.Register("inventory.has_item", {
    name = "Inventory: has item",
    description = "Checks the selected inventory provider (or the sole available provider).",
    category = "inventory",
    provider_kind = "inventory",
    provider_method = "get_item_count",
    params = { provider = providerParam, item = itemParam, amount = countParam },
    run = function(context, params)
        local p = provider(context, params, "inventory", "get_item_count")
        local count = invoke(p, "get_item_count", context.player, params.item)
        return isnumber(count) and count >= params.amount
    end,
})

TS.Conditions.Register("inventory.has_space", {
    name = "Inventory: has space",
    description = "Checks whether the selected provider can receive the requested amount.",
    category = "inventory",
    provider_kind = "inventory",
    provider_method = "can_receive",
    params = { provider = providerParam, item = itemParam, amount = countParam },
    run = function(context, params)
        return invoke(
            provider(context, params, "inventory", "can_receive"),
            "can_receive",
            context.player,
            params.item,
            params.amount
        ) == true
    end,
})

TS.Actions.Register("inventory.give_item", {
    name = "Inventory: give item",
    description = "Adds an item through a supported inventory provider.",
    category = "inventory",
    provider_kind = "inventory",
    provider_method = "give_item",
    permission = "talksmith.actions.inventory",
    cost_param = "amount",
    params = { provider = providerParam, item = itemParam, amount = countParam },
    preflight = function(context, params)
        local p = provider(context, params, "inventory", "give_item")
        if not p then return false end
        if isfunction(p.can_receive) then
            return invoke(p, "can_receive", context.player, params.item, params.amount) == true
        end
        return true
    end,
    run = function(context, params)
        return invoke(
            provider(context, params, "inventory", "give_item"),
            "give_item",
            context.player,
            params.item,
            params.amount
        )
    end,
})

TS.Actions.Register("inventory.take_item", {
    name = "Inventory: take item",
    description = "Removes an item through a supported inventory provider.",
    category = "inventory",
    provider_kind = "inventory",
    provider_method = "take_item",
    dangerous = true,
    permission = "talksmith.actions.inventory",
    cost_param = "amount",
    params = { provider = providerParam, item = itemParam, amount = countParam },
    preflight = function(context, params)
        local p = provider(context, params, "inventory", "take_item")
        if not p then return false end
        if isfunction(p.get_item_count) then
            local count = invoke(p, "get_item_count", context.player, params.item)
            return isnumber(count) and count >= params.amount
        end
        return true
    end,
    run = function(context, params)
        return invoke(
            provider(context, params, "inventory", "take_item"),
            "take_item",
            context.player,
            params.item,
            params.amount
        )
    end,
})

TS.Actions.Register("inventory.open", {
    name = "Inventory: open",
    description = "Opens the selected inventory for the player.",
    category = "inventory",
    safe = true,
    provider_kind = "inventory",
    provider_method = "open",
    params = { provider = providerParam },
    run = function(context, params)
        return invoke(provider(context, params, "inventory", "open"), "open", context.player, context)
    end,
})

TS.Integrations.RegisterVariable("inventory.item_count", {
    name = "Inventory item count",
    provider_kind = "inventory",
    provider_method = "get_item_count",
    resolve = function(context, argument)
        local p = TS.Providers.Get("inventory", "auto", "get_item_count")
        local value = invoke(p, "get_item_count", context.player, argument)
        return tonumber(value) or 0
    end,
})

TS.Conditions.Register("currency.has_amount", {
    name = "Currency: has amount",
    description = "Checks a supported currency provider.",
    category = "economy",
    provider_kind = "currency",
    provider_method = "get_balance",
    params = { provider = providerParam, currency = { type = "string", max = 64 }, amount = amountParam },
    run = function(context, params)
        local p = provider(context, params, "currency", "get_balance")
        local value = invoke(p, "get_balance", context.player, params.currency)
        return isnumber(value) and value >= params.amount
    end,
})

TS.Actions.Register("currency.add", {
    name = "Currency: add",
    category = "economy",
    provider_kind = "currency",
    provider_method = "add",
    permission = "talksmith.actions.economy",
    params = { provider = providerParam, currency = { type = "string", max = 64 }, amount = amountParam },
    run = function(context, params)
        return invoke(
            provider(context, params, "currency", "add"),
            "add",
            context.player,
            params.currency,
            params.amount
        )
    end,
})

TS.Actions.Register("currency.take", {
    name = "Currency: take",
    description = "Removes an amount through a supported currency provider.",
    category = "economy",
    provider_kind = "currency",
    provider_method = "take",
    dangerous = true,
    permission = "talksmith.actions.economy",
    params = { provider = providerParam, currency = { type = "string", max = 64 }, amount = amountParam },
    preflight = function(context, params)
        local p = provider(context, params, "currency", "take")
        if not p then return false end
        if isfunction(p.get_balance) then
            local balance = invoke(p, "get_balance", context.player, params.currency)
            return isnumber(balance) and balance >= params.amount
        end
        return true
    end,
    run = function(context, params)
        return invoke(
            provider(context, params, "currency", "take"),
            "take",
            context.player,
            params.currency,
            params.amount
        )
    end,
})
