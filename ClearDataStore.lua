-- Wipes saved character slots for everyone currently in the server.
-- Paste this into Studio's Command Bar (Server context) and press Enter.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

-- Must match the DataStore name in src/server/services/DataStoreService.lua.
local CharacterDataStore = DataStoreService:GetDataStore("CharacterData_v2")

-- Clear saved data for every player currently in the game.
for _, player in pairs(Players:GetPlayers()) do
	local success, err = pcall(function()
		CharacterDataStore:RemoveAsync("Player_" .. player.UserId)
	end)
	
	if success then
		print("Cleared data for:", player.Name)
	else
		warn("Failed to clear data for:", player.Name, err)
	end
end

print("Data cleared! Restart the game to see changes.")
