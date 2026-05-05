-- UI Manager for character slot selection
-- Displays MAX_SLOTS character slots and handles slot selection /
-- unlocking. The actual character preview thumbnail is just a flat
-- placeholder right now — when we have stored HumanoidDescriptions
-- per slot we can render a mini ViewportFrame here the same way the
-- editor does for its option list.

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
-- Subcomponents
-- =================================================================

-- Dim overlay shown over locked slots, with the unlock-cost button.
local function CreateLockOverlay(slotIndex)
	local lockOverlay = Instance.new("Frame")
	lockOverlay.Name = "LockOverlay"
	lockOverlay.Size = UDim2.new(1, 0, 1, 0)
	lockOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	lockOverlay.BackgroundTransparency = 0.7
	lockOverlay.BorderSizePixel = 0
	lockOverlay.Visible = true

	local lockCorner = Instance.new("UICorner")
	lockCorner.CornerRadius = UDim.new(0, 12)
	lockCorner.Parent = lockOverlay

	local lockIcon = Instance.new("TextLabel")
	lockIcon.Size = UDim2.new(0, 100, 0, 100)
	lockIcon.Position = UDim2.new(0.5, -50, 0.4, -50)
	lockIcon.BackgroundTransparency = 1
	lockIcon.Text = "🔒"
	lockIcon.TextSize = 60
	lockIcon.Parent = lockOverlay

	local unlockButton = Instance.new("TextButton")
	unlockButton.Name = "UnlockButton"
	unlockButton.Size = UDim2.new(0, 200, 0, 50)
	unlockButton.Position = UDim2.new(0.5, -100, 0.7, 0)
	unlockButton.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
	unlockButton.Text = "UNLOCK\n" .. CharacterConfig.SLOT_COSTS[slotIndex] .. " Robux"
	unlockButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	unlockButton.TextSize = 16
	unlockButton.Font = Enum.Font.GothamBold
	unlockButton.Parent = lockOverlay

	local unlockCorner = Instance.new("UICorner")
	unlockCorner.CornerRadius = UDim.new(0, 8)
	unlockCorner.Parent = unlockButton

	return lockOverlay
end

-- One slot card: title, preview placeholder, select/create button, and
-- (for slots > 1) a lock overlay.
local function CreateSlotFrame(slotIndex)
	local slotFrame = Instance.new("Frame")
	slotFrame.Name = "Slot" .. slotIndex
	slotFrame.Size = UDim2.new(0, 280, 0, 380)
	slotFrame.Position = UDim2.new(0, (slotIndex - 1) * 310, 0, 0)
	slotFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	slotFrame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = slotFrame

	local slotNumber = Instance.new("TextLabel")
	slotNumber.Name = "SlotNumber"
	slotNumber.Size = UDim2.new(1, 0, 0, 50)
	slotNumber.Position = UDim2.new(0, 0, 0, 10)
	slotNumber.BackgroundTransparency = 1
	slotNumber.Text = "SLOT " .. slotIndex
	slotNumber.TextColor3 = Color3.fromRGB(200, 200, 200)
	slotNumber.TextSize = 24
	slotNumber.Font = Enum.Font.GothamBold
	slotNumber.Parent = slotFrame

	local preview = Instance.new("Frame")
	preview.Name = "Preview"
	preview.Size = UDim2.new(0, 200, 0, 200)
	preview.Position = UDim2.new(0.5, -100, 0, 70)
	preview.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	preview.BorderSizePixel = 0
	preview.Parent = slotFrame

	local previewCorner = Instance.new("UICorner")
	previewCorner.CornerRadius = UDim.new(0, 8)
	previewCorner.Parent = preview

	local emptyText = Instance.new("TextLabel")
	emptyText.Name = "EmptyText"
	emptyText.Size = UDim2.new(1, 0, 1, 0)
	emptyText.BackgroundTransparency = 1
	emptyText.Text = "Empty"
	emptyText.TextColor3 = Color3.fromRGB(150, 150, 150)
	emptyText.TextSize = 20
	emptyText.Font = Enum.Font.Gotham
	emptyText.Parent = preview

	local selectButton = Instance.new("TextButton")
	selectButton.Name = "SelectButton"
	selectButton.Size = UDim2.new(0, 240, 0, 50)
	selectButton.Position = UDim2.new(0.5, -120, 1, -70)
	selectButton.BackgroundColor3 = Color3.fromRGB(60, 150, 60)
	selectButton.Text = "CREATE"
	selectButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	selectButton.TextSize = 20
	selectButton.Font = Enum.Font.GothamBold
	selectButton.Parent = slotFrame

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 8)
	buttonCorner.Parent = selectButton

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
	resetButton.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
	resetButton.Text = "[DEBUG] RESET SLOTS"
	resetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	resetButton.TextSize = 14
	resetButton.Font = Enum.Font.GothamBold
	resetButton.AutoButtonColor = true

	local resetCorner = Instance.new("UICorner")
	resetCorner.CornerRadius = UDim.new(0, 6)
	resetCorner.Parent = resetButton

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

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	background.BorderSizePixel = 0
	background.Parent = screenGui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0, 600, 0, 80)
	title.Position = UDim2.new(0.5, -300, 0.1, 0)
	title.BackgroundTransparency = 1
	title.Text = "CHOOSE A CHARACTER SLOT"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 36
	title.Font = Enum.Font.GothamBold
	title.Parent = background

	local slotsContainer = Instance.new("Frame")
	slotsContainer.Name = "SlotsContainer"
	slotsContainer.Size = UDim2.new(0, 900, 0, 400)
	slotsContainer.Position = UDim2.new(0.5, -450, 0.5, -200)
	slotsContainer.BackgroundTransparency = 1
	slotsContainer.Parent = background

	for i = 1, CharacterConfig.MAX_SLOTS do
		CreateSlotFrame(i).Parent = slotsContainer
	end

	if RunService:IsStudio() then
		CreateDebugResetButton().Parent = background
	end

	screenGui.Parent = playerGui
	return screenGui
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

		if not isUnlocked then continue end

		local selectButton = slotFrame:FindFirstChild("SelectButton")
		local preview = slotFrame:FindFirstChild("Preview")
		local emptyText = preview and preview:FindFirstChild("EmptyText")

		if characterData then
			if selectButton then
				selectButton.Text = "SELECT"
				selectButton.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
			end
			if emptyText then
				emptyText.Text = characterData.Race or "Character"
			end
		else
			if selectButton then
				selectButton.Text = "CREATE"
				selectButton.BackgroundColor3 = Color3.fromRGB(60, 150, 60)
			end
			if emptyText then
				emptyText.Text = "Empty"
			end
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

		local selectButton = slotFrame:FindFirstChild("SelectButton")
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
