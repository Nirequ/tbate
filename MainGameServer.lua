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
		HasEars = false,
		EarAssetId = nil,
	},
	Elf = {
		Name = "Эльф",
		HeightScale = 1.15,
		WidthScale = 0.95,
		HeadScale = 1.0,
		BodyTypeScale = 0.95,
		HasEars = true,
		EarAssetId = 242662351524411,
	},
	Dwarf = {
		Name = "Дварф",
		HeightScale = 0.75,
		WidthScale = 1.15,
		HeadScale = 1.1,
		BodyTypeScale = 1.2,
		HasEars = false,
		EarAssetId = nil,
	}
}

-- Asset ID лежат в HumanoidDescription.HairAccessory / Face / Shirt /
-- Pants; держим список в этом скрипте чтобы не дёргать общий конфиг
-- (это standalone-скрипт для Place 2). Если меняешь shared/CharacterConfig
-- — продублируй значения сюда же, иначе персонаж в основном игровом
-- месте загрузится со старой одеждой/лицом.
local HAIRSTYLES = {
	[1] = 97714842615043,
	[2] = 93559114730036,
	[3] = 140687194936636,
	[4] = 0,
}
local FACES = {
	[1] = 7074786,
	[2] = 28999228,
	[3] = 7074774,
	[4] = 7074825,
	[5] = 0,
}
local SHIRTS = {
	[1] = 113764433325496,
	[2] = 5261079458,
	[3] = 113319764815263,
}
local PANTS = {
	[1] = 1736042024,
	[2] = 12551073709,
	[3] = 9157798320,
}

-- Build a HumanoidDescription that fully matches what the player picked
-- in the editor: race scales, skin color, hair, ears, shirt, pants. Used
-- to spawn a fresh R6 character so the rig is always blocky.
local function BuildDescription(characterData)
	local description = Instance.new("HumanoidDescription")
	if not characterData then
		return description
	end

	local race = RACES[characterData.Race]
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

	local hairId = HAIRSTYLES[characterData.HairstyleIndex]
	if hairId and hairId > 0 then
		description.HairAccessory = tostring(hairId)
	end

	local faceId = FACES[characterData.FaceIndex]
	if faceId and faceId > 0 then
		description.Face = faceId
	end

	local shirtId = SHIRTS[characterData.ShirtIndex]
	if shirtId and shirtId > 0 then
		description.Shirt = shirtId
	end
	local pantsId = PANTS[characterData.PantsIndex]
	if pantsId and pantsId > 0 then
		description.Pants = pantsId
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

-- Tint every hair-style accessory currently parented to the character.
-- Mirrors the client logic: covers BasePart.Color, SpecialMesh.VertexColor,
-- and SurfaceAppearance.ColorMap so the chosen color shows up regardless
-- of how the catalog asset was authored.
local function TintHair(character, color)
	if not color then return end
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Accessory") then
			local isHair = descendant.AccessoryType == Enum.AccessoryType.Hair
			if not isHair then
				isHair = descendant.Name:lower():find("hair") ~= nil
			end
			if isHair then
				for _, part in ipairs(descendant:GetDescendants()) do
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
		end
	end
end

-- BuildDescription уже включает hair / shirt / pants / ears / colors,
-- так что ApplyAppearance остаётся только подкрасить волосы (это
-- делается после ApplyDescription, чтобы не быть перезаписанным).
local function ApplyAppearance(character, characterData)
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

	-- R6 ignores HumanoidDescription scale fields, so apply the race
	-- height ratio uniformly via Model:ScaleTo. Same approach as the
	-- editor preview so the spawned character matches it visually.
	local raceData = characterData and RACES[characterData.Race]
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
