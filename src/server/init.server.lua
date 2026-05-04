-- Server initialization script
-- Initializes all services and sets up remote event handlers

print("=== TBATE RPG Server Starting ===")

local Players = game:GetService("Players")

-- В этом Place игрок проводит всё время в UI редактора персонажа,
-- поэтому отключаем автоматический спавн — никаких лишних R15-аватаров
-- в воркспейсе.
Players.CharacterAutoLoads = false

-- Load shared modules
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemoteObjects = require(Shared:WaitForChild("RemoteObjects"))
local CharacterConfig = require(Shared:WaitForChild("CharacterConfig"))

-- Load server services
local DataStoreService = require(script.services.DataStoreService)
local CharacterService = require(script.services.CharacterService)

-- Initialize services
DataStoreService.Init()
CharacterService.Init(DataStoreService)

-- Setup remote event handlers
RemoteObjects.GetCharacterSlotsFunction.OnServerInvoke = function(player)
	local slots = DataStoreService.GetCharacterSlots(player)
	return slots
end

RemoteObjects.CreateCharacterFunction.OnServerInvoke = function(player, slotIndex, characterData)
	local success, message = CharacterService.CreateCharacter(player, slotIndex, characterData)
	return {success = success, message = message}
end

RemoteObjects.LoadCharacterFunction.OnServerInvoke = function(player, slotIndex)
	local success, message = CharacterService.LoadCharacter(player, slotIndex)
	return {success = success, message = message}
end

RemoteObjects.UnlockSlotFunction.OnServerInvoke = function(player, slotIndex)
	local success, message = CharacterService.UnlockSlot(player, slotIndex)
	return {success = success, message = message}
end

RemoteObjects.TeleportToMainGameFunction.OnServerInvoke = function(player)
	local success, message = CharacterService.TeleportToMainGame(player)
	return {success = success, message = message}
end

print("=== TBATE RPG Server Ready ===")
print("Character creation system initialized")
print("Waiting for players...")
