-- Client-side controller for character creation system
-- Manages UI interactions and communication with server

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteObjects = require(Shared:WaitForChild("RemoteObjects"))
local CharacterConfig = require(Shared:WaitForChild("CharacterConfig"))

local CharacterController = {}

-- Current state
local currentSlots = nil
local selectedSlot = nil
local currentCharacterData = nil

-- Get player's character slots from server
function CharacterController.GetCharacterSlots()
	local slots = RemoteObjects.GetCharacterSlotsFunction:InvokeServer()
	currentSlots = slots
	return slots
end

-- Create a new character in the selected slot
function CharacterController.CreateCharacter(slotIndex, characterData)
	local result = RemoteObjects.CreateCharacterFunction:InvokeServer(slotIndex, characterData)
	return result.success, result.message
end

-- Load character from a slot
function CharacterController.LoadCharacter(slotIndex)
	local result = RemoteObjects.LoadCharacterFunction:InvokeServer(slotIndex)
	return result.success, result.message
end

-- Unlock a character slot
function CharacterController.UnlockSlot(slotIndex)
	local result = RemoteObjects.UnlockSlotFunction:InvokeServer(slotIndex)
	return result.success, result.message
end

-- Teleport to main game
function CharacterController.TeleportToMainGame()
	local result = RemoteObjects.TeleportToMainGameFunction:InvokeServer()
	return result.success, result.message
end

-- Debug-only: ask the server to wipe the player's saved slots. The
-- server-side handler refuses the call outside of Studio, so this is
-- a no-op in published places.
function CharacterController.ResetCharacterSlots()
	local result = RemoteObjects.ResetCharacterSlotsFunction:InvokeServer()
	return result.success, result.message
end

-- Set selected slot
function CharacterController.SetSelectedSlot(slotIndex)
	selectedSlot = slotIndex
end

-- Get selected slot
function CharacterController.GetSelectedSlot()
	return selectedSlot
end

-- Set current character data being edited
function CharacterController.SetCurrentCharacterData(data)
	currentCharacterData = data
end

-- Get current character data
function CharacterController.GetCurrentCharacterData()
	return currentCharacterData or CharacterConfig.DEFAULT_CHARACTER
end

-- Initialize default character data
function CharacterController.InitializeDefaultCharacter()
	currentCharacterData = {
		Race = CharacterConfig.DEFAULT_CHARACTER.Race,
		HairstyleIndex = CharacterConfig.DEFAULT_CHARACTER.HairstyleIndex,
		FaceIndex = CharacterConfig.DEFAULT_CHARACTER.FaceIndex,
		ShirtIndex = CharacterConfig.DEFAULT_CHARACTER.ShirtIndex,
		PantsIndex = CharacterConfig.DEFAULT_CHARACTER.PantsIndex,
		SkinColor = CharacterConfig.DEFAULT_CHARACTER.SkinColor,
		HairColor = CharacterConfig.DEFAULT_CHARACTER.HairColor
	}
end

-- Initialize controller
function CharacterController.Init()
	print("CharacterController initialized")
	CharacterController.InitializeDefaultCharacter()
end

return CharacterController
