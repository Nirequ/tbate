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

-- Build a HumanoidDescription pre-populated with race scales / character
-- colors. Used to spawn a fresh R6 character so the rig is always blocky.
local function BuildDescription(characterData)
	local description = Instance.new("HumanoidDescription")
	if characterData then
		local race = RACES[characterData.Race]
		if race then
			description.HeightScale = race.HeightScale
			description.WidthScale = race.WidthScale
			description.HeadScale = race.HeadScale
			description.BodyTypeScale = race.BodyTypeScale
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
	end
	return description
end

-- Применить характеристики расы к персонажу (на случай если описание
-- было применено не полностью — например, рёлоадим существующего).
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

-- Отключаем автоспавн, чтобы строить R6-риг вручную из HumanoidDescription
Players.CharacterAutoLoads = false

-- Найти место спавна (SpawnLocation в Workspace) или дать запасную точку.
local function GetSpawnCFrame()
	local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
	if spawn then
		return spawn.CFrame + Vector3.new(0, 5, 0)
	end
	return CFrame.new(0, 10, 0)
end

-- Спавн R6-персонажа с применённой внешностью.
local function SpawnCharacter(player, characterData)
	-- Удалить предыдущего персонажа, если он остался
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

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		rootPart.CFrame = GetSpawnCFrame()
	end

	character.Parent = workspace
	player.Character = character

	-- Авто-респавн при смерти
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

-- Загрузить персонажа игрока
local function LoadPlayerCharacter(player)
	print("Loading character for player:", player.Name)
	
	-- Загрузить данные из DataStore
	local success, data = pcall(function()
		return CharacterDataStore:GetAsync("Player_" .. player.UserId)
	end)
	
	if not success then
		warn("Failed to load character data for:", player.Name)
	end
	
	-- Найти активного персонажа (последний созданный) — может быть nil
	local activeCharacter = nil
	if data and data.Characters then
		for i = 1, 3 do
			if data.Characters[i] then
				activeCharacter = data.Characters[i]
				break
			end
		end
	end

	if not activeCharacter then
		warn("No active character found for:", player.Name, "- spawning default R6 character")
	else
		print("Found character data:", activeCharacter.Race)
	end

	-- Спавним R6-риг с уже применёнными scales и цветом кожи
	local character = SpawnCharacter(player, activeCharacter)
	if not character then
		return
	end

	-- Дополнительно применить аксессуары / цвет волос (то, что не входит
	-- в HumanoidDescription напрямую).
	if activeCharacter then
		ApplyRaceModifications(character, activeCharacter.Race)
		ApplyAppearance(character, activeCharacter)
	end

	-- Сохранить данные персонажа в player для доступа из других скриптов
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

-- Обработка входа игрока
Players.PlayerAdded:Connect(function(player)
	print("Player joined:", player.Name)
	LoadPlayerCharacter(player)
end)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(LoadPlayerCharacter, player)
end

print("=== TBATE RPG Main Game Server Ready ===")
print("Waiting for players...")
