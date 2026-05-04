-- UI Manager for character slot selection
-- Displays 3 character slots and handles slot selection/unlocking

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterController = require(script.Parent.Parent.controllers.CharacterController)
local CharacterConfig = require(Shared:WaitForChild("CharacterConfig"))

local SlotSelectionUI = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create slot selection UI
function SlotSelectionUI.CreateUI()
	-- Create ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SlotSelectionUI"
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
	title.Position = UDim2.new(0.5, -300, 0.1, 0)
	title.BackgroundTransparency = 1
	title.Text = "ВЫБЕРИТЕ СЛОТ ПЕРСОНАЖА"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 36
	title.Font = Enum.Font.GothamBold
	title.Parent = background
	
	-- Container for slots
	local slotsContainer = Instance.new("Frame")
	slotsContainer.Name = "SlotsContainer"
	slotsContainer.Size = UDim2.new(0, 900, 0, 400)
	slotsContainer.Position = UDim2.new(0.5, -450, 0.5, -200)
	slotsContainer.BackgroundTransparency = 1
	slotsContainer.Parent = background
	
	-- Create 3 slot buttons
	for i = 1, CharacterConfig.MAX_SLOTS do
		local slotFrame = Instance.new("Frame")
		slotFrame.Name = "Slot" .. i
		slotFrame.Size = UDim2.new(0, 280, 0, 380)
		slotFrame.Position = UDim2.new(0, (i - 1) * 310, 0, 0)
		slotFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
		slotFrame.BorderSizePixel = 0
		slotFrame.Parent = slotsContainer
		
		-- Corner rounding
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = slotFrame
		
		-- Slot number
		local slotNumber = Instance.new("TextLabel")
		slotNumber.Name = "SlotNumber"
		slotNumber.Size = UDim2.new(1, 0, 0, 50)
		slotNumber.Position = UDim2.new(0, 0, 0, 10)
		slotNumber.BackgroundTransparency = 1
		slotNumber.Text = "СЛОТ " .. i
		slotNumber.TextColor3 = Color3.fromRGB(200, 200, 200)
		slotNumber.TextSize = 24
		slotNumber.Font = Enum.Font.GothamBold
		slotNumber.Parent = slotFrame
		
		-- Character preview (placeholder)
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
		
		-- Empty slot text
		local emptyText = Instance.new("TextLabel")
		emptyText.Name = "EmptyText"
		emptyText.Size = UDim2.new(1, 0, 1, 0)
		emptyText.BackgroundTransparency = 1
		emptyText.Text = "Пусто"
		emptyText.TextColor3 = Color3.fromRGB(150, 150, 150)
		emptyText.TextSize = 20
		emptyText.Font = Enum.Font.Gotham
		emptyText.Parent = preview
		
		-- Select/Create button
		local selectButton = Instance.new("TextButton")
		selectButton.Name = "SelectButton"
		selectButton.Size = UDim2.new(0, 240, 0, 50)
		selectButton.Position = UDim2.new(0.5, -120, 1, -70)
		selectButton.BackgroundColor3 = Color3.fromRGB(60, 150, 60)
		selectButton.Text = "СОЗДАТЬ"
		selectButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		selectButton.TextSize = 20
		selectButton.Font = Enum.Font.GothamBold
		selectButton.Parent = slotFrame
		
		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, 8)
		buttonCorner.Parent = selectButton
		
		-- Lock overlay (for slots 2 and 3)
		if i > 1 then
			local lockOverlay = Instance.new("Frame")
			lockOverlay.Name = "LockOverlay"
			lockOverlay.Size = UDim2.new(1, 0, 1, 0)
			lockOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			lockOverlay.BackgroundTransparency = 0.7
			lockOverlay.BorderSizePixel = 0
			lockOverlay.Visible = true
			lockOverlay.Parent = slotFrame
			
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
			unlockButton.Text = "РАЗБЛОКИРОВАТЬ\n" .. CharacterConfig.SLOT_COSTS[i] .. " Robux"
			unlockButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			unlockButton.TextSize = 16
			unlockButton.Font = Enum.Font.GothamBold
			unlockButton.Parent = lockOverlay
			
			local unlockCorner = Instance.new("UICorner")
			unlockCorner.CornerRadius = UDim.new(0, 8)
			unlockCorner.Parent = unlockButton
		end
	end
	
	screenGui.Parent = playerGui
	return screenGui
end

-- Update UI with character data
function SlotSelectionUI.UpdateUI(screenGui, slotsData)
	local slotsContainer = screenGui.Background.SlotsContainer
	
	for i = 1, CharacterConfig.MAX_SLOTS do
		local slotFrame = slotsContainer:FindFirstChild("Slot" .. i)
		if not slotFrame then continue end
		
		local isUnlocked = slotsData.UnlockedSlots[i]
		local characterData = slotsData.Characters[i]
		local lockOverlay = slotFrame:FindFirstChild("LockOverlay")
		
		-- Update lock state
		if lockOverlay then
			lockOverlay.Visible = not isUnlocked
		end
		
		-- Update character preview
		if isUnlocked then
			local selectButton = slotFrame:FindFirstChild("SelectButton")
			local preview = slotFrame:FindFirstChild("Preview")
			local emptyText = preview and preview:FindFirstChild("EmptyText")
			
			if characterData then
				-- Character exists
				if selectButton then
					selectButton.Text = "ВЫБРАТЬ"
					selectButton.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
				end
				if emptyText then
					emptyText.Text = characterData.Race or "Персонаж"
				end
			else
				-- Empty slot
				if selectButton then
					selectButton.Text = "СОЗДАТЬ"
					selectButton.BackgroundColor3 = Color3.fromRGB(60, 150, 60)
				end
				if emptyText then
					emptyText.Text = "Пусто"
				end
			end
		end
	end
end

-- Setup button handlers
function SlotSelectionUI.SetupHandlers(screenGui, slotsData, onSlotSelected)
	local slotsContainer = screenGui.Background.SlotsContainer
	
	for i = 1, CharacterConfig.MAX_SLOTS do
		local slotFrame = slotsContainer:FindFirstChild("Slot" .. i)
		if not slotFrame then continue end
		
		local selectButton = slotFrame:FindFirstChild("SelectButton")
		local lockOverlay = slotFrame:FindFirstChild("LockOverlay")
		local unlockButton = lockOverlay and lockOverlay:FindFirstChild("UnlockButton")
		
		-- Select/Create button
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
		
		-- Unlock button
		if unlockButton then
			unlockButton.MouseButton1Click:Connect(function()
				-- TODO: Implement Robux purchase via game pass
				local success, message = CharacterController.UnlockSlot(i)
				if success then
					-- Refresh UI
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
