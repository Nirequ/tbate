-- UIBuilder
-- Pure-ish factories for the editor's right-hand options panel.
-- "Pure-ish" because mini-preview thumbnails do require a fresh R6
-- rig to be built (via HumanoidBuilder) and re-tinted with the user's
-- current hair colour — that hair colour is provided as a getter
-- callback so this module never has to read editor state directly.

local UserInputService = game:GetService("UserInputService")

local HumanoidBuilder = require(script.Parent.HumanoidBuilder)
local PreviewSpawn = require(script.Parent.PreviewSpawn)

local UIBuilder = {}

-- A vertical-list section with a title bar and a content area.
function UIBuilder.CreateSection(parent, sectionId, titleText)
	local section = Instance.new("Frame")
	section.Name = sectionId
	section.Size = UDim2.new(1, -20, 0, 0)
	section.AutomaticSize = Enum.AutomaticSize.Y
	section.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
	section.BackgroundTransparency = 0.15
	section.BorderSizePixel = 0
	section.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = section

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = section

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = section

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 24)
	title.BackgroundTransparency = 1
	title.Text = titleText
	title.TextColor3 = Color3.fromRGB(245, 215, 110)
	title.TextSize = 16
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.LayoutOrder = 0
	title.Parent = section

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(1, 0, 0, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.BackgroundTransparency = 1
	content.LayoutOrder = 1
	content.Parent = section

	return section, content
end

-- A grid of mini items. Each item is a square button with an optional
-- ViewportFrame thumbnail above its label.
function UIBuilder.MakeGridContainer(parent, cellSize)
	parent.Size = UDim2.new(1, 0, 0, 0)
	parent.AutomaticSize = Enum.AutomaticSize.Y

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = cellSize
	grid.CellPadding = UDim2.new(0, 6, 0, 6)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	grid.Parent = parent

	return grid
end

-- A single text-only option button (used for races).
function UIBuilder.CreateTextOptionButton(id, text)
	local button = Instance.new("TextButton")
	button.Name = id
	button.AutoButtonColor = false
	button.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 14
	button.Font = Enum.Font.GothamBold

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(70, 70, 80)
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button

	return button
end

-- Camera CFrame for each mini-preview body region. R6 rigs from
-- CreateHumanoidModelFromDescription face -Z (their default LookVector),
-- so to see the FRONT of the character the camera has to sit at
-- NEGATIVE Z relative to the rig.
local MINI_PREVIEW_CAMERAS = {
	-- Show the head + hair. Head center is at y≈1.5, hair tops out
	-- around y≈3. Aim the look-at slightly below head center while
	-- keeping the camera at head height — this tilts the view a touch
	-- downwards, so the rig sits higher in the thumbnail and we see
	-- more of the hair on top.
	hair  = {eye = Vector3.new(0,  2.0, -3.2), look = Vector3.new(0,  1.5, 0)},
	-- Tight close-up on the front of the head so the face decal fills
	-- the thumbnail. BuildSingleAssetDescription leaves hair off for
	-- face minis so the decal isn't covered by a fringe.
	face  = {eye = Vector3.new(0,  0.4, -2.0), look = Vector3.new(0,  0.4, 0)},
	-- Torso center is at y=0; pull camera back enough that the whole
	-- shirt (HRP±1) is comfortably in frame.
	shirt = {eye = Vector3.new(0,  0.2, -4.5), look = Vector3.new(0,  0.2, 0)},
	-- Legs span y=-3..-1. Center the look at y=-2.
	pants = {eye = Vector3.new(0, -2.0, -3.5), look = Vector3.new(0, -2.0, 0)},
}
local DEFAULT_MINI_CAMERA = {eye = Vector3.new(0, 0, -6), look = Vector3.new(0, 0, 0)}

-- A mini-preview button: a 3D thumbnail of an R6 dummy wearing only this
-- particular item, rendered into a tiny ViewportFrame, with a label
-- underneath.
--
-- opts.getHairColor : function() returning the current hair Color3 — used
--                     to re-tint hair accessories as they finish loading.
function UIBuilder.CreateMiniPreviewButton(id, displayName, kind, asset, opts)
	opts = opts or {}
	local getHairColor = opts.getHairColor or function() return Color3.fromRGB(255, 255, 255) end

	local button = Instance.new("TextButton")
	button.Name = id
	button.AutoButtonColor = false
	button.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
	button.Text = ""

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(70, 70, 80)
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Thumbnail"
	viewport.Size = UDim2.new(1, -8, 1, -22)
	viewport.Position = UDim2.new(0, 4, 0, 4)
	viewport.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	viewport.BorderSizePixel = 0
	viewport.LightDirection = Vector3.new(-0.5, -1, -0.5)
	viewport.Ambient = Color3.fromRGB(160, 160, 160)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.Parent = button

	local viewportCorner = Instance.new("UICorner")
	viewportCorner.CornerRadius = UDim.new(0, 4)
	viewportCorner.Parent = viewport

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport

	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -2)
	label.Size = UDim2.new(1, -8, 0, 16)
	label.BackgroundTransparency = 1
	label.Text = displayName
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.TextSize = 11
	label.Font = Enum.Font.Gotham
	label.TextScaled = false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = button

	-- Build the dummy asynchronously so we don't block the UI thread.
	task.spawn(function()
		local description = HumanoidBuilder.BuildSingleAssetDescription(kind, asset)
		local rig = HumanoidBuilder.BuildR6Rig(description)
		if not rig then return end
		local primary = rig.PrimaryPart or rig:FindFirstChild("HumanoidRootPart")
		if primary then
			rig.PrimaryPart = primary
			rig:PivotTo(CFrame.new(0, 0, 0))
		end
		rig.Parent = worldModel
		PreviewSpawn.AnchorRig(rig)

		-- Re-tint after late accessory load. Fetching the colour each
		-- call so changes the user makes after the mini was built also
		-- show up on the next retint pass.
		local function retint()
			HumanoidBuilder.TintHair(rig, getHairColor())
		end
		retint()
		for _, t in ipairs({0.2, 0.6, 1.2, 2.4}) do
			task.delay(t, function() if rig.Parent then retint() end end)
		end
		rig.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("Accessory") and HumanoidBuilder.IsHairAccessory(descendant) then
				task.defer(retint)
			end
		end)

		-- Frame the camera based on which body region we want to highlight.
		local cam = MINI_PREVIEW_CAMERAS[kind] or DEFAULT_MINI_CAMERA
		camera.CFrame = CFrame.lookAt(cam.eye, cam.look)
	end)

	return button
end

-- =================================================================
-- RGB color picker (3 sliders + HEX input).
-- =================================================================
local function ToHex(color)
	local r = math.clamp(math.floor(color.R * 255 + 0.5), 0, 255)
	local g = math.clamp(math.floor(color.G * 255 + 0.5), 0, 255)
	local b = math.clamp(math.floor(color.B * 255 + 0.5), 0, 255)
	return string.format("%02X%02X%02X", r, g, b)
end

local function FromHex(hex)
	hex = hex:gsub("#", ""):gsub("%s", "")
	if #hex ~= 6 then return nil end
	local r = tonumber(hex:sub(1, 2), 16)
	local g = tonumber(hex:sub(3, 4), 16)
	local b = tonumber(hex:sub(5, 6), 16)
	if not r or not g or not b then return nil end
	return Color3.fromRGB(r, g, b)
end

local SLIDER_FILL_COLORS = {
	R = Color3.fromRGB(220,  60,  60),
	G = Color3.fromRGB( 60, 200,  80),
	B = Color3.fromRGB( 80, 120, 220),
}

function UIBuilder.CreateRGBColorPicker(id, initialColor, onChange)
	local picker = Instance.new("Frame")
	picker.Name = id
	picker.Size = UDim2.new(1, 0, 0, 130)
	picker.BackgroundTransparency = 1

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = picker

	-- Top row: swatch preview + HEX input.
	local topRow = Instance.new("Frame")
	topRow.Name = "TopRow"
	topRow.Size = UDim2.new(1, 0, 0, 32)
	topRow.BackgroundTransparency = 1
	topRow.LayoutOrder = 0
	topRow.Parent = picker

	local swatch = Instance.new("Frame")
	swatch.Name = "Swatch"
	swatch.Size = UDim2.new(0, 32, 0, 32)
	swatch.Position = UDim2.new(0, 0, 0, 0)
	swatch.BackgroundColor3 = initialColor
	swatch.BorderSizePixel = 0
	swatch.Parent = topRow

	local swatchCorner = Instance.new("UICorner")
	swatchCorner.CornerRadius = UDim.new(0, 4)
	swatchCorner.Parent = swatch

	local hexLabel = Instance.new("TextLabel")
	hexLabel.Size = UDim2.new(0, 30, 1, 0)
	hexLabel.Position = UDim2.new(0, 40, 0, 0)
	hexLabel.BackgroundTransparency = 1
	hexLabel.Text = "#"
	hexLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	hexLabel.TextSize = 14
	hexLabel.Font = Enum.Font.GothamBold
	hexLabel.TextXAlignment = Enum.TextXAlignment.Left
	hexLabel.Parent = topRow

	local hexBox = Instance.new("TextBox")
	hexBox.Name = "HexBox"
	hexBox.Size = UDim2.new(0, 80, 1, 0)
	hexBox.Position = UDim2.new(0, 56, 0, 0)
	hexBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	hexBox.TextColor3 = Color3.fromRGB(245, 245, 245)
	hexBox.TextSize = 14
	hexBox.Font = Enum.Font.Code
	hexBox.PlaceholderText = "FFFFFF"
	hexBox.Text = ToHex(initialColor)
	hexBox.ClearTextOnFocus = false
	hexBox.Parent = topRow

	local hexCorner = Instance.new("UICorner")
	hexCorner.CornerRadius = UDim.new(0, 4)
	hexCorner.Parent = hexBox

	local hexStroke = Instance.new("UIStroke")
	hexStroke.Color = Color3.fromRGB(60, 60, 80)
	hexStroke.Thickness = 1
	hexStroke.Parent = hexBox

	local current = initialColor
	local sliderRefs = {}

	local function applyColor(newColor)
		current = newColor
		swatch.BackgroundColor3 = newColor
		hexBox.Text = ToHex(newColor)
		for _, ref in ipairs(sliderRefs) do
			ref.refresh(newColor)
		end
		if onChange then
			onChange(newColor)
		end
	end

	-- Build a single horizontal RGB slider row.
	local function CreateChannelSlider(channelName, channelGetter, layoutOrder)
		local row = Instance.new("Frame")
		row.Name = channelName .. "Slider"
		row.Size = UDim2.new(1, 0, 0, 26)
		row.BackgroundTransparency = 1
		row.LayoutOrder = layoutOrder
		row.Parent = picker

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(0, 18, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = channelName
		label.TextColor3 = Color3.fromRGB(220, 220, 220)
		label.TextSize = 14
		label.Font = Enum.Font.GothamBold
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = row

		local track = Instance.new("Frame")
		track.Name = "Track"
		track.Size = UDim2.new(1, -70, 0, 6)
		track.Position = UDim2.new(0, 22, 0.5, -3)
		track.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
		track.BorderSizePixel = 0
		track.Parent = row

		local trackCorner = Instance.new("UICorner")
		trackCorner.CornerRadius = UDim.new(1, 0)
		trackCorner.Parent = track

		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.new(channelGetter(initialColor), 0, 1, 0)
		fill.BackgroundColor3 = SLIDER_FILL_COLORS[channelName] or Color3.fromRGB(200, 200, 200)
		fill.BorderSizePixel = 0
		fill.Parent = track

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = fill

		local thumb = Instance.new("Frame")
		thumb.Name = "Thumb"
		thumb.AnchorPoint = Vector2.new(0.5, 0.5)
		thumb.Size = UDim2.new(0, 14, 0, 14)
		thumb.Position = UDim2.new(channelGetter(initialColor), 0, 0.5, 0)
		thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		thumb.BorderSizePixel = 0
		thumb.Parent = track

		local thumbCorner = Instance.new("UICorner")
		thumbCorner.CornerRadius = UDim.new(1, 0)
		thumbCorner.Parent = thumb

		local valueLabel = Instance.new("TextLabel")
		valueLabel.Size = UDim2.new(0, 40, 1, 0)
		valueLabel.Position = UDim2.new(1, -42, 0, 0)
		valueLabel.BackgroundTransparency = 1
		valueLabel.Text = tostring(math.floor(channelGetter(initialColor) * 255 + 0.5))
		valueLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
		valueLabel.TextSize = 12
		valueLabel.Font = Enum.Font.Code
		valueLabel.TextXAlignment = Enum.TextXAlignment.Right
		valueLabel.Parent = row

		local dragging = false
		local function setFromMouseX(mouseX)
			local trackPos = track.AbsolutePosition.X
			local trackSize = track.AbsoluteSize.X
			if trackSize <= 0 then return end
			local t = math.clamp((mouseX - trackPos) / trackSize, 0, 1)
			local r, g, b = current.R, current.G, current.B
			if channelName == "R" then r = t
			elseif channelName == "G" then g = t
			else b = t
			end
			applyColor(Color3.new(r, g, b))
		end

		track.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				setFromMouseX(input.Position.X)
			end
		end)
		thumb.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch) then
				setFromMouseX(input.Position.X)
			end
		end)

		table.insert(sliderRefs, {
			refresh = function(newColor)
				local v = channelGetter(newColor)
				fill.Size = UDim2.new(v, 0, 1, 0)
				thumb.Position = UDim2.new(v, 0, 0.5, 0)
				valueLabel.Text = tostring(math.floor(v * 255 + 0.5))
			end,
		})
	end

	CreateChannelSlider("R", function(c) return c.R end, 1)
	CreateChannelSlider("G", function(c) return c.G end, 2)
	CreateChannelSlider("B", function(c) return c.B end, 3)

	hexBox.FocusLost:Connect(function()
		local parsed = FromHex(hexBox.Text)
		if parsed then
			applyColor(parsed)
		else
			hexBox.Text = ToHex(current)
		end
	end)

	-- Stash the current hex on the Frame as an attribute so external code
	-- (or an inspector) can read it back.
	picker:SetAttribute("CurrentHex", ToHex(initialColor))

	return picker
end

-- Highlight the active text-/mini-preview button with a gold UIStroke.
function UIBuilder.SetGroupSelection(container, selectedId)
	if not container then return end
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("TextButton") then
			local stroke = child:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = Color3.fromRGB(70, 70, 80)
				stroke.Thickness = 2
			end
		end
	end
	local selected = container:FindFirstChild(selectedId)
	if selected then
		local stroke = selected:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = Color3.fromRGB(255, 215, 0)
			stroke.Thickness = 4
		end
	end
end

return UIBuilder
