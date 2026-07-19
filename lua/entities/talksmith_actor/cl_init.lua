include("shared.lua")

function ENT:Initialize()
    self:SetIK(false)
end

function ENT:Draw()
    self:DrawModel()
end
