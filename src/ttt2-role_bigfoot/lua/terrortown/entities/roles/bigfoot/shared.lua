if SERVER then
  AddCSLuaFile()
  util.AddNetworkString("ttt2_bigfoot_blackout")    -- 2s blackout overlay
  util.AddNetworkString("ttt2_bigfoot_revived_msg") -- post-revive reminder

  -- ConVars (created here so they always exist)
  if not ConVarExists("ttt2_bigfoot_hp") then
    CreateConVar("ttt2_bigfoot_hp", 300, {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "HP after transforming (default 300)")
  end
  if not ConVarExists("ttt2_bigfoot_popup") then
    CreateConVar("ttt2_bigfoot_popup", 1, {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Show post-revive reminder popup (1/0, default 1)")
  end
end

BIGFOOT = BIGFOOT or {}

function ROLE:PreInitialize()
  -- Lighter brown (Peru)
  self.color = Color(205, 133, 63, 255)
  self.abbr  = "big"

  -- scoring baseline
  self.score.teamKillsMultiplier           = -8
  self.score.killsMultiplier               = 0
  self.score.bodyFoundMuliplier            = 1
  self.score.surviveBonusMultiplier        = 0
  self.score.aliveTeammatesBonusMultiplier = 1
  self.score.allSurviveBonusMultiplier     = 0
  self.score.timelimitMultiplier           = 0
  self.score.suicideMultiplier             = -1

  self.defaultTeam = TEAM_INNOCENT

  -- We manually control sync (Wrath-style concealment)
  self.disableSync      = true
  self.unknownTeam      = true
  self.isPublicRole     = false
  self.isOmniscientRole = false

  self.conVarData = {
    pct = 0.15, maximum = 1, minPlayers = 6,
    credits = 0, shopFallback = SHOP_DISABLED,
    togglable = true, random = 33
  }
end

function ROLE:Initialize()
  roles.SetBaseRole(self, ROLE_INNOCENT)
end

-- ===== helpers =====
local BIGFOOT_MODEL          = "models/player/bigfoot/bigfoot.mdl"  -- << your custom model
local BIGFOOT_MODEL_FALLBACK = "models/player/guerilla.mdl"

local function IsBigfoot(p) return IsValid(p) and p:GetSubRole() == ROLE_BIGFOOT end
local function GetBFHP() local c = GetConVar("ttt2_bigfoot_hp"); return (c and c:GetInt()) or 300 end
local function ShouldShowPopup() local c = GetConVar("ttt2_bigfoot_popup"); return not c or c:GetBool() end

-- Precaches the model on server for faster SetModel (less hitching)
if SERVER then
  util.PrecacheModel(BIGFOOT_MODEL)
end

-- ===== state reset =====
local function BigfootClearState(p)
  if not IsValid(p) then return end
  p.bigfoot_has_revived = false  -- becomes true AFTER revive completes
  p.bigfoot_feral       = false
  p.bigfoot_silenced    = false
  p:SetNWBool("bigfoot_silenced", false)
end

hook.Add("TTTPrepareRound", "ttt2_bigfoot_reset_prepare", function()
  for _, p in ipairs(player.GetAll()) do BigfootClearState(p) end
end)

hook.Add("TTTBeginRound", "ttt2_bigfoot_reset_begin", function()
  for _, p in ipairs(player.GetAll()) do
    if p:GetSubRole() ~= ROLE_BIGFOOT then BigfootClearState(p) end
  end
end)

hook.Add("PlayerSpawn", "ttt2_bigfoot_reset_on_spawn", function(p)
  if p:GetSubRole() ~= ROLE_BIGFOOT then BigfootClearState(p) end
end)

-- ===== role syncing (strict concealment)
-- Before transform: self sees INNOCENT, others see NONE.
-- After transform:  self sees BIGFOOT,  others still see NONE.
if SERVER then
  hook.Add("TTT2SpecialRoleSyncing", "ttt2_bigfoot_conceal_sync", function(viewer, tbl)
    for ply, _ in pairs(tbl) do
      if IsValid(ply) and ply:GetSubRole() == ROLE_BIGFOOT then
        local selfView = (viewer == ply)
        if selfView then
          if ply.bigfoot_has_revived then
            tbl[ply] = {ROLE_BIGFOOT, TEAM_INNOCENT}   -- self after transform
          else
            tbl[ply] = {ROLE_INNOCENT, TEAM_INNOCENT}  -- self before transform
          end
        else
          tbl[ply] = {ROLE_NONE, TEAM_NONE}            -- others never see Bigfoot at all
        end
      end
    end
  end)
end

-- ===== transform (first death) with 2.0s blackout =====
local function SetBigfootPostReviveState(ply)
  if not IsValid(ply) then return end

  -- HP + model
  local hp = math.max(1, GetBFHP())
  ply:SetMaxHealth(hp)
  ply:SetHealth(hp)

  local mdl = util.IsValidModel(BIGFOOT_MODEL) and BIGFOOT_MODEL or BIGFOOT_MODEL_FALLBACK
  ply:SetModel(mdl)

  -- strip all; give & select HelpMe (with small retries for timing)
  ply:StripWeapons()

  timer.Simple(0, function()
    if not IsValid(ply) then return end
    if not IsValid(ply:GetWeapon("weapon_ttt2_helpme")) then
      ply:GiveEquipmentWeapon("weapon_ttt2_helpme")
    end
    if IsValid(ply:GetWeapon("weapon_ttt2_helpme")) then
      ply:SelectWeapon("weapon_ttt2_helpme")
    end
  end)

  timer.Simple(0.2, function()
    if not IsValid(ply) then return end
    if not IsValid(ply:GetWeapon("weapon_ttt2_helpme")) then
      ply:GiveEquipmentWeapon("weapon_ttt2_helpme")
    end
  end)

  -- silence + feral flags
  ply.bigfoot_silenced = true
  ply.bigfoot_feral    = true
  ply:SetNWBool("bigfoot_silenced", true)

  -- mark fully transformed so self-view shows Bigfoot in scoreboard after revive
  ply.bigfoot_has_revived = true

  -- update role sync (self will see Bigfoot; others still none)
  SendFullStateUpdate()

  -- post-revive reminder popup (optional)
  if SERVER and ShouldShowPopup() then
    net.Start("ttt2_bigfoot_revived_msg")
    net.Send(ply)
  end
end

if SERVER then
  local REVIVE_DELAY = 2.0  -- exactly 2 seconds

  hook.Add("PlayerDeath", "ttt2_bigfoot_delayed_revive", function(victim)
    if not IsBigfoot(victim) or victim.bigfoot_has_revived then return end
    if SpecDM and (victim.IsGhost and victim:IsGhost()) then return end

    -- Start client blackout for 2 seconds (shows "You can no longer speak!")
    net.Start("ttt2_bigfoot_blackout")
      net.WriteFloat(CurTime() + REVIVE_DELAY)
    net.Send(victim)

    -- Perform delayed revive
    if isfunction(victim.Revive) then
      victim:Revive(REVIVE_DELAY, function(p)
        if not IsValid(p) then return end
        p:SetRole(ROLE_BIGFOOT, TEAM_INNOCENT)
        SetBigfootPostReviveState(p)
      end, nil, false, REVIVAL_BLOCK_ALL) -- use enum; silence round-end until revived
    else
      timer.Simple(REVIVE_DELAY, function()
        if not IsValid(victim) then return end
        victim:Spawn()
        victim:SetRole(ROLE_BIGFOOT, TEAM_INNOCENT)
        SetBigfootPostReviveState(victim)
      end)
    end
  end)

  -- If something strips on spawn after revive, re-give HelpMe
  hook.Add("PlayerSpawn", "ttt2_bigfoot_helpme_on_spawn", function(ply)
    if not IsValid(ply) then return end
    if ply:GetSubRole() == ROLE_BIGFOOT and ply.bigfoot_feral then
      timer.Simple(0, function()
        if not IsValid(ply) then return end
        if not IsValid(ply:GetWeapon("weapon_ttt2_helpme")) then
          ply:GiveEquipmentWeapon("weapon_ttt2_helpme")
        end
        if IsValid(ply:GetWeapon("weapon_ttt2_helpme")) then
          ply:SelectWeapon("weapon_ttt2_helpme")
        end
      end)
    end
  end)

  -- Block pickups while feral, except HelpMe (or explicit opt-ins)
  hook.Add("PlayerCanPickupWeapon", "ttt2_bigfoot_block_pickups", function(ply, wep)
    if not IsValid(ply) or not IsValid(wep) then return end
    if ply.bigfoot_feral then
      if wep:GetClass() == "weapon_ttt2_helpme" or wep.BigfootAllowed then return end
      return false
    end
  end)

  -- No ordering equipment
  hook.Add("TTT2CanOrderEquipment", "ttt2_bigfoot_no_shop", function(ply)
    if IsBigfoot(ply) then return false end
  end)

  -- Loadout hooks (Alien-style)
  function ROLE:GiveRoleLoadout(ply, isRoleChange)
    if ply.bigfoot_feral then
      ply:GiveEquipmentWeapon("weapon_ttt2_helpme")
    end
  end

  function ROLE:RemoveRoleLoadout(ply, isRoleChange)
    ply:StripWeapon("weapon_ttt2_helpme")
  end
end

-- ===== mute after transform =====
hook.Add("PlayerCanHearPlayersVoice", "ttt2_bigfoot_mute_voice", function(_, talker)
  if IsValid(talker) and talker.bigfoot_silenced then return false, false end
end)

hook.Add("PlayerSay", "ttt2_bigfoot_mute_text", function(ply)
  if IsValid(ply) and ply.bigfoot_silenced then return "" end
end)

-- =====================================================
-- WIN CHECK: Ignore *revived* Bigfoots for victory
-- Intervene ONLY while at least one revived Bigfoot is alive.
-- =====================================================
if SERVER then
  -- Is there any revived Bigfoot alive right now?
  local function anyRevivedBigfootAlive()
    for _, p in ipairs(player.GetAll()) do
      if IsValid(p)
        and p:Alive()
        and p:IsTerror()
        and p:GetSubRole() == ROLE_BIGFOOT
        and p.bigfoot_has_revived
      then
        return true
      end
    end
    return false
  end

  -- Count living teams while treating revived Bigfoots as "ignored"
  local function livingNonBigfootTeams()
    local teams_alive       = { INNOCENT = false, TRAITOR = false, OTHER = false }
    local non_bigfoot_count = 0

    for _, p in ipairs(player.GetAll()) do
      if IsValid(p) and p:Alive() and p:IsTerror() then
        local is_revived_bigfoot =
          (p:GetSubRole() == ROLE_BIGFOOT and p.bigfoot_has_revived)

        -- Skip revived Bigfoots entirely for win calc
        if not is_revived_bigfoot then
          non_bigfoot_count = non_bigfoot_count + 1

          local t = p.GetTeam and p:GetTeam() or nil
          if t == TEAM_TRAITOR then
            teams_alive.TRAITOR = true
          elseif t == TEAM_INNOCENT then
            teams_alive.INNOCENT = true
          else
            teams_alive.OTHER = true
          end
        end
      end
    end

    return teams_alive, non_bigfoot_count
  end

  hook.Add("TTTCheckForWin", "ttt2_bigfoot_ignore_for_win", function()
    -- Only touch win logic while a revived Bigfoot exists
    if not anyRevivedBigfootAlive() then return end

    local teams_alive, non_bigfoot_count = livingNonBigfootTeams()

    -- If there are NO living non-Bigfoots but a revived Bigfoot exists,
    -- keep your original design: traitors win in this case.
    if non_bigfoot_count == 0 then
      return WIN_TRAITOR
    end

    -- If ONLY one real team remains among non-Bigfoots, end in their favor.
    local only_inno  = teams_alive.INNOCENT and not teams_alive.TRAITOR and not teams_alive.OTHER
    local only_trait = teams_alive.TRAITOR  and not teams_alive.INNOCENT and not teams_alive.OTHER

    if only_inno then
      return WIN_INNOCENT
    elseif only_trait then
      return WIN_TRAITOR
    end

    -- Mixed non-Bigfoot teams still alive (e.g. Traitor + Vulture + Heretic) -> do nothing.
    -- Core TTT2 + other roles' win hooks will handle it.
    return
  end)
end

-- ===== client UI: blackout with text + post-revive reminder =====
if CLIENT then
  -- Fonts (define once)
  surface.CreateFont("BF_Bigfoot_Primary", { -- BIG text
    font = "Trebuchet MS", size = 64, weight = 1000, antialias = true, extended = true
  })

  local bf_blackout_end = 0
  net.Receive("ttt2_bigfoot_blackout", function()
    bf_blackout_end = net.ReadFloat()
  end)

  hook.Add("HUDPaint", "ttt2_bigfoot_blackout_paint", function()
    if bf_blackout_end <= CurTime() then return end

    -- full black
    surface.SetDrawColor(0, 0, 0, 255)
    surface.DrawRect(0, 0, ScrW(), ScrH())

    -- centered text (only this line during blackout)
    draw.SimpleTextOutlined("You can no longer speak!", "BF_Bigfoot_Primary",
      ScrW() * 0.5, ScrH() * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
  end)

  -- Post-revive reminder popup (after vision returns) — lasts 8s
  net.Receive("ttt2_bigfoot_revived_msg", function()
    local txt = "You are Bigfoot (Innocent).\nRemain silent — voice & text are disabled."
    local col = Color(205, 133, 63, 255) -- match role lighter brown

    if EPOP and EPOP.AddMessage then
      EPOP:AddMessage({text = txt, color = col}, "", 8)
    else
      chat.AddText(col, "You are Bigfoot (Innocent). Remain silent — voice & text are disabled.")
    end

    surface.PlaySound("buttons/button1.wav")
  end)

  -- Settings UI
  function ROLE:AddToSettingsMenu(parent)
    local form = vgui.CreateTTT2Form(parent, "header_roles_additional")
    form:MakeSlider({
      serverConvar = "ttt2_bigfoot_hp",
      label = "Bigfoot HP after transform",
      min = 1, max = 500, decimal = 0
    })
    form:MakeCheckBox({
      serverConvar = "ttt2_bigfoot_popup",
      label = "Show post-revive reminder popup"
    })
  end
end
