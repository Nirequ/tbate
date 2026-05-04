-- UI Manager for character customization
-- Allows player to select race, hairstyle, clothing and colors

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterController = require(script.Parent.Parent.controllers.CharacterController)
local CharacterConfig = require(Shared:WaitForChild("CharacterConfig"))

local CharacterEditorUI = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local currentRace = "Human"
local currentHairstyle = 1
local currentShirt = 1
local currentPants = 1
local currentSkinColorIndex = CharacterConfig.DEFAULT_CHARACTER.SkinColorIndex or 1
local currentHairColorIndex = CharacterConfig.DEFAULT_CHARACTER.HairColorIndex or 1
local previewCharacter = nil
local previewTemplate = nil
local rotationConnection = nil

-- Hair-like accessory enum values that should be tinted by hair color
local HAIR_ACCESSORY_TYPES = {
	[Enum.AccessoryType.Hair] = true,
}

-- Lazily build (or fetch) a humanoid rig used as a preview template.
-- Falls back to Players:CreateHumanoidModelFromUserId(1) so the editor
-- works without a manually-placed PreviewDummy in ReplicatedStorage.Shared.
local function GetPreviewTemplate()
	if previewTemplate and previewTemplate.Parent == nil then
		return previewTemplate
	end

	local manual = Shared:FindFirstChild("PreviewDummy")
	if manual then
		previewTemplate = manual:Clone()
		return previewTemplate
	end

	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromUserId(1)
	end)
	if ok and rig then
		previewTemplate = rig
		return previewTemplate
	end

	warn("CharacterEditorUI: failed to build preview rig:", rig)
	return nil
end

-- Tint every hair-style accessory currently parented to the model.
local function TintHair(model, color)
	if not model or not color then return end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Accessory") and HAIR_ACCESSORY_TYPES[descendant.AccessoryType] then
			for _, part in ipairs(descendant:GetDescendants()) do
				if part:IsA("BasePart") or part:IsA("MeshPart") then
					part.Color = color
				end
			end
		end
	end
end

-- Resolve current skin / hair colors from the palette indices.
local function GetCurrentSkinColor()
	local entry = CharacterConfig.SKIN_COLORS[currentSkinColorIndex]
	if entry then return entry.Color end
	return CharacterConfig.DEFAULT_CHARACTER.SkinColor
end

local function GetCurrentHairColor()
	local entry = CharacterConfig.HAIR_COLORS[currentHairColorIndex]
	if entry then return entry.Color end
	return CharacterConfig.DEFAULT_CHARACTER.HairColor
end

-- Continuously rotate the preview camera around the character.
local function StartCameraRotation(viewport)
	if rotationConnection then
		rotationConnection:Disconnect()
		rotationConnection = nil
	end

	local angle = 0
	local radius = 8
	local height = 2

	rotationConnection = RunService.RenderStepped:Connect(function(dt)
		if not viewport or not viewport.Parent then
			rotationConnection:Disconnect()
			rotationConnection = nil
			return
		end
		angle = angle + dt * 0.6
		local camera = viewport.CurrentCamera
		if not camera then return end
		local x = math.sin(angle) * radius
		local z = math.cos(angle) * radius
		camera.CFrame = CFrame.lookAt(Vector3.new(x, height, z), Vector3.new(0, height, 0))
	end)
end

-- Update preview character
function CharacterEditorUI.UpdatePreview(previewPanel)
	-- Remove old preview
	if previewCharacter then
		previewCharacter:Destroy()
		previewCharacter = nil
	end

	-- Ensure a WorldModel exists inside the ViewportFrame
	local worldModel = previewPanel:FindFirstChildOfClass("WorldModel")
	if not worldModel then
		worldModel = Instance.new("WorldModel")
		worldModel.Name = "WorldModel"
		worldModel.Parent = previewPanel
	end

	local character = GetPreviewTemplate()
	if not character then
		warn("CharacterEditorUI: cannot create preview character")
		return
	end
	-- GetPreviewTemplate may return the cached template directly; clone it
	-- so the cache is preserved for the next update.
	if character.Parent ~= nil and character.Parent ~= worldModel then
		character = character:Clone()
	elseif character == previewTemplate then
		character = character:Clone()
	end
	character.Name = "PreviewCharacter"

	-- Place the rig at the origin inside the WorldModel.
	local primary = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
	if primary then
		character.PrimaryPart = primary
		character:PivotTo(CFrame.new(0, 0, 0))
	end
	character.Parent = worldModel
	previewCharacter = character

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("CharacterEditorUI: preview rig has no Humanoid")
		return
	end

	local skinColor = GetCurrentSkinColor()
	local hairColor = GetCurrentHairColor()

	local success, err = pcall(function()
		local description = humanoid:GetAppliedDescription()

		-- 1. Race (scale)
		local raceData = CharacterConfig.RACES[currentRace]
		if raceData then
			description.HeightScale = raceData.HeightScale
			description.WidthScale = raceData.WidthScale
			description.HeadScale = raceData.HeadScale
			description.BodyTypeScale = raceData.BodyTypeScale
		end

		-- 2. Hairstyle
		local hairstyle = CharacterConfig.HAIRSTYLES[currentHairstyle]
		if hairstyle and hairstyle.AssetId and hairstyle.AssetId > 0 then
			description.HairAccessory = tostring(hairstyle.AssetId)
		else
			description.HairAccessory = ""
		end

		-- 3. Clothing
		local shirt = CharacterConfig.CLOTHING.Shirts[currentShirt]
		if shirt and shirt.AssetId and shirt.AssetId > 0 then
			description.Shirt = shirt.AssetId
		end
		local pants = CharacterConfig.CLOTHING.Pants[currentPants]
		if pants and pants.AssetId and pants.AssetId > 0 then
			description.Pants = pants.AssetId
		end

		-- 4. Skin color (all body parts)
		description.HeadColor = skinColor
		description.TorsoColor = skinColor
		description.LeftArmColor = skinColor
		description.RightArmColor = skinColor
		description.LeftLegColor = skinColor
		description.RightLegColor = skinColor

		humanoid:ApplyDescription(description)
	end)

	if not success then
		warn("CharacterEditorUI: failed to apply description:", err)
	end

	-- Hair color is applied after ApplyDescription so it overrides the
	-- accessory's stock color.
	TintHair(character, hairColor)

	-- Camera setup
	local camera = previewPanel.CurrentCamera
	if not camera then
		camera = Instance.new("Camera")
		camera.Parent = previewPanel
		previewPanel.CurrentCamera = camera
	end
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 2, 8), Vector3.new(0, 2, 0))
	StartCameraRotation(previewPanel)

	-- Update race label text
	local previewPanelFrame = previewPanel.Parent
	if previewPanelFrame then
		local raceLabel = previewPanelFrame:FindFirstChild("RaceLabel")
		if raceLabel then
			local raceData = CharacterConfig.RACES[currentRace]
			raceLabel.Text = raceData and raceData.Name or currentRace
		end
	end

	print("Preview updated for race:", currentRace)
end

-- Create character editor UI
function CharacterEditorUI.CreateUI()
	-- Create ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CharacterEditorUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	
	-- Background frame
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	background.BorderSizePixel = 0
	background.Parent = screenGui
	
	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0, 600, 0, 80)
	title.Position = UDim2.new(0.5, -300, 0.05, 0)
	title.BackgroundTransparency = 1
	title.Text = "СОЗДАНИЕ ПЕРСОНАЖА"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 36
	title.Font = Enum.Font.GothamBold
	title.Parent = background
	
	-- Left panel - Character preview
	local previewPanel = Instance.new("Frame")
	previewPanel.Name = "PreviewPanel"
	previewPanel.Size = UDim2.new(0, 400, 0, 600)
	previewPanel.Position = UDim2.new(0.1, 0, 0.2, 0)
	previewPanel.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	previewPanel.BorderSizePixel = 0
	previewPanel.Parent = background
	
	local previewCorner = Instance.new("UICorner")
	previewCorner.CornerRadius = UDim.new(0, 12)
	previewCorner.Parent = previewPanel
	
	-- Preview title
	local previewTitle = Instance.new("TextLabel")
	previewTitle.Name = "PreviewTitle"
	previewTitle.Size = UDim2.new(1, 0, 0, 50)
	previewTitle.BackgroundTransparency = 1
	previewTitle.Text = "Предпросмотр"
	previewTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	previewTitle.TextSize = 24
	previewTitle.Font = Enum.Font.GothamBold
	previewTitle.Parent = previewPanel
	
	-- Race label
	local raceLabel = Instance.new("TextLabel")
	raceLabel.Name = "RaceLabel"
	raceLabel.Size = UDim2.new(1, 0, 0, 40)
	raceLabel.Position = UDim2.new(0, 0, 0, 50)
	raceLabel.BackgroundTransparency = 1
	raceLabel.Text = "Человек"
	raceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	raceLabel.TextSize = 20
	raceLabel.Font = Enum.Font.Gotham
	raceLabel.Parent = previewPanel
	
	-- ViewportFrame for 3D preview
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Viewport"
	viewport.Size = UDim2.new(1, -40, 1, -140)
	viewport.Position = UDim2.new(0, 20, 0, 100)
	viewport.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	viewport.BorderSizePixel = 0
	viewport.Parent = previewPanel
	
	local viewportCorner = Instance.new("UICorner")
	viewportCorner.CornerRadius = UDim.new(0, 8)
	viewportCorner.Parent = viewport
	
	-- Camera for viewport
	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.new(0, 2, 8) * CFrame.Angles(0, math.rad(180), 0)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	
	-- Initial preview
	CharacterEditorUI.UpdatePreview(viewport)
	
	-- Right panel - Customization options
	local optionsPanel = Instance.new("ScrollingFrame")
	optionsPanel.Name = "OptionsPanel"
	optionsPanel.Size = UDim2.new(0, 500, 0, 600)
	optionsPanel.Position = UDim2.new(0.55, 0, 0.2, 0)
	optionsPanel.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	optionsPanel.BorderSizePixel = 0
	optionsPanel.ScrollBarThickness = 8
	optionsPanel.CanvasSize = UDim2.new(0, 0, 0, 1000)
	optionsPanel.Parent = background
	
	local optionsCorner = Instance.new("UICorner")
	optionsCorner.CornerRadius = UDim.new(0, 12)
	optionsCorner.Parent = optionsPanel
	
	local optionsLayout = Instance.new("UIListLayout")
	optionsLayout.Padding = UDim.new(0, 20)
	optionsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	optionsLayout.Parent = optionsPanel
	
	-- Spacer at top
	local topSpacer = Instance.new("Frame")
	topSpacer.Size = UDim2.new(1, 0, 0, 10)
	topSpacer.BackgroundTransparency = 1
	topSpacer.Parent = optionsPanel
	
	-- Race selection
	CharacterEditorUI.CreateSection(optionsPanel, "РАСА", function(container)
		for raceName, raceData in pairs(CharacterConfig.RACES) do
			local button = CharacterEditorUI.CreateOptionButton(raceName, raceData.Name)
			button.Parent = container
		end
	end)
	
	-- Hairstyle selection
	CharacterEditorUI.CreateSection(optionsPanel, "ПРИЧЕСКА", function(container)
		for i, hairstyle in ipairs(CharacterConfig.HAIRSTYLES) do
			local button = CharacterEditorUI.CreateOptionButton("Hairstyle" .. i, hairstyle.Name)
			button.Parent = container
		end
	end)
	
	-- Shirt selection
	CharacterEditorUI.CreateSection(optionsPanel, "РУБАШКА", function(container)
		for i, shirt in ipairs(CharacterConfig.CLOTHING.Shirts) do
			local button = CharacterEditorUI.CreateOptionButton("Shirt" .. i, shirt.Name)
			button.Parent = container
		end
	end)
	
	-- Pants selection
	CharacterEditorUI.CreateSection(optionsPanel, "ШТАНЫ", function(container)
		for i, pants in ipairs(CharacterConfig.CLOTHING.Pants) do
			local button = CharacterEditorUI.CreateOptionButton("Pants" .. i, pants.Name)
			button.Parent = container
		end
	end)

	-- Skin color selection
	CharacterEditorUI.CreateSection(optionsPanel, "ЦВЕТ КОЖИ", function(container)
		for i, swatch in ipairs(CharacterConfig.SKIN_COLORS) do
			local button = CharacterEditorUI.CreateColorButton("Skin" .. i, swatch.Name, swatch.Color)
			button.Parent = container
		end
	end)

	-- Hair color selection
	CharacterEditorUI.CreateSection(optionsPanel, "ЦВЕТ ВОЛОС", function(container)
		for i, swatch in ipairs(CharacterConfig.HAIR_COLORS) do
			local button = CharacterEditorUI.CreateColorButton("Hair" .. i, swatch.Name, swatch.Color)
			button.Parent = container
		end
	end)

	-- Grow the scrolling canvas to fit the new sections
	optionsPanel.CanvasSize = UDim2.new(0, 0, 0, 1500)

	
	-- Bottom buttons
	local buttonsContainer = Instance.new("Frame")
	buttonsContainer.Name = "ButtonsContainer"
	buttonsContainer.Size = UDim2.new(0, 500, 0, 60)
	buttonsContainer.Position = UDim2.new(0.5, -250, 0.9, 0)
	buttonsContainer.BackgroundTransparency = 1
	buttonsContainer.Parent = background
	
	-- Back button
	local backButton = Instance.new("TextButton")
	backButton.Name = "BackButton"
	backButton.Size = UDim2.new(0, 230, 0, 50)
	backButton.Position = UDim2.new(0, 0, 0, 0)
	backButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
	backButton.Text = "НАЗАД"
	backButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	backButton.TextSize = 20
	backButton.Font = Enum.Font.GothamBold
	backButton.Parent = buttonsContainer
	
	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0, 8)
	backCorner.Parent = backButton
	
	-- Confirm button
	local confirmButton = Instance.new("TextButton")
	confirmButton.Name = "ConfirmButton"
	confirmButton.Size = UDim2.new(0, 230, 0, 50)
	confirmButton.Position = UDim2.new(1, -230, 0, 0)
	confirmButton.BackgroundColor3 = Color3.fromRGB(60, 150, 60)
	confirmButton.Text = "ПОДТВЕРДИТЬ"
	confirmButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	confirmButton.TextSize = 20
	confirmButton.Font = Enum.Font.GothamBold
	confirmButton.Parent = buttonsContainer
	
	local confirmCorner = Instance.new("UICorner")
	confirmCorner.CornerRadius = UDim.new(0, 8)
	confirmCorner.Parent = confirmButton
	
	screenGui.Parent = playerGui
	return screenGui
end

-- Create a customization section
function CharacterEditorUI.CreateSection(parent, title, createOptions)
	local section = Instance.new("Frame")
	section.Name = title .. "Section"
	section.Size = UDim2.new(0, 460, 0, 200)
	section.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	section.BorderSizePixel = 0
	section.Parent = parent
	
	local sectionCorner = Instance.new("UICorner")
	sectionCorner.CornerRadius = UDim.new(0, 8)
	sectionCorner.Parent = section
	
	-- Section title
	local sectionTitle = Instance.new("TextLabel")
	sectionTitle.Name = "Title"
	sectionTitle.Size = UDim2.new(1, 0, 0, 40)
	sectionTitle.BackgroundTransparency = 1
	sectionTitle.Text = title
	sectionTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	sectionTitle.TextSize = 20
	sectionTitle.Font = Enum.Font.GothamBold
	sectionTitle.Parent = section
	
	-- Options container
	local optionsContainer = Instance.new("Frame")
	optionsContainer.Name = "OptionsContainer"
	optionsContainer.Size = UDim2.new(1, -20, 1, -50)
	optionsContainer.Position = UDim2.new(0, 10, 0, 45)
	optionsContainer.BackgroundTransparency = 1
	optionsContainer.Parent = section
	
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, 140, 0, 40)
	layout.CellPadding = UDim2.new(0, 5, 0, 5)
	layout.Parent = optionsContainer
	
	-- Create options
	if createOptions then
		createOptions(optionsContainer)
	end
	
	-- Auto-resize section based on content
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		section.Size = UDim2.new(0, 460, 0, layout.AbsoluteContentSize.Y + 60)
	end)
	
	return section
end

-- Create an option button
function CharacterEditorUI.CreateOptionButton(id, text)
	local button = Instance.new("TextButton")
	button.Name = id
	button.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 16
	button.Font = Enum.Font.Gotham
	button.AutoButtonColor = false
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button
	
	return button
end

-- Create a color swatch button. The button background shows the swatch
-- color directly and a translucent label strip displays its name. The
-- selection state is shown via a colored UIStroke.
function CharacterEditorUI.CreateColorButton(id, text, color)
	local button = Instance.new("TextButton")
	button.Name = id
	button.BackgroundColor3 = color
	button.Text = ""
	button.AutoButtonColor = false

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Color = Color3.fromRGB(70, 70, 80)
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -2)
	label.Size = UDim2.new(1, -4, 0, 16)
	label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	label.BackgroundTransparency = 0.45
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 12
	label.Font = Enum.Font.Gotham
	label.Parent = button

	local labelCorner = Instance.new("UICorner")
	labelCorner.CornerRadius = UDim.new(0, 4)
	labelCorner.Parent = label

	return button
end

-- Setup button handlers
function CharacterEditorUI.SetupHandlers(screenGui, onBack, onConfirm)
	local background = screenGui.Background
	local optionsPanel = background.OptionsPanel
	local viewport = background.PreviewPanel.Viewport
	
	-- Race buttons
	for raceName, raceData in pairs(CharacterConfig.RACES) do
		local button = optionsPanel:FindFirstChild(raceName, true)
		if button then
			button.MouseButton1Click:Connect(function()
				currentRace = raceName
				CharacterEditorUI.UpdateSelection(optionsPanel, "РАСА", raceName)
				CharacterEditorUI.UpdatePreview(viewport)
				print("Selected race:", raceName)
			end)
		end
	end
	
	-- Hairstyle buttons
	for i, hairstyle in ipairs(CharacterConfig.HAIRSTYLES) do
		local button = optionsPanel:FindFirstChild("Hairstyle" .. i, true)
		if button then
			button.MouseButton1Click:Connect(function()
				currentHairstyle = i
				CharacterEditorUI.UpdateSelection(optionsPanel, "ПРИЧЕСКА", "Hairstyle" .. i)
				CharacterEditorUI.UpdatePreview(viewport)
				print("Selected hairstyle:", i)
			end)
		end
	end
	
	-- Shirt buttons
	for i, shirt in ipairs(CharacterConfig.CLOTHING.Shirts) do
		local button = optionsPanel:FindFirstChild("Shirt" .. i, true)
		if button then
			button.MouseButton1Click:Connect(function()
				currentShirt = i
				CharacterEditorUI.UpdateSelection(optionsPanel, "РУБАШКА", "Shirt" .. i)
				CharacterEditorUI.UpdatePreview(viewport)
				print("Selected shirt:", i)
			end)
		end
	end
	
	-- Pants buttons
	for i, pants in ipairs(CharacterConfig.CLOTHING.Pants) do
		local button = optionsPanel:FindFirstChild("Pants" .. i, true)
		if button then
			button.MouseButton1Click:Connect(function()
				currentPants = i
				CharacterEditorUI.UpdateSelection(optionsPanel, "ШТАНЫ", "Pants" .. i)
				CharacterEditorUI.UpdatePreview(viewport)
				print("Selected pants:", i)
			end)
		end
	end

	-- Skin color buttons
	for i in ipairs(CharacterConfig.SKIN_COLORS) do
		local button = optionsPanel:FindFirstChild("Skin" .. i, true)
		if button then
			button.MouseButton1Click:Connect(function()
				currentSkinColorIndex = i
				CharacterEditorUI.UpdateSelection(optionsPanel, "ЦВЕТ КОЖИ", "Skin" .. i)
				CharacterEditorUI.UpdatePreview(viewport)
			end)
		end
	end

	-- Hair color buttons
	for i in ipairs(CharacterConfig.HAIR_COLORS) do
		local button = optionsPanel:FindFirstChild("Hair" .. i, true)
		if button then
			button.MouseButton1Click:Connect(function()
				currentHairColorIndex = i
				CharacterEditorUI.UpdateSelection(optionsPanel, "ЦВЕТ ВОЛОС", "Hair" .. i)
				CharacterEditorUI.UpdatePreview(viewport)
			end)
		end
	end

	-- Back button
	local backButton = background.ButtonsContainer.BackButton
	backButton.MouseButton1Click:Connect(function()
		if onBack then
			onBack()
		end
	end)
	
	-- Confirm button
	local confirmButton = background.ButtonsContainer.ConfirmButton
	confirmButton.MouseButton1Click:Connect(function()
		local skinSwatch = CharacterConfig.SKIN_COLORS[currentSkinColorIndex]
		local hairSwatch = CharacterConfig.HAIR_COLORS[currentHairColorIndex]
		local characterData = {
			Race = currentRace,
			HairstyleIndex = currentHairstyle,
			ShirtIndex = currentShirt,
			PantsIndex = currentPants,
			SkinColorIndex = currentSkinColorIndex,
			HairColorIndex = currentHairColorIndex,
			SkinColor = (skinSwatch and skinSwatch.Color) or CharacterConfig.DEFAULT_CHARACTER.SkinColor,
			HairColor = (hairSwatch and hairSwatch.Color) or CharacterConfig.DEFAULT_CHARACTER.HairColor,
		}

		if onConfirm then
			onConfirm(characterData)
		end
	end)
end

-- Update the selection visual for a section. Color-swatch buttons keep
-- their swatch color and instead toggle a gold UIStroke to indicate the
-- active choice; regular text buttons swap their background color.
function CharacterEditorUI.UpdateSelection(optionsPanel, sectionName, selectedId)
	local section = optionsPanel:FindFirstChild(sectionName .. "Section")
	if not section then return end

	local container = section:FindFirstChild("OptionsContainer")
	if not container then return end

	for _, button in ipairs(container:GetChildren()) do
		if button:IsA("TextButton") then
			local stroke = button:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = Color3.fromRGB(70, 70, 80)
				stroke.Thickness = 2
			else
				button.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
			end
		end
	end

	local selectedButton = container:FindFirstChild(selectedId)
	if selectedButton then
		local stroke = selectedButton:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = Color3.fromRGB(255, 215, 0)
			stroke.Thickness = 4
		else
			selectedButton.BackgroundColor3 = Color3.fromRGB(100, 150, 100)
		end
	end
end

-- Initialize with default selections
function CharacterEditorUI.InitializeDefaults(screenGui)
	local optionsPanel = screenGui.Background.OptionsPanel
	CharacterEditorUI.UpdateSelection(optionsPanel, "РАСА", "Human")
	CharacterEditorUI.UpdateSelection(optionsPanel, "ПРИЧЕСКА", "Hairstyle1")
	CharacterEditorUI.UpdateSelection(optionsPanel, "РУБАШКА", "Shirt1")
	CharacterEditorUI.UpdateSelection(optionsPanel, "ШТАНЫ", "Pants1")
	CharacterEditorUI.UpdateSelection(optionsPanel, "ЦВЕТ КОЖИ", "Skin" .. currentSkinColorIndex)
	CharacterEditorUI.UpdateSelection(optionsPanel, "ЦВЕТ ВОЛОС", "Hair" .. currentHairColorIndex)
end

return CharacterEditorUI
