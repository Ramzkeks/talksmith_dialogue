local TS, API = Talksmith, Talksmith.VJ

-- Class selection comes from the installed VJ spawn registry, never an
-- arbitrary entity class supplied by a client. Optional server allowlist.
function API.GetSpawnDefinition(class)
    if not isstring(class) or #class > 128 then return end
    local definition = (list.Get("VJBASE_SPAWNABLE_NPC") or {})[class]
    if not istable(definition) or definition.Class ~= class then return end
    if istable(TS.Config.vj_allowed_classes) and not TS.Utils.InList(TS.Config.vj_allowed_classes, class) then return end
    local current, seen = class, {}
    for _ = 1, 16 do
        if current == "npc_vj_human_base" or current == "npc_vj_creature_base" then return definition end
        if seen[current] then return end
        seen[current] = true
        local stored = scripted_ents.GetStored(current)
        current = stored and stored.t and stored.t.Base
        if not isstring(current) then return end
    end
end

local function canSpawn(context, params)
    local player = context.player
    if API.Failed or not IsValid(player) or not player:Alive() or not TS.Integrations.IsAvailable("vj")
        or API.Attempts[player] or IsValid(API.OwnedTargets[player]) then return false end
    if params.map ~= game.GetMap() or not TS.Dialogues.Get(params.dialogue) then return false end
    local definition = API.GetSpawnDefinition(params.class)
    if not definition or definition.AdminOnly and not player:IsAdmin() then return false end
    if params.weapon and params.weapon ~= "" and not TS.Utils.InList(definition.Weapons or {}, params.weapon) then return false end
    if table.Count(API.OwnedTargets) >= math.Clamp(tonumber(TS.Config.vj_max_targets) or 32, 1, 128) then return false end
    local pos = Vector(params.x, params.y, params.z)
    if not util.IsInWorld(pos) then return false end
    local trace = util.TraceHull({ start = pos, endpos = pos, mins = Vector(-16, -16, 1),
        maxs = Vector(16, 16, 72), mask = MASK_NPCSOLID })
    return not trace.Hit and not trace.StartSolid
end

local spawnParams = {
    class = { type = "string", required = true, max = 128 },
    dialogue = { type = "string", required = true, max = 64 },
    map = { type = "string", required = true, max = 128 },
    x = { type = "number", required = true, min = -32768, max = 32768 },
    y = { type = "number", required = true, min = -32768, max = 32768 },
    z = { type = "number", required = true, min = -32768, max = 32768 },
    yaw = { type = "number", min = -360, max = 360 },
    weapon = { type = "string", max = 128 },
    lifetime = { type = "number", min = 30, max = 3600 },
}

function API.SpawnTarget(player, params)
    if not TS.Validation.ValidateParams(spawnParams, params) or not canSpawn({ player = player }, params) then
        return nil, "invalid_or_occupied_spawn"
    end
    local definition = API.GetSpawnDefinition(params.class)
    local entity = ents.Create(params.class)
    if not IsValid(entity) then return nil, "create_failed" end
    local ok, errorMessage = pcall(function()
        entity:SetPos(Vector(params.x, params.y, params.z))
        entity:SetAngles(Angle(0, params.yaw or 0, 0))
        for key, value in pairs(definition.KeyValues or {}) do entity:SetKeyValue(key, tostring(value)) end
        if definition.SpawnFlags then entity:SetKeyValue("spawnflags", tostring(definition.SpawnFlags)) end
        local weapon = params.weapon
        if not weapon or weapon == "" then weapon = (definition.Weapons or {})[1] end
        if weapon then entity:SetKeyValue("additionalequipment", weapon) end
        entity:Spawn()
        entity:Activate()
        if not API.IsCompatible(entity) then error("unsupported_npc") end
        local trace = util.TraceHull({ start = entity:GetPos(), endpos = entity:GetPos(),
            mins = entity:OBBMins() + Vector(0, 0, 1), maxs = entity:OBBMaxs(),
            filter = entity, mask = MASK_NPCSOLID })
        if trace.Hit or trace.StartSolid then error("occupied_spawn") end
        if not API.Bind(entity, params.dialogue, { mode = "staged", owner = player, owned = true }) then error("bind_failed") end
    end)
    if not ok then
        API.Unbind(entity)
        if IsValid(entity) then entity:Remove() end
        TS.Logging.Log(0, "VJ target spawn failed: " .. tostring(errorMessage))
        return nil, "spawn_failed"
    end
    API.OwnedTargets[player] = entity
    API.Bindings[entity].waitingUntil = CurTime() + (params.lifetime or 600)
    if isfunction(entity.CPPISetOwner) then pcall(entity.CPPISetOwner, entity, player) end
    hook.Run("Talksmith.VJTargetCreated", player, entity, params.dialogue)
    return entity
end

TS.Integrations.RegisterAction("vj", "spawn_target", {
    name = "VJ: spawn personal dialogue target", permission = "talksmith.actions.events", vj_scene_action = true,
    description = "Create one owned VJ target at explicit map coordinates. Occupied points fail; no random placement. Must be the only action in its list.",
    params = spawnParams, preflight = canSpawn,
    run = function(context, params) return IsValid(API.SpawnTarget(context.player, params)) end,
})

TS.Integrations.RegisterCondition("vj", "has_target", {
    name = "VJ: player has a target", params = {},
    run = function(context) return IsValid(API.OwnedTargets[context.player]) or API.Attempts[context.player] ~= nil end,
})

timer.Create("Talksmith.VJTargetExpiry", 1, 0, function()
    for player, entity in pairs(API.OwnedTargets) do
        local binding = API.Bindings[entity]
        if not IsValid(entity) then
            API.OwnedTargets[player] = nil
        elseif binding and not binding.attempt and binding.waitingUntil and CurTime() >= binding.waitingUntil then
            API.Unbind(entity)
            entity:Remove()
        end
    end
end)
