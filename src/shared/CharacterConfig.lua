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
		Name = "Человек",
		Description = "Сбалансированная раса без особых модификаций",
		HeightScale = 1.0,
		WidthScale = 1.0,
		HeadScale = 1.0,
		BodyTypeScale = 1.0,
		HasEars = false,
		EarAssetId = nil
	},
	Elf = {
		Name = "Эльф",
		Description = "Высокая раса с длинными ушами",
		HeightScale = 1.15,
		WidthScale = 0.95,
		HeadScale = 1.0,
		BodyTypeScale = 0.95,
		HasEars = true,
		EarAssetId = 242662351524411  -- TODO: Add elf ear accessory asset ID
	},
	Dwarf = {
		Name = "Дварф",
		Description = "Низкорослая крепкая раса",
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
	{Name = "Короткие волосы", AssetId = 97714842615043},  -- Roblox Boy Hair
	{Name = "Длинные волосы", AssetId = 93559114730036},    -- Beautiful Hair
	{Name = "Женские длинные", AssetId = 140687194936636},           -- Pigtails
	{Name = "Лысый", AssetId = 0}
}

-- Available clothing options (catalog asset IDs)
CharacterConfig.CLOTHING = {
	Shirts = {
		{Name = "Простая рубашка", AssetId = 75963774189458},    -- Red Roblox Jacket
		{Name = "Кожаная броня", AssetId = 127024238577346},      -- Leather Vest
		{Name = "Магическая роба", AssetId = 106568140379876}    -- Wizard Robe
	},
	Pants = {
		{Name = "Простые штаны", AssetId = 1736042024},      -- Jeans
		{Name = "Кожаные штаны", AssetId = 85767393275851},       -- Leather Pants
		{Name = "Магические штаны", AssetId = 4863136941}   -- Wizard Pants
	}
}

-- Available skin colors (palette swatches shown in the editor)
CharacterConfig.SKIN_COLORS = {
	{Name = "Светлая",       Color = Color3.fromRGB(255, 220, 192)},
	{Name = "Бежевая",       Color = Color3.fromRGB(255, 204, 153)},
	{Name = "Загорелая",     Color = Color3.fromRGB(217, 156, 105)},
	{Name = "Смуглая",       Color = Color3.fromRGB(165, 110,  65)},
	{Name = "Тёмная",        Color = Color3.fromRGB(110,  70,  40)},
	{Name = "Очень тёмная",  Color = Color3.fromRGB( 60,  40,  25)},
	{Name = "Эльфийская",    Color = Color3.fromRGB(245, 230, 220)},
}

-- Available hair colors (palette swatches shown in the editor)
CharacterConfig.HAIR_COLORS = {
	{Name = "Чёрный",      Color = Color3.fromRGB( 25,  20,  20)},
	{Name = "Каштановый",  Color = Color3.fromRGB( 80,  50,  30)},
	{Name = "Коричневый",  Color = Color3.fromRGB(139,  69,  19)},
	{Name = "Русый",       Color = Color3.fromRGB(170, 130,  80)},
	{Name = "Блонд",       Color = Color3.fromRGB(230, 200, 130)},
	{Name = "Платиновый",  Color = Color3.fromRGB(240, 235, 220)},
	{Name = "Рыжий",       Color = Color3.fromRGB(200,  90,  30)},
	{Name = "Серебряный",  Color = Color3.fromRGB(190, 195, 200)},
	{Name = "Синий",       Color = Color3.fromRGB( 40,  90, 180)},
}

-- Default character appearance
CharacterConfig.DEFAULT_CHARACTER = {
	Race = "Human",
	HairstyleIndex = 1,
	ShirtIndex = 1,
	PantsIndex = 1,
	SkinColorIndex = 2,
	HairColorIndex = 3,
	SkinColor = Color3.fromRGB(255, 204, 153),
	HairColor = Color3.fromRGB(139, 69, 19)
}

-- Teleport configuration
-- ВАЖНО: Замените 0 на Place ID вашего основного игрового места
-- Получить Place ID можно на create.roblox.com в разделе Places
CharacterConfig.MAIN_GAME_PLACE_ID = 87736930204659  -- TODO: Set your main game place ID

return CharacterConfig
