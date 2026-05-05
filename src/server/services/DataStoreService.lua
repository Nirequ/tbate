-- Manages DataStore operations for character data
-- Handles saving/loading character slots and character customization data

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterConfig = require(Shared:WaitForChild("CharacterConfig"))

local CharacterDataStore = DataStoreService:GetDataStore("CharacterData_v2")  -- Изменили v1 на v2

local DataStore = {}

-- Get player's character slots data
function DataStore.GetCharacterSlots(player)
	local userId = player.UserId
	local success, data = pcall(function()
		return CharacterDataStore:GetAsync("Player_" .. userId)
	end)
	
	if not success then
		warn("Failed to load character data for player:", player.Name)
		return nil
	end
	
	-- Return default data if no saved data exists
	if not data then
		return {
			UnlockedSlots = {true, false, false}, -- Only first slot unlocked by default
			Characters = {nil, nil, nil}
		}
	end
	
	return data
end

-- Save character data to a specific slot
function DataStore.SaveCharacter(player, slotIndex, characterData)
	local userId = player.UserId
	
	-- Convert Color3 to table for DataStore
	local dataToSave = {
		Race = characterData.Race,
		HairstyleIndex = characterData.HairstyleIndex,
		FaceIndex = characterData.FaceIndex,
		ShirtIndex = characterData.ShirtIndex,
		PantsIndex = characterData.PantsIndex,
		SkinColor = {characterData.SkinColor.R, characterData.SkinColor.G, characterData.SkinColor.B},
		HairColor = {characterData.HairColor.R, characterData.HairColor.G, characterData.HairColor.B}
	}
	
	local success, err = pcall(function()
		local data = CharacterDataStore:GetAsync("Player_" .. userId) or {
			UnlockedSlots = {true, false, false},
			Characters = {nil, nil, nil}
		}
		
		-- Save character to slot
		data.Characters[slotIndex] = dataToSave
		
		CharacterDataStore:SetAsync("Player_" .. userId, data)
	end)
	
	if not success then
		warn("Failed to save character for player:", player.Name, "Error:", err)
		return false
	end
	
	print("Saved character to slot", slotIndex, "for player:", player.Name)
	return true
end

-- Load character from a specific slot
function DataStore.LoadCharacter(player, slotIndex)
	local data = DataStore.GetCharacterSlots(player)
	if not data then
		return nil
	end
	
	local characterData = data.Characters[slotIndex]
	if not characterData then
		return nil
	end
	
	-- Convert color tables back to Color3
	if characterData.SkinColor and type(characterData.SkinColor) == "table" then
		characterData.SkinColor = Color3.new(
			characterData.SkinColor[1],
			characterData.SkinColor[2],
			characterData.SkinColor[3]
		)
	end
	
	if characterData.HairColor and type(characterData.HairColor) == "table" then
		characterData.HairColor = Color3.new(
			characterData.HairColor[1],
			characterData.HairColor[2],
			characterData.HairColor[3]
		)
	end
	
	return characterData
end

-- Unlock a character slot
function DataStore.UnlockCharacterSlot(player, slotIndex)
	local userId = player.UserId
	
	local success, err = pcall(function()
		local data = CharacterDataStore:GetAsync("Player_" .. userId) or {
			UnlockedSlots = {true, false, false},
			Characters = {nil, nil, nil}
		}
		
		data.UnlockedSlots[slotIndex] = true
		
		CharacterDataStore:SetAsync("Player_" .. userId, data)
	end)
	
	if not success then
		warn("Failed to unlock slot for player:", player.Name, "Error:", err)
		return false
	end
	
	print("Unlocked slot", slotIndex, "for player:", player.Name)
	return true
end

-- Delete character from a slot
function DataStore.DeleteCharacter(player, slotIndex)
	local userId = player.UserId
	
	local success, err = pcall(function()
		local data = CharacterDataStore:GetAsync("Player_" .. userId)
		if not data then return end
		
		data.Characters[slotIndex] = nil
		
		CharacterDataStore:SetAsync("Player_" .. userId, data)
	end)
	
	if not success then
		warn("Failed to delete character for player:", player.Name, "Error:", err)
		return false
	end
	
	print("Deleted character from slot", slotIndex, "for player:", player.Name)
	return true
end

-- Wipe ALL character slot data for a player (debug-only).
-- Used by the in-game "Reset slots" button in Studio so we can
-- iterate on character creation without manually clearing the DataStore.
-- The caller (init.server.lua) is responsible for gating this with
-- RunService:IsStudio() so it can never be invoked from a live game.
function DataStore.ResetCharacterSlots(player)
	local userId = player.UserId
	local success, err = pcall(function()
		CharacterDataStore:RemoveAsync("Player_" .. userId)
	end)
	if not success then
		warn("Failed to reset slots for player:", player.Name, "Error:", err)
		return false
	end
	print("Reset all slots for player:", player.Name)
	return true
end

-- Initialize service
function DataStore.Init()
	print("DataStoreService initialized")
end

return DataStore
