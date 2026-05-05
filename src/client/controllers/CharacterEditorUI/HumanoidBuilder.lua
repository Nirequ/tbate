-- HumanoidBuilder
-- Pure helpers for building / recolouring R6 character rigs from a
-- HumanoidDescription. No editor state lives here — every function
-- takes the rig (and any colour) it operates on.
--
-- Used by both the in-world preview (CharacterEditorUI/init.lua) and
-- the mini-preview thumbnails (UIBuilder.CreateMiniPreviewButton).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterConfig = require(Shared:WaitForChild("CharacterConfig"))

local DEFAULT_SKIN = CharacterConfig.DEFAULT_CHARACTER.SkinColor or Color3.fromRGB(255, 204, 153)

local HumanoidBuilder = {}

HumanoidBuilder.DEFAULT_SKIN = DEFAULT_SKIN

-- Hair-like accessory enum values that should be tinted by hair color
local HAIR_ACCESSORY_TYPES = {
	[Enum.AccessoryType.Hair] = true,
}

-- R6 body part names that should be tinted by skin color.
local R6_BODY_PARTS = {
	Head = true,
	Torso = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
}

-- Directly set BasePart.Color on every R6 body part.
function HumanoidBuilder.SetSkinColor(character, color)
	if not character or not color then return end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("BasePart") and R6_BODY_PARTS[child.Name] then
			child.Color = color
		end
	end
end

-- Build a fresh blocky R6 rig with the given description applied. Used
-- both for the in-world player preview and for the mini-preview thumbnails
-- shown next to each hairstyle / clothing entry in the option list.
function HumanoidBuilder.BuildR6Rig(description)
	description = description or Instance.new("HumanoidDescription")
	if description.HeadColor == Color3.new(0, 0, 0) then
		description.HeadColor = DEFAULT_SKIN
		description.TorsoColor = DEFAULT_SKIN
		description.LeftArmColor = DEFAULT_SKIN
		description.RightArmColor = DEFAULT_SKIN
		description.LeftLegColor = DEFAULT_SKIN
		description.RightLegColor = DEFAULT_SKIN
	end

	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	end)
	if not ok or not rig then
		warn("HumanoidBuilder: failed to build R6 rig:", rig)
		return nil
	end

	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.RigType = Enum.HumanoidRigType.R6
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		-- Hide the floating name / health gui that Roblox renders
		-- above every Humanoid by default.
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.NameDisplayDistance = 0
		humanoid.HealthDisplayDistance = 0
		humanoid.DisplayName = ""
	end
	HumanoidBuilder.SetSkinColor(rig, description.HeadColor)
	return rig
end

function HumanoidBuilder.IsHairAccessory(accessory)
	if HAIR_ACCESSORY_TYPES[accessory.AccessoryType] then
		return true
	end
	local name = accessory.Name:lower()
	return name:find("hair") ~= nil
end

-- Recolor every renderable bit of an Accessory. Different catalog hair
-- assets render through different mechanisms — some use BasePart.Color
-- directly, some use SpecialMesh + VertexColor, some use MeshPart with
-- a baked TextureID, some use SurfaceAppearance. To make slider changes
-- actually visible we have to touch all of them.
local function TintAccessoryParts(accessory, color)
	for _, descendant in ipairs(accessory:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Color = color
		elseif descendant:IsA("SpecialMesh") then
			-- VertexColor multiplies against the mesh texture. White (1,1,1)
			-- shows the original texture; tint colors stain it.
			descendant.VertexColor = Vector3.new(color.R, color.G, color.B)
		elseif descendant:IsA("SurfaceAppearance") then
			-- Catalog hair using PBR SurfaceAppearance fully overrides
			-- BasePart.Color. There is no "tint" property; the only way to
			-- let our color through is to remove the override texture.
			pcall(function()
				descendant.ColorMap = ""
				descendant.AlphaMode = Enum.AlphaMode.Overlay
			end)
		end
	end
end

function HumanoidBuilder.TintHair(model, color)
	if not model or not color then return end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Accessory") and HumanoidBuilder.IsHairAccessory(descendant) then
			TintAccessoryParts(descendant, color)
		end
	end
end

-- Build a HumanoidDescription from a `selection` table:
--   { race = "Human", hairstyleIndex = 1, faceIndex = 1,
--     shirtIndex = 1, pantsIndex = 1,
--     skinColor = Color3, hairColor = Color3 (unused — applied post-build) }
function HumanoidBuilder.BuildSelectionDescription(selection)
	local description = Instance.new("HumanoidDescription")

	local raceData = CharacterConfig.RACES[selection.race]
	if raceData then
		description.HeightScale = raceData.HeightScale
		description.WidthScale = raceData.WidthScale
		description.HeadScale = raceData.HeadScale
		description.BodyTypeScale = raceData.BodyTypeScale
		-- R6 ignores HumanoidDescription scale fields — those only work on
		-- R15. We still set them above for any code that reads them back
		-- (DataStore round-trip), but the actual visual scaling for R6
		-- happens via Model:ScaleTo() in the spawn pipeline.

		-- Race-specific accessories (e.g. elf ears) ride along on the
		-- HatAccessory CSV slot so they don't conflict with the chosen
		-- HairAccessory.
		if raceData.HasEars and raceData.EarAssetId and raceData.EarAssetId > 0 then
			description.HatAccessory = tostring(raceData.EarAssetId)
		end
	end

	local hairstyle = CharacterConfig.HAIRSTYLES[selection.hairstyleIndex]
	if hairstyle and hairstyle.AssetId and hairstyle.AssetId > 0 then
		description.HairAccessory = tostring(hairstyle.AssetId)
	end

	local face = CharacterConfig.FACES[selection.faceIndex]
	if face and face.AssetId and face.AssetId > 0 then
		description.Face = face.AssetId
	end

	local shirt = CharacterConfig.CLOTHING.Shirts[selection.shirtIndex]
	if shirt and shirt.AssetId and shirt.AssetId > 0 then
		description.Shirt = shirt.AssetId
	end
	local pants = CharacterConfig.CLOTHING.Pants[selection.pantsIndex]
	if pants and pants.AssetId and pants.AssetId > 0 then
		description.Pants = pants.AssetId
	end

	local skin = selection.skinColor or DEFAULT_SKIN
	description.HeadColor = skin
	description.TorsoColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.LeftLegColor = skin
	description.RightLegColor = skin

	return description
end

-- Build a description for ONE single asset (just the hair, just the
-- shirt, etc.) — used to render mini-preview thumbnails for the option
-- list. Skin colour stays default so all minis look uniform.
function HumanoidBuilder.BuildSingleAssetDescription(kind, asset)
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = DEFAULT_SKIN
	description.TorsoColor = DEFAULT_SKIN
	description.LeftArmColor = DEFAULT_SKIN
	description.RightArmColor = DEFAULT_SKIN
	description.LeftLegColor = DEFAULT_SKIN
	description.RightLegColor = DEFAULT_SKIN

	if asset and asset.AssetId and asset.AssetId > 0 then
		if kind == "hair" then
			description.HairAccessory = tostring(asset.AssetId)
		elseif kind == "face" then
			description.Face = asset.AssetId
		elseif kind == "shirt" then
			description.Shirt = asset.AssetId
		elseif kind == "pants" then
			description.Pants = asset.AssetId
		end
	end
	return description
end

return HumanoidBuilder
