local TS = Talksmith

function TS.Runtime.GetDarkRPMoney(player)
    if not IsValid(player) or not player.getDarkRPVar then
        return 0
    end

    return math.max(tonumber(player:getDarkRPVar("money", 0)) or 0, 0)
end

local function darkRPMoneyCap()
    return math.max(math.floor(tonumber(TS.Config.darkrp_max_money_action) or 0), 0)
end

local function registerAction(id, name, params, run, security)
    local definition = {
        name = name,
        description = name,
        params = params,
        run = run,
    }
    for key, value in pairs(security or {}) do
        definition[key] = value
    end
    TS.Actions.Register(id, definition)
end

registerAction("core.set_flag", "Set flag", {
    key = { type = "string", required = true, max = 64 },
    value = { required = true },
}, function(context, params)
    return TS.Storage.SetFlag(context.player, params.key, params.value)
end, { safe = true })

registerAction("core.clear_flag", "Clear flag", {
    key = { type = "string", required = true, max = 64 },
}, function(context, params)
    return TS.Storage.ClearFlag(context.player, params.key)
end, { safe = true })

registerAction("core.give_weapon", "Give weapon", {
    class = { type = "string", required = true, max = 64 },
}, function(context, params)
    if not TS.Utils.InList(TS.Config.allowed_weapons, params.class) then
        return false
    end
    context.player:Give(params.class)
    return true
end, { permission = "talksmith.actions.inventory" })

registerAction("core.take_weapon", "Take weapon", {
    class = { type = "string", required = true, max = 64 },
}, function(context, params)
    if not TS.Utils.InList(TS.Config.allowed_weapons, params.class) then
        return false
    end
    context.player:StripWeapon(params.class)
    return true
end, { permission = "talksmith.actions.inventory" })

registerAction("core.give_health", "Give health", {
    amount = { type = "number", required = true, min = 0 },
}, function(context, params)
    context.player:SetHealth(math.Clamp(context.player:Health() + params.amount, 0, context.player:GetMaxHealth()))
    return true
end, { permission = "talksmith.actions.inventory" })

registerAction("core.give_armor", "Give armor", {
    amount = { type = "number", required = true, min = 0 },
}, function(context, params)
    context.player:SetArmor(math.Clamp(context.player:Armor() + params.amount, 0, 255))
    return true
end, { permission = "talksmith.actions.inventory" })

registerAction("core.play_sound", "Play sound", {
    sound = { type = "string", required = true, max = 128 },
}, function(context, params)
    if not TS.Utils.InList(TS.Config.allowed_sounds, params.sound) then
        return false
    end
    context.player:EmitSound(params.sound)
    return true
end, { safe = true })

registerAction("core.change_team", "Change team", {
    team = { type = "number", required = true, min = 0 },
}, function(context, params)
    if not TS.Utils.InList(TS.Config.allowed_teams, params.team) or not context.player.changeTeam then
        return false
    end
    return context.player:changeTeam(params.team, false) ~= false
end, { permission = "talksmith.actions.jobs" })

registerAction("core.emit_event", "Emit event", {
    event = { type = "string", required = true, max = 64 },
    data = { max = 256 },
}, function(context, params)
    hook.Run("Talksmith.Event", params.event, context.player, context.actor, params.data)
    return true
end, { permission = "talksmith.actions.events", dangerous = true })

registerAction("core.close_dialogue", "Close dialogue", {}, function(context)
    context.close = true
    return true
end, { safe = true })

registerAction("core.open_dialogue", "Open dialogue", {
    dialogue = { type = "string", required = true, max = 64 },
}, function(context, params)
    if not TS.Dialogues.Get(params.dialogue) then
        return false
    end
    context.open = params.dialogue
    return true
end, {
    safe = true,
    preflight = function(context, params)
        local source = context and TS.Dialogues.Get(context.dialogue_id)
        return TS.Dialogues.IsDependencyCurrent(source, params.dialogue)
    end,
})

local function findDarkRPTeam(command)
    if not isstring(command) then
        return
    end
    if DarkRP and DarkRP.getJobByCommand then
        local _, teamID = DarkRP.getJobByCommand(command)
        if teamID then
            return teamID
        end
    end
    for id, job in pairs(RPExtraTeams or {}) do
        if istable(job) and job.command == command then
            return id
        end
    end
end

local function registerDarkRPActions()
    if not DarkRP or TS.Runtime.DarkRPActionsRegistered then
        return
    end
    TS.Runtime.DarkRPActionsRegistered = true

    registerAction("darkrp.change_job", "DarkRP: set job", {
        job = { type = "string", required = true, max = 64 },
    }, function(context, params)
        local allowedJobs = TS.Config.allowed_darkrp_jobs or {}
        if #allowedJobs > 0 and not TS.Utils.InList(allowedJobs, params.job) then
            return false
        end
        local teamID = findDarkRPTeam(params.job)
        if teamID and context.player.changeTeam then
            return context.player:changeTeam(teamID, false, false) ~= false
        end
        return false
    end, { permission = "talksmith.actions.jobs", dangerous = true })

    registerAction("darkrp.give_money", "DarkRP: give money", {
        amount = { type = "number", required = true, min = 0 },
    }, function(context, params)
        if not context.player.addMoney then
            return false
        end
        local amount = math.Clamp(math.floor(params.amount), 0, darkRPMoneyCap())
        context.player:addMoney(amount)
        return true
    end, { permission = "talksmith.actions.economy" })

    registerAction("darkrp.take_money", "DarkRP: take money", {
        amount = { type = "number", required = true, min = 0 },
    }, function(context, params)
        if not context.player.addMoney then
            return false
        end
        local balance = TS.Runtime.GetDarkRPMoney(context.player)
        local amount = math.min(math.Clamp(math.floor(params.amount), 0, darkRPMoneyCap()), balance)
        context.player:addMoney(-amount)
        return true
    end, { permission = "talksmith.actions.economy", dangerous = true })
end

registerDarkRPActions()
hook.Add("Initialize", "Talksmith.DarkRPActions", registerDarkRPActions)
hook.Add("DarkRPFinishedLoading", "Talksmith.DarkRPActions", registerDarkRPActions)
