local TS = Talksmith
TS.VJ = TS.VJ or {}
local API = TS.VJ
API.Bindings = API.Bindings or {}
API.Attempts = API.Attempts or {}
API.OwnedTargets = API.OwnedTargets or {}
local B = API.Bindings
local ROOT = "talksmith/vj_attempts"
file.CreateDir(ROOT)

TS.Integrations.Register("vj", {
    name = "VJ Base", category = "npc", automatic = false,
    capabilities = { "dialogue", "combat", "personal_objectives" },
    detect = function()
        return istable(VJ) and VJ_STATE_FREEZE ~= nil and VJ.MEM_OVERRIDE_DISPOSITION ~= nil, "VJ Base AI API"
    end,
})

local function living(entity)
    return IsValid(entity) and not entity.Dead and entity:Health() > 0
end

function API.IsCompatible(entity)
    if not living(entity) or not entity.IsVJBaseSNPC or entity.VJ_IsBeingControlled then return false end
    for _, name in ipairs({ "SetState", "GetState", "StopAttacks", "ResetTurnTarget", "ForceSetEnemy",
        "SetRelationshipMemory", "SCHEDULE_IDLE_STAND", "MaintainIdleAnimation", "StopMoving", "ClearGoal" }) do
        if not isfunction(entity[name]) then return false end
    end
    -- Flying/swimming NPCs, vehicles and custom movement require a dedicated adapter.
    return entity.MovementType == VJ_MOVETYPE_GROUND
        and istable(entity.RelationshipMemory) and istable(entity.EnemyData)
end

local function copy(value)
    return istable(value) and table.Copy(value) or value
end

local function patch(record, entity, key, value)
    if not record.fields[key] then
        record.fields[key] = { value = copy(rawget(entity:GetTable(), key)) }
    end
    entity[key] = value
    record.fields[key].applied = value
end

local function restoreFields(record, entity)
    for key, field in pairs(record.fields) do
        -- Do not overwrite changes made by another addon while we held the NPC.
        if entity[key] == field.applied then entity[key] = field.value end
    end
end

local function timerSnapshot(name)
    local remaining = timer.TimeLeft(name)
    if remaining then return { remaining = math.abs(remaining), paused = remaining < 0 } end
end

local function snapshot(entity)
    return {
        fields = {}, state = entity:GetState(), enemy = entity:GetEnemy(),
        npcState = entity:GetNPCState(), yaw = entity:GetMaxYawSpeed(),
        stateTimer = timerSnapshot("state_reset" .. entity:EntIndex()),
        turnTimer = timerSnapshot("turn_reset" .. entity:EntIndex()),
        turn = copy(entity.TurnData), sequence = entity:GetSequence(),
        cycle = entity:GetCycle(), playback = entity:GetPlaybackRate(),
    }
end

local function restoreTimer(entity, prefix, saved, callback)
    if not saved then return end
    local name = prefix .. entity:EntIndex()
    timer.Create(name, math.max(saved.remaining, 0.01), 1, function()
        if IsValid(entity) then callback(entity) end
    end)
    if saved.paused then timer.Pause(name) end
end

local function restore(entity, saved)
    if not saved or not living(entity) then return end
    restoreFields(saved, entity)
    entity:StopMoving()
    entity:ClearGoal()
    entity:ResetTurnTarget()
    entity:SetMaxYawSpeed(saved.yaw)
    entity:SetState(saved.state)
    restoreTimer(entity, "state_reset", saved.stateTimer, function(e) e:SetState() end)
    entity.TurnData = saved.turn
    restoreTimer(entity, "turn_reset", saved.turnTimer, function(e) e:ResetTurnTarget() end)
    entity:SetEnemy(living(saved.enemy) and saved.enemy or NULL)
    entity:SetNPCState(living(saved.enemy) and saved.npcState or NPC_STATE_IDLE)
    -- Resume AI from idle, never replay a partially executed attack animation.
    entity:SCHEDULE_IDLE_STAND()
    if saved.state == VJ_STATE_FREEZE and saved.sequence >= 0 then
        entity:ResetSequence(saved.sequence)
        entity:SetCycle(saved.cycle)
        entity:SetPlaybackRate(saved.playback)
    end
end

local pausedCallbacks = {
    "OnThink", "OnThinkActive", "SelectSchedule", "Touch", "AcceptInput",
    "ExecuteMeleeAttack", "ExecuteRangeAttack", "ExecuteLeapAttack", "ExecuteGrenadeAttack",
    "HandleAnimEvent", "OnAnimEvent", "CustomOnThink", "CustomOnThink_AIEnabled",
}
local function noop() end
local function noFire() return false end

local function hold(entity, binding)
    if binding.hold then return true end
    if not API.IsCompatible(entity) then return false end
    local saved = snapshot(entity)
    binding.hold = saved
    entity:StopAttacks(true)
    entity:ClearGoal()
    entity:StopMoving()
    entity:ResetTurnTarget()
    entity:SetEnemy(NULL)
    entity:SetState(VJ_STATE_FREEZE)
    for _, key in ipairs({ "EnemyDetection", "EnemyTouchDetection", "FollowPlayer", "IsFollowing",
        "DamageResponse", "CombatDamageResponse", "CallForHelp", "CanReceiveOrders", "HasSounds", "HasPoseParameterLooking" }) do
        patch(saved, entity, key, false)
    end
    patch(saved, entity, "PauseAttacks", true)
    for _, key in ipairs(pausedCallbacks) do patch(saved, entity, key, noop) end
    patch(saved, entity, "CanFireWeapon", noFire)
    if entity.StopAllSounds then entity:StopAllSounds() end
    entity:SetMaxYawSpeed(0)
    entity:SetIdealYaw(entity:GetAngles().y)
    -- SCHEDULE_IDLE_STAND can early-return while NextIdleTime is locked by a
    -- previous attack. Explicitly enter VJ's translated idle once instead.
    entity:MaintainIdleAnimation(true)
    return true
end

local function releaseHold(entity, binding)
    local saved = binding.hold
    binding.hold = nil
    restore(entity, saved)
end

local function sync(entity, binding)
    local doc = TS.Dialogues.Get(binding.dialogue)
    if not doc or not IsValid(entity) then return end
    entity:SetNW2Bool("Talksmith.VJBound", true)
    entity:SetNW2String("Talksmith.Dialogue", binding.dialogue)
    entity:SetNW2String("Talksmith.Name", doc.settings.actor_name)
    entity:SetNW2String("Talksmith.Subtitle", doc.settings.actor_subtitle)
    entity:SetNW2String("Talksmith.Theme", doc.settings.theme)
    entity:SetNW2Float("Talksmith.NameOffset", doc.settings.name_offset)
    entity:SetNW2Bool("Talksmith.Busy", binding.player ~= nil or binding.attempt ~= nil)
end

function API.Bind(entity, dialogue, options)
    options = options or {}
    if API.Failed or not TS.Integrations.IsAvailable("vj") or not API.IsCompatible(entity)
        or not TS.Dialogues.Get(dialogue) then return false, "unsupported_npc" end
    local mode = options.mode or "staged"
    if mode ~= "staged" and mode ~= "native" then return false, "invalid_mode" end
    if B[entity] and (B[entity].player or B[entity].attempt) then return false, "busy" end
    if B[entity] then API.Unbind(entity) end
    local binding = { dialogue = dialogue, mode = mode, owner = options.owner, owned = options.owned == true }
    B[entity] = binding
    if mode == "staged" and not hold(entity, binding) then B[entity] = nil; return false, "unsupported_npc" end
    sync(entity, binding)
    return true
end

function API.Acquire(entity, player)
    local binding = B[entity]
    if API.Failed or not TS.Integrations.IsAvailable("vj")
        or not binding or binding.attempt or (binding.player and binding.player ~= player)
        or (binding.owner and binding.owner ~= player) or not API.IsCompatible(entity) then return false end
    if not hold(entity, binding) then return false end
    binding.player = player
    sync(entity, binding)
    return true
end

function API.Release(entity, player, reason)
    local binding = B[entity]
    if not binding or binding.player ~= player then return end
    binding.player = nil
    if reason ~= "switched" and binding.mode == "native" then releaseHold(entity, binding) end
    sync(entity, binding)
end

local function validFlag(value)
    return isstring(value) and TS.Utils.SafeID(value) == value
end

local function validOutcome(params)
    if not validFlag(params.result_flag) then return false end
    local used = { [params.result_flag] = true }
    for _, key in ipairs({ "success_flag", "failure_flag", "active_flag" }) do
        local value = params[key]
        if value and value ~= "" then
            if not validFlag(value) or used[value] then return false end
            used[value] = true
        end
    end
    return true
end

local function setOutcome(player, params, result)
    local values = { [params.result_flag] = result }
    for _, key in ipairs({ "success_flag", "failure_flag", "active_flag" }) do
        local flag = params[key]
        if flag and flag ~= "" then
            values[flag] = key == "success_flag" and result == "success"
                or key == "failure_flag" and result == "failed"
                or key == "active_flag" and result == "active"
        end
    end
    return TS.Storage.SetFlags(player, values)
end

local function attemptPath(player)
    local id = IsValid(player) and tostring(player:SteamID64()) or ""
    if not id:match("^%d+$") then return nil end
    return ROOT .. "/" .. id .. ".json"
end

local function recover(player)
    local path = attemptPath(player)
    if not path then return false end
    if not file.Exists(path, "DATA") then return true end
    local raw = file.Read(path, "DATA")
    local record = raw and #raw <= 8192 and util.JSONToTable(raw)
    if not istable(record) or not istable(record.params) or not validOutcome(record.params) then return false end
    local result = record.result == "success" and "success" or "failed"
    if not setOutcome(player, record.params, result) then return false end
    file.Delete(path)
    return true
end

local function combatAllowed(context, params)
    local entity, player = context.actor, context.player
    local binding = B[entity]
    local ignore = GetConVar("ai_ignoreplayers")
    local disabled = GetConVar("ai_disabled")
    return not API.Failed and TS.Integrations.IsAvailable("vj")
        and validOutcome(params) and IsValid(player) and player:Alive()
        and context.session ~= nil and TS.Runtime.GetSession(player) == context.session
        and binding ~= nil and binding.player == player and not binding.attempt and not API.Attempts[player]
        and API.IsCompatible(entity) and (not ignore or not ignore:GetBool())
        and (not disabled or not disabled:GetBool())
        and entity.Behavior ~= VJ_BEHAVIOR_PASSIVE_NATURE and entity.Behavior ~= VJ_BEHAVIOR_PASSIVE
end

local function restoreCombat(entity, attempt)
    if not living(entity) then return end
    restoreFields(attempt.saved, entity)
    if IsValid(attempt.player) then
        entity:SetRelationshipMemory(attempt.player, VJ.MEM_OVERRIDE_DISPOSITION, attempt.relationship)
        entity:AddEntityRelationship(attempt.player, attempt.disposition, 0)
    end
    entity:StopAttacks(true)
    entity:SetEnemy(NULL)
    entity:SetNPCState(NPC_STATE_IDLE)
    entity:ClearGoal()
    entity:StopMoving()
    entity:SCHEDULE_IDLE_STAND()
end

function API.Finish(attempt, result, reason)
    if not attempt or attempt.done then return end
    attempt.done = true
    API.Attempts[attempt.player] = nil
    local entity, binding = attempt.entity, B[attempt.entity]
    if binding then binding.attempt = nil end
    -- Persist the terminal result before writing flags; a restart cannot turn
    -- an unfinished fight into success or award somebody else's kill.
    local record = { params = attempt.params, result = result }
    local saved = TS.Utils.WriteDataFile(attempt.path, util.TableToJSON(record))
    if saved and IsValid(attempt.player) and setOutcome(attempt.player, attempt.params, result) then
        file.Delete(attempt.path)
    else
        TS.Logging.Log(0, "VJ objective result could not be saved; recovery record: " .. attempt.path)
    end
    restoreCombat(entity, attempt)
    if binding and living(entity) then
        if binding.owned then
            API.Unbind(entity)
            entity:Remove()
        elseif binding.mode == "staged" then
            hold(entity, binding)
        end
        if IsValid(entity) then sync(entity, binding) end
    end
    hook.Run("Talksmith.VJCombatEnded", attempt.player, entity, result, reason, attempt.params.result_flag)
end

function API.CommitCombat(context)
    local params = context.vjCombat
    if not params or not combatAllowed(context, params) or not recover(context.player) then return false end
    local entity, player = context.actor, context.player
    local binding = B[entity]
    local path = attemptPath(player)
    if not path or not TS.Utils.WriteDataFile(path, util.TableToJSON({ params = params, result = "active" })) then return false end
    if not setOutcome(player, params, "active") then file.Delete(path); return false end
    TS.Runtime.Stop(player, "combat")
    releaseHold(entity, binding)
    local memory = entity.RelationshipMemory[player]
    local attempt = {
        player = player, entity = entity, params = params, path = path,
        saved = { fields = {} }, relationship = memory and memory[VJ.MEM_OVERRIDE_DISPOSITION],
        disposition = entity:Disposition(player), expires = CurTime() + (params.timeout or 300),
    }
    binding.attempt, API.Attempts[player] = attempt, attempt
    for _, key in ipairs({ "EnemyDetection", "EnemyTouchDetection", "DamageResponse", "BecomeEnemyToPlayer",
        "CallForHelp", "CanReceiveOrders", "DamageAllyResponse", "DeathAllyResponse", "IsMedic", "CanInvestigate",
        "FollowPlayer", "IsFollowing", "DisableChasingEnemy", "IsGuard" }) do
        patch(attempt.saved, entity, key, false)
    end
    if istable(entity.FollowData) then patch(attempt.saved, entity, "FollowData", table.Copy(entity.FollowData)) end
    -- Losing sight should chase the assigned opponent until the scene timeout,
    -- not run ResetEnemy's ally scan or wipe combat state behind the lease.
    patch(attempt.saved, entity, "ResetEnemy", noop)
    -- VJ's nearest-enemy scan and damage callbacks both use ForceSetEnemy.
    -- Guard SetEnemy as well for custom classes using the engine API directly.
    for _, key in ipairs({ "ForceSetEnemy", "SetEnemy" }) do
        local original = entity[key]
        patch(attempt.saved, entity, key, function(self, target, ...)
            if target ~= player then return end
            return original(self, target, ...)
        end)
    end
    entity:SetRelationshipMemory(player, VJ.MEM_OVERRIDE_DISPOSITION, D_HT)
    entity:AddEntityRelationship(player, D_HT, 0)
    entity:SetState(VJ_STATE_NONE)
    entity:ForceSetEnemy(player, true)
    sync(entity, binding)
    hook.Run("Talksmith.VJCombatStarted", player, entity, params.result_flag)
    return true
end

function API.Unbind(entity)
    local binding = B[entity]
    if not binding then return false end
    if binding.attempt then API.Finish(binding.attempt, "failed", "unbound") end
    if binding.player then TS.Runtime.Stop(binding.player, "npc_unbound") end
    releaseHold(entity, binding)
    B[entity] = nil
    if binding.owner and API.OwnedTargets[binding.owner] == entity then API.OwnedTargets[binding.owner] = nil end
    if IsValid(entity) then
        entity:SetNW2Bool("Talksmith.VJBound", false)
        entity:SetNW2Bool("Talksmith.Busy", false)
    end
    return true
end

function API.Deactivate()
    -- Snapshot before cleanup: Finish/Unbind/EntityRemoved can mutate B.
    local bindings = {}
    for entity, binding in pairs(B) do
        bindings[#bindings + 1] = { entity = entity, binding = binding }
    end
    for _, item in ipairs(bindings) do
        local entity, binding = item.entity, item.binding
        if binding.attempt then API.Finish(binding.attempt, "failed", "integration_disabled") end
        if binding.player then TS.Runtime.Stop(binding.player, "integration_disabled") end
        API.Unbind(entity)
        -- Existing world NPCs are released; only our personal targets are removed.
        if binding.owned and IsValid(entity) then entity:Remove() end
    end
end

hook.Add("Talksmith.IntegrationSettingChanged", "Talksmith.VJToggle", function(id, enabled)
    if id == "vj" and not enabled then API.Deactivate() end
end)

hook.Add("Talksmith.IntegrationStatusChanged", "Talksmith.VJUnavailable", function(id, status)
    if id ~= "vj" or status == "available" then return end
    -- Refresh also runs before settings are saved. Defer destructive cleanup
    -- until a failed save has had a chance to roll the toggle back.
    timer.Create("Talksmith.VJDeactivate", 0, 1, function()
        if not TS.Integrations.IsAvailable("vj") then API.Deactivate() end
    end)
end)

TS.Integrations.RegisterAction("vj", "start_combat", {
    name = "VJ: start combat with speaker", permission = "talksmith.actions.events", vj_scene_action = true,
    description = "Fight the current VJ speaker. Only the initiating player's kill succeeds; death/disconnect fails. Must be the only action in its list.",
    params = {
        result_flag = { type = "string", required = true, max = 64 },
        success_flag = { type = "string", max = 64 }, failure_flag = { type = "string", max = 64 },
        active_flag = { type = "string", max = 64 }, timeout = { type = "number", min = 10, max = 3600 },
    },
    preflight = combatAllowed,
    run = function(context, params)
        if not combatAllowed(context, params) then return false end
        context.vjCombat = table.Copy(params)
        return true
    end,
})

hook.Add("PlayerUse", "Talksmith.VJUse", function(player, entity)
    local binding = B[entity]
    if not binding then return end
    if TS.Network.Allow(player, "open", TS.Config.open_cooldown) then
        TS.Runtime.Start(player, entity, binding.dialogue)
    end
    return false
end)

hook.Add("PhysgunPickup", "Talksmith.VJScenePickup", function(player, entity)
    local binding = B[entity]
    if not binding then return end
    if binding.player or binding.attempt then return false end
    -- A staged idle NPC is held even outside conversation. Allow admins to
    -- arrange it, without overriding other addons' ownership/physgun rules.
    if binding.hold and not (IsValid(player) and player:IsAdmin()) then return false end
end)

-- Resolve only explicit engine ownership. Never infer kill credit from last
-- damage, nearby players, class names or a matching dialogue identifier.
local function source(entity)
    local seen = {}
    for _ = 1, 5 do
        if not IsValid(entity) or seen[entity] then return nil end
        if entity:IsPlayer() or B[entity] then return entity end
        seen[entity] = true
        entity = entity.GetOwner and entity:GetOwner() or nil
    end
end

hook.Add("EntityTakeDamage", "Talksmith.VJDamage", function(entity, damage)
    local binding = B[entity]
    if binding and binding.hold then damage:SetDamage(0); return true end
    local attacker = source(damage:GetAttacker()) or source(damage:GetInflictor())
    local attackerBinding = B[attacker]
    if attackerBinding and (attackerBinding.hold
        or attackerBinding.attempt and entity ~= attackerBinding.attempt.player
            and (entity:IsPlayer() or entity:IsNPC() or entity:IsNextBot())) then
        damage:SetDamage(0)
        return true
    end
end)

hook.Add("OnNPCKilled", "Talksmith.VJKilled", function(entity, attacker, inflictor)
    local binding = B[entity]
    if not binding then return end
    if binding.player then TS.Runtime.Stop(binding.player, "npc_killed") end
    local attempt = binding.attempt
    if attempt then
        local killer = source(attacker)
        -- World damage must not be credited via a stale projectile owner.
        if not killer and IsValid(attacker) and not attacker:IsWorld() then killer = source(inflictor) end
        local won = killer == attempt.player and IsValid(attempt.player) and attempt.player:Alive()
        API.Finish(attempt, won and "success" or "failed", won and "owner_kill" or "other_kill")
    end
    API.Unbind(entity)
end)

hook.Add("EntityRemoved", "Talksmith.VJRemoved", function(entity)
    local binding = B[entity]
    if not binding then return end
    if binding.attempt then API.Finish(binding.attempt, "failed", "npc_removed") end
    if binding.player then TS.Runtime.Stop(binding.player, "npc_removed") end
    if binding.owner and API.OwnedTargets[binding.owner] == entity then API.OwnedTargets[binding.owner] = nil end
    B[entity] = nil
end)

local function playerFailed(player)
    if API.Attempts[player] then API.Finish(API.Attempts[player], "failed", "owner_unavailable") end
    local target = API.OwnedTargets[player]
    if IsValid(target) then API.Unbind(target); target:Remove() end
    API.OwnedTargets[player] = nil
end
hook.Add("PlayerDeath", "Talksmith.VJOwnerDeath", playerFailed)
hook.Add("PlayerDisconnected", "Talksmith.VJOwnerLeave", playerFailed)
hook.Add("PlayerInitialSpawn", "Talksmith.VJRecover", function(player)
    timer.Simple(1, function() if IsValid(player) then recover(player) end end)
end)

hook.Add("Think", "Talksmith.VJGuard", function()
    local now = CurTime()
    for entity, binding in pairs(B) do
        if IsValid(entity) then
            if entity.VJ_IsBeingControlled or not living(entity) then
                API.Unbind(entity)
            elseif binding.hold then
                -- One yaw writer, shortest angular path, bounded speed, no
                -- per-tick sequence restart and no competing engine turn task.
                if entity:GetState() ~= VJ_STATE_FREEZE then entity:SetState(VJ_STATE_FREEZE) end
                entity:StopMoving()
                entity:MaintainIdleAnimation()
                local player = binding.player
                if IsValid(player) then
                    local delta = player:GetPos() - entity:GetPos()
                    if delta:Length2DSqr() > 1 then
                        local angle = entity:GetAngles()
                        local elapsed = math.Clamp(now - (binding.lastTurn or now), 0, 0.1)
                        angle.y = math.ApproachAngle(angle.y, delta:Angle().y, 100 * elapsed)
                        entity:SetAngles(angle)
                        entity:SetIdealYaw(angle.y)
                    end
                elseif binding.mode == "native" then
                    releaseHold(entity, binding)
                end
                binding.lastTurn = now
            elseif binding.attempt then
                local attempt = binding.attempt
                if not IsValid(attempt.player) or not attempt.player:Alive() or now >= attempt.expires then
                    API.Finish(attempt, "failed", "owner_unavailable_or_timeout")
                elseif entity:GetEnemy() ~= attempt.player then
                    entity:ForceSetEnemy(attempt.player, false)
                end
            end
        end
    end
end)

hook.Add("Talksmith.DialogueSaved", "Talksmith.VJRefresh", function(id)
    for entity, binding in pairs(B) do if binding.dialogue == id then sync(entity, binding) end end
end)
hook.Add("Talksmith.DialogueDeleted", "Talksmith.VJDelete", function(id)
    for entity, binding in pairs(B) do
        if binding.dialogue == id then
            API.Unbind(entity)
            if binding.owned and IsValid(entity) then entity:Remove() end
        end
    end
end)

TS.Integrations.RegisterCondition("vj", "result_is", {
    name = "VJ: combat result is",
    params = {
        result_flag = { type = "string", required = true, max = 64 },
        result = { type = "string", required = true, options = { "active", "success", "failed" } },
    },
    run = function(context, params)
        local value, available = TS.Storage.GetFlag(context.player, params.result_flag)
        return available and value == params.result
    end,
})
