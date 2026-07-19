local TS = Talksmith
local ID = "darkrp_multicharacter"

TS.Integrations.Register(ID, {
    name = "DarkRP Multi Character",
    category = "character",
    priority = 80,
    capabilities = { "character", "identity", "job" },
    detect = function()
        return istable(BMCharSystemValues), "BM character API"
    end,
})

local function records(player)
    local result = {}
    local raw = player:GetPData("BM_char", "") or ""

    for index, encoded in ipairs(string.Explode("<|>", raw, false)) do
        if encoded ~= "" then
            local fields = string.Explode("<?>", encoded, false)
            result[#result + 1] = {
                index = index,
                name = fields[1] or "",
                money = tonumber(fields[2]) or 0,
                team = tonumber(fields[3]) or 0,
                model = fields[4] or "",
            }
        end
    end

    return result
end

local function current(player)
    local name = player:Name()
    local matched = nil

    for _, record in ipairs(records(player)) do
        if record.name == name then
            if matched then
                matched = nil
                break
            end

            matched = record
        end
    end

    if matched then return matched end

    return {
        index = 0,
        name = name,
        money = 0,
        team = player:Team(),
        model = player:GetModel(),
    }
end

local function ready(player)
    return not player:GetNWBool("SelectChar", true)
end

TS.Integrations.RegisterCondition(ID, "ready", {
    name = "Multi Character: character selected",
    params = {},
    run = function(context)
        return ready(context.player)
    end,
})

TS.Integrations.RegisterCondition(ID, "name_is", {
    name = "Multi Character: name is",
    params = { name = { type = "string", required = true, max = 128 } },
    run = function(context, params)
        return ready(context.player) and current(context.player).name == params.name
    end,
})

TS.Integrations.RegisterCondition(ID, "index_is", {
    name = "Multi Character: index is",
    params = { index = { type = "number", required = true, integer = true, min = 1, max = 128 } },
    run = function(context, params)
        return ready(context.player) and current(context.player).index == params.index
    end,
})

TS.Integrations.RegisterCondition(ID, "job_is", {
    name = "Multi Character: job is",
    params = { job = { type = "string", required = true, max = 128 } },
    run = function(context, params)
        local teamID = context.player:Team()
        return ready(context.player)
            and (tostring(teamID) == params.job or team.GetName(teamID) == params.job)
    end,
})

TS.Providers.Register("character", ID, {
    integration = ID,
    priority = 80,
    is_ready = function(_, player)
        return ready(player)
    end,
    get_current = function(_, player)
        return current(player)
    end,
    get_all = function(_, player)
        return records(player)
    end,
})

TS.Integrations.RegisterVariable("darkrp_multicharacter.name", {
    integration = ID,
    resolve = function(context)
        return current(context.player).name
    end,
})

TS.Integrations.RegisterVariable("darkrp_multicharacter.index", {
    integration = ID,
    resolve = function(context)
        return current(context.player).index
    end,
})

TS.Integrations.RegisterVariable("darkrp_multicharacter.job", {
    integration = ID,
    resolve = function(context)
        return team.GetName(context.player:Team()) or context.player:Team()
    end,
})
