if SERVER then
  AddCSLuaFile()

  -- Optional icon
  -- resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_incu.vmt")

  -- Optional sounds (add these if you’re using FastDL/workshop)
  -- resource.AddFile("sound/incubator/growl.wav")
  -- resource.AddFile("sound/incubator/splat.wav")
end

INCUBATOR = INCUBATOR or {}

-- Track spawned NPCs so we can clean them up between rounds
INCUBATOR.SpawnedNPCs = INCUBATOR.SpawnedNPCs or {}

local function IncubatorCleanupNPCs()
  -- If something overwrote/reset the table, recover safely
  if not istable(INCUBATOR.SpawnedNPCs) then
    INCUBATOR.SpawnedNPCs = {}
    return
  end

  for i = #INCUBATOR.SpawnedNPCs, 1, -1 do
    local ent = INCUBATOR.SpawnedNPCs[i]
    if IsValid(ent) then
      ent:Remove()
    end
    INCUBATOR.SpawnedNPCs[i] = nil
  end
end

-------------------------
-- ROLE INITIALISATION --
-------------------------

function ROLE:PreInitialize()
  -- Role color
  self.color = Color(120, 200, 120, 255)

  self.abbr = "incu"
  self.defaultTeam = TEAM_INNOCENT

  -- Hidden innocent-type role
  self.isPublicRole     = false   -- NOT globally revealed
  self.isPolicingRole   = false
  self.unknownTeam      = true
  self.isOmniscientRole = false
  self.disableSync      = false

  -- No shop
  self.defaultEquipment = nil

  self.conVarData = {
    pct          = 0.13,
    maximum      = 1,
    minPlayers   = 6,
    credits      = 0,
    shopFallback = SHOP_DISABLED,
    togglable    = true
  }
end

function ROLE:Initialize()
  roles.SetBaseRole(self, ROLE_INNOCENT)
end

-------------------
-- CLIENT STRINGS --
-------------------

if CLIENT then
  hook.Add("Initialize", "ttt2_incubator_lang", function()
    LANG.AddToLanguage("english", "role_incubator", "Incubator")
    LANG.AddToLanguage("english", "info_role_incubator",
      "You are the Incubator! When you die, a Podbeg mutant will hatch from your corpse.")
    LANG.AddToLanguage("english", "body_found_incubator", "They were an Incubator.")
    LANG.AddToLanguage("english", "search_role_incubator", "This person was an Incubator!")
    LANG.AddToLanguage("english", "target_incubator", "Incubator")
  end)

  -- ROLE.icon = "vgui/ttt/dynamic/roles/icon_incu"
end

-------------------------
-- NPC SPAWN SETTINGS --
-------------------------

-- ONLY the 2 Podbeg NPCs
local INCUBATOR_NPCS = {
  "npc_vj_ah_podbeg",
  "npc_vj_ah_podbegorange"
}

-- Delay before the monster spawns (3 seconds)
local INCUBATOR_SPAWN_DELAY = 3.0

-- Sounds (change to match your actual paths)
local INCUBATOR_GROWL_SOUND = "incubator/growl.wav" -- played on death
local INCUBATOR_SPLAT_SOUND = "incubator/splat.wav" -- played on spawn

local function IsIncubator(ply)
  return IsValid(ply) and ply:GetSubRole() == ROLE_INCUBATOR
end

-----------------------
-- CORPSE RESOLUTION --
-----------------------

local function GetCorpseForPlayer(ply)
  if not IsValid(ply) then return nil end

  if IsValid(ply.server_ragdoll) then
    return ply.server_ragdoll
  end

  if CORPSE and CORPSE.GetPlayer then
    for _, rag in ipairs(ents.FindByClass("prop_ragdoll")) do
      if CORPSE.GetPlayer(rag) == ply then
        return rag
      end
    end
  end

  return nil
end

local function GetIncubatorSpawnPosAng(ply)
  local rag = GetCorpseForPlayer(ply)
  if IsValid(rag) then
    return rag:GetPos() + Vector(0, 0, 5), rag:GetAngles()
  end

  -- fallback
  return ply:GetPos() + Vector(0, 0, 5), ply:GetAngles()
end

------------------------
-- BLOOD EFFECT LOGIC --
------------------------

local function SpawnBloodEffect(pos)
  -- Big sprays around the corpse
  for i = 1, 18 do
    local offset = pos + Vector(math.random(-40, 40), math.random(-40, 40), math.random(0, 25))

    local effect = EffectData()
    effect:SetOrigin(offset)
    effect:SetScale(7)        -- large splash
    effect:SetMagnitude(7)    -- intense
    util.Effect("BloodImpact", effect, true, true)
  end

  -- Wide area floor splats
  for i = 1, 24 do
    local decalPos = pos + Vector(math.random(-80, 80), math.random(-80, 80), 0)
    util.Decal("Blood", decalPos + Vector(0, 0, 35), decalPos - Vector(0, 0, 70))
  end
end

-----------------------
-- NPC SPAWN LOGIC   --
-----------------------

local function GetRandomIncubatorNPC()
  return INCUBATOR_NPCS[math.random(#INCUBATOR_NPCS)]
end

local function SpawnIncubatorNPC(victim)
  if not IsValid(victim) then return end

  local class = GetRandomIncubatorNPC()
  if not class then return end

  local pos, ang = GetIncubatorSpawnPosAng(victim)
  if not pos then return end

  local npc = ents.Create(class)
  if not IsValid(npc) then
    print("[TTT2 Incubator] Failed to create NPC:", class)
    return
  end

  npc:SetPos(pos)
  npc:SetAngles(ang)
  npc:Spawn()
  npc:Activate()

  -- Ensure the tracking table exists even if something reset/overwrote it
  if not istable(INCUBATOR.SpawnedNPCs) then
    INCUBATOR.SpawnedNPCs = {}
  end

  -- Track it for cleanup between rounds
  table.insert(INCUBATOR.SpawnedNPCs, npc)

  -- Splat sound at spawn position
  sound.Play(INCUBATOR_SPLAT_SOUND, pos, 75, 100, 1)

  -- Huge blood effect
  SpawnBloodEffect(pos)

  print(string.format("[TTT2 Incubator] Spawned '%s' at %s for %s",
    class, tostring(pos), victim:Nick()))
end

-----------------------
-- HOOKS (SERVER)    --
-----------------------

if SERVER then

  hook.Add("TTTPrepareRound", "ttt2_incubator_reset_prepare", function()
    -- Remove any incubator-spawned NPCs from the previous round
    IncubatorCleanupNPCs()

    for _, p in ipairs(player.GetAll()) do
      p.incubator_spawned_npc = false
    end
  end)

  hook.Add("TTTBeginRound", "ttt2_incubator_reset_begin", function()
    -- Also remove them at begin-round to be extra safe
    IncubatorCleanupNPCs()

    for _, p in ipairs(player.GetAll()) do
      p.incubator_spawned_npc = false
    end
  end)

  hook.Add("PlayerDeath", "ttt2_incubator_spawn_npc_on_death", function(victim, inflictor, attacker)
    if not IsIncubator(victim) then return end
    if victim.incubator_spawned_npc then return end

    victim.incubator_spawned_npc = true

    -- Play growl sound immediately on death at the victim's position
    if IsValid(victim) then
      local pos = victim:GetPos()
      sound.Play(INCUBATOR_GROWL_SOUND, pos, 75, 100, 1)
    end

    -- Spawn the NPC after the delay
    timer.Simple(INCUBATOR_SPAWN_DELAY, function()
      if IsValid(victim) then
        SpawnIncubatorNPC(victim)
      end
    end)
  end)

end