local TS = Talksmith
local ID = "advanced_character_creator"
local MAX_CHARACTERS = 128

TS.Integrations.Register(ID, {
    name = "Advanced Character Creator",
    version = "1.5.5+",
    category = "character",
    priority = 90,
    capabilities = { "character", "identity", "job", "faction" },
    detect = function()
        return istable(ACC2) and isfunction(ACC2.GetNWVariables), "ACC2 API"
    end,
})

local function characterID(player)
    if not IsValid(player) or not istable(ACC2) or not isfunction(ACC2.GetNWVariables) then
        return nil
    end

    local value = tonumber(ACC2.GetNWVariables("characterId", player))
    if not value or value < 1 or value ~= math.floor(value) then
        return nil
    end

    return value
end

local function characterData(player, id)
    if not IsValid(player) or not istable(player.ACC2) or not istable(player.ACC2.characters) then
        return nil
    end

    local data = player.ACC2.characters[id]
    return istable(data) and data or nil
end

local function factionName(factionID)
    factionID = tonumber(factionID)
    local faction = factionID and istable(ACC2.Factions) and ACC2.Factions[factionID] or nil
    return istable(faction) and tostring(faction.name or factionID) or tostring(factionID or "")
end

local function normalizeRecord(id, data, player)
    data = istable(data) and data or {}
    local firstName = TS.Utils.ClampString(data.name or "", 128)
    local lastName = TS.Utils.ClampString(data.lastName or "", 128)
    local fullName = firstName

    if isfunction(ACC2.GetFormatedName) and (firstName ~= "" or lastName ~= "") then
        local ok, formatted = pcall(ACC2.GetFormatedName, firstName, lastName)
        if ok and isstring(formatted) then
            fullName = TS.Utils.ClampString(formatted, 128)
        end
    elseif lastName ~= "" then
        fullName = string.Trim(firstName .. " " .. lastName)
    end

    if fullName == "" and IsValid(player) then
        fullName = TS.Utils.ClampString(player:Nick(), 128)
    end

    local factionID = tonumber(data.factionId)
    return {
        index = id,
        character_id = id,
        name = fullName,
        first_name = firstName,
        last_name = lastName,
        job = TS.Utils.ClampString(data.job or (IsValid(player) and team.GetName(player:Team())) or "", 128),
        faction_id = factionID or 0,
        faction = factionName(factionID),
        model = TS.Utils.ClampString(data.model or "", 260),
    }
end

local function current(player)
    local id = characterID(player)
    local data = id and characterData(player, id) or nil
    if not id or not data then
        return nil
    end

    return normalizeRecord(id, data, player)
end

local function records(player)
    local result = {}
    local characters = IsValid(player) and istable(player.ACC2) and player.ACC2.characters or nil
    if not istable(characters) then
        return result
    end

    local ids = {}
    for rawID, data in pairs(characters) do
        local id = tonumber(rawID)
        if id and id >= 1 and id == math.floor(id) and istable(data) then
            ids[#ids + 1] = id
            if #ids >= MAX_CHARACTERS then
                break
            end
        end
    end
    table.sort(ids)

    for index = 1, math.min(#ids, MAX_CHARACTERS) do
        local id = ids[index]
        result[#result + 1] = normalizeRecord(id, characters[id] or characters[tostring(id)], player)
    end
    return result
end

local function ready(player)
    return current(player) ~= nil
end

TS.Integrations.RegisterCondition(ID, "ready", {
    name = "ACC2: character selected",
    params = {},
    run = function(context)
        return ready(context.player)
    end,
})

TS.Integrations.RegisterCondition(ID, "name_is", {
    name = "ACC2: character name is",
    params = { name = { type = "string", required = true, max = 128 } },
    run = function(context, params)
        local record = current(context.player)
        return record ~= nil and record.name == params.name
    end,
})

TS.Integrations.RegisterCondition(ID, "id_is", {
    name = "ACC2: character ID is",
    params = { id = { type = "number", required = true, integer = true, min = 1, max = 4194303 } },
    run = function(context, params)
        local record = current(context.player)
        return record ~= nil and record.character_id == params.id
    end,
})

TS.Integrations.RegisterCondition(ID, "job_is", {
    name = "ACC2: character job is",
    params = { job = { type = "string", required = true, max = 128 } },
    run = function(context, params)
        local record = current(context.player)
        return record ~= nil
            and (record.job == params.job or tostring(context.player:Team()) == params.job)
    end,
})

TS.Integrations.RegisterCondition(ID, "faction_is", {
    name = "ACC2: character faction is",
    params = { faction = { type = "string", required = true, max = 128 } },
    run = function(context, params)
        local record = current(context.player)
        return record ~= nil
            and (record.faction == params.faction or tostring(record.faction_id) == params.faction)
    end,
})

TS.Providers.Register("character", ID, {
    integration = ID,
    priority = 90,
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

for variable, field in pairs({
    name = "name",
    first_name = "first_name",
    last_name = "last_name",
    id = "character_id",
    job = "job",
    faction = "faction",
    faction_id = "faction_id",
}) do
    local variableID = variable
    local recordField = field
    TS.Integrations.RegisterVariable(ID .. "." .. variableID, {
        integration = ID,
        resolve = function(context)
            local record = current(context.player)
            return record and record[recordField] or ""
        end,
    })
end

hook.Add("ACC2:PreLoad:Character", "Talksmith.StopACC2CharacterSwitch", function(player)
    if TS.Runtime and isfunction(TS.Runtime.Stop) then
        TS.Runtime.Stop(player, "character_changed")
    end
end)

hook.Add("ACC2:Character:Created", "Talksmith.StopACC2CharacterCreation", function(player)
    if IsValid(player) and TS.Runtime and isfunction(TS.Runtime.Stop) then
        TS.Runtime.Stop(player, "character_changed")
    end
end)

hook.Add("ACC2:Load:Character", "Talksmith.StopACC2CharacterLoad", function(player)
    if IsValid(player) and TS.Runtime and isfunction(TS.Runtime.Stop) then
        TS.Runtime.Stop(player, "character_changed")
    end
end)

hook.Add("ACC2:RemoveCharacter", "Talksmith.StopACC2CharacterRemoval", function(characterIDValue, player)
    if IsValid(player) and TS.Runtime and isfunction(TS.Runtime.Stop) then
        TS.Runtime.Stop(player, "character_removed")
    end
end)

hook.Add("ACC2:RemovePermanentCharacter", "Talksmith.StopACC2PermanentCharacterRemoval", function(_, player)
    if IsValid(player) and TS.Runtime and isfunction(TS.Runtime.Stop) then
        TS.Runtime.Stop(player, "character_removed")
    end
end)
