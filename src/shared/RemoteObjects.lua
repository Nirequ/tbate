-- Creates all RemoteEvents and RemoteFunctions for client-server communication
-- Must be required before any service that uses these remotes

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteObjects = {}

local RunService = game:GetService("RunService")
local isServer = RunService:IsServer()

-- Get or create folder for remotes
local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")

if isServer then
	-- Server creates all remotes
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = ReplicatedStorage
		print("Created Remotes folder")
	end

	-- Character creation remotes
	local getCharacterSlotsFunction = Instance.new("RemoteFunction")
	getCharacterSlotsFunction.Name = "GetCharacterSlotsFunction"
	getCharacterSlotsFunction.Parent = remotesFolder
	print("Created GetCharacterSlotsFunction")

	local createCharacterFunction = Instance.new("RemoteFunction")
	createCharacterFunction.Name = "CreateCharacterFunction"
	createCharacterFunction.Parent = remotesFolder
	print("Created CreateCharacterFunction")

	local loadCharacterFunction = Instance.new("RemoteFunction")
	loadCharacterFunction.Name = "LoadCharacterFunction"
	loadCharacterFunction.Parent = remotesFolder
	print("Created LoadCharacterFunction")

	local unlockSlotFunction = Instance.new("RemoteFunction")
	unlockSlotFunction.Name = "UnlockSlotFunction"
	unlockSlotFunction.Parent = remotesFolder
	print("Created UnlockSlotFunction")

	local teleportToMainGameFunction = Instance.new("RemoteFunction")
	teleportToMainGameFunction.Name = "TeleportToMainGameFunction"
	teleportToMainGameFunction.Parent = remotesFolder
	print("Created TeleportToMainGameFunction")

	-- Export references
	RemoteObjects.GetCharacterSlotsFunction = getCharacterSlotsFunction
	RemoteObjects.CreateCharacterFunction = createCharacterFunction
	RemoteObjects.LoadCharacterFunction = loadCharacterFunction
	RemoteObjects.UnlockSlotFunction = unlockSlotFunction
	RemoteObjects.TeleportToMainGameFunction = teleportToMainGameFunction
else
	-- Client waits for remotes to replicate from server
	if not remotesFolder then
		print("Client waiting for Remotes folder...")
		remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
	end

	if remotesFolder then
		RemoteObjects.GetCharacterSlotsFunction = remotesFolder:WaitForChild("GetCharacterSlotsFunction", 10)
		RemoteObjects.CreateCharacterFunction = remotesFolder:WaitForChild("CreateCharacterFunction", 10)
		RemoteObjects.LoadCharacterFunction = remotesFolder:WaitForChild("LoadCharacterFunction", 10)
		RemoteObjects.UnlockSlotFunction = remotesFolder:WaitForChild("UnlockSlotFunction", 10)
		RemoteObjects.TeleportToMainGameFunction = remotesFolder:WaitForChild("TeleportToMainGameFunction", 10)
		print("Client found all RemoteObjects")
	else
		warn("Client failed to find Remotes folder!")
	end
end

return RemoteObjects
