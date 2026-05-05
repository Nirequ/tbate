-- CharacterEditorUI (composer)
-- Owns the editor's visible UI state and orchestrates the four
-- sibling helper modules:
--
--   HumanoidBuilder — pure rig + description helpers
--   PreviewSpawn    — anchor / placement / body-bounds math
--   OrbitCamera     — Workspace.CurrentCamera scriptable orbit
--   UIBuilder       — section / mini-preview / RGB-picker factories
--
-- Architecture (post-redesign):
--   * The "preview" is the player's R6 character placed directly in
--     the real Workspace (FilteringEnabled means only this client sees
--     it), anchored on top of a Part named "PreviewSpot" or the
--     SpawnLocation.
--   * Workspace.CurrentCamera is locked into Scriptable mode and
--     orbits the preview character; mouse drag rotates, scroll wheel
--     zooms.
--   * The UI itself is just a transparent right-hand options panel
--     with mini-preview thumbnails for hair / face / clothing and an
--     RGB+HEX color picker for skin / hair colour.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterConfig = require(Shared:WaitForChild("CharacterConfig"))

local HumanoidBuilder = require(script.HumanoidBuilder)
local PreviewSpawn = require(script.PreviewSpawn)
local OrbitCamera = require(script.OrbitCamera)
local UIBuilder = require(script.UIBuilder)

local CharacterEditorUI = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DEFAULT_SKIN = CharacterConfig.DEFAULT_CHARACTER.SkinColor or Color3.fromRGB(255, 204, 153)
local DEFAULT_HAIR = CharacterConfig.DEFAULT_CHARACTER.HairColor or Color3.fromRGB(139, 69, 19)

-- All editor state in one table so it's obvious what gets mutated by
-- handlers and what's read by UpdatePreview / SetupHandlers / etc.
local state = {
	selection = {
		race           = "Human",
		hairstyleIndex = 1,
		faceIndex      = CharacterConfig.DEFAULT_CHARACTER.FaceIndex or 1,
		shirtIndex     = 1,
		pantsIndex     = 1,
		skinColor      = DEFAULT_SKIN,
		hairColor      = DEFAULT_HAIR,
	},
	worldCharacter   = nil,
	activeScreenGui  = nil,
	optionsPanelRef  = nil,
	previewGeneration = 0,
}

-- The asset categories that all share the mini-preview-grid UI shape:
-- hairstyle, face, shirt, pants. The race section is text-only and is
-- handled separately because its key is a string, not an integer index.
local CATEGORIES = {
	{idPrefix = "Hairstyle", sectionId = "HairstyleSection", title = "HAIR",  kind = "hair",  options = CharacterConfig.HAIRSTYLES,            stateKey = "hairstyleIndex"},
	{idPrefix = "Face",      sectionId = "FaceSection",      title = "FACE",  kind = "face",  options = CharacterConfig.FACES,                 stateKey = "faceIndex"},
	{idPrefix = "Shirt",     sectionId = "ShirtSection",     title = "SHIRT", kind = "shirt", options = CharacterConfig.CLOTHING.Shirts,       stateKey = "shirtIndex"},
	{idPrefix = "Pants",     sectionId = "PantsSection",     title = "PANTS", kind = "pants", options = CharacterConfig.CLOTHING.Pants,        stateKey = "pantsIndex"},
}

local function getHairColor() return state.selection.hairColor end

-- =================================================================
-- World preview lifecycle.
-- =================================================================

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
function CharacterEditorUI.UpdatePreview()
	state.previewGeneration = state.previewGeneration + 1
	local myGen = state.previewGeneration
	local description = HumanoidBuilder.BuildSelectionDescription(state.selection)

	for _, child in ipairs(Workspace:GetChildren()) do
		if child.Name == "PreviewCharacter" then
			child:Destroy()
		end
	end
	state.worldCharacter = nil

	local character = HumanoidBuilder.BuildR6Rig(description)
	if not character then
		warn("CharacterEditorUI: cannot create world preview character")
		return
	end

	-- A newer UpdatePreview call superseded us while BuildR6Rig was
	-- yielding on asset loads; throw this rig away instead of leaking
	-- it into the workspace as a duplicate.
	if myGen ~= state.previewGeneration then
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
	local raceData = CharacterConfig.RACES[state.selection.race]
	local raceScale = (raceData and raceData.HeightScale) or 1.0
	pcall(function()
		character:ScaleTo(raceScale)
	end)

	PreviewSpawn.PlaceOnAnchor(character)
	-- Anchor the HRP BEFORE parenting so physics doesn't get a chance to
	-- run a tick on the unanchored rig and drift it before AnchorRig
	-- finishes (the visible "flying / floating" symptom users were
	-- seeing when swapping race / hair / clothing).
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.Anchored = true
	end
	character.Parent = Workspace
	PreviewSpawn.AnchorRig(character)
	state.worldCharacter = character

	HumanoidBuilder.SetSkinColor(character, state.selection.skinColor)
	HumanoidBuilder.TintHair(character, state.selection.hairColor)
	for _, delaySeconds in ipairs({0.1, 0.5, 1.5, 3.0}) do
		task.delay(delaySeconds, function()
			if character.Parent and myGen == state.previewGeneration then
				HumanoidBuilder.TintHair(character, state.selection.hairColor)
				-- Re-anchor only the HRP — accessories (hair) need to stay
				-- non-anchored so their welds keep them attached to the head.
				PreviewSpawn.AnchorRig(character)
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
		if descendant:IsA("Accessory") and HumanoidBuilder.IsHairAccessory(descendant) then
			task.defer(HumanoidBuilder.TintHair, character, state.selection.hairColor)
		end
	end)
end

-- Don't start an orbit-camera drag if the click landed on top of any
-- of our UI panels (options panel, side shade, or the buttons inside).
-- gameProcessed isn't reliable for plain Frame/TextButton clicks, so
-- we do an explicit hit-test against the panel bounds.
local function isClickOverUI(input)
	local panel = state.optionsPanelRef
	if not panel or not panel.Parent then return false end
	local pos = input.Position
	local panelPos = panel.AbsolutePosition
	local panelSize = panel.AbsoluteSize
	if pos.X >= panelPos.X and pos.X <= panelPos.X + panelSize.X
		and pos.Y >= panelPos.Y and pos.Y <= panelPos.Y + panelSize.Y then
		return true
	end
	local screenGui = panel.Parent
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

-- =================================================================
-- Main UI.
-- =================================================================
function CharacterEditorUI.CreateUI()
	-- Place the world preview character first so the camera has something
	-- to lock onto when the UI fades in.
	CharacterEditorUI.UpdatePreview()
	OrbitCamera.Setup({
		getCharacter = function() return state.worldCharacter end,
		isClickOverUI = isClickOverUI,
	})

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
	title.Text = "CHARACTER CREATION"
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
	state.optionsPanelRef = optionsPanel

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
	local raceSection, raceContent = UIBuilder.CreateSection(optionsPanel, "RaceSection", "RACE")
	raceSection.LayoutOrder = 1
	UIBuilder.MakeGridContainer(raceContent, UDim2.new(0, 130, 0, 36))
	for raceName, raceData in pairs(CharacterConfig.RACES) do
		local btn = UIBuilder.CreateTextOptionButton(raceName, raceData.Name)
		btn.Parent = raceContent
	end

	-- Hairstyle / face / shirt / pants — all share the mini-preview grid.
	for catIndex, category in ipairs(CATEGORIES) do
		local section, content = UIBuilder.CreateSection(optionsPanel, category.sectionId, category.title)
		section.LayoutOrder = catIndex + 1
		UIBuilder.MakeGridContainer(content, UDim2.new(0, 92, 0, 110))
		for i, asset in ipairs(category.options) do
			local btn = UIBuilder.CreateMiniPreviewButton(
				category.idPrefix .. i,
				asset.Name,
				category.kind,
				asset,
				{getHairColor = getHairColor})
			btn.LayoutOrder = i
			btn.Parent = content
		end
	end

	-- Skin colour picker.
	local skinSection, skinContent = UIBuilder.CreateSection(optionsPanel, "SkinColorSection", "SKIN COLOR")
	skinSection.LayoutOrder = 6
	local skinPicker = UIBuilder.CreateRGBColorPicker("SkinPicker", state.selection.skinColor, function(color)
		state.selection.skinColor = color
		if state.worldCharacter then
			HumanoidBuilder.SetSkinColor(state.worldCharacter, color)
		end
	end)
	skinPicker.Parent = skinContent

	-- Hair colour picker.
	local hairColorSection, hairColorContent = UIBuilder.CreateSection(optionsPanel, "HairColorSection", "HAIR COLOR")
	hairColorSection.LayoutOrder = 7
	local hairPicker = UIBuilder.CreateRGBColorPicker("HairPicker", state.selection.hairColor, function(color)
		state.selection.hairColor = color
		if state.worldCharacter then
			HumanoidBuilder.TintHair(state.worldCharacter, color)
		end
	end)
	hairPicker.Parent = hairColorContent

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
	backButton.Text = "BACK"
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
	confirmButton.Text = "CONFIRM"
	confirmButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	confirmButton.TextSize = 18
	confirmButton.Font = Enum.Font.GothamBold
	confirmButton.AutoButtonColor = false
	confirmButton.Parent = buttonsContainer

	local confirmCorner = Instance.new("UICorner")
	confirmCorner.CornerRadius = UDim.new(0, 8)
	confirmCorner.Parent = confirmButton

	screenGui.Parent = playerGui
	state.activeScreenGui = screenGui
	return screenGui
end

-- =================================================================
-- Selection state visuals.
-- =================================================================
function CharacterEditorUI.UpdateSelection(_, sectionId, selectedId)
	if not state.optionsPanelRef then return end
	local section = state.optionsPanelRef:FindFirstChild(sectionId)
	if not section then return end
	local content = section:FindFirstChild("Content")
	UIBuilder.SetGroupSelection(content, selectedId)
end

-- =================================================================
-- Wire up button handlers.
-- =================================================================
local function teardown()
	OrbitCamera.Restore()
	if state.worldCharacter then
		state.worldCharacter:Destroy()
		state.worldCharacter = nil
	end
end

function CharacterEditorUI.SetupHandlers(screenGui, onBack, onConfirm)
	local optionsPanel = screenGui:FindFirstChild("OptionsPanel") or state.optionsPanelRef
	if not optionsPanel then return end

	-- Race buttons.
	for raceName in pairs(CharacterConfig.RACES) do
		local btn = optionsPanel:FindFirstChild(raceName, true)
		if btn then
			btn.MouseButton1Click:Connect(function()
				state.selection.race = raceName
				CharacterEditorUI.UpdateSelection(nil, "RaceSection", raceName)
				CharacterEditorUI.UpdatePreview()
			end)
		end
	end

	-- Hair / Face / Shirt / Pants buttons — all the same shape.
	for _, category in ipairs(CATEGORIES) do
		for i in ipairs(category.options) do
			local id = category.idPrefix .. i
			local btn = optionsPanel:FindFirstChild(id, true)
			if btn then
				btn.MouseButton1Click:Connect(function()
					state.selection[category.stateKey] = i
					CharacterEditorUI.UpdateSelection(nil, category.sectionId, id)
					CharacterEditorUI.UpdatePreview()
				end)
			end
		end
	end

	-- Action buttons.
	local buttons = screenGui:FindFirstChild("ButtonsContainer")
	if buttons then
		local backButton = buttons:FindFirstChild("BackButton")
		if backButton then
			backButton.MouseButton1Click:Connect(function()
				teardown()
				if onBack then onBack() end
			end)
		end

		local confirmButton = buttons:FindFirstChild("ConfirmButton")
		if confirmButton then
			confirmButton.MouseButton1Click:Connect(function()
				local characterData = {
					Race           = state.selection.race,
					HairstyleIndex = state.selection.hairstyleIndex,
					FaceIndex      = state.selection.faceIndex,
					ShirtIndex     = state.selection.shirtIndex,
					PantsIndex     = state.selection.pantsIndex,
					SkinColor      = state.selection.skinColor,
					HairColor      = state.selection.hairColor,
				}

				teardown()

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
	CharacterEditorUI.UpdateSelection(nil, "RaceSection", state.selection.race)
	for _, category in ipairs(CATEGORIES) do
		CharacterEditorUI.UpdateSelection(
			nil,
			category.sectionId,
			category.idPrefix .. state.selection[category.stateKey])
	end
end

return CharacterEditorUI
