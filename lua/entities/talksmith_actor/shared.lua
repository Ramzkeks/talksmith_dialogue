AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Talksmith Actor"
ENT.Category = "Talksmith"
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.AutomaticFrameAdvance = true

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "ActorName")
    self:NetworkVar("String", 1, "ActorSubtitle")
    self:NetworkVar("String", 2, "DialogueID")
    self:NetworkVar("String", 3, "Theme")
    self:NetworkVar("Float", 0, "NameOffset")
    self:NetworkVar("Bool", 0, "UseLimit")
    self:NetworkVar("Bool", 1, "Busy")
end
