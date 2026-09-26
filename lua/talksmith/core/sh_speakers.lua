local TS = Talksmith

-- Actors retain their existing identity/appearance API. Other speakers never
-- inherit Actor physics, invulnerability, model changes or persistence rules.
TS.Speakers = TS.Speakers or {}
local S = TS.Speakers

function S.IsBoundNPC(entity)
    if not IsValid(entity) then return false end
    if SERVER then
        return TS.VJ ~= nil and not TS.VJ.Failed and istable(TS.VJ.Bindings)
            and TS.VJ.Bindings[entity] ~= nil
    end
    return entity:GetNW2Bool("Talksmith.VJBound", false)
end

function S.IsSpeaker(entity)
    return TS.Actors.IsActor(entity) or S.IsBoundNPC(entity)
end

function S.IsAlive(entity)
    return S.IsSpeaker(entity) and (not S.IsBoundNPC(entity) or (not entity.Dead and entity:Health() > 0))
end

local fields = { Name = "Name", Subtitle = "Subtitle", Dialogue = "Dialogue", Theme = "Theme" }
for method, key in pairs(fields) do
    S["Get" .. method] = function(entity)
        if TS.Actors.IsActor(entity) then return TS.Actors["Get" .. method](entity) end
        return IsValid(entity) and entity:GetNW2String("Talksmith." .. key, "") or ""
    end
end

function S.GetNameOffset(entity)
    if TS.Actors.IsActor(entity) then return TS.Actors.GetNameOffset(entity) end
    return IsValid(entity) and entity:GetNW2Float("Talksmith.NameOffset", 82) or 82
end

function S.GetBusy(entity)
    if TS.Actors.IsActor(entity) then return entity:GetBusy() end
    return IsValid(entity) and entity:GetNW2Bool("Talksmith.Busy", false) or false
end

if SERVER then
    function S.SetBusy(entity, value)
        if TS.Actors.IsActor(entity) then return TS.Actors.SetBusy(entity, value) end
        if IsValid(entity) then entity:SetNW2Bool("Talksmith.Busy", value == true) end
    end

    function S.GetAll()
        local result = TS.Actors.GetAll()
        for entity in pairs(TS.VJ and TS.VJ.Bindings or {}) do
            if IsValid(entity) then result[#result + 1] = entity end
        end
        return result
    end

    function S.Acquire(entity, player)
        if TS.Actors.IsActor(entity) then return true end
        if S.IsBoundNPC(entity) then return TS.VJ.Acquire(entity, player) end
        return false
    end

    function S.Release(entity, player, reason)
        if TS.Actors.IsActor(entity) then return end
        if TS.VJ and isfunction(TS.VJ.Release) then TS.VJ.Release(entity, player, reason) end
    end

    function S.PlayGesture(entity, name)
        -- Arbitrary sequence resets can execute attack animation events on VJ.
        if TS.Actors.IsActor(entity) and entity.PlayGesture then entity:PlayGesture(name) end
    end
end
