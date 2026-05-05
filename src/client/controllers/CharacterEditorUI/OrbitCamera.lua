-- OrbitCamera
-- Locks Workspace.CurrentCamera into Scriptable mode and orbits it
-- around a target model. Mouse drag rotates, scroll wheel zooms, mouse
-- movement clamps the height between -2 and 8 studs.
--
-- Owns its own state (orbit angles, the RenderStepped binding, the
-- input connections, and the previously-active CameraType / Subject
-- so we can restore them when the editor closes).

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local OrbitCamera = {}

local orbitState = {
	angle = math.pi,
	height = 3,
	distance = 8,
	dragging = false,
	lastMouseX = 0,
	lastMouseY = 0,
}

local renderConnection = nil
local inputConnections = {}
local originalCameraType = nil
local originalCameraSubject = nil

local function disconnectInputs()
	for _, conn in ipairs(inputConnections) do
		if conn.Connected then conn:Disconnect() end
	end
	inputConnections = {}
end

-- Setup({
--   getCharacter   = function() return <Model> | nil end,   -- the rig to orbit
--   isClickOverUI  = function(input) return <bool> end,     -- ignore drags that started on UI panels
-- })
function OrbitCamera.Setup(opts)
	local getCharacter = opts.getCharacter
	local isClickOverUI = opts.isClickOverUI or function() return false end

	local camera = Workspace.CurrentCamera
	if not camera then return end

	if originalCameraType == nil then
		originalCameraType = camera.CameraType
		originalCameraSubject = camera.CameraSubject
	end
	camera.CameraType = Enum.CameraType.Scriptable

	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	disconnectInputs()

	local function update()
		local cam = Workspace.CurrentCamera
		if not cam then return end
		local character = getCharacter()
		if not character then return end
		local primary = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
		if not primary then return end

		local target = primary.Position + Vector3.new(0, 0.5, 0)
		local x = math.sin(orbitState.angle) * orbitState.distance
		local z = math.cos(orbitState.angle) * orbitState.distance
		local cameraPosition = target + Vector3.new(x, orbitState.height, z)
		cam.CFrame = CFrame.lookAt(cameraPosition, target)
	end

	update()
	renderConnection = RunService.RenderStepped:Connect(update)

	table.insert(inputConnections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton2
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			if isClickOverUI(input) then return end
			orbitState.dragging = true
			orbitState.lastMouseX = input.Position.X
			orbitState.lastMouseY = input.Position.Y
		end
	end))
	table.insert(inputConnections, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			orbitState.dragging = false
		end
	end))
	table.insert(inputConnections, UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseMovement and orbitState.dragging then
			local dx = input.Position.X - orbitState.lastMouseX
			local dy = input.Position.Y - orbitState.lastMouseY
			orbitState.lastMouseX = input.Position.X
			orbitState.lastMouseY = input.Position.Y
			orbitState.angle = orbitState.angle - dx * 0.01
			orbitState.height = math.clamp(orbitState.height + dy * 0.05, -2, 8)
		elseif input.UserInputType == Enum.UserInputType.MouseWheel and not gameProcessed then
			-- Don't zoom if the wheel is over the UI panel either.
			if isClickOverUI(input) then return end
			orbitState.distance = math.clamp(
				orbitState.distance - input.Position.Z,
				3, 20)
		end
	end))
end

function OrbitCamera.Restore()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	disconnectInputs()
	local camera = Workspace.CurrentCamera
	if camera and originalCameraType then
		camera.CameraType = originalCameraType
		if originalCameraSubject then
			camera.CameraSubject = originalCameraSubject
		end
	end
	originalCameraType = nil
	originalCameraSubject = nil
end

return OrbitCamera
