-- Main Game Server Script
-- Загружает персонажей игроков из DataStore и применяет их характеристики

print("=== TBATE RPG Main Game Server Starting ===")

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- DataStore (должен совпадать с Character Creation Place)
local CharacterDataStore = DataStoreService:GetDataStore("CharacterData_v1")

-- Конфигурация рас (скопируйте из CharacterConfig.lua)
local RACES = {
	Human = {
		Name = "Человек",
		HeightScale = 1.0,
		WidthScale = 1.0,
		HeadScale = 1.0,
		BodyTypeScale = 1.0,
	},
	Elf = {
		Name = "Эльф",
		HeightScale = 1.15,
		WidthScale = 0.95,
		HeadScale = 1.0,
		BodyTypeScale = 0.95,
	},
	Dwarf = {
		Name = "Дварф",
		HeightScale = 0.75,
		WidthScale = 1.15,
		HeadScale = 1.1,
		BodyTypeScale = 1.2,
	}
}

-- Применить характеристики расы к персонажу
local function ApplyRaceModifications(character, race)
	local raceData = RACES[race]
	if not raceData then
		warn("Invalid race:", race)
		return
	end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	
	local humanoidDescription = humanoid:GetAppliedDescription()
	
	-- Применить модификации расы
	humanoidDescription.HeightScale = raceData.HeightScale
	humanoidDescription.WidthScale = raceData.WidthScale
	humanoidDescription.HeadScale = raceData.HeadScale
	humanoidDescription.BodyTypeScale = raceData.BodyTypeScale
	
	humanoid:ApplyDescription(humanoidDescription)
	
	print("Applied race modifications:", race, "to", character.Name)
end

-- Tint every hair-style accessory currently parented to the character
local function TintHair(character, color)
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

-- Применить внешность персонажа
local function ApplyAppearance(character, characterData)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	
	local humanoidDescription = humanoid:GetAppliedDescription()
	
	-- Применить цвет кожи
	if characterData.SkinColor then
		local color = characterData.SkinColor
		humanoidDescription.HeadColor = color
		humanoidDescription.TorsoColor = color
		humanoidDescription.LeftArmColor = color
		humanoidDescription.RightArmColor = color
		humanoidDescription.LeftLegColor = color
		humanoidDescription.RightLegColor = color
	end
	
	-- TODO: Применить прическу и одежду по AssetId
	
	humanoid:ApplyDescription(humanoidDescription)
	
	-- Применить цвет волос (после ApplyDescription)
	TintHair(character, characterData.HairColor)
	
	print("Applied appearance to", character.Name)
end

-- Загрузить персонажа игрока
local function LoadPlayerCharacter(player)
	print("Loading character for player:", player.Name)
	
	-- Загрузить данные из DataStore
	local success, data = pcall(function()
		return CharacterDataStore:GetAsync("Player_" .. player.UserId)
	end)
	
	if not success then
		warn("Failed to load character data for:", player.Name)
		return
	end
	
	if not data or not data.Characters then
		warn("No character data found for:", player.Name)
		return
	end
	
	-- Найти активного персонажа (последний созданный)
	local activeCharacter = nil
	for i = 1, 3 do
		if data.Characters[i] then
			activeCharacter = data.Characters[i]
			break
		end
	end
	
	if not activeCharacter then
		warn("No active character found for:", player.Name)
		return
	end
	
	print("Found character data:", activeCharacter.Race)
	
	-- Дождаться появления персонажа
	local character = player.Character or player.CharacterAdded:Wait()
	
	-- Применить расу и внешность
	ApplyRaceModifications(character, activeCharacter.Race)
	ApplyAppearance(character, activeCharacter)
	
	-- Сохранить данные персонажа в player для доступа из других скриптов
	local characterDataValue = Instance.new("Folder")
	characterDataValue.Name = "CharacterData"
	characterDataValue.Parent = player
	
	local raceValue = Instance.new("StringValue")
	raceValue.Name = "Race"
	raceValue.Value = activeCharacter.Race
	raceValue.Parent = characterDataValue
	
	print("Character loaded successfully for:", player.Name)
end

-- Обработка входа игрока
Players.PlayerAdded:Connect(function(player)
	print("Player joined:", player.Name)
	
	-- Загрузить персонажа при первом спавне
	player.CharacterAdded:Connect(function(character)
		task.wait(0.5) -- Небольшая задержка для загрузки персонажа
		LoadPlayerCharacter(player)
	end)
	
	-- Если персонаж уже есть
	if player.Character then
		task.wait(0.5)
		LoadPlayerCharacter(player)
	end
end)

print("=== TBATE RPG Main Game Server Ready ===")
print("Waiting for players...")
