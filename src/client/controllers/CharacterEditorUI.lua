-- UI Manager for character customization
-- Allows player to select race, hairstyle, clothing and colors
--
-- Architecture (post-redesign):
--   * The "preview" is the player's R6 character placed directly in the
--     real Workspace (FilteringEnabled means only this client sees it),
--     anchored on top of a Part named "PreviewSpot" or the SpawnLocation.
--   * Workspace.CurrentCamera is locked into Scriptable mode and orbits
--     the preview character; mouse drag rotates, scroll wheel zooms.
--   * The UI itself is just a transparent right-hand options panel with
--     mini-preview thumbnails for hair/clothing and an RGB+HEX color
--     picker for skin/hair colour.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterConfig = require(Shared:WaitForChild("CharacterConfig"))

local CharacterEditorUI = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DEFAULT_SKIN = CharacterConfig.DEFAULT_CHARACTER.SkinColor or Color3.fromRGB(255, 204, 153)
local DEFAULT_HAIR = CharacterConfig.DEFAULT_CHARACTER.HairColor or Color3.fromRGB(139, 69, 19)

local currentRace = "Human"
local currentHairstyle = 1
local currentShirt = 1
local currentPants = 1
local currentSkinColor = DEFAULT_SKIN
local currentHairColor = DEFAULT_HAIR

-- World-preview character (lives in real Workspace, only this client sees it
-- because FilteringEnabled is true and we parent it client-side).
local worldCharacter = nil
local worldCameraConnection = nil
local originalCameraType = nil
local originalCameraSubject = nil
local cameraOrbitState = {
	angle = math.pi,
	height = 3,
	distance = 8,
	dragging = false,
	lastMouseX = 0,
	lastMouseY = 0,
}

local activeScreenGui = nil
local optionsPanelRef = nil
local skinPickerRef = nil
local hairPickerRef = nil

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
local function SetSkinColor(character, color)
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
local function BuildR6Rig(description)
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
		warn("CharacterEditorUI: failed to build R6 rig:", rig)
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
	SetSkinColor(rig, description.HeadColor)
	return rig
end

local function IsHairAccessory(accessory)
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

local function TintHair(model, color)
	if not model or not color then return end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Accessory") and IsHairAccessory(descendant) then
			TintAccessoryParts(descendant, color)
		end
	end
end

-- Build a HumanoidDescription describing the *currently selected* combo
-- of race / hair / clothing / colors. Used for the world preview and the
-- final SaveCharacter payload.
local function BuildCurrentDescription()
	local description = Instance.new("HumanoidDescription")

	local raceData = CharacterConfig.RACES[currentRace]
	if raceData then
		description.HeightScale = raceData.HeightScale
		description.WidthScale = raceData.WidthScale
		description.HeadScale = raceData.HeadScale
		description.BodyTypeScale = raceData.BodyTypeScale
		-- R6 ignores HumanoidDescription scale fields — those only work on
		-- R15. We still set them above for any code that reads them back
		-- (DataStore round-trip), but the actual visual scaling for R6
		-- happens via Model:ScaleTo() in UpdatePreview().

		-- Race-specific accessories (e.g. elf ears) ride along on the
		-- HatAccessory CSV slot so they don't conflict with the chosen
		-- HairAccessory.
		if raceData.HasEars and raceData.EarAssetId and raceData.EarAssetId > 0 then
			description.HatAccessory = tostring(raceData.EarAssetId)
		end
	end

	local hairstyle = CharacterConfig.HAIRSTYLES[currentHairstyle]
	if hairstyle and hairstyle.AssetId and hairstyle.AssetId > 0 then
		description.HairAccessory = tostring(hairstyle.AssetId)
	end

	local shirt = CharacterConfig.CLOTHING.Shirts[currentShirt]
	if shirt and shirt.AssetId and shirt.AssetId > 0 then
		description.Shirt = shirt.AssetId
	end
	local pants = CharacterConfig.CLOTHING.Pants[currentPants]
	if pants and pants.AssetId and pants.AssetId > 0 then
		description.Pants = pants.AssetId
	end

	description.HeadColor = currentSkinColor
	description.TorsoColor = currentSkinColor
	description.LeftArmColor = currentSkinColor
	description.RightArmColor = currentSkinColor
	description.LeftLegColor = currentSkinColor
	description.RightLegColor = currentSkinColor

	return description
end

-- Build a description for ONE single asset (just the hair, just the
-- shirt, etc.) — used to render mini-preview thumbnails for the option
-- list. Skin colour stays default so all minis look uniform.
local function BuildSingleAssetDescription(kind, asset)
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
		elseif kind == "shirt" then
			description.Shirt = asset.AssetId
		elseif kind == "pants" then
			description.Pants = asset.AssetId
		end
	end
	return description
end

-- Pick the BasePart in the world we should stand the preview character
-- on top of. A Part named "PreviewSpot" wins. Otherwise the first
-- SpawnLocation we can find anywhere in the world (recursive — Folder /
-- Model nesting is fine).
local function ResolvePreviewAnchorPart()
	local explicit = Workspace:FindFirstChild("PreviewSpot", true)
	if explicit and explicit:IsA("BasePart") then
		return explicit
	end
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("SpawnLocation") then
			return descendant
		end
	end
	return nil
end

-- Compute the bounding box of the rig's actual body parts only,
-- ignoring anything inside an Accessory. Accessories (hair, hats,
-- earrings…) load asynchronously and can briefly sit at world origin
-- (0,0,0) before their weld snaps them to the head. If we feed those
-- stray positions into Model:GetBoundingBox the resulting box is much
-- bigger than the body and the foot-alignment math puts the rig deep
-- into the ground (or way above it), which is the visible "sinking"
-- bug players saw when picking different hairstyles.
local function GetBodyBoundsY(character)
	local minY, maxY = math.huge, -math.huge
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and not part:FindFirstAncestorWhichIsA("Accessory") then
			local centerY = part.Position.Y
			local halfY = part.Size.Y * 0.5
			if centerY - halfY < minY then
				minY = centerY - halfY
			end
			if centerY + halfY > maxY then
				maxY = centerY + halfY
			end
		end
	end
	return minY, maxY
end

-- Place the rig so its feet land on the top face of the chosen anchor
-- Part. Uses only body-part bounds (not accessories) so the offset
-- stays correct regardless of which hairstyle / hat is loading at the
-- moment.
local previewAnchorWarned = false
local function PlaceCharacterOnSpawn(character)
	local anchor = ResolvePreviewAnchorPart()
	if not anchor then
		if not previewAnchorWarned then
			warn("[CharacterEditorUI] No SpawnLocation or PreviewSpot Part "
				.. "found in Workspace — falling back to (0, 10, 0). "
				.. "Add a Part named PreviewSpot where you want the "
				.. "preview character to stand.")
			previewAnchorWarned = true
		end
		character:PivotTo(CFrame.new(0, 10, 0))
		return
	end

	local topY = anchor.Position.Y + anchor.Size.Y * 0.5
	-- First place the rig somewhere near the anchor so we can read its
	-- body bounds; the X/Z are correct, only the Y needs adjusting.
	character:PivotTo(CFrame.new(anchor.Position.X, topY + 5, anchor.Position.Z)
		* (anchor.CFrame - anchor.Position))
	local minBodyY = GetBodyBoundsY(character)
	if minBodyY == math.huge then
		-- No body parts found yet (rig still spinning up). Fall back
		-- to the model's full bounding box so we at least don't NaN.
		local cf, size = character:GetBoundingBox()
		minBodyY = cf.Y - size.Y * 0.5
	end
	local correction = topY - minBodyY
	character:PivotTo(character:GetPivot() + Vector3.new(0, correction, 0))
	print(("[CharacterEditorUI] Preview anchor: %s @ (%.1f, %.1f, %.1f), "
		.. "body min Y was %.2f, feet placed at Y=%.1f"):format(
			anchor:GetFullName(),
			anchor.Position.X, anchor.Position.Y, anchor.Position.Z,
			minBodyY, topY))
end

-- Lock the rig in place by anchoring ONLY the HumanoidRootPart. Body
-- parts stay attached via Motor6Ds, accessories (e.g. hair) stay attached
-- via Attachments — anchoring them too would freeze them at their initial
-- position before the welds positioned them, which is why hair was
-- floating off in space.
--
-- We deliberately don't set humanoid.PlatformStand = true: it puts the
-- Humanoid into a ragdoll-like state where Motor6Ds go limp and the
-- limbs flop / drift away from the torso. Anchoring the HRP plus
-- WalkSpeed/JumpPower=0 (set in BuildR6Rig) is enough to hold the rig
-- still while the idle animation plays normally.
local function AnchorRig(model)
	if not model then return end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
		end
	end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.Anchored = true
	end
end

-- Spawn (or rebuild) the player-preview character directly in Workspace.
--
-- Race / hairstyle / clothing changes can fire faster than a rig builds
-- (CreateHumanoidModelFromDescription yields while it pulls assets), so
-- we use a generation counter to discard rigs that finished building
-- after a newer call took over. We also sweep any orphan
-- "PreviewCharacter" already in the workspace before spawning a new
-- one — without that sweep, a rig from an in-flight call could parent
-- itself in *after* worldCharacter was reassigned, leaving a duplicate
-- behind for every fast click.
local previewGeneration = 0
function CharacterEditorUI.UpdatePreview()
	previewGeneration = previewGeneration + 1
	local myGeneration = previewGeneration
	local description = BuildCurrentDescription()

	for _, child in ipairs(Workspace:GetChildren()) do
		if child.Name == "PreviewCharacter" then
			child:Destroy()
		end
	end
	worldCharacter = nil

	local character = BuildR6Rig(description)
	if not character then
		warn("CharacterEditorUI: cannot create world preview character")
		return
	end

	-- A newer UpdatePreview call superseded us while BuildR6Rig was
	-- yielding on asset loads; throw this rig away instead of leaking
	-- it into the workspace as a duplicate.
	if myGeneration ~= previewGeneration then
		character:Destroy()
		return
	end

	-- Use a name that won't show up over the character; the floating
	-- "TBATE_PreviewCharacter" label was distracting.
	character.Name = "PreviewCharacter"

	local primary = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
	if primary then
		character.PrimaryPart = primary
	end

	-- R6 ignores HumanoidDescription scale fields, so apply the race
	-- height ratio uniformly via Model:ScaleTo. Do this BEFORE placing
	-- the rig so the bounding-box-based foot alignment uses the post-
	-- scale dimensions.
	local raceData = CharacterConfig.RACES[currentRace]
	local raceScale = (raceData and raceData.HeightScale) or 1.0
	pcall(function()
		character:ScaleTo(raceScale)
	end)

	PlaceCharacterOnSpawn(character)
	-- Anchor the HRP BEFORE parenting so physics doesn't get a chance to
	-- run a tick on the unanchored rig and drift it before AnchorRig
	-- finishes (the visible "flying / floating" symptom users were
	-- seeing when swapping race / hair / clothing).
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.Anchored = true
	end
	character.Parent = Workspace
	AnchorRig(character)
	worldCharacter = character

	SetSkinColor(character, currentSkinColor)
	TintHair(character, currentHairColor)
	for _, delaySeconds in ipairs({0.1, 0.5, 1.5, 3.0}) do
		task.delay(delaySeconds, function()
			if character.Parent and myGeneration == previewGeneration then
				TintHair(character, currentHairColor)
				-- Re-anchor only the HRP — accessories (hair) need to stay
				-- non-anchored so their welds keep them attached to the head.
				AnchorRig(character)
			end
		end)
	end
	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			-- Keep collision off for any new sub-part, but DO NOT anchor
			-- — anchoring an accessory part before its weld places it
			-- freezes it at world origin.
			descendant.CanCollide = false
		end
		if descendant:IsA("Accessory") and IsHairAccessory(descendant) then
			task.defer(TintHair, character, currentHairColor)
		end
	end)
end

-- =================================================================
-- Orbit camera around the workspace preview character.
-- =================================================================
local function UpdateOrbitCamera()
	local camera = Workspace.CurrentCamera
	if not camera or not worldCharacter then return end

	local primary = worldCharacter.PrimaryPart or worldCharacter:FindFirstChild("HumanoidRootPart")
	if not primary then return end

	local target = primary.Position + Vector3.new(0, 0.5, 0)
	local x = math.sin(cameraOrbitState.angle) * cameraOrbitState.distance
	local z = math.cos(cameraOrbitState.angle) * cameraOrbitState.distance
	local cameraPosition = target + Vector3.new(x, cameraOrbitState.height, z)
	camera.CFrame = CFrame.lookAt(cameraPosition, target)
end

local cameraInputConnections = {}

local function DisconnectInputConnections()
	for _, conn in ipairs(cameraInputConnections) do
		if conn.Connected then conn:Disconnect() end
	end
	cameraInputConnections = {}
end

local function SetupOrbitCamera()
	local camera = Workspace.CurrentCamera
	if not camera then return end

	if originalCameraType == nil then
		originalCameraType = camera.CameraType
		originalCameraSubject = camera.CameraSubject
	end
	camera.CameraType = Enum.CameraType.Scriptable

	if worldCameraConnection then
		worldCameraConnection:Disconnect()
		worldCameraConnection = nil
	end
	DisconnectInputConnections()

	UpdateOrbitCamera()

	worldCameraConnection = RunService.RenderStepped:Connect(function()
		UpdateOrbitCamera()
	end)

	-- Don't start an orbit-camera drag if the click landed on top of any
	-- of our UI panels (options panel, side shade, or the buttons inside).
	-- gameProcessed isn't reliable for plain Frame/TextButton clicks, so
	-- we do an explicit hit-test against the panel bounds.
	local function IsClickOverUI(input)
		if not optionsPanelRef or not optionsPanelRef.Parent then
			return false
		end
		local pos = input.Position
		local panelPos = optionsPanelRef.AbsolutePosition
		local panelSize = optionsPanelRef.AbsoluteSize
		if pos.X >= panelPos.X and pos.X <= panelPos.X + panelSize.X
			and pos.Y >= panelPos.Y and pos.Y <= panelPos.Y + panelSize.Y then
			return true
		end
		local screenGui = optionsPanelRef.Parent
		local sideShade = screenGui:FindFirstChild("SideShade")
		if sideShade then
			local sp = sideShade.AbsolutePosition
			local ss = sideShade.AbsoluteSize
			if pos.X >= sp.X and pos.X <= sp.X + ss.X
				and pos.Y >= sp.Y and pos.Y <= sp.Y + ss.Y then
				return true
			end
		end
		return false
	end

	table.insert(cameraInputConnections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton2
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			if IsClickOverUI(input) then return end
			cameraOrbitState.dragging = true
			cameraOrbitState.lastMouseX = input.Position.X
			cameraOrbitState.lastMouseY = input.Position.Y
		end
	end))
	table.insert(cameraInputConnections, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			cameraOrbitState.dragging = false
		end
	end))
	table.insert(cameraInputConnections, UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseMovement and cameraOrbitState.dragging then
			local dx = input.Position.X - cameraOrbitState.lastMouseX
			local dy = input.Position.Y - cameraOrbitState.lastMouseY
			cameraOrbitState.lastMouseX = input.Position.X
			cameraOrbitState.lastMouseY = input.Position.Y
			cameraOrbitState.angle = cameraOrbitState.angle - dx * 0.01
			cameraOrbitState.height = math.clamp(cameraOrbitState.height + dy * 0.05, -2, 8)
		elseif input.UserInputType == Enum.UserInputType.MouseWheel and not gameProcessed then
			-- Don't zoom if the wheel is over the UI panel either.
			if IsClickOverUI(input) then return end
			cameraOrbitState.distance = math.clamp(
				cameraOrbitState.distance - input.Position.Z,
				3, 20)
		end
	end))
end

local function RestoreCamera()
	if worldCameraConnection then
		worldCameraConnection:Disconnect()
		worldCameraConnection = nil
	end
	DisconnectInputConnections()
	local camera = Workspace.CurrentCamera
	if camera and originalCameraType then
		camera.CameraType = originalCameraType
		if originalCameraSubject then
			camera.CameraSubject = originalCameraSubject
		end
	end
	originalCameraType = nil
	originalCameraSubject = nil
end

-- =================================================================
-- UI building primitives.
-- =================================================================

-- A vertical-list section with a title bar and a content area.
local function CreateSection(parent, sectionId, titleText)
	local section = Instance.new("Frame")
	section.Name = sectionId
	section.Size = UDim2.new(1, -20, 0, 0)
	section.AutomaticSize = Enum.AutomaticSize.Y
	section.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
	section.BackgroundTransparency = 0.15
	section.BorderSizePixel = 0
	section.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = section

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = section

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = section

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 24)
	title.BackgroundTransparency = 1
	title.Text = titleText
	title.TextColor3 = Color3.fromRGB(245, 215, 110)
	title.TextSize = 16
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.LayoutOrder = 0
	title.Parent = section

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(1, 0, 0, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.BackgroundTransparency = 1
	content.LayoutOrder = 1
	content.Parent = section

	return section, content
end

-- A grid of mini items. Each item is a square button with an optional
-- ViewportFrame thumbnail above its label.
local function MakeGridContainer(parent, cellSize)
	parent.Size = UDim2.new(1, 0, 0, 0)
	parent.AutomaticSize = Enum.AutomaticSize.Y

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = cellSize
	grid.CellPadding = UDim2.new(0, 6, 0, 6)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	grid.Parent = parent

	return grid
end

-- A single text-only option button (used for races).
local function CreateTextOptionButton(id, text)
	local button = Instance.new("TextButton")
	button.Name = id
	button.AutoButtonColor = false
	button.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 14
	button.Font = Enum.Font.GothamBold

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(70, 70, 80)
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button

	return button
end

-- A mini-preview button: a 3D thumbnail of an R6 dummy wearing only this
-- particular item, rendered into a tiny ViewportFrame, with a label
-- underneath.
local function CreateMiniPreviewButton(id, displayName, kind, asset)
	local button = Instance.new("TextButton")
	button.Name = id
	button.AutoButtonColor = false
	button.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
	button.Text = ""

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(70, 70, 80)
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Thumbnail"
	viewport.Size = UDim2.new(1, -8, 1, -22)
	viewport.Position = UDim2.new(0, 4, 0, 4)
	viewport.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	viewport.BorderSizePixel = 0
	viewport.LightDirection = Vector3.new(-0.5, -1, -0.5)
	viewport.Ambient = Color3.fromRGB(160, 160, 160)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.Parent = button

	local viewportCorner = Instance.new("UICorner")
	viewportCorner.CornerRadius = UDim.new(0, 4)
	viewportCorner.Parent = viewport

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport

	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -2)
	label.Size = UDim2.new(1, -8, 0, 16)
	label.BackgroundTransparency = 1
	label.Text = displayName
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.TextSize = 11
	label.Font = Enum.Font.Gotham
	label.TextScaled = false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = button

	-- Build the dummy asynchronously so we don't block the UI thread.
	task.spawn(function()
		local description = BuildSingleAssetDescription(kind, asset)
		local rig = BuildR6Rig(description)
		if not rig then return end
		local primary = rig.PrimaryPart or rig:FindFirstChild("HumanoidRootPart")
		if primary then
			rig.PrimaryPart = primary
			rig:PivotTo(CFrame.new(0, 0, 0))
		end
		rig.Parent = worldModel
		-- Anchor in the WorldModel so physics doesn't make the rig drift.
		AnchorRig(rig)

		-- Re-tint after late accessory load.
		local function retint()
			TintHair(rig, currentHairColor)
		end
		retint()
		for _, t in ipairs({0.2, 0.6, 1.2, 2.4}) do
			task.delay(t, function() if rig.Parent then retint() end end)
		end
		rig.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("Accessory") and IsHairAccessory(descendant) then
				task.defer(retint)
			end
		end)

		-- Frame the camera based on which body region we want to highlight.
		if kind == "hair" then
			camera.CFrame = CFrame.lookAt(Vector3.new(0, 2.5, 4), Vector3.new(0, 2.2, 0))
		elseif kind == "shirt" then
			camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.5, 5), Vector3.new(0, 0.5, 0))
		elseif kind == "pants" then
			camera.CFrame = CFrame.lookAt(Vector3.new(0, -1.5, 5), Vector3.new(0, -1.5, 0))
		else
			camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, 6), Vector3.new(0, 0, 0))
		end
	end)

	return button
end

-- =================================================================
-- RGB color picker (3 sliders + HEX input).
-- =================================================================
local function ToHex(color)
	local r = math.clamp(math.floor(color.R * 255 + 0.5), 0, 255)
	local g = math.clamp(math.floor(color.G * 255 + 0.5), 0, 255)
	local b = math.clamp(math.floor(color.B * 255 + 0.5), 0, 255)
	return string.format("%02X%02X%02X", r, g, b)
end

local function FromHex(hex)
	hex = hex:gsub("#", ""):gsub("%s", "")
	if #hex ~= 6 then return nil end
	local r = tonumber(hex:sub(1, 2), 16)
	local g = tonumber(hex:sub(3, 4), 16)
	local b = tonumber(hex:sub(5, 6), 16)
	if not r or not g or not b then return nil end
	return Color3.fromRGB(r, g, b)
end

local function CreateRGBColorPicker(id, initialColor, onChange)
	local picker = Instance.new("Frame")
	picker.Name = id
	picker.Size = UDim2.new(1, 0, 0, 130)
	picker.BackgroundTransparency = 1

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = picker

	-- Top row: swatch preview + HEX input.
	local topRow = Instance.new("Frame")
	topRow.Name = "TopRow"
	topRow.Size = UDim2.new(1, 0, 0, 32)
	topRow.BackgroundTransparency = 1
	topRow.LayoutOrder = 0
	topRow.Parent = picker

	local swatch = Instance.new("Frame")
	swatch.Name = "Swatch"
	swatch.Size = UDim2.new(0, 32, 0, 32)
	swatch.Position = UDim2.new(0, 0, 0, 0)
	swatch.BackgroundColor3 = initialColor
	swatch.BorderSizePixel = 0
	swatch.Parent = topRow

	local swatchCorner = Instance.new("UICorner")
	swatchCorner.CornerRadius = UDim.new(0, 4)
	swatchCorner.Parent = swatch

	local hexLabel = Instance.new("TextLabel")
	hexLabel.Size = UDim2.new(0, 30, 1, 0)
	hexLabel.Position = UDim2.new(0, 40, 0, 0)
	hexLabel.BackgroundTransparency = 1
	hexLabel.Text = "#"
	hexLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	hexLabel.TextSize = 14
	hexLabel.Font = Enum.Font.GothamBold
	hexLabel.TextXAlignment = Enum.TextXAlignment.Left
	hexLabel.Parent = topRow

	local hexBox = Instance.new("TextBox")
	hexBox.Name = "HexBox"
	hexBox.Size = UDim2.new(0, 80, 1, 0)
	hexBox.Position = UDim2.new(0, 56, 0, 0)
	hexBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	hexBox.TextColor3 = Color3.fromRGB(245, 245, 245)
	hexBox.TextSize = 14
	hexBox.Font = Enum.Font.Code
	hexBox.PlaceholderText = "FFFFFF"
	hexBox.Text = ToHex(initialColor)
	hexBox.ClearTextOnFocus = false
	hexBox.Parent = topRow

	local hexCorner = Instance.new("UICorner")
	hexCorner.CornerRadius = UDim.new(0, 4)
	hexCorner.Parent = hexBox

	local hexStroke = Instance.new("UIStroke")
	hexStroke.Color = Color3.fromRGB(60, 60, 80)
	hexStroke.Thickness = 1
	hexStroke.Parent = hexBox

	local current = initialColor
	local sliderRefs = {}

	local function applyColor(newColor)
		current = newColor
		swatch.BackgroundColor3 = newColor
		hexBox.Text = ToHex(newColor)
		for _, ref in ipairs(sliderRefs) do
			ref.refresh(newColor)
		end
		if onChange then
			onChange(newColor)
		end
	end

	-- Build a single horizontal RGB slider row.
	local function CreateChannelSlider(channelName, channelGetter, layoutOrder)
		local row = Instance.new("Frame")
		row.Name = channelName .. "Slider"
		row.Size = UDim2.new(1, 0, 0, 26)
		row.BackgroundTransparency = 1
		row.LayoutOrder = layoutOrder
		row.Parent = picker

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(0, 18, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = channelName
		label.TextColor3 = Color3.fromRGB(220, 220, 220)
		label.TextSize = 14
		label.Font = Enum.Font.GothamBold
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = row

		local track = Instance.new("Frame")
		track.Name = "Track"
		track.Size = UDim2.new(1, -70, 0, 6)
		track.Position = UDim2.new(0, 22, 0.5, -3)
		track.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
		track.BorderSizePixel = 0
		track.Parent = row

		local trackCorner = Instance.new("UICorner")
		trackCorner.CornerRadius = UDim.new(1, 0)
		trackCorner.Parent = track

		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.new(channelGetter(initialColor), 0, 1, 0)
		fill.BackgroundColor3 = (channelName == "R" and Color3.fromRGB(220, 60, 60))
			or (channelName == "G" and Color3.fromRGB(60, 200, 80))
			or Color3.fromRGB(80, 120, 220)
		fill.BorderSizePixel = 0
		fill.Parent = track

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = fill

		local thumb = Instance.new("Frame")
		thumb.Name = "Thumb"
		thumb.AnchorPoint = Vector2.new(0.5, 0.5)
		thumb.Size = UDim2.new(0, 14, 0, 14)
		thumb.Position = UDim2.new(channelGetter(initialColor), 0, 0.5, 0)
		thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		thumb.BorderSizePixel = 0
		thumb.Parent = track

		local thumbCorner = Instance.new("UICorner")
		thumbCorner.CornerRadius = UDim.new(1, 0)
		thumbCorner.Parent = thumb

		local valueLabel = Instance.new("TextLabel")
		valueLabel.Size = UDim2.new(0, 40, 1, 0)
		valueLabel.Position = UDim2.new(1, -42, 0, 0)
		valueLabel.BackgroundTransparency = 1
		valueLabel.Text = tostring(math.floor(channelGetter(initialColor) * 255 + 0.5))
		valueLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
		valueLabel.TextSize = 12
		valueLabel.Font = Enum.Font.Code
		valueLabel.TextXAlignment = Enum.TextXAlignment.Right
		valueLabel.Parent = row

		local dragging = false
		local function setFromMouseX(mouseX)
			local trackPos = track.AbsolutePosition.X
			local trackSize = track.AbsoluteSize.X
			if trackSize <= 0 then return end
			local t = math.clamp((mouseX - trackPos) / trackSize, 0, 1)
			local r, g, b = current.R, current.G, current.B
			if channelName == "R" then r = t
			elseif channelName == "G" then g = t
			else b = t
			end
			applyColor(Color3.new(r, g, b))
		end

		track.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				setFromMouseX(input.Position.X)
			end
		end)
		thumb.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch) then
				setFromMouseX(input.Position.X)
			end
		end)

		table.insert(sliderRefs, {
			refresh = function(newColor)
				local v = channelGetter(newColor)
				fill.Size = UDim2.new(v, 0, 1, 0)
				thumb.Position = UDim2.new(v, 0, 0.5, 0)
				valueLabel.Text = tostring(math.floor(v * 255 + 0.5))
			end,
		})
	end

	CreateChannelSlider("R", function(c) return c.R end, 1)
	CreateChannelSlider("G", function(c) return c.G end, 2)
	CreateChannelSlider("B", function(c) return c.B end, 3)

	hexBox.FocusLost:Connect(function()
		local parsed = FromHex(hexBox.Text)
		if parsed then
			applyColor(parsed)
		else
			hexBox.Text = ToHex(current)
		end
	end)

	-- Stash the current hex on the Frame as an attribute so external code
	-- (or an inspector) can read it back. We don't try to attach a custom
	-- :SetColor method here because Roblox Instance objects don't accept
	-- arbitrary new members at runtime.
	picker:SetAttribute("CurrentHex", ToHex(initialColor))

	return picker
end

-- =================================================================
-- Main UI.
-- =================================================================
function CharacterEditorUI.CreateUI()
	-- Place the world preview character first so the camera has something
	-- to lock onto when the UI fades in.
	CharacterEditorUI.UpdatePreview()
	SetupOrbitCamera()

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CharacterEditorUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Side gradient acts as a vignette so the right options panel reads
	-- well over the world without entirely covering it.
	local sideShade = Instance.new("Frame")
	sideShade.Name = "SideShade"
	sideShade.AnchorPoint = Vector2.new(1, 0)
	sideShade.Position = UDim2.new(1, 0, 0, 0)
	sideShade.Size = UDim2.new(0, 460, 1, 0)
	sideShade.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
	sideShade.BackgroundTransparency = 0.25
	sideShade.BorderSizePixel = 0
	sideShade.Parent = screenGui

	-- Title banner along the top.
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.3, 0, 0.04, 0)
	title.Size = UDim2.new(0, 600, 0, 60)
	title.BackgroundTransparency = 1
	title.Text = "СОЗДАНИЕ ПЕРСОНАЖА"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 32
	title.Font = Enum.Font.GothamBold
	title.TextStrokeTransparency = 0.3
	title.Parent = screenGui

	-- Right options panel — the main UI.
	local optionsPanel = Instance.new("ScrollingFrame")
	optionsPanel.Name = "OptionsPanel"
	optionsPanel.AnchorPoint = Vector2.new(1, 0.5)
	optionsPanel.Position = UDim2.new(1, -10, 0.5, 0)
	optionsPanel.Size = UDim2.new(0, 440, 0.85, 0)
	optionsPanel.BackgroundTransparency = 1
	optionsPanel.BorderSizePixel = 0
	optionsPanel.ScrollBarThickness = 6
	optionsPanel.CanvasSize = UDim2.new(0, 0, 0, 0)
	-- ScrollingFrame.AutomaticCanvasSize takes Enum.AutomaticSize (NOT a
	-- separate Enum.AutomaticCanvasSize — that one doesn't exist).
	optionsPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
	optionsPanel.Parent = screenGui
	optionsPanelRef = optionsPanel

	local panelLayout = Instance.new("UIListLayout")
	panelLayout.FillDirection = Enum.FillDirection.Vertical
	panelLayout.SortOrder = Enum.SortOrder.LayoutOrder
	panelLayout.Padding = UDim.new(0, 12)
	panelLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	panelLayout.Parent = optionsPanel

	local panelPadding = Instance.new("UIPadding")
	panelPadding.PaddingTop = UDim.new(0, 10)
	panelPadding.PaddingBottom = UDim.new(0, 80) -- leave room for buttons
	panelPadding.Parent = optionsPanel

	-- Race section (text buttons, races are few).
	local raceSection, raceContent = CreateSection(optionsPanel, "RaceSection", "РАСА")
	raceSection.LayoutOrder = 1
	MakeGridContainer(raceContent, UDim2.new(0, 130, 0, 36))
	for raceName, raceData in pairs(CharacterConfig.RACES) do
		local btn = CreateTextOptionButton(raceName, raceData.Name)
		btn.Parent = raceContent
	end

	-- Hairstyle section (mini previews).
	local hairSection, hairContent = CreateSection(optionsPanel, "HairstyleSection", "ПРИЧЕСКА")
	hairSection.LayoutOrder = 2
	MakeGridContainer(hairContent, UDim2.new(0, 92, 0, 110))
	for i, hairstyle in ipairs(CharacterConfig.HAIRSTYLES) do
		local btn = CreateMiniPreviewButton("Hairstyle" .. i, hairstyle.Name, "hair", hairstyle)
		btn.LayoutOrder = i
		btn.Parent = hairContent
	end

	-- Shirt section.
	local shirtSection, shirtContent = CreateSection(optionsPanel, "ShirtSection", "РУБАШКА")
	shirtSection.LayoutOrder = 3
	MakeGridContainer(shirtContent, UDim2.new(0, 92, 0, 110))
	for i, shirt in ipairs(CharacterConfig.CLOTHING.Shirts) do
		local btn = CreateMiniPreviewButton("Shirt" .. i, shirt.Name, "shirt", shirt)
		btn.LayoutOrder = i
		btn.Parent = shirtContent
	end

	-- Pants section.
	local pantsSection, pantsContent = CreateSection(optionsPanel, "PantsSection", "ШТАНЫ")
	pantsSection.LayoutOrder = 4
	MakeGridContainer(pantsContent, UDim2.new(0, 92, 0, 110))
	for i, pants in ipairs(CharacterConfig.CLOTHING.Pants) do
		local btn = CreateMiniPreviewButton("Pants" .. i, pants.Name, "pants", pants)
		btn.LayoutOrder = i
		btn.Parent = pantsContent
	end

	-- Skin colour picker.
	local skinSection, skinContent = CreateSection(optionsPanel, "SkinColorSection", "ЦВЕТ КОЖИ")
	skinSection.LayoutOrder = 5
	skinPickerRef = CreateRGBColorPicker("SkinPicker", currentSkinColor, function(color)
		currentSkinColor = color
		if worldCharacter then
			SetSkinColor(worldCharacter, color)
		end
	end)
	skinPickerRef.Parent = skinContent

	-- Hair colour picker.
	local hairColorSection, hairColorContent = CreateSection(optionsPanel, "HairColorSection", "ЦВЕТ ВОЛОС")
	hairColorSection.LayoutOrder = 6
	hairPickerRef = CreateRGBColorPicker("HairPicker", currentHairColor, function(color)
		currentHairColor = color
		if worldCharacter then
			TintHair(worldCharacter, color)
		end
	end)
	hairPickerRef.Parent = hairColorContent

	-- Bottom action buttons (overlay on the options panel).
	local buttonsContainer = Instance.new("Frame")
	buttonsContainer.Name = "ButtonsContainer"
	buttonsContainer.AnchorPoint = Vector2.new(1, 1)
	buttonsContainer.Position = UDim2.new(1, -10, 1, -10)
	buttonsContainer.Size = UDim2.new(0, 440, 0, 50)
	buttonsContainer.BackgroundTransparency = 1
	buttonsContainer.Parent = screenGui

	local backButton = Instance.new("TextButton")
	backButton.Name = "BackButton"
	backButton.Size = UDim2.new(0.45, -5, 1, 0)
	backButton.Position = UDim2.new(0, 0, 0, 0)
	backButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
	backButton.Text = "НАЗАД"
	backButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	backButton.TextSize = 18
	backButton.Font = Enum.Font.GothamBold
	backButton.AutoButtonColor = false
	backButton.Parent = buttonsContainer

	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0, 8)
	backCorner.Parent = backButton

	local confirmButton = Instance.new("TextButton")
	confirmButton.Name = "ConfirmButton"
	confirmButton.Size = UDim2.new(0.55, -5, 1, 0)
	confirmButton.Position = UDim2.new(0.45, 5, 0, 0)
	confirmButton.BackgroundColor3 = Color3.fromRGB(60, 150, 60)
	confirmButton.Text = "ПОДТВЕРДИТЬ"
	confirmButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	confirmButton.TextSize = 18
	confirmButton.Font = Enum.Font.GothamBold
	confirmButton.AutoButtonColor = false
	confirmButton.Parent = buttonsContainer

	local confirmCorner = Instance.new("UICorner")
	confirmCorner.CornerRadius = UDim.new(0, 8)
	confirmCorner.Parent = confirmButton

	screenGui.Parent = playerGui
	activeScreenGui = screenGui
	return screenGui
end

-- =================================================================
-- Selection state visuals: highlight active text-/mini-preview button
-- with a gold UIStroke.
-- =================================================================
local function SetGroupSelection(container, selectedId)
	if not container then return end
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("TextButton") then
			local stroke = child:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = Color3.fromRGB(70, 70, 80)
				stroke.Thickness = 2
			end
		end
	end
	local selected = container:FindFirstChild(selectedId)
	if selected then
		local stroke = selected:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = Color3.fromRGB(255, 215, 0)
			stroke.Thickness = 4
		end
	end
end

function CharacterEditorUI.UpdateSelection(_, sectionId, selectedId)
	if not optionsPanelRef then return end
	local section = optionsPanelRef:FindFirstChild(sectionId)
	if not section then return end
	local content = section:FindFirstChild("Content")
	SetGroupSelection(content, selectedId)
end

-- =================================================================
-- Wire up button handlers.
-- =================================================================
function CharacterEditorUI.SetupHandlers(screenGui, onBack, onConfirm)
	local optionsPanel = screenGui:FindFirstChild("OptionsPanel") or optionsPanelRef
	if not optionsPanel then return end

	-- Race buttons.
	for raceName in pairs(CharacterConfig.RACES) do
		local btn = optionsPanel:FindFirstChild(raceName, true)
		if btn then
			btn.MouseButton1Click:Connect(function()
				currentRace = raceName
				CharacterEditorUI.UpdateSelection(nil, "RaceSection", raceName)
				CharacterEditorUI.UpdatePreview()
			end)
		end
	end

	-- Hairstyle buttons.
	for i in ipairs(CharacterConfig.HAIRSTYLES) do
		local id = "Hairstyle" .. i
		local btn = optionsPanel:FindFirstChild(id, true)
		if btn then
			btn.MouseButton1Click:Connect(function()
				currentHairstyle = i
				CharacterEditorUI.UpdateSelection(nil, "HairstyleSection", id)
				CharacterEditorUI.UpdatePreview()
			end)
		end
	end

	-- Shirt buttons.
	for i in ipairs(CharacterConfig.CLOTHING.Shirts) do
		local id = "Shirt" .. i
		local btn = optionsPanel:FindFirstChild(id, true)
		if btn then
			btn.MouseButton1Click:Connect(function()
				currentShirt = i
				CharacterEditorUI.UpdateSelection(nil, "ShirtSection", id)
				CharacterEditorUI.UpdatePreview()
			end)
		end
	end

	-- Pants buttons.
	for i in ipairs(CharacterConfig.CLOTHING.Pants) do
		local id = "Pants" .. i
		local btn = optionsPanel:FindFirstChild(id, true)
		if btn then
			btn.MouseButton1Click:Connect(function()
				currentPants = i
				CharacterEditorUI.UpdateSelection(nil, "PantsSection", id)
				CharacterEditorUI.UpdatePreview()
			end)
		end
	end

	-- Back button.
	local buttons = screenGui:FindFirstChild("ButtonsContainer")
	if buttons then
		local backButton = buttons:FindFirstChild("BackButton")
		if backButton then
			backButton.MouseButton1Click:Connect(function()
				RestoreCamera()
				if worldCharacter then
					worldCharacter:Destroy()
					worldCharacter = nil
				end
				if onBack then onBack() end
			end)
		end

		local confirmButton = buttons:FindFirstChild("ConfirmButton")
		if confirmButton then
			confirmButton.MouseButton1Click:Connect(function()
				local characterData = {
					Race = currentRace,
					HairstyleIndex = currentHairstyle,
					ShirtIndex = currentShirt,
					PantsIndex = currentPants,
					SkinColor = currentSkinColor,
					HairColor = currentHairColor,
				}

				RestoreCamera()
				if worldCharacter then
					worldCharacter:Destroy()
					worldCharacter = nil
				end

				if onConfirm then
					onConfirm(characterData)
				end
			end)
		end
	end
end

-- =================================================================
-- Initialize defaults — highlight the starting selection.
-- =================================================================
function CharacterEditorUI.InitializeDefaults(_)
	CharacterEditorUI.UpdateSelection(nil, "RaceSection", currentRace)
	CharacterEditorUI.UpdateSelection(nil, "HairstyleSection", "Hairstyle" .. currentHairstyle)
	CharacterEditorUI.UpdateSelection(nil, "ShirtSection", "Shirt" .. currentShirt)
	CharacterEditorUI.UpdateSelection(nil, "PantsSection", "Pants" .. currentPants)
end

return CharacterEditorUI
