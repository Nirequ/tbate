-- UI Manager for character slot selection
-- Renders MAX_SLOTS slot cards with three visual states (empty,
-- filled, locked) styled after the dark-fantasy / gold-accent
-- mockup. The middle of each card stays a flat placeholder for now —
-- once we store HumanoidDescriptions per slot we can drop a real
-- ViewportFrame in there.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterController = require(script.Parent.CharacterController)
local CharacterConfig = require(Shared:WaitForChild("CharacterConfig"))

local SlotSelectionUI = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- =================================================================
-- Theme
-- =================================================================

local THEME = {
	Background        = Color3.fromRGB(14, 13, 12),
	CardBackground    = Color3.fromRGB(26, 23, 20),
	PreviewBackground = Color3.fromRGB(22, 20, 18),
	BorderDim         = Color3.fromRGB(82, 65, 38),
	BorderActive      = Color3.fromRGB(229, 196, 106),
	StripeDark        = Color3.fromRGB(20, 17, 14),
	StripeMid         = Color3.fromRGB(38, 32, 22),
	TextPrimary       = Color3.fromRGB(232, 220, 196),
	TextSecondary     = Color3.fromRGB(160, 145, 120),
	TextDim           = Color3.fromRGB(120, 100, 70),
	GoldBright        = Color3.fromRGB(229, 196, 106),
	GoldDim           = Color3.fromRGB(140, 110, 60),
	GoldButtonText    = Color3.fromRGB(28, 22, 14),
	AccentDanger      = Color3.fromRGB(180, 60, 60),
}

local SLOT_FLAVOR = {
	[1] = "Forge a new legend in the annals of history.",
	[2] = "Expand your barracks to house another champion of the realm.",
	[3] = "Inscribe one more saga upon the everlasting tome.",
}

-- =================================================================
-- Helpers
-- =================================================================

local function MakeCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = parent
	return corner
end

local function MakeStroke(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1
	stroke.Parent = parent
	return stroke
end

-- Diagonal hatching effect rendered as a fan of thin rotated Frames.
-- Cheap and works without a tiling texture asset; the parent's
-- ClipsDescendants + UICorner do the rounded-rectangle masking for
-- us so the stripes don't poke past the card corners.
local function MakeDiagonalStripes(parent, color, transparency)
	local container = Instance.new("Frame")
	container.Name = "Stripes"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.Parent = parent

	local stripeWidth = 4
	local stripeGap = 14
	local stripeLen = 700
	for i = -25, 25 do
		local stripe = Instance.new("Frame")
		stripe.Size = UDim2.new(0, stripeWidth, 0, stripeLen)
		stripe.AnchorPoint = Vector2.new(0.5, 0.5)
		stripe.Position = UDim2.new(0.5, i * stripeGap, 0.5, 0)
		stripe.BackgroundColor3 = color
		stripe.BackgroundTransparency = transparency
		stripe.BorderSizePixel = 0
		stripe.Rotation = 45
		stripe.Parent = container
	end

	return container
end

-- A short horizontal gold line, used to flank the title text.
local function MakeTitleAccentLine(parent, name)
	local line = Instance.new("Frame")
	line.Name = name
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Size = UDim2.new(0, 90, 0, 1)
	line.BackgroundColor3 = THEME.GoldBright
	line.BorderSizePixel = 0
	line.Parent = parent
	return line
end

-- =================================================================
-- Slot card subcomponents
-- =================================================================

-- The dim overlay that sits on top of locked slots.
local function CreateLockOverlay(slotIndex)
	local lockOverlay = Instance.new("Frame")
	lockOverlay.Name = "LockOverlay"
	lockOverlay.Size = UDim2.new(1, 0, 1, 0)
	lockOverlay.BackgroundColor3 = THEME.StripeDark
	lockOverlay.BorderSizePixel = 0
	lockOverlay.ClipsDescendants = true
	lockOverlay.ZIndex = 5
	lockOverlay.Visible = true
	MakeCorner(lockOverlay, 12)
	MakeStroke(lockOverlay, THEME.BorderDim, 1)

	MakeDiagonalStripes(lockOverlay, THEME.StripeMid, 0.15)

	local lockIcon = Instance.new("TextLabel")
	lockIcon.Name = "LockIcon"
	lockIcon.Size = UDim2.new(0, 60, 0, 60)
	lockIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	lockIcon.Position = UDim2.new(0.5, 0, 0.30, 0)
	lockIcon.BackgroundTransparency = 1
	lockIcon.Text = "🔒"
	lockIcon.TextSize = 44
	lockIcon.TextColor3 = THEME.TextSecondary
	lockIcon.ZIndex = 6
	lockIcon.Parent = lockOverlay

	local lockTitle = Instance.new("TextLabel")
	lockTitle.Name = "LockTitle"
	lockTitle.Size = UDim2.new(1, -32, 0, 26)
	lockTitle.AnchorPoint = Vector2.new(0.5, 0)
	lockTitle.Position = UDim2.new(0.5, 0, 0.46, 0)
	lockTitle.BackgroundTransparency = 1
	lockTitle.Text = "Sealed Slot"
	lockTitle.TextColor3 = THEME.TextPrimary
	lockTitle.TextSize = 20
	lockTitle.Font = Enum.Font.GothamBold
	lockTitle.ZIndex = 6
	lockTitle.Parent = lockOverlay

	local lockFlavor = Instance.new("TextLabel")
	lockFlavor.Name = "LockFlavor"
	lockFlavor.Size = UDim2.new(1, -36, 0, 50)
	lockFlavor.AnchorPoint = Vector2.new(0.5, 0)
	lockFlavor.Position = UDim2.new(0.5, 0, 0.55, 0)
	lockFlavor.BackgroundTransparency = 1
	lockFlavor.Text = SLOT_FLAVOR[slotIndex] or "Expand your barracks to house another champion."
	lockFlavor.TextColor3 = THEME.TextSecondary
	lockFlavor.TextSize = 12
	lockFlavor.Font = Enum.Font.Gotham
	lockFlavor.TextWrapped = true
	lockFlavor.ZIndex = 6
	lockFlavor.Parent = lockOverlay

	local unlockButton = Instance.new("TextButton")
	unlockButton.Name = "UnlockButton"
	unlockButton.Size = UDim2.new(1, -32, 0, 42)
	unlockButton.AnchorPoint = Vector2.new(0.5, 1)
	unlockButton.Position = UDim2.new(0.5, 0, 1, -16)
	unlockButton.BackgroundColor3 = THEME.CardBackground
	unlockButton.AutoButtonColor = false
	unlockButton.Text = "🔒 UNLOCK " .. CharacterConfig.SLOT_COSTS[slotIndex] .. " ROBUX"
	unlockButton.TextColor3 = THEME.GoldDim
	unlockButton.TextSize = 13
	unlockButton.Font = Enum.Font.GothamBold
	unlockButton.ZIndex = 6
	unlockButton.Parent = lockOverlay
	MakeCorner(unlockButton, 6)
	MakeStroke(unlockButton, THEME.GoldDim, 1)

	return lockOverlay
end

-- One slot card. Visual state (empty / filled / locked) is set by
-- UpdateUI based on server data; CreateSlotFrame just lays out all
-- the elements in their default empty appearance plus the hidden
-- filled-state widgets, so UpdateUI only has to flip Visible flags
-- and recolour the border/button.
local function CreateSlotFrame(slotIndex)
	local slotFrame = Instance.new("Frame")
	slotFrame.Name = "Slot" .. slotIndex
	slotFrame.Size = UDim2.new(0, 230, 0, 360)
	slotFrame.BackgroundColor3 = THEME.CardBackground
	slotFrame.BorderSizePixel = 0
	slotFrame.ClipsDescendants = true
	MakeCorner(slotFrame, 12)
	local cardStroke = MakeStroke(slotFrame, THEME.BorderDim, 1)
	cardStroke.Name = "CardStroke"

	-- Inner content holder so the lock overlay can sit on top
	-- without clobbering the card-frame stroke.
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(1, 0, 1, 0)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Parent = slotFrame

	-- Empty-state center icon + flavor text, shown when the slot is
	-- unlocked but no character has been created yet.
	local iconBubble = Instance.new("Frame")
	iconBubble.Name = "IconBubble"
	iconBubble.Size = UDim2.new(0, 64, 0, 64)
	iconBubble.AnchorPoint = Vector2.new(0.5, 0)
	iconBubble.Position = UDim2.new(0.5, 0, 0.20, 0)
	iconBubble.BackgroundColor3 = THEME.PreviewBackground
	iconBubble.BorderSizePixel = 0
	iconBubble.Parent = content
	MakeCorner(iconBubble, 32)
	MakeStroke(iconBubble, THEME.BorderDim, 1)

	local iconPlus = Instance.new("TextLabel")
	iconPlus.Name = "IconPlus"
	iconPlus.Size = UDim2.new(1, 0, 1, 0)
	iconPlus.BackgroundTransparency = 1
	iconPlus.Text = "+"
	iconPlus.TextColor3 = THEME.GoldDim
	iconPlus.TextSize = 36
	iconPlus.Font = Enum.Font.GothamBold
	iconPlus.Parent = iconBubble

	local emptyTitle = Instance.new("TextLabel")
	emptyTitle.Name = "EmptyTitle"
	emptyTitle.Size = UDim2.new(1, -32, 0, 26)
	emptyTitle.AnchorPoint = Vector2.new(0.5, 0)
	emptyTitle.Position = UDim2.new(0.5, 0, 0.46, 0)
	emptyTitle.BackgroundTransparency = 1
	emptyTitle.Text = "New Lineage"
	emptyTitle.TextColor3 = THEME.TextPrimary
	emptyTitle.TextSize = 20
	emptyTitle.Font = Enum.Font.GothamBold
	emptyTitle.Parent = content

	local emptyFlavor = Instance.new("TextLabel")
	emptyFlavor.Name = "EmptyFlavor"
	emptyFlavor.Size = UDim2.new(1, -36, 0, 50)
	emptyFlavor.AnchorPoint = Vector2.new(0.5, 0)
	emptyFlavor.Position = UDim2.new(0.5, 0, 0.55, 0)
	emptyFlavor.BackgroundTransparency = 1
	emptyFlavor.Text = SLOT_FLAVOR[slotIndex] or "Forge a new legend."
	emptyFlavor.TextColor3 = THEME.TextSecondary
	emptyFlavor.TextSize = 12
	emptyFlavor.Font = Enum.Font.Gotham
	emptyFlavor.TextWrapped = true
	emptyFlavor.Parent = content

	-- Filled-state widgets. Hidden by default; UpdateUI flips them on
	-- and hides the empty-state widgets when characterData arrives.
	local lvlBadge = Instance.new("TextLabel")
	lvlBadge.Name = "LvlBadge"
	lvlBadge.Size = UDim2.new(0, 56, 0, 22)
	lvlBadge.Position = UDim2.new(0, 12, 0, 12)
	lvlBadge.BackgroundColor3 = THEME.CardBackground
	lvlBadge.BorderSizePixel = 0
	lvlBadge.Text = "LVL 1"
	lvlBadge.TextColor3 = THEME.GoldBright
	lvlBadge.TextSize = 12
	lvlBadge.Font = Enum.Font.GothamBold
	lvlBadge.Visible = false
	lvlBadge.Parent = content
	MakeCorner(lvlBadge, 4)
	MakeStroke(lvlBadge, THEME.GoldBright, 1)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, -24, 0, 26)
	nameLabel.AnchorPoint = Vector2.new(0, 1)
	nameLabel.Position = UDim2.new(0, 12, 1, -86)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = ""
	nameLabel.TextColor3 = THEME.TextPrimary
	nameLabel.TextSize = 22
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Visible = false
	nameLabel.Parent = content

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "SubtitleLabel"
	subtitleLabel.Size = UDim2.new(1, -24, 0, 16)
	subtitleLabel.AnchorPoint = Vector2.new(0, 1)
	subtitleLabel.Position = UDim2.new(0, 12, 1, -68)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Text = ""
	subtitleLabel.TextColor3 = THEME.GoldDim
	subtitleLabel.TextSize = 12
	subtitleLabel.Font = Enum.Font.Gotham
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.Visible = false
	subtitleLabel.Parent = content

	-- Action button. Default styling = empty state (dim outline,
	-- transparent fill); UpdateUI re-styles it for the filled state.
	local selectButton = Instance.new("TextButton")
	selectButton.Name = "SelectButton"
	selectButton.Size = UDim2.new(1, -32, 0, 42)
	selectButton.AnchorPoint = Vector2.new(0.5, 1)
	selectButton.Position = UDim2.new(0.5, 0, 1, -16)
	selectButton.BackgroundColor3 = THEME.CardBackground
	selectButton.AutoButtonColor = false
	selectButton.Text = "+ CREATE"
	selectButton.TextColor3 = THEME.GoldBright
	selectButton.TextSize = 14
	selectButton.Font = Enum.Font.GothamBold
	selectButton.Parent = content
	MakeCorner(selectButton, 6)
	local btnStroke = MakeStroke(selectButton, THEME.GoldDim, 1)
	btnStroke.Name = "ButtonStroke"

	if slotIndex > 1 then
		CreateLockOverlay(slotIndex).Parent = slotFrame
	end

	return slotFrame
end

-- Debug-only "Reset slots" button: only shown when running inside
-- Studio. Wipes the player's saved slot data so the editor can be
-- exercised from a clean state without poking the DataStore by
-- hand. The actual reset is performed server-side and gated again
-- with RunService:IsStudio() there for safety.
local function CreateDebugResetButton()
	local resetButton = Instance.new("TextButton")
	resetButton.Name = "DebugResetButton"
	resetButton.Size = UDim2.new(0, 220, 0, 36)
	resetButton.AnchorPoint = Vector2.new(1, 1)
	resetButton.Position = UDim2.new(1, -16, 1, -16)
	resetButton.BackgroundColor3 = THEME.AccentDanger
	resetButton.Text = "[DEBUG] RESET SLOTS"
	resetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	resetButton.TextSize = 14
	resetButton.Font = Enum.Font.GothamBold
	resetButton.AutoButtonColor = true
	MakeCorner(resetButton, 6)
	return resetButton
end

-- =================================================================
-- Public API
-- =================================================================

function SlotSelectionUI.CreateUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SlotSelectionUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = true

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = THEME.Background
	background.BorderSizePixel = 0
	background.Parent = screenGui

	-- Title block: centered "CHOOSE YOUR HERO" flanked by two short
	-- gold accent lines and topped by a tiny ornament glyph.
	local titleHolder = Instance.new("Frame")
	titleHolder.Name = "TitleHolder"
	titleHolder.AnchorPoint = Vector2.new(0.5, 0)
	titleHolder.Position = UDim2.new(0.5, 0, 0.10, 0)
	titleHolder.Size = UDim2.new(0, 720, 0, 80)
	titleHolder.BackgroundTransparency = 1
	titleHolder.Parent = background

	local titleOrnament = Instance.new("TextLabel")
	titleOrnament.Name = "TitleOrnament"
	titleOrnament.Size = UDim2.new(1, 0, 0, 18)
	titleOrnament.Position = UDim2.new(0, 0, 0, 0)
	titleOrnament.BackgroundTransparency = 1
	titleOrnament.Text = "✦"
	titleOrnament.TextColor3 = THEME.GoldBright
	titleOrnament.TextSize = 16
	titleOrnament.Font = Enum.Font.Gotham
	titleOrnament.Parent = titleHolder

	local accentLeft = MakeTitleAccentLine(titleHolder, "TitleAccentLeft")
	accentLeft.Position = UDim2.new(0.5, -110, 0, 9)
	local accentRight = MakeTitleAccentLine(titleHolder, "TitleAccentRight")
	accentRight.Position = UDim2.new(0.5, 110, 0, 9)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 50)
	title.Position = UDim2.new(0, 0, 0, 22)
	title.BackgroundTransparency = 1
	title.Text = "CHOOSE YOUR HERO"
	title.TextColor3 = THEME.GoldBright
	title.TextSize = 36
	title.Font = Enum.Font.GothamBlack
	title.Parent = titleHolder

	-- 3 cards horizontally. Container width is computed so the cards
	-- end up evenly spaced regardless of MAX_SLOTS.
	local cardWidth = 230
	local cardGap = 24
	local cardCount = CharacterConfig.MAX_SLOTS
	local containerWidth = cardWidth * cardCount + cardGap * (cardCount - 1)

	local slotsContainer = Instance.new("Frame")
	slotsContainer.Name = "SlotsContainer"
	slotsContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	slotsContainer.Size = UDim2.new(0, containerWidth, 0, 360)
	slotsContainer.Position = UDim2.new(0.5, 0, 0.55, 0)
	slotsContainer.BackgroundTransparency = 1
	slotsContainer.Parent = background

	for i = 1, cardCount do
		local slot = CreateSlotFrame(i)
		slot.Position = UDim2.new(0, (i - 1) * (cardWidth + cardGap), 0, 0)
		slot.Parent = slotsContainer
	end

	if RunService:IsStudio() then
		CreateDebugResetButton().Parent = background
	end

	screenGui.Parent = playerGui
	return screenGui
end

-- Promote a card to its filled visual state (gold border + solid
-- gold action button + character info), or revert it to the empty
-- state. Called from UpdateUI for every unlocked slot.
local function ApplySlotState(slotFrame, characterData)
	local content = slotFrame:FindFirstChild("Content")
	if not content then return end

	local cardStroke      = slotFrame:FindFirstChild("CardStroke")
	local iconBubble      = content:FindFirstChild("IconBubble")
	local emptyTitle      = content:FindFirstChild("EmptyTitle")
	local emptyFlavor     = content:FindFirstChild("EmptyFlavor")
	local lvlBadge        = content:FindFirstChild("LvlBadge")
	local nameLabel       = content:FindFirstChild("NameLabel")
	local subtitleLabel   = content:FindFirstChild("SubtitleLabel")
	local selectButton    = content:FindFirstChild("SelectButton")
	local btnStroke       = selectButton and selectButton:FindFirstChild("ButtonStroke")

	local isFilled = characterData ~= nil

	if iconBubble    then iconBubble.Visible    = not isFilled end
	if emptyTitle    then emptyTitle.Visible    = not isFilled end
	if emptyFlavor   then emptyFlavor.Visible   = not isFilled end
	if lvlBadge      then lvlBadge.Visible      = isFilled end
	if nameLabel     then nameLabel.Visible     = isFilled end
	if subtitleLabel then subtitleLabel.Visible = isFilled end

	if isFilled then
		if cardStroke then
			cardStroke.Color = THEME.BorderActive
			cardStroke.Thickness = 2
		end
		local displayName = characterData.Name
			or (characterData.Race and characterData.Race:upper())
			or "ADVENTURER"
		if nameLabel then
			nameLabel.Text = displayName
		end
		if subtitleLabel then
			subtitleLabel.Text = characterData.Class or "Wanderer"
		end
		if lvlBadge then
			lvlBadge.Text = "LVL " .. (characterData.Level or 1)
		end
		if selectButton then
			selectButton.Text = "▶ SELECT"
			selectButton.BackgroundColor3 = THEME.GoldBright
			selectButton.TextColor3 = THEME.GoldButtonText
		end
		if btnStroke then
			btnStroke.Color = THEME.GoldBright
		end
	else
		if cardStroke then
			cardStroke.Color = THEME.BorderDim
			cardStroke.Thickness = 1
		end
		if selectButton then
			selectButton.Text = "+ CREATE"
			selectButton.BackgroundColor3 = THEME.CardBackground
			selectButton.TextColor3 = THEME.GoldBright
		end
		if btnStroke then
			btnStroke.Color = THEME.GoldDim
		end
	end
end

-- Reflect the server's view of slot ownership / character data into
-- the existing slot frames.
function SlotSelectionUI.UpdateUI(screenGui, slotsData)
	local slotsContainer = screenGui.Background.SlotsContainer

	for i = 1, CharacterConfig.MAX_SLOTS do
		local slotFrame = slotsContainer:FindFirstChild("Slot" .. i)
		if not slotFrame then continue end

		local isUnlocked = slotsData.UnlockedSlots[i]
		local characterData = slotsData.Characters[i]
		local lockOverlay = slotFrame:FindFirstChild("LockOverlay")

		if lockOverlay then
			lockOverlay.Visible = not isUnlocked
		end

		if isUnlocked then
			ApplySlotState(slotFrame, characterData)
		end
	end
end

-- Setup button handlers.
-- onSlotSelected(slotIndex, characterData) — fired when the player
--   picks one of the slots.
-- onResetClicked() — fired when the [DEBUG] reset button is clicked
--   in Studio. The caller is expected to re-show this screen so the
--   wiped state is reflected. Optional; ignored when nil or when the
--   button isn't visible (i.e. outside Studio).
function SlotSelectionUI.SetupHandlers(screenGui, slotsData, onSlotSelected, onResetClicked)
	local slotsContainer = screenGui.Background.SlotsContainer

	local resetButton = screenGui.Background:FindFirstChild("DebugResetButton")
	if resetButton and onResetClicked then
		resetButton.MouseButton1Click:Connect(function()
			-- Disable while the request is in flight so the user can't
			-- queue up duplicate resets.
			resetButton.Active = false
			resetButton.Text = "Resetting..."
			local ok, message = CharacterController.ResetCharacterSlots()
			if not ok then
				warn("Reset slots failed:", message)
				resetButton.Active = true
				resetButton.Text = "[DEBUG] RESET SLOTS"
				return
			end
			onResetClicked()
		end)
	end

	for i = 1, CharacterConfig.MAX_SLOTS do
		local slotFrame = slotsContainer:FindFirstChild("Slot" .. i)
		if not slotFrame then continue end

		local content = slotFrame:FindFirstChild("Content")
		local selectButton = content and content:FindFirstChild("SelectButton")
		local lockOverlay = slotFrame:FindFirstChild("LockOverlay")
		local unlockButton = lockOverlay and lockOverlay:FindFirstChild("UnlockButton")

		if selectButton then
			selectButton.MouseButton1Click:Connect(function()
				if slotsData.UnlockedSlots[i] then
					CharacterController.SetSelectedSlot(i)
					if onSlotSelected then
						onSlotSelected(i, slotsData.Characters[i])
					end
				end
			end)
		end

		if unlockButton then
			unlockButton.MouseButton1Click:Connect(function()
				-- TODO: Implement Robux purchase via game pass
				local success, message = CharacterController.UnlockSlot(i)
				if success then
					local newSlotsData = CharacterController.GetCharacterSlots()
					SlotSelectionUI.UpdateUI(screenGui, newSlotsData)
				else
					warn("Failed to unlock slot:", message)
				end
			end)
		end
	end
end

return SlotSelectionUI
