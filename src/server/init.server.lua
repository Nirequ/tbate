-- Server initialization script
-- Initializes all services and sets up remote event handlers

print("=== TBATE RPG Server Starting ===")

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- The player spends all of their time in this Place inside the character
-- editor UI, so disable automatic spawning — no stray R15 avatars in the
-- workspace.
Players.CharacterAutoLoads = false

-- StreamingEnabled has to be turned off manually in the editor place's
-- Workspace properties (Studio: select Workspace → Properties →
-- StreamingEnabled = false). Setting it from a regular Script is no
-- longer allowed — Roblox now requires script capability "Plugin",
-- which we don't have, and the assignment throws and aborts the init
-- script. We still wrap the assignment in pcall in case the capability
-- becomes available in the future.
pcall(function()
	Workspace.StreamingEnabled = false
end)

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

-- Debug-only: wipe a player's saved character slots so the editor can
-- be tested from a clean state. RunService:IsStudio() is true ONLY in
-- Studio (both Edit and playtest); in a published place it returns
-- false, so the remote is a no-op there even though the client can see
-- the function. This keeps the debug button safe to ship.
local RunService = game:GetService("RunService")
RemoteObjects.ResetCharacterSlotsFunction.OnServerInvoke = function(player)
	if not RunService:IsStudio() then
		return {success = false, message = "Reset is Studio-only"}
	end
	local ok = DataStoreService.ResetCharacterSlots(player)
	return {success = ok, message = ok and "Slots reset" or "Reset failed"}
end

print("=== TBATE RPG Server Ready ===")
print("Character creation system initialized")
print("Waiting for players...")
