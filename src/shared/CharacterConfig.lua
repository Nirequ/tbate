-- Configuration for character creation system
-- Defines races, customization options, and slot costs

local CharacterConfig = {}

-- Character slots configuration
CharacterConfig.MAX_SLOTS = 3
CharacterConfig.SLOT_COSTS = {
	[1] = 0,      -- First slot is free
	[2] = 100,    -- Second slot costs 100 Robux
	[3] = 100     -- Third slot costs 100 Robux
}

-- Race definitions with their visual modifications
CharacterConfig.RACES = {
	Human = {
		Name = "Human",
		Description = "Balanced race with no special modifiers",
		HeightScale = 1.0,
		WidthScale = 1.0,
		HeadScale = 1.0,
		BodyTypeScale = 1.0,
		HasEars = false,
		EarAssetId = nil
	},
	Elf = {
		Name = "Elf",
		Description = "Tall race with long ears",
		HeightScale = 1.15,
		WidthScale = 0.95,
		HeadScale = 1.0,
		BodyTypeScale = 0.95,
		HasEars = true,
		EarAssetId = 242662351524411
	},
	Dwarf = {
		Name = "Dwarf",
		Description = "Short and sturdy race",
		HeightScale = 0.75,
		WidthScale = 1.15,
		HeadScale = 1.1,
		BodyTypeScale = 1.2,
		HasEars = false,
		EarAssetId = nil
	}
}

-- Available hairstyles (catalog asset IDs)
CharacterConfig.HAIRSTYLES = {
	{Name = "Short hair",       AssetId = 97714842615043},
	{Name = "Long hair",        AssetId = 93559114730036},
	{Name = "Long hair (alt)",  AssetId = 140687194936636},
	{Name = "Bald",             AssetId = 0}
}

-- Available faces (catalog Decal asset IDs). Roblox stores a face as a
-- single decal that lives on the front of the head — eyes and mouth
-- are baked into the same image, so each entry here is a complete
-- expression. Swap these IDs for whatever Public Decals you want; the
-- ones below are stock Roblox faces.
CharacterConfig.FACES = {
	{Name = "Smile",     AssetId = 7074786},
	{Name = "Cheerful",  AssetId = 28999228},
	{Name = "Sly",       AssetId = 7074774},
	{Name = "Surprised", AssetId = 7074825},
	{Name = "No face",   AssetId = 0}
}

-- Available clothing options (catalog asset IDs)
CharacterConfig.CLOTHING = {
	Shirts = {
		{Name = "Shirt 1", AssetId = 113764433325496},
		{Name = "Shirt 2", AssetId = 5261079458},
		{Name = "Shirt 3", AssetId = 113319764815263}
	},
	Pants = {
		{Name = "Pants 1", AssetId = 1736042024},
		{Name = "Pants 2", AssetId = 12551073709},
		{Name = "Pants 3", AssetId = 9157798320}
	}
}

-- Default character appearance. Skin/hair colors are picked freely via the
-- in-game RGB color picker, so we only ship one set of starting Color3
-- values here — no palette indices.
CharacterConfig.DEFAULT_CHARACTER = {
	Race = "Human",
	HairstyleIndex = 1,
	FaceIndex = 1,
	ShirtIndex = 1,
	PantsIndex = 1,
	SkinColor = Color3.fromRGB(255, 204, 153),
	HairColor = Color3.fromRGB(255, 255, 255)
}

-- Teleport configuration
-- IMPORTANT: replace this with the Place ID of your main game place.
-- You can find the Place ID at create.roblox.com under Places.
CharacterConfig.MAIN_GAME_PLACE_ID = 87736930204659

return CharacterConfig
