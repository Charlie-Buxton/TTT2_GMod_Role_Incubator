if SERVER then
  AddCSLuaFile()
end

SWEP.Base         = "weapon_tttbase"
SWEP.HoldType     = "normal"

if CLIENT then
  SWEP.PrintName     = "Help me"
  SWEP.Slot          = 8
  SWEP.ViewModelFOV  = 70
  SWEP.DrawCrosshair = false
end

SWEP.UseHands       = true
SWEP.ViewModel      = "models/weapons/c_arms.mdl"
SWEP.WorldModel     = ""
SWEP.Kind           = WEAPON_EQUIP2
SWEP.AllowDrop      = false
SWEP.AutoSpawnable  = false
SWEP.Spawnable      = false
SWEP.DrawAmmo       = false

-- 2.5s cooldown
SWEP.Primary.Damage       = 0
SWEP.Primary.ClipSize     = -1
SWEP.Primary.DefaultClip  = -1
SWEP.Primary.Automatic    = false
SWEP.Primary.Delay        = 2.5
SWEP.Primary.Ammo         = "none"

-- allowed while Bigfoot is feral (role checks this flag)
SWEP.BigfootAllowed = true

-- your custom sound (path is relative to 'sound/')
local HELP_SOUND = "bigfoot/helpme.wav"

function SWEP:OnDrop() self:Remove() end
function SWEP:Deploy() self:SetHoldType(self.HoldType) return true end

function SWEP:PrimaryAttack()
  self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

  local owner = self:GetOwner()
  if not IsValid(owner) then return end

  if SERVER then
    -- Positional voice shout so others hear it
    owner:EmitSound(HELP_SOUND, 90, 100, 1, CHAN_VOICE)
  end
end

-- Debug
print("[Bigfoot] HelpMe SWEP shared.lua executed on " .. (SERVER and "SERVER" or "CLIENT"))
if weapons and not weapons.GetStored("weapon_ttt2_helpme") then
  weapons.Register(SWEP, "weapon_ttt2_helpme")
  print("[Bigfoot] weapons.Register('weapon_ttt2_helpme') called")
end