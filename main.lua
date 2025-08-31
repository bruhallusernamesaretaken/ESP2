local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- =======================
-- Settings (edit here)
-- =======================
local Settings = {
	-- toggles
	ShowName = true,
	ShowDistance = true,
	ShowSkeleton = true,

	-- colorMode: "team" (use player's TeamColor), "friendEnemy" (friendly/enemy), "custom"
	ColorMode = "friendEnemy",

	-- used when ColorMode == "custom"
	CustomColor = Color3.fromRGB(200, 100, 255),

	-- colors used for friend/enemy mode
	FriendColor = Color3.fromRGB(0, 255, 0),
	EnemyColor  = Color3.fromRGB(255, 0, 0),

	-- maximum distance to show ESP (nil or number)
	MaxDistance = 5000, -- e.g., 300

	-- if true: when a player is off-screen the script removes (cleans up) their ESP drawings
	OffscreenRemove = true,

	-- when OffscreenRemove is true and a player goes off-screen, they will be removed immediately.
	-- their visuals will be recreated automatically once they re-enter the screen.
}
-- =======================

local ESP = {}

-- Safe Drawing creation wrapper (returns nil if creating fails)
local function safeNewDrawing(kind)
	local ok, obj = pcall(function() return Drawing.new(kind) end)
	if ok then
		return obj
	end
	return nil
end

local function createLine()
	local line = safeNewDrawing("Line")
	if not line then return nil end
	line.Thickness = 2
	line.Color = Color3.new(1, 1, 1)
	line.Visible = false
	return line
end

local function createText()
	local t = safeNewDrawing("Text")
	if not t then return nil end
	t.Size = 14
	t.Center = true
	t.Outline = true
	t.Visible = false
	return t
end

-- clear drawings but keep data table (used for immediate offscreen removal)
local function clearVisuals(data)
	if not data then return end
	if data.Name and type(data.Name.Remove) == "function" then
		pcall(function() data.Name:Remove() end)
	end
	if data.Distance and type(data.Distance.Remove) == "function" then
		pcall(function() data.Distance:Remove() end)
	end
	if data.Skeleton then
		for _, line in pairs(data.Skeleton) do
			if line and type(line.Remove) == "function" then
				pcall(function() line:Remove() end)
			end
		end
	end

	data.Name = nil
	data.Distance = nil
	data.Skeleton = nil
	data.BonePairs = nil
	data.VisualsRemoved = true -- flag for recreation
end

local function removeESP(player)
	local data = ESP[player]
	if not data then return end

	if data._connections then
		for _, conn in ipairs(data._connections) do
			if conn and conn.Disconnect then
				pcall(function() conn:Disconnect() end)
			end
		end
	end

	clearVisuals(data)
	ESP[player] = nil
end

-- Choose color according to Settings
local function getColorForPlayer(player)
	if Settings.ColorMode == "custom" then
		return Settings.CustomColor
	elseif Settings.ColorMode == "team" then
		-- use TeamColor if available
		if player and player.TeamColor then
			local c = player.TeamColor.Color
			if c then return c end
		end
		-- fallback
		return Settings.EnemyColor
	else -- friendEnemy
		if LocalPlayer and player and LocalPlayer.Team and player.Team and (LocalPlayer.Team == player.Team) then
			return Settings.FriendColor
		else
			return Settings.EnemyColor
		end
	end
end

-- Build bone pair lists (R15/R6)
local function defaultBonePairsForRig(rigType)
	if rigType == Enum.HumanoidRigType.R15 then
		return {
			{"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
			{"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
			{"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
			{"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
			{"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"}
		}
	else
		return {
			{"Head", "Torso"},
			{"Torso", "Left Arm"}, {"Left Arm", "Left Leg"},
			{"Torso", "Right Arm"}, {"Right Arm", "Right Leg"},
		}
	end
end

-- Create visuals for character (used on spawn and when re-creating after offscreen removal)
local function createVisualsForCharacter(player, char, data)
	-- sanity
	if not char then return end
	data.Character = char
	data.VisualsRemoved = false

	-- attempt to get humanoid for rig type
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local rigType = humanoid and humanoid.RigType or Enum.HumanoidRigType.R6

	-- texts
	if Settings.ShowName then
		local nameTag = createText()
		if nameTag then
			nameTag.Size = 14
			nameTag.Center = true
			nameTag.Outline = true
			nameTag.Color = Color3.fromRGB(255, 255, 255)
			nameTag.Visible = false
			data.Name = nameTag
		end
	end

	if Settings.ShowDistance then
		local distanceTag = createText()
		if distanceTag then
			distanceTag.Size = 13
			distanceTag.Center = true
			distanceTag.Outline = true
			distanceTag.Color = Color3.new(0.6, 0.6, 0.6)
			distanceTag.Visible = false
			data.Distance = distanceTag
		end
	end

	-- skeleton lines
	local skeletonLines = {}
	local bonePairs = defaultBonePairsForRig(rigType)
	for _, pair in ipairs(bonePairs) do
		local id = pair[1] .. "_" .. pair[2]
		local l = createLine()
		if l then
			-- initial color set; it will be updated each frame
			l.Color = getColorForPlayer(player)
		end
		skeletonLines[id] = l
	end

	data.Skeleton = skeletonLines
	data.BonePairs = bonePairs
	data.VisualsRemoved = false
end

-- Create ESP visuals for a player (setup handlers)
local function setupESP(player)
	if player == LocalPlayer then return end
	if ESP[player] then return end

	local data = {}
	data._connections = {}
	ESP[player] = data

	local function onCharacterAdded(char)
		-- clear any previous visuals and create fresh ones
		clearVisuals(data)
		-- wait for humanoid but don't block too long
		local humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
		-- create visuals (safe even if humanoid nil)
		createVisualsForCharacter(player, char, data)

		-- 🔹 FIX: Clear ESP immediately when humanoid dies
		if humanoid then
			local ok, conn = pcall(function()
				return humanoid.Died:Connect(function()
					clearVisuals(data)
				end)
			end)
			if ok and conn then
				table.insert(data._connections, conn)
			end
		end
	end

	local function onCharacterRemoving(char)
		clearVisuals(data)
	end

	local ok1, conn1 = pcall(function() return player.CharacterAdded:Connect(onCharacterAdded) end)
	if ok1 and conn1 then table.insert(data._connections, conn1) end

	local ok2, conn2 = pcall(function() return player.CharacterRemoving:Connect(onCharacterRemoving) end)
	if ok2 and conn2 then table.insert(data._connections, conn2) end

	-- If player already has a character, set it up now
	if player.Character then
		pcall(function() onCharacterAdded(player.Character) end)
	end
end

-- Initialize existing players and hook up joins/leaves
for _, player in ipairs(Players:GetPlayers()) do
	setupESP(player)
end
local connAdded = Players.PlayerAdded:Connect(setupESP)
local connRemoving = Players.PlayerRemoving:Connect(removeESP)
ESP._topConnections = {connAdded, connRemoving}

-- Helper to draw a single skeleton line safely
local function drawLineBetweenParts(part1, part2, line, color)
	if not line then return end
	if not part1 or not part2 then
		line.Visible = false
		return
	end

	local ok1, p1x, p1y, p1z = pcall(function() return part1.Position.X, part1.Position.Y, part1.Position.Z end)
	local ok2, p2x, p2y, p2z = pcall(function() return part2.Position.X, part2.Position.Y, part2.Position.Z end)
	if not (ok1 and ok2) then
		line.Visible = false
		return
	end

	local fromPos = Vector3.new(p1x, p1y, p1z)
	local toPos   = Vector3.new(p2x, p2y, p2z)
	local p1, on1 = Camera:WorldToViewportPoint(fromPos)
	local p2, on2 = Camera:WorldToViewportPoint(toPos)
	if on1 and on2 then
		line.From = Vector2.new(p1.X, p1.Y)
		line.To   = Vector2.new(p2.X, p2.Y)
		line.Color = color
		line.Visible = true
	else
		line.Visible = false
	end
end

-- Main render loop
RunService.RenderStepped:Connect(function()
	local cam = Camera
	if not cam or not cam.CFrame then return end
	local camPos = cam.CFrame.Position

	for player, data in pairs(ESP) do
		if player == "_topConnections" then continue end
		if not data then continue end

		local char = data.Character
		-- if there's no character, ensure visuals cleared
		if not char then
			if not data.VisualsRemoved then
				clearVisuals(data)
			end
			continue
		end

		local head = char:FindFirstChild("Head")
		local hrp  = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("LowerTorso") or char:FindFirstChild("Torso")
		if not head or not hrp then
			-- hide or clear visuals if parts missing
			if data.Name then data.Name.Visible = false end
			if data.Distance then data.Distance.Visible = false end
			if data.Skeleton then
				for _, line in pairs(data.Skeleton) do
					if line then line.Visible = false end
				end
			end
			continue
		end

		local worldHeadPos = head.Position + Vector3.new(0, 0.5, 0)
		local screenPos, onScreen = cam:WorldToViewportPoint(worldHeadPos)

		-- Offscreen remove behavior: if player offscreen and OffscreenRemove true -> clear visuals now
		if Settings.OffscreenRemove and not onScreen then
			if not data.VisualsRemoved then
				clearVisuals(data)
			end
			-- don't draw anything else for this player this frame
			continue
		end

		-- If visuals were removed earlier (e.g., due to offscreen removal) and they are now on screen, recreate them
		if data.VisualsRemoved and onScreen then
			createVisualsForCharacter(player, char, data)
		end

		-- Check max distance
		if Settings.MaxDistance then
			local dist = (camPos - hrp.Position).Magnitude
			if dist > Settings.MaxDistance then
				-- hide visuals if beyond max distance
				if data.Name then data.Name.Visible = false end
				if data.Distance then data.Distance.Visible = false end
				if data.Skeleton then
					for _, line in pairs(data.Skeleton) do if line then line.Visible = false end end
				end
				continue
			end
		end

		-- color for this frame (account for team changes dynamically)
		local color = getColorForPlayer(player)

		-- Draw name + distance
		if onScreen then
			local dist = math.floor((camPos - hrp.Position).Magnitude)
			if data.Name and Settings.ShowName then
				data.Name.Text = player.DisplayName or player.Name
				data.Name.Position = Vector2.new(screenPos.X, screenPos.Y - 50)
				data.Name.Color = color -- tint name text to player color
				data.Name.Visible = true
			elseif data.Name then
				data.Name.Visible = false
			end

			if data.Distance and Settings.ShowDistance then
				data.Distance.Text = tostring(dist) .. " studs"
				data.Distance.Position = Vector2.new(screenPos.X, screenPos.Y)
				data.Distance.Visible = true
			elseif data.Distance then
				data.Distance.Visible = false
			end
		else
			if data.Name then data.Name.Visible = false end
			if data.Distance then data.Distance.Visible = false end
		end

		-- Draw skeleton
		if Settings.ShowSkeleton and data.BonePairs and data.Skeleton then
			for _, pair in ipairs(data.BonePairs) do
				local part1 = char:FindFirstChild(pair[1])
				local part2 = char:FindFirstChild(pair[2])
				local id = pair[1] .. "_" .. pair[2]
				local line = data.Skeleton[id]
				-- update line color each frame and draw between parts
				drawLineBetweenParts(part1, part2, line, color)
			end
		elseif data.Skeleton then
			for _, line in pairs(data.Skeleton) do
				if line then line.Visible = false end
			end
		end
	end
end)
