-- Client initialization script
-- Manages character creation flow and UI

print("=== TBATE RPG Client Starting ===")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for player
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Load modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterController = require(script.controllers.CharacterController)
local SlotSelectionUI = require(script.controllers.SlotSelectionUI)
local CharacterEditorUI = require(script.controllers.CharacterEditorUI)

-- Initialize controller
CharacterController.Init()

-- UI state
local currentUI = nil
local currentSlotIndex = nil

-- Forward declarations
local ShowSlotSelection
local ShowCharacterEditor

-- Show character editor screen
ShowCharacterEditor = function()
	-- Clean up previous UI
	if currentUI then
		currentUI:Destroy()
		currentUI = nil
	end
	
	-- Create and show character editor UI
	local editorUI = CharacterEditorUI.CreateUI()
	CharacterEditorUI.InitializeDefaults(editorUI)
	
	-- Setup handlers
	CharacterEditorUI.SetupHandlers(editorUI, 
		function()
			-- Back button - return to slot selection
			print("Returning to slot selection")
			ShowSlotSelection()
		end,
		function(characterData)
			-- Confirm button - save character
			print("Saving character to slot", currentSlotIndex)
			
			local success, message = CharacterController.CreateCharacter(currentSlotIndex, characterData)
			
			if success then
				print("Character created successfully!")
				
				-- Load the character
				local loadSuccess, loadMessage = CharacterController.LoadCharacter(currentSlotIndex)
				
				if loadSuccess then
					print("Character loaded!")
					-- Teleport to main game after a short delay
					task.wait(2)
					CharacterController.TeleportToMainGame()
				else
					warn("Failed to load character:", loadMessage)
				end
			else
				warn("Failed to create character:", message)
			end
		end
	)
	
	currentUI = editorUI
	print("Character editor UI ready")
end

-- Show slot selection screen
ShowSlotSelection = function()
	-- Clean up previous UI
	if currentUI then
		currentUI:Destroy()
		currentUI = nil
	end
	
	print("Loading character slots...")
	local slotsData = CharacterController.GetCharacterSlots()
	
	if not slotsData then
		warn("Failed to load character slots!")
		return
	end
	
	-- Create and show slot selection UI
	local slotUI = SlotSelectionUI.CreateUI()
	SlotSelectionUI.UpdateUI(slotUI, slotsData)
	
	-- Setup handlers
	SlotSelectionUI.SetupHandlers(slotUI, slotsData, function(slotIndex, characterData)
		currentSlotIndex = slotIndex
		
		if characterData then
			-- Character exists, load it
			print("Loading existing character from slot", slotIndex)
			local success, message = CharacterController.LoadCharacter(slotIndex)
			
			if success then
				print("Character loaded successfully!")
				-- Teleport to main game
				task.wait(1)
				CharacterController.TeleportToMainGame()
			else
				warn("Failed to load character:", message)
			end
		else
			-- No character, show editor
			print("Creating new character in slot", slotIndex)
			ShowCharacterEditor()
		end
	end)
	
	currentUI = slotUI
	print("Slot selection UI ready")
end

-- Start the character creation flow
print("Starting character creation flow...")
task.wait(1) -- Wait for everything to load
ShowSlotSelection()

print("=== TBATE RPG Client Ready ===")
