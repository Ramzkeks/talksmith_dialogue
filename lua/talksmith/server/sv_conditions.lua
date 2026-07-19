local TS = Talksmith

local function registerCondition(id, name, params, run)
    TS.Conditions.Register(id, {
        name = name,
        description = name,
        params = params,
        run = run,
    })
end

registerCondition("core.flag_is_set", "Flag is set", {
    key = { type = "string", required = true, max = 64 },
}, function(context, params)
    local value, available = TS.Storage.GetFlag(context.player, params.key, false)
    return available and not not value
end)

registerCondition("core.flag_is_not_set", "Flag is not set", {
    key = { type = "string", required = true, max = 64 },
}, function(context, params)
    local value, available = TS.Storage.GetFlag(context.player, params.key, false)
    return available and not value
end)

registerCondition("core.has_weapon", "Has weapon", {
    class = { type = "string", required = true, max = 64 },
}, function(context, params)
    return TS.Utils.InList(TS.Config.allowed_weapons, params.class) and context.player:HasWeapon(params.class)
end)

registerCondition("core.does_not_have_weapon", "Does not have weapon", {
    class = { type = "string", required = true, max = 64 },
}, function(context, params)
    return TS.Utils.InList(TS.Config.allowed_weapons, params.class) and not context.player:HasWeapon(params.class)
end)

registerCondition("core.team_is", "Team is", {
    team = { type = "number", required = true, min = 0 },
}, function(context, params)
    return context.player:Team() == params.team
end)

registerCondition("core.team_is_not", "Team is not", {
    team = { type = "number", required = true, min = 0 },
}, function(context, params)
    return context.player:Team() ~= params.team
end)

registerCondition("core.health_above", "Health above", {
    value = { type = "number", required = true },
}, function(context, params)
    return context.player:Health() > params.value
end)

registerCondition("core.health_below", "Health below", {
    value = { type = "number", required = true },
}, function(context, params)
    return context.player:Health() < params.value
end)

registerCondition("core.random_chance", "Random chance", {
    chance = { type = "number", required = true, min = 0, max = 1 },
}, function(_, params)
    return params.chance >= 1 or (params.chance > 0 and math.Rand(0, 1) < params.chance)
end)
TS.Conditions.Registry["core.random_chance"].cache_result = true

registerCondition("core.is_admin", "Is admin", {}, function(context)
    return context.player:IsAdmin()
end)

local function registerDarkRPConditions()
    if not DarkRP or TS.Runtime.DarkRPConditionsRegistered then
        return
    end
    TS.Runtime.DarkRPConditionsRegistered = true

    registerCondition("darkrp.is_job", "DarkRP: job is", {
        job = { type = "string", required = true, max = 64 },
    }, function(context, params)
        local job = context.player.getJobTable and context.player:getJobTable()
            or (RPExtraTeams or {})[context.player:Team()]
        return istable(job) and job.command == params.job
    end)

    registerCondition("darkrp.has_money", "DarkRP: has money", {
        amount = { type = "number", required = true, min = 0 },
    }, function(context, params)
        return TS.Runtime.GetDarkRPMoney(context.player) >= math.max(params.amount, 0)
    end)

    registerCondition("darkrp.is_cp", "DarkRP: is civil protection", {}, function(context)
        return context.player.isCP and context.player:isCP() or false
    end)
end

registerDarkRPConditions()
hook.Add("Initialize", "Talksmith.DarkRPConditions", registerDarkRPConditions)
hook.Add("DarkRPFinishedLoading", "Talksmith.DarkRPConditions", registerDarkRPConditions)
