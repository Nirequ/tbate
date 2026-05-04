-- Manages character creation, storage, and customization
-- Handles character slots, race modifications, and appearance

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterConfig = require(Shared:WaitForChild("CharacterConfig"))

local CharacterService = {}
local dataStoreService = nil

-- Apply race-specific modifications to character
function CharacterService.ApplyRaceModifications(character, race)
	local raceData = CharacterConfig.RACES[race]
	if not raceData then
		warn("Invalid race:", race)
		return
	end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	
	local humanoidDescription = humanoid:GetAppliedDescription()
	
	-- Apply height and body type scaling
	humanoidDescription.HeightScale = raceData.HeightScale
	humanoidDescription.WidthScale = raceData.WidthScale
	humanoidDescription.HeadScale = raceData.HeadScale
	humanoidDescription.BodyTypeScale = raceData.BodyTypeScale
	
	humanoid:ApplyDescription(humanoidDescription)
	
	-- Add elf ears if needed
	if raceData.HasEars and raceData.EarAssetId then
		-- TODO: Add ear accessory to character
		-- This requires creating an Accessory instance with the ear mesh
	end
	
	print("Applied race modifications:", race, "to character")
end

-- Tint every hair-style accessory currently parented to the character
local function tintHair(character, color)
	if not color then return end
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Accessory") and descendant.AccessoryType == Enum.AccessoryType.Hair then
			for _, part in ipairs(descendant:GetDescendants()) do
				if part:IsA("BasePart") or part:IsA("MeshPart") then
					part.Color = color
				end
			end
		end
	end
end

-- Apply appearance customization to character
function CharacterService.ApplyAppearance(character, characterData)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	
	local humanoidDescription = humanoid:GetAppliedDescription()
	
	-- Apply skin color
	if characterData.SkinColor then
		local color = characterData.SkinColor
		humanoidDescription.HeadColor = color
		humanoidDescription.TorsoColor = color
		humanoidDescription.LeftArmColor = color
		humanoidDescription.RightArmColor = color
		humanoidDescription.LeftLegColor = color
		humanoidDescription.RightLegColor = color
	end
	
	-- Apply hairstyle
	if characterData.HairstyleIndex then
		local hairstyle = CharacterConfig.HAIRSTYLES[characterData.HairstyleIndex]
		if hairstyle and hairstyle.AssetId > 0 then
			humanoidDescription.HairAccessory = tostring(hairstyle.AssetId)
		else
			humanoidDescription.HairAccessory = ""
		end
	end
	
	-- Apply clothing
	if characterData.ShirtIndex then
		local shirt = CharacterConfig.CLOTHING.Shirts[characterData.ShirtIndex]
		if shirt and shirt.AssetId > 0 then
			humanoidDescription.Shirt = shirt.AssetId
		end
	end
	
	if characterData.PantsIndex then
		local pants = CharacterConfig.CLOTHING.Pants[characterData.PantsIndex]
		if pants and pants.AssetId > 0 then
			humanoidDescription.Pants = pants.AssetId
		end
	end
	
	humanoid:ApplyDescription(humanoidDescription)
	
	-- Hair color is applied after ApplyDescription so it overrides the
	-- accessory's stock color.
	tintHair(character, characterData.HairColor)
	
	print("Applied appearance to character")
end

-- Create a new character in a slot
function CharacterService.CreateCharacter(player, slotIndex, characterData)
	if slotIndex < 1 or slotIndex > CharacterConfig.MAX_SLOTS then
		return false, "Invalid slot index"
	end
	
	-- Check if slot is unlocked
	local playerData = dataStoreService and dataStoreService.GetCharacterSlots(player)
	if not playerData then
		return false, "Failed to load player data"
	end
	
	if not playerData.UnlockedSlots[slotIndex] then
		return false, "Slot is locked"
	end
	
	-- Validate character data
	if not CharacterConfig.RACES[characterData.Race] then
		return false, "Invalid race"
	end
	
	-- Save character data
	if dataStoreService then
		local success = dataStoreService.SaveCharacter(player, slotIndex, characterData)
		if not success then
			return false, "Failed to save character"
		end
	end
	
	print("Created character in slot", slotIndex, "for player:", player.Name)
	return true, "Character created successfully"
end

-- Unlock a character slot (with Robux payment)
function CharacterService.UnlockSlot(player, slotIndex)
	if slotIndex < 1 or slotIndex > CharacterConfig.MAX_SLOTS then
		return false, "Invalid slot index"
	end
	
	if slotIndex == 1 then
		return true, "First slot is always unlocked"
	end
	
	local cost = CharacterConfig.SLOT_COSTS[slotIndex]
	if not cost or cost == 0 then
		return false, "Invalid slot cost"
	end
	
	-- TODO: Implement game pass check for slot unlocking
	-- For now, just unlock the slot
	if dataStoreService then
		dataStoreService.UnlockCharacterSlot(player, slotIndex)
	end
	
	return true, "Slot unlocked"
end

-- Load character and apply to player
function CharacterService.LoadCharacter(player, slotIndex)
	if not dataStoreService then
		return false, "DataStore not initialized"
	end
	
	local characterData = dataStoreService.LoadCharacter(player, slotIndex)
	if not characterData then
		return false, "No character in this slot"
	end
	
	-- Wait for character to spawn
	local character = player.Character or player.CharacterAdded:Wait()
	
	-- Apply race modifications
	CharacterService.ApplyRaceModifications(character, characterData.Race)
	
	-- Apply appearance
	CharacterService.ApplyAppearance(character, characterData)
	
	print("Loaded character from slot", slotIndex, "for player:", player.Name)
	return true, "Character loaded"
end

-- Teleport player to main game after character creation
function CharacterService.TeleportToMainGame(player)
	local placeId = CharacterConfig.MAIN_GAME_PLACE_ID
	if placeId == 0 then
		warn("Main game place ID not set! Skipping teleport for testing.")
		print("Character creation complete for:", player.Name)
		print("In production, player would be teleported to main game.")
		return true, "Character created! (Teleport disabled for testing)"
	end
	
	local success, errorMessage = pcall(function()
		TeleportService:Teleport(placeId, player)
	end)
	
	if not success then
		warn("Failed to teleport player:", errorMessage)
		return false, "Teleport failed"
	end
	
	return true, "Teleporting..."
end

-- Initialize service
function CharacterService.Init(dataStore)
	dataStoreService = dataStore
	print("CharacterService initialized")
end

return CharacterService
