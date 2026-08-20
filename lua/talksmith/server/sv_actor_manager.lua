local TS = Talksmith

function TS.Actors.GetByDialogue(dialogue, except)
    dialogue = TS.Utils.SafeID(dialogue or "")
    if not dialogue then
        return
    end
    for _, actor in ipairs(TS.Actors.GetAll()) do
        if actor ~= except and TS.Actors.GetDialogue(actor) == dialogue then
            return actor
        end
    end
end

function TS.Actors.RemoveByDialogue(dialogue, except)
    dialogue = TS.Utils.SafeID(dialogue or "")
    if not dialogue then
        return 0
    end
    local remove = {}
    for _, actor in ipairs(TS.Actors.GetAll()) do
        if actor ~= except and TS.Actors.GetDialogue(actor) == dialogue then
            remove[#remove + 1] = actor
        end
    end
    for _, actor in ipairs(remove) do
        if IsValid(actor) then
            actor:Remove()
        end
    end
    return #remove
end

function TS.Actors.ApplyAppearance(actor, settings)
    if not TS.Actors.IsActor(actor) or not istable(settings) then
        return
    end

    local scale = math.Clamp(tonumber(settings.actor_scale) or 1, 0.25, 4)
    actor:SetModelScale(scale, 0)
    actor:SetCollisionBounds(Vector(-13, -13, 0) * scale, Vector(13, 13, 72) * scale)

    actor:SetSkin(math.Clamp(math.floor(tonumber(settings.actor_skin) or 0), 0, 255))
    for id, value in pairs(istable(settings.actor_bodygroups) and settings.actor_bodygroups or {}) do
        local bg = tonumber(id)
        if bg then
            actor:SetBodygroup(bg, math.Clamp(math.floor(tonumber(value) or 0), 0, 63))
        end
    end

    TS.Actors.SetAppearance(actor, settings)
    if TS.Actors.RefreshBusy then
        TS.Actors.RefreshBusy(actor)
    end

    if actor.SetupBlock then
        actor:SetupBlock()
    end
end

-- Applies the visual part of a dialogue without changing the Actor's identity.
-- Runtime dialogue switches use this so the model's idle animation is refreshed
-- before the first node of the newly opened dialogue is shown.
function TS.Actors.ApplyDialogueAppearance(actor, settings)
    if not TS.Actors.IsActor(actor) or not istable(settings) then
        return
    end

    if not actor.ModelOverride and TS.Utils.IsModelAllowed(settings.actor_model) then
        actor:SetModel(settings.actor_model)
    end
    if actor.ApplyIdleSettings then
        actor:ApplyIdleSettings(settings)
    end
    TS.Actors.ApplyAppearance(actor, settings)
end
function TS.Actors.Spawn(data)
    local doc = data.dialogue and TS.Dialogues.Get(data.dialogue)
    local modelOverride = data.model_override == true
    local model = modelOverride and data.model or (doc and doc.settings.actor_model or data.model)
    local actor = ents.Create("talksmith_actor")
    if not IsValid(actor) then
        return
    end

    actor:SetModel(model or "models/Humans/Group01/male_02.mdl")
    actor:SetPos(data.pos or vector_origin)
    actor:SetAngles(data.ang or Angle())
    actor:Spawn()
    if IsValid(data.owner) and isfunction(actor.CPPISetOwner) then
        local ok, reason = pcall(actor.CPPISetOwner, actor, data.owner)
        if not ok then
            TS.Logging.Log(0, "Could not assign Actor CPPI owner: " .. tostring(reason))
        end
    end

    TS.Actors.RemoveByDialogue(data.dialogue, actor)
    TS.Actors.SetData(actor, TS.Utils.ClampString(data.name, 128), TS.Utils.ClampString(data.subtitle, 128), data.dialogue)

    actor.ModelOverride = modelOverride
    if doc then
        TS.Actors.ApplyDialogueAppearance(actor, doc.settings)
    end

    actor.Persistent = true
    hook.Run("Talksmith.ActorCreated", actor, data)
    return actor
end

function TS.Actors.Remove(actor)
    if not TS.Actors.IsActor(actor) then
        return false
    end
    actor:Remove()
    return true
end

function TS.Actors.SetDialogue(actor, dialogueID)
    dialogueID = TS.Utils.SafeID(dialogueID or "")
    local doc = dialogueID and TS.Dialogues.Get(dialogueID)
    if not TS.Actors.IsActor(actor) or not doc then
        return false
    end
    TS.Actors.SetData(
        actor,
        TS.Utils.ClampString(doc.settings.actor_name, 128),
        TS.Utils.ClampString(doc.settings.actor_subtitle, 128),
        dialogueID
    )
    TS.Actors.ApplyDialogueAppearance(actor, doc.settings)
    return true
end

function TS.Actors.Update(actor, data)
    if not TS.Actors.IsActor(actor) or not istable(data) then
        return false
    end
    if data.dialogue ~= nil and not TS.Actors.SetDialogue(actor, data.dialogue) then
        return false
    end
    local name = data.name ~= nil and TS.Utils.ClampString(data.name, 128) or TS.Actors.GetName(actor)
    local subtitle = data.subtitle ~= nil and TS.Utils.ClampString(data.subtitle, 128) or TS.Actors.GetSubtitle(actor)
    TS.Actors.SetData(actor, name, subtitle, TS.Actors.GetDialogue(actor))
    if data.pos ~= nil and isvector(data.pos) then actor:SetPos(data.pos) end
    if data.ang ~= nil and isangle(data.ang) then actor:SetAngles(data.ang) end
    return true
end

function TS.Actors.Create(player, data)
    if istable(player) and data == nil then
        data = player
        if not TS.Utils.MapMatches(data.map) then
            return nil, "wrong_map"
        end
        local dialogue = TS.Utils.SafeID(data.dialogue or "")
        local doc = dialogue and TS.Dialogues.Get(dialogue)
        local model = data.model or (doc and doc.settings.actor_model)
        if not doc or not isvector(data.pos) or not TS.Utils.IsModelAllowed(model) then
            return nil, "invalid_spawn"
        end
        if #TS.Actors.GetAll() >= TS.Config.max_actors and not TS.Actors.GetByDialogue(dialogue) then
            return nil, "actor_limit"
        end
        local actor = TS.Actors.Spawn({
            model = model,
            model_override = data.model ~= nil,
            pos = data.pos,
            ang = isangle(data.ang) and data.ang or angle_zero,
            name = data.name or doc.settings.actor_name,
            subtitle = data.subtitle or doc.settings.actor_subtitle,
            dialogue = dialogue,
        })
        if IsValid(actor) then
            actor.Persistent = false
            actor.CodeConfigured = data.code_key ~= nil
            actor.CodeSpawnKey = data.code_key
        end
        return actor
    end

    if not TS.Permissions.Has(player, "talksmith.actors.manage") then
        return
    end
    if not TS.Utils.IsModelAllowed(data.model) or not TS.Dialogues.Get(data.dialogue) then
        return
    end
    if #TS.Actors.GetAll() >= TS.Config.max_actors and not TS.Actors.GetByDialogue(data.dialogue) then
        return
    end
    data.pos = data.pos or player:GetEyeTrace().HitPos
    data.owner = player
    return TS.Actors.Spawn(data)
end

hook.Add("Talksmith.DialogueSaved", "Talksmith.RefreshSavedActors", function(dialogueID)
    local doc = TS.Dialogues.Get(dialogueID)
    if not doc then
        return
    end
    for _, actor in ipairs(TS.Actors.GetAll()) do
        if TS.Actors.GetDialogue(actor) == dialogueID then
            TS.Actors.SetData(
                actor,
                TS.Utils.ClampString(doc.settings.actor_name, 128),
                TS.Utils.ClampString(doc.settings.actor_subtitle, 128),
                dialogueID
            )
            TS.Actors.ApplyDialogueAppearance(actor, doc.settings)
        end
    end
end)

hook.Add("PhysgunPickup", "Talksmith.ActorPickup", function(player, entity)
    if not IsValid(entity) or entity:GetClass() ~= "talksmith_actor" then
        return
    end
    if not TS.Permissions.Has(player, "talksmith.actors.manage") then
        return false
    end
    entity:SetMoveType(MOVETYPE_VPHYSICS)
    local phys = entity:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(true)
        phys:Wake()
    end
    return true
end)

hook.Add("GravGunPickupAllowed", "Talksmith.ProtectActor", function(_, entity)
    if IsValid(entity) and entity:GetClass() == "talksmith_actor" then
        return false
    end
end)

hook.Add("EntityTakeDamage", "Talksmith.ProtectActor", function(entity)
    if IsValid(entity) and entity:GetClass() == "talksmith_actor" then
        return true
    end
end)

hook.Add("PhysgunDrop", "Talksmith.ActorDrop", function(_, entity)
    if not IsValid(entity) or entity:GetClass() ~= "talksmith_actor" then
        return
    end
    entity:FreezeActor()
    if entity.Persistent and TS.Config.autosave_actors then
        timer.Simple(0, TS.Actors.SaveLayout)
    end
end)
