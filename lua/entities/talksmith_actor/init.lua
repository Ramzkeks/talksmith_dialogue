AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local TS = Talksmith

function ENT:Initialize()
    if self:GetModel() == "" then
        self:SetModel("models/Humans/Group01/male_02.mdl")
    end
    self:SetupBlock()
    self:SetUseType(SIMPLE_USE)
    self:SetIK(false)

    if self:GetActorName() == "" then
        self:SetActorName("Собеседник")
    end
    if self:GetNameOffset() <= 0 then
        self:SetNameOffset(82)
    end
    self:SetBusy(false)

    if TS.Actors.SetupWire then
        TS.Actors.SetupWire(self)
    end

    self:StartIdleAnim()
end

function ENT:TriggerInput(name, value)
    if TS.Actors.HandleWireInput then
        TS.Actors.HandleWireInput(self, name, value)
    end
end

function ENT:SetupBlock()
    self:SetSolid(SOLID_BBOX)
    self:PhysicsInitBox(self:OBBMins(), self:OBBMaxs())
    self:SetMoveType(MOVETYPE_NONE)
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:Sleep()
    end
end

function ENT:FreezeActor()
    self:SetMoveType(MOVETYPE_NONE)
    self:SetAngles(Angle(0, self:GetAngles().y, 0))
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:Sleep()
    end
end

function ENT:ApplyIdleSettings(settings)
    settings = settings or {}
    self.IdleSequenceName = isstring(settings.idle_sequence) and settings.idle_sequence or ""
    self.IdleSequences = istable(settings.idle_sequences) and settings.idle_sequences or {}
    self:StartIdleAnim()
end

function ENT:StartIdleAnim()
    local name = self.IdleSequenceName
    local list = self.IdleSequences
    if istable(list) and #list > 0 then
        name = list[math.random(#list)]
    end

    local seq
    if isstring(name) and name ~= "" then
        seq = self:LookupSequence(name)
    end
    if not seq or seq < 0 then
        seq = self:SelectWeightedSequence(ACT_IDLE)
    end
    if not seq or seq < 0 then
        for _, candidate in ipairs({ "idle_all_01", "idle_subtle", "idle_unarmed", "idle01", "idle", "menu_walk" }) do
            local s = self:LookupSequence(candidate)
            if s and s >= 0 then
                seq = s
                break
            end
        end
    end

    if seq and seq >= 0 then
        self:ResetSequence(seq)
        self:SetCycle(0)
        self:SetPlaybackRate(1)
        self.IdleSeqIndex = seq
        local now = CurTime()
        if istable(list) and #list > 1 then
            self.IdleSwitchAt = now + math.max(self:SequenceDuration(seq), 0.2)
            self:NextThink(self.IdleSwitchAt)
        else
            self.IdleSwitchAt = nil
            self:NextThink(now + 60)
        end
    end
end

function ENT:PlayGesture(name)
    if not isstring(name) or name == "" then
        return
    end
    local seq = self:LookupSequence(name)
    if not seq or seq < 0 then
        return
    end
    self:ResetSequence(seq)
    self:SetCycle(0)
    self:SetPlaybackRate(1)
    local dur = math.max(self:SequenceDuration(seq), 0.2)
    self.GestureUntil = CurTime() + dur
    self.IdleSwitchAt = nil
    self:NextThink(self.GestureUntil)
end

function ENT:Use(player)
    if not (IsValid(player) and player:IsPlayer()) then
        return
    end
    if not TS.Network.Allow(player, "open", TS.Config.open_cooldown) then
        return
    end
    TS.Runtime.Start(player, self, self:GetDialogueID())
end

function ENT:Think()
    local now = CurTime()
    if self.GestureUntil then
        if now < self.GestureUntil then
            self:NextThink(self.GestureUntil)
            return true
        end
        self.GestureUntil = nil
        self:StartIdleAnim()
        return true
    end
    if not (istable(self.IdleSequences) and #self.IdleSequences > 1) then
        self:NextThink(now + 60)
        return true
    end

    if not self.IdleSwitchAt or now >= self.IdleSwitchAt then
        self:StartIdleAnim()
    else
        self:NextThink(self.IdleSwitchAt)
    end
    return true
end

function ENT:OnRemove()
    hook.Run("Talksmith.ActorRemoved", self)
    if TS.Actors.RemoveWire then
        TS.Actors.RemoveWire(self)
    end
    for player, session in pairs(TS.Runtime.Sessions or {}) do
        if session.actor == self then
            TS.Runtime.Stop(player, "actor_removed")
        end
    end
end
