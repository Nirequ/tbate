-- Скрипт для очистки данных персонажей
-- Вставьте этот код в Command Bar в Studio и нажмите Enter

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local CharacterDataStore = DataStoreService:GetDataStore("CharacterData_v1")

-- Очистить данные для всех игроков в игре
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
