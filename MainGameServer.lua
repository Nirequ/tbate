-- Main Game Server (standalone for Place 2 — the actual gameplay
-- place that the character-creation place teleports the player to).
--
-- This script lives outside src/ because it ships with Place 2, which
-- is a SEPARATE Roblox place from the character-creation place. The
-- two places share a DataStore name but they cannot share Roblox
-- ModuleScripts the way the rest of the project does — every script
-- under ReplicatedStorage / ServerScriptService is per-place.
--
-- IMPORTANT — keeping CONFIG in sync:
-- The CONFIG table below MUST mirror src/shared/CharacterConfig.lua.
-- When you change race / asset IDs in CharacterConfig, copy the new
-- values into CONFIG here as well, otherwise teleported players spawn
-- with stale clothing / faces / scaling.

print("=== TBATE RPG Main Game Server Starting ===")

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

-- Must match the DataStore name used by the character-creation place
-- (src/server/services/DataStoreService.lua), otherwise saved
-- characters won't load here after teleport.
local CharacterDataStore = DataStoreService:GetDataStore("CharacterData_v2")

-- =================================================================
-- CONFIG — keep in sync with src/shared/CharacterConfig.lua.
-- =================================================================
local CONFIG = {
	RACES = {
		Human = {
			HeightScale = 1.0, WidthScale = 1.0,
			HeadScale = 1.0,  BodyTypeScale = 1.0,
			HasEars = false,  EarAssetId = nil,
		},
		Elf = {
			HeightScale = 1.15, WidthScale = 0.95,
			HeadScale = 1.0,    BodyTypeScale = 0.95,
			HasEars = true,     EarAssetId = 242662351524411,
		},
		Dwarf = {
			HeightScale = 0.75, WidthScale = 1.15,
			HeadScale = 1.1,    BodyTypeScale = 1.2,
			HasEars = false,    EarAssetId = nil,
		},
	},
	-- Indexed asset arrays. The character-creation editor stores the
	-- player's pick as an index into the corresponding array; we look
	-- the asset ID up by that index here.
	HAIRSTYLES = { 97714842615043, 93559114730036, 140687194936636, 0 },
	FACES      = {       7074786,       28999228,        7074774, 7074825, 0 },
	SHIRTS     = { 113764433325496,     5261079458, 113319764815263 },
	PANTS      = {      1736042024,    12551073709,      9157798320 },
}

-- =================================================================
-- HumanoidDescription construction.
-- =================================================================

-- Build a HumanoidDescription that fully matches what the player
-- picked in the editor: race scales (cosmetic only on R6 — the actual
-- visual scaling happens via Model:ScaleTo in SpawnCharacter), skin
-- color, hair, ears, face, shirt, pants.
local function BuildDescription(characterData)
	local description = Instance.new("HumanoidDescription")
	if not characterData then
		return description
	end

	local race = CONFIG.RACES[characterData.Race]
	if race then
		description.HeightScale = race.HeightScale
		description.WidthScale = race.WidthScale
		description.HeadScale = race.HeadScale
		description.BodyTypeScale = race.BodyTypeScale
		if race.HasEars and race.EarAssetId and race.EarAssetId > 0 then
			description.HatAccessory = tostring(race.EarAssetId)
		end
	end

	if characterData.SkinColor then
		local c = characterData.SkinColor
		description.HeadColor = c
		description.TorsoColor = c
		description.LeftArmColor = c
		description.RightArmColor = c
		description.LeftLegColor = c
		description.RightLegColor = c
	end

	-- Helper for "look up asset id by index, set field if nonzero".
	local function setIfPresent(arr, idx, fieldName, asString)
		local id = arr[idx]
		if id and id > 0 then
			description[fieldName] = asString and tostring(id) or id
		end
	end

	setIfPresent(CONFIG.HAIRSTYLES, characterData.HairstyleIndex, "HairAccessory", true)
	setIfPresent(CONFIG.FACES,      characterData.FaceIndex,      "Face",          false)
	setIfPresent(CONFIG.SHIRTS,     characterData.ShirtIndex,     "Shirt",         false)
	setIfPresent(CONFIG.PANTS,      characterData.PantsIndex,     "Pants",         false)

	return description
end

-- =================================================================
-- Hair recolouring after spawn.
-- =================================================================

local function isHairAccessory(accessory)
	if accessory.AccessoryType == Enum.AccessoryType.Hair then
		return true
	end
	return accessory.Name:lower():find("hair") ~= nil
end

local function tintAccessory(accessory, color)
	for _, part in ipairs(accessory:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Color = color
		elseif part:IsA("SpecialMesh") then
			part.VertexColor = Vector3.new(color.R, color.G, color.B)
		elseif part:IsA("SurfaceAppearance") then
			pcall(function()
				part.ColorMap = ""
				part.AlphaMode = Enum.AlphaMode.Overlay
			end)
		end
	end
end

-- Tint every hair-style accessory currently parented to the character.
-- Mirrors the client logic: covers BasePart.Color, SpecialMesh.VertexColor,
-- and SurfaceAppearance.ColorMap so the chosen color shows up regardless
-- of how the catalog asset was authored.
local function TintHair(character, color)
	if not color then return end
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Accessory") and isHairAccessory(descendant) then
			tintAccessory(descendant, color)
		end
	end
end

-- =================================================================
-- Spawning.
-- =================================================================

-- Disable autospawn — we build the R6 rig manually from the
-- HumanoidDescription so the character is always blocky.
Players.CharacterAutoLoads = false

local function GetSpawnCFrame()
	local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
	if spawn then
		return spawn.CFrame + Vector3.new(0, 5, 0)
	end
	return CFrame.new(0, 10, 0)
end

local function SpawnCharacter(player, characterData)
	if player.Character then
		player.Character:Destroy()
	end

	local description = BuildDescription(characterData)
	local ok, character = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	end)
	if not ok or not character then
		warn("Failed to build R6 character for:", player.Name, character)
		return nil
	end

	character.Name = player.Name
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.RigType = Enum.HumanoidRigType.R6
		humanoid.DisplayName = player.DisplayName
	end

	-- R6 ignores HumanoidDescription scale fields, so apply the race
	-- height ratio uniformly via Model:ScaleTo. Same approach as the
	-- editor preview so the spawned character matches it visually.
	local raceData = characterData and CONFIG.RACES[characterData.Race]
	local raceScale = (raceData and raceData.HeightScale) or 1.0
	pcall(function()
		character:ScaleTo(raceScale)
	end)

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		rootPart.CFrame = GetSpawnCFrame()
	end

	character.Parent = workspace
	player.Character = character

	if humanoid then
		humanoid.Died:Connect(function()
			task.wait(Players.RespawnTime)
			if player.Parent then
				SpawnCharacter(player, characterData)
			end
		end)
	end

	return character
end

-- =================================================================
-- Loading.
-- =================================================================

-- Pull saved character data from the DataStore, pick the first non-
-- empty slot as the active character, spawn it, and re-apply hair
-- colour (BuildDescription already covers everything else).
local function LoadPlayerCharacter(player)
	print("Loading character for player:", player.Name)

	local success, data = pcall(function()
		return CharacterDataStore:GetAsync("Player_" .. player.UserId)
	end)
	if not success then
		warn("Failed to load character data for:", player.Name)
	end

	local activeCharacter = nil
	if data and data.Characters then
		for i = 1, 3 do
			if data.Characters[i] then
				activeCharacter = data.Characters[i]
				break
			end
		end
	end

	if activeCharacter then
		print("Found character data:", activeCharacter.Race)
	else
		warn("No active character found for:", player.Name, "- spawning default R6 character")
	end

	local character = SpawnCharacter(player, activeCharacter)
	if not character then return end

	-- Hair colour isn't part of HumanoidDescription, so apply it after
	-- spawning. Skin colour, accessories and clothing already came
	-- through the description.
	if activeCharacter then
		TintHair(character, activeCharacter.HairColor)
	end

	-- Expose the loaded race to other scripts via player.CharacterData.
	local existing = player:FindFirstChild("CharacterData")
	if existing then existing:Destroy() end

	local characterDataValue = Instance.new("Folder")
	characterDataValue.Name = "CharacterData"
	characterDataValue.Parent = player

	local raceValue = Instance.new("StringValue")
	raceValue.Name = "Race"
	raceValue.Value = (activeCharacter and activeCharacter.Race) or "Human"
	raceValue.Parent = characterDataValue

	print("Character loaded successfully for:", player.Name)
end

-- =================================================================
-- Wire up player join / already-present.
-- =================================================================
Players.PlayerAdded:Connect(function(player)
	print("Player joined:", player.Name)
	LoadPlayerCharacter(player)
end)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(LoadPlayerCharacter, player)
end

print("=== TBATE RPG Main Game Server Ready ===")
print("Waiting for players...")
