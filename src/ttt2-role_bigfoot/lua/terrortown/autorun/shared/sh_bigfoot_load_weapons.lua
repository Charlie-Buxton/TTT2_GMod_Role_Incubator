-- Load AFTER gamemode init (safe for base classes)
hook.Add("Initialize", "ttt2_bigfoot_load_helpme", function()
  local path = "gamemodes/terrortown/entities/weapons/weapon_ttt2_helpme/shared.lua"

  if SERVER then
    AddCSLuaFile(path) -- send to clients
  end

  if file.Exists(path, "LUA") then
    include(path)
    local ok = weapons and weapons.GetStored and weapons.GetStored("weapon_ttt2_helpme") ~= nil
    print("[Bigfoot] HelpMe loader ran on " .. (SERVER and "SERVER" or "CLIENT") .. " | registered = " .. tostring(ok))
  else
    print("[Bigfoot] HelpMe file missing at: " .. path)
  end
end)