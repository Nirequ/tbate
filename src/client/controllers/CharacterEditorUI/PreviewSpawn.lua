-- PreviewSpawn
-- Workspace placement helpers for the in-world editor preview rig:
-- finds the anchor Part, computes a body-only bounding box that ignores
-- still-loading accessories, and locks the rig in place by anchoring
-- the HumanoidRootPart only.

local Workspace = game:GetService("Workspace")

local PreviewSpawn = {}

-- Pick the BasePart in the world we should stand the preview character
-- on top of. A Part named "PreviewSpot" wins. Otherwise the first
-- SpawnLocation we can find anywhere in the world (recursive — Folder /
-- Model nesting is fine).
function PreviewSpawn.ResolveAnchorPart()
	local explicit = Workspace:FindFirstChild("PreviewSpot", true)
	if explicit and explicit:IsA("BasePart") then
		return explicit
	end
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("SpawnLocation") then
			return descendant
		end
	end
	return nil
end

-- Compute the bounding box of the rig's actual body parts only,
-- ignoring anything inside an Accessory. Accessories (hair, hats,
-- earrings…) load asynchronously and can briefly sit at world origin
-- (0,0,0) before their weld snaps them to the head. If we feed those
-- stray positions into Model:GetBoundingBox the resulting box is much
-- bigger than the body and the foot-alignment math puts the rig deep
-- into the ground (or way above it), which is the visible "sinking"
-- bug players saw when picking different hairstyles.
function PreviewSpawn.GetBodyBoundsY(character)
	local minY, maxY = math.huge, -math.huge
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and not part:FindFirstAncestorWhichIsA("Accessory") then
			local centerY = part.Position.Y
			local halfY = part.Size.Y * 0.5
			if centerY - halfY < minY then
				minY = centerY - halfY
			end
			if centerY + halfY > maxY then
				maxY = centerY + halfY
			end
		end
	end
	return minY, maxY
end

-- Place the rig so its feet land on the top face of the chosen anchor
-- Part. Uses only body-part bounds (not accessories) so the offset
-- stays correct regardless of which hairstyle / hat is loading at the
-- moment.
local previewAnchorWarned = false
function PreviewSpawn.PlaceOnAnchor(character)
	local anchor = PreviewSpawn.ResolveAnchorPart()
	if not anchor then
		if not previewAnchorWarned then
			warn("[CharacterEditorUI] No SpawnLocation or PreviewSpot Part "
				.. "found in Workspace — falling back to (0, 10, 0). "
				.. "Add a Part named PreviewSpot where you want the "
				.. "preview character to stand.")
			previewAnchorWarned = true
		end
		character:PivotTo(CFrame.new(0, 10, 0))
		return
	end

	local topY = anchor.Position.Y + anchor.Size.Y * 0.5
	-- First place the rig somewhere near the anchor so we can read its
	-- body bounds; the X/Z are correct, only the Y needs adjusting.
	character:PivotTo(CFrame.new(anchor.Position.X, topY + 5, anchor.Position.Z)
		* (anchor.CFrame - anchor.Position))
	local minBodyY = PreviewSpawn.GetBodyBoundsY(character)
	if minBodyY == math.huge then
		-- No body parts found yet (rig still spinning up). Fall back
		-- to the model's full bounding box so we at least don't NaN.
		local cf, size = character:GetBoundingBox()
		minBodyY = cf.Y - size.Y * 0.5
	end
	local correction = topY - minBodyY
	character:PivotTo(character:GetPivot() + Vector3.new(0, correction, 0))
	print(("[CharacterEditorUI] Preview anchor: %s @ (%.1f, %.1f, %.1f), "
		.. "body min Y was %.2f, feet placed at Y=%.1f"):format(
			anchor:GetFullName(),
			anchor.Position.X, anchor.Position.Y, anchor.Position.Z,
			minBodyY, topY))
end

-- Lock the rig in place by anchoring ONLY the HumanoidRootPart. Body
-- parts stay attached via Motor6Ds, accessories (e.g. hair) stay attached
-- via Attachments — anchoring them too would freeze them at their initial
-- position before the welds positioned them, which is why hair was
-- floating off in space.
--
-- We deliberately don't set humanoid.PlatformStand = true: it puts the
-- Humanoid into a ragdoll-like state where Motor6Ds go limp and the
-- limbs flop / drift away from the torso. Anchoring the HRP plus
-- WalkSpeed/JumpPower=0 is enough to hold the rig still while the idle
-- animation plays normally.
function PreviewSpawn.AnchorRig(model)
	if not model then return end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
		end
	end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.Anchored = true
	end
end

return PreviewSpawn
