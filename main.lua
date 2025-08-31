-- Fixed WA Universal ESP (with distance above name)
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Drawings = {
	ESP = {},
	Tracers = {},
	Boxes = {},
	Healthbars = {},
	Names = {},
	Distances = {},
	Snaplines = {},
	Skeleton = {}
}

local Colors = {
	Enemy = Color3.fromRGB(255, 25, 25),
	Ally = Color3.fromRGB(25, 255, 25),
	Neutral = Color3.fromRGB(255, 255, 255),
	Selected = Color3.fromRGB(255, 210, 0),
	Health = Color3.fromRGB(0, 255, 0),
	Distance = Color3.fromRGB(200, 200, 200),
	Rainbow = Color3.fromRGB(255,255,255)
}

local Highlights = {}

local Settings = {
	Enabled = false,
	TeamCheck = false,
	ShowTeam = false,
	VisibilityCheck = true,
	BoxESP = false,
	BoxStyle = "Corner",
	BoxOutline = true,
	BoxFilled = false,
	BoxFillTransparency = 0.5,
	BoxThickness = 1,
	TracerESP = false,
	TracerOrigin = "Bottom",
	TracerStyle = "Line",
	TracerThickness = 1,
	HealthESP = false,
	HealthStyle = "Bar",
	HealthBarSide = "Left",
	HealthTextSuffix = "HP",
	NameESP = true,
	NameMode = "DisplayName",
	ShowDistance = true,
	DistanceUnit = "studs",
	TextSize = 14,
	TextFont = 2,
	RainbowSpeed = 1,
	MaxDistance = 1000,
	RefreshRate = 1/144,
	Snaplines = false,
	SnaplineStyle = "Straight",
	RainbowEnabled = false,
	RainbowBoxes = false,
	RainbowTracers = false,
	RainbowText = false,
	ChamsEnabled = false,
	ChamsOutlineColor = Color3.fromRGB(255, 255, 255),
	ChamsFillColor = Color3.fromRGB(255, 0, 0),
	ChamsOccludedColor = Color3.fromRGB(150, 0, 0),
	ChamsTransparency = 0.5,
	ChamsOutlineTransparency = 0,
	ChamsOutlineThickness = 0.1,
	SkeletonESP = false,
	SkeletonColor = Color3.fromRGB(255, 255, 255),
	SkeletonThickness = 1.5,
	SkeletonTransparency = 1
}

-- Helper: hide a drawing (or table of drawings)
local function hideDrawingOrTable(obj)
	if type(obj) == "table" then
		for _, v in pairs(obj) do
			if v and v.Visible ~= nil then
				v.Visible = false
			end
		end
	else
		if obj and obj.Visible ~= nil then
			obj.Visible = false
		end
	end
end

local function CreateESP(player)
	if player == LocalPlayer then return end

	-- Box lines (8 lines)
	local box = {
		TopLeft = Drawing.new("Line"),
		TopRight = Drawing.new("Line"),
		BottomLeft = Drawing.new("Line"),
		BottomRight = Drawing.new("Line"),
		Left = Drawing.new("Line"),
		Right = Drawing.new("Line"),
		Top = Drawing.new("Line"),
		Bottom = Drawing.new("Line")
	}

	-- Connector lines for 3D box (persistent, reused)
	box.Connectors = {
		Drawing.new("Line"),
		Drawing.new("Line"),
		Drawing.new("Line"),
		Drawing.new("Line")
	}

	for _, line in pairs(box) do
		if type(line) == "table" then
			-- connectors handled separately
		else
			line.Visible = false
			line.Color = Colors.Enemy
			line.Thickness = Settings.BoxThickness
		end
	end

	for _, c in ipairs(box.Connectors) do
		c.Visible = false
		c.Color = Colors.Enemy
		c.Thickness = Settings.BoxThickness
	end

	-- Tracer
	local tracer = Drawing.new("Line")
	tracer.Visible = false
	tracer.Color = Colors.Enemy
	tracer.Thickness = Settings.TracerThickness

	-- Health bar: outline square, fill square, text
	local healthBar = {
		Outline = Drawing.new("Square"),
		Fill = Drawing.new("Square"),
		Text = Drawing.new("Text")
	}

	healthBar.Outline.Visible = false
	healthBar.Outline.Filled = false
	healthBar.Outline.Color = Colors.Distance

	healthBar.Fill.Visible = false
	healthBar.Fill.Filled = true
	healthBar.Fill.Color = Colors.Health
	healthBar.Fill.Transparency = 1 - Settings.BoxFillTransparency -- Drawing API varities; keep reasonable default

	healthBar.Text.Visible = false
	healthBar.Text.Center = true
	healthBar.Text.Size = Settings.TextSize
	healthBar.Text.Color = Colors.Health
	healthBar.Text.Font = Settings.TextFont
	healthBar.Text.Outline = true

	-- Info (name + distance)
	local info = {
		Name = Drawing.new("Text"),
		Distance = Drawing.new("Text")
	}

	for _, text in pairs(info) do
		text.Visible = false
		text.Center = true
		text.Size = Settings.TextSize
		text.Color = Colors.Enemy
		text.Font = Settings.TextFont
		text.Outline = true
	end

	-- Snapline
	local snapline = Drawing.new("Line")
	snapline.Visible = false
	snapline.Color = Colors.Enemy
	snapline.Thickness = 1

	-- Highlight (chams)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Settings.ChamsFillColor
	highlight.OutlineColor = Settings.ChamsOutlineColor
	highlight.FillTransparency = Settings.ChamsTransparency
	highlight.OutlineTransparency = Settings.ChamsOutlineTransparency
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = Settings.ChamsEnabled

	Highlights[player] = highlight

	-- Skeleton lines
	local skeleton = {
		Head = Drawing.new("Line"),
		Neck = Drawing.new("Line"),
		UpperSpine = Drawing.new("Line"),
		LowerSpine = Drawing.new("Line"),
		LeftShoulder = Drawing.new("Line"),
		LeftUpperArm = Drawing.new("Line"),
		LeftLowerArm = Drawing.new("Line"),
		LeftHand = Drawing.new("Line"),
		RightShoulder = Drawing.new("Line"),
		RightUpperArm = Drawing.new("Line"),
		RightLowerArm = Drawing.new("Line"),
		RightHand = Drawing.new("Line"),
		LeftHip = Drawing.new("Line"),
		LeftUpperLeg = Drawing.new("Line"),
		LeftLowerLeg = Drawing.new("Line"),
		LeftFoot = Drawing.new("Line"),
		RightHip = Drawing.new("Line"),
		RightUpperLeg = Drawing.new("Line"),
		RightLowerLeg = Drawing.new("Line"),
		RightFoot = Drawing.new("Line")
	}

	for _, line in pairs(skeleton) do
		line.Visible = false
		line.Color = Settings.SkeletonColor
		line.Thickness = Settings.SkeletonThickness
		line.Transparency = Settings.SkeletonTransparency
	end

	Drawings.Skeleton[player] = skeleton

	Drawings.ESP[player] = {
		Box = box,
		Tracer = tracer,
		HealthBar = healthBar,
		Info = info,
		Snapline = snapline
	}
end

local function RemoveESP(player)
	local esp = Drawings.ESP[player]
	if esp then
		-- Box: may include connectors table
		local box = esp.Box
		if box then
			for k, obj in pairs(box) do
				if type(obj) == "table" then
					for _, v in pairs(obj) do
						if v and v.Remove then pcall(function() v:Remove() end) end
					end
				else
					if obj and obj.Remove then pcall(function() obj:Remove() end) end
				end
			end
		end

		if esp.Tracer and esp.Tracer.Remove then pcall(function() esp.Tracer:Remove() end) end

		if esp.HealthBar then
			for _, obj in pairs(esp.HealthBar) do
				if obj and obj.Remove then pcall(function() obj:Remove() end) end
			end
		end

		if esp.Info then
			for _, obj in pairs(esp.Info) do
				if obj and obj.Remove then pcall(function() obj:Remove() end) end
			end
		end

		if esp.Snapline and esp.Snapline.Remove then pcall(function() esp.Snapline:Remove() end) end

		Drawings.ESP[player] = nil
	end

	local highlight = Highlights[player]
	if highlight then
		pcall(function() highlight:Destroy() end)
		Highlights[player] = nil
	end

	local skeleton = Drawings.Skeleton[player]
	if skeleton then
		for _, line in pairs(skeleton) do
			if line and line.Remove then pcall(function() line:Remove() end) end
		end
		Drawings.Skeleton[player] = nil
	end
end

local function GetPlayerColor(player)
	if Settings.RainbowEnabled then
		if Settings.RainbowBoxes and Settings.BoxESP then return Colors.Rainbow end
		if Settings.RainbowTracers and Settings.TracerESP then return Colors.Rainbow end
		if Settings.RainbowText and (Settings.NameESP or Settings.HealthESP) then return Colors.Rainbow end
	end
	-- Return ally color if same team, else enemy
	if LocalPlayer and LocalPlayer.Team and player.Team and player.Team == LocalPlayer.Team then
		return Colors.Ally
	else
		return Colors.Enemy
	end
end

local function GetTracerOrigin()
	local origin = Settings.TracerOrigin
	if origin == "Bottom" then
		return Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
	elseif origin == "Top" then
		return Vector2.new(Camera.ViewportSize.X/2, 0)
	elseif origin == "Mouse" then
		return UserInputService:GetMouseLocation()
	else
		return Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
	end
end

local function UpdateESP(player)
	if not Settings.Enabled then return end
	local esp = Drawings.ESP[player]
	if not esp then return end

	local character = player.Character
	if not character then
		-- hide all
		for _, obj in pairs(esp.Box) do hideDrawingOrTable(obj) end
		esp.Tracer.Visible = false
		for _, obj in pairs(esp.HealthBar) do hideDrawingOrTable(obj) end
		for _, obj in pairs(esp.Info) do hideDrawingOrTable(obj) end
		esp.Snapline.Visible = false
		local skeleton = Drawings.Skeleton[player]
		if skeleton then for _, line in pairs(skeleton) do line.Visible = false end end
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		for _, obj in pairs(esp.Box) do hideDrawingOrTable(obj) end
		esp.Tracer.Visible = false
		for _, obj in pairs(esp.HealthBar) do hideDrawingOrTable(obj) end
		for _, obj in pairs(esp.Info) do hideDrawingOrTable(obj) end
		esp.Snapline.Visible = false
		local skeleton = Drawings.Skeleton[player]
		if skeleton then for _, line in pairs(skeleton) do line.Visible = false end end
		return
	end

	-- camera check
	local pos3, onScreenRoot = Camera:WorldToViewportPoint(rootPart.Position)
	if not onScreenRoot then
		for _, obj in pairs(esp.Box) do hideDrawingOrTable(obj) end
		esp.Tracer.Visible = false
		for _, obj in pairs(esp.HealthBar) do hideDrawingOrTable(obj) end
		for _, obj in pairs(esp.Info) do hideDrawingOrTable(obj) end
		esp.Snapline.Visible = false
		local skeleton = Drawings.Skeleton[player]
		if skeleton then for _, line in pairs(skeleton) do line.Visible = false end end
		return
	end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		for _, obj in pairs(esp.Box) do hideDrawingOrTable(obj) end
		esp.Tracer.Visible = false
		for _, obj in pairs(esp.HealthBar) do hideDrawingOrTable(obj) end
		for _, obj in pairs(esp.Info) do hideDrawingOrTable(obj) end
		esp.Snapline.Visible = false
		local skeleton = Drawings.Skeleton[player]
		if skeleton then for _, line in pairs(skeleton) do line.Visible = false end end
		return
	end

	-- depth/distance check
	local pos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
	local distance = (rootPart.Position - Camera.CFrame.Position).Magnitude
	if not onScreen or distance > Settings.MaxDistance then
		for _, obj in pairs(esp.Box) do hideDrawingOrTable(obj) end
		esp.Tracer.Visible = false
		for _, obj in pairs(esp.HealthBar) do hideDrawingOrTable(obj) end
		for _, obj in pairs(esp.Info) do hideDrawingOrTable(obj) end
		esp.Snapline.Visible = false
		return
	end

	if Settings.TeamCheck and LocalPlayer and player.Team == LocalPlayer.Team and not Settings.ShowTeam then
		for _, obj in pairs(esp.Box) do hideDrawingOrTable(obj) end
		esp.Tracer.Visible = false
		for _, obj in pairs(esp.HealthBar) do hideDrawingOrTable(obj) end
		for _, obj in pairs(esp.Info) do hideDrawingOrTable(obj) end
		esp.Snapline.Visible = false
		return
	end

	local color = GetPlayerColor(player)
	local size = character:GetExtentsSize()
	local cf = rootPart.CFrame

	-- top/bottom positions (fixed parentheses)
	local top3, top_onscreen = Camera:WorldToViewportPoint((cf * CFrame.new(0, size.Y/2, 0)).Position)
	local bottom3, bottom_onscreen = Camera:WorldToViewportPoint((cf * CFrame.new(0, -size.Y/2, 0)).Position)

	if not top_onscreen or not bottom_onscreen then
		for _, obj in pairs(esp.Box) do hideDrawingOrTable(obj) end
		return
	end

	local screenSize = bottom3.Y - top3.Y
	local boxWidth = math.clamp(screenSize * 0.65, 8, Camera.ViewportSize.X)
	local boxPosition = Vector2.new(top3.X - boxWidth/2, top3.Y)
	local boxSize = Vector2.new(boxWidth, screenSize)

	-- Hide box elements by default (handles nested connector tables)
	for _, obj in pairs(esp.Box) do
		if type(obj) == "table" then
			for _, v in pairs(obj) do
				if v and v.Visible ~= nil then v.Visible = false end
			end
		else
			if obj and obj.Visible ~= nil then obj.Visible = false end
		end
	end

	-- BOX DRAWING
	if Settings.BoxESP then
		if Settings.BoxStyle == "ThreeD" then
			-- get front/back corners (fixed parentheses)
			local front = {
				TL = Camera:WorldToViewportPoint((cf * CFrame.new(-size.X/2, size.Y/2, -size.Z/2)).Position),
				TR = Camera:WorldToViewportPoint((cf * CFrame.new(size.X/2, size.Y/2, -size.Z/2)).Position),
				BL = Camera:WorldToViewportPoint((cf * CFrame.new(-size.X/2, -size.Y/2, -size.Z/2)).Position),
				BR = Camera:WorldToViewportPoint((cf * CFrame.new(size.X/2, -size.Y/2, -size.Z/2)).Position)
			}
			local back = {
				TL = Camera:WorldToViewportPoint((cf * CFrame.new(-size.X/2, size.Y/2, size.Z/2)).Position),
				TR = Camera:WorldToViewportPoint((cf * CFrame.new(size.X/2, size.Y/2, size.Z/2)).Position),
				BL = Camera:WorldToViewportPoint((cf * CFrame.new(-size.X/2, -size.Y/2, size.Z/2)).Position),
				BR = Camera:WorldToViewportPoint((cf * CFrame.new(size.X/2, -size.Y/2, size.Z/2)).Position)
			}

			-- ensure all are in front of camera (Z > 0)
			if not (front.TL.Z > 0 and front.TR.Z > 0 and front.BL.Z > 0 and front.BR.Z > 0 and back.TL.Z > 0 and back.TR.Z > 0 and back.BL.Z > 0 and back.BR.Z > 0) then
				for _, obj in pairs(esp.Box) do hideDrawingOrTable(obj) end
				return
			end

			-- convert Vector3 -> Vector2
			local function toVec2(v3) return Vector2.new(v3.X, v3.Y) end
			local fTL, fTR, fBL, fBR = toVec2(front.TL), toVec2(front.TR), toVec2(front.BL), toVec2(front.BR)
			local bTL, bTR, bBL, bBR = toVec2(back.TL), toVec2(back.TR), toVec2(back.BL), toVec2(back.BR)

			-- front face (draw rectangle lines)
			esp.Box.TopLeft.From = fTL
			esp.Box.TopLeft.To = fTR
			esp.Box.TopLeft.Visible = true

			esp.Box.TopRight.From = fTR
			esp.Box.TopRight.To = fBR
			esp.Box.TopRight.Visible = true

			esp.Box.BottomLeft.From = fBL
			esp.Box.BottomLeft.To = fBR
			esp.Box.BottomLeft.Visible = true

			esp.Box.BottomRight.From = fTL
			esp.Box.BottomRight.To = fBL
			esp.Box.BottomRight.Visible = true

			-- back face
			esp.Box.Left.From = bTL
			esp.Box.Left.To = bTR
			esp.Box.Left.Visible = true

			esp.Box.Right.From = bTR
			esp.Box.Right.To = bBR
			esp.Box.Right.Visible = true

			esp.Box.Top.From = bBL
			esp.Box.Top.To = bBR
			esp.Box.Top.Visible = true

			esp.Box.Bottom.From = bTL
			esp.Box.Bottom.To = bBL
			esp.Box.Bottom.Visible = true

			-- connectors (reuse persistent connector lines)
			local connectors = esp.Box.Connectors
			if connectors then
				connectors[1].From = fTL
				connectors[1].To = bTL
				connectors[1].Visible = true

				connectors[2].From = fTR
				connectors[2].To = bTR
				connectors[2].Visible = true

				connectors[3].From = fBL
				connectors[3].To = bBL
				connectors[3].Visible = true

				connectors[4].From = fBR
				connectors[4].To = bBR
				connectors[4].Visible = true

				for _, c in ipairs(connectors) do
					c.Color = color
					c.Thickness = Settings.BoxThickness
				end
			end
		elseif Settings.BoxStyle == "Corner" then
			local cornerSize = boxWidth * 0.2

			-- top horizontal pieces
			esp.Box.TopLeft.From = boxPosition
			esp.Box.TopLeft.To = boxPosition + Vector2.new(cornerSize, 0)
			esp.Box.TopLeft.Visible = true

			esp.Box.TopRight.From = boxPosition + Vector2.new(boxSize.X, 0)
			esp.Box.TopRight.To = boxPosition + Vector2.new(boxSize.X - cornerSize, 0)
			esp.Box.TopRight.Visible = true

			-- bottom horizontals
			esp.Box.BottomLeft.From = boxPosition + Vector2.new(0, boxSize.Y)
			esp.Box.BottomLeft.To = boxPosition + Vector2.new(cornerSize, boxSize.Y)
			esp.Box.BottomLeft.Visible = true

			esp.Box.BottomRight.From = boxPosition + Vector2.new(boxSize.X, boxSize.Y)
			esp.Box.BottomRight.To = boxPosition + Vector2.new(boxSize.X - cornerSize, boxSize.Y)
			esp.Box.BottomRight.Visible = true

			-- verticals
			esp.Box.Left.From = boxPosition
			esp.Box.Left.To = boxPosition + Vector2.new(0, cornerSize)
			esp.Box.Left.Visible = true

			esp.Box.Right.From = boxPosition + Vector2.new(boxSize.X, 0)
			esp.Box.Right.To = boxPosition + Vector2.new(boxSize.X, cornerSize)
			esp.Box.Right.Visible = true

			esp.Box.Top.From = boxPosition + Vector2.new(0, boxSize.Y)
			esp.Box.Top.To = boxPosition + Vector2.new(0, boxSize.Y - cornerSize)
			esp.Box.Top.Visible = true

			esp.Box.Bottom.From = boxPosition + Vector2.new(boxSize.X, boxSize.Y)
			esp.Box.Bottom.To = boxPosition + Vector2.new(boxSize.X, boxSize.Y - cornerSize)
			esp.Box.Bottom.Visible = true
		else -- Full
			esp.Box.Left.From = boxPosition
			esp.Box.Left.To = boxPosition + Vector2.new(0, boxSize.Y)
			esp.Box.Left.Visible = true

			esp.Box.Right.From = boxPosition + Vector2.new(boxSize.X, 0)
			esp.Box.Right.To = boxPosition + Vector2.new(boxSize.X, boxSize.Y)
			esp.Box.Right.Visible = true

			esp.Box.Top.From = boxPosition
			esp.Box.Top.To = boxPosition + Vector2.new(boxSize.X, 0)
			esp.Box.Top.Visible = true

			esp.Box.Bottom.From = boxPosition + Vector2.new(0, boxSize.Y)
			esp.Box.Bottom.To = boxPosition + Vector2.new(boxSize.X, boxSize.Y)
			esp.Box.Bottom.Visible = true

			-- corners not used in full box; keep invisible
			esp.Box.TopLeft.Visible = false
			esp.Box.TopRight.Visible = false
			esp.Box.BottomLeft.Visible = false
			esp.Box.BottomRight.Visible = false
		end

		-- apply color & thickness to visible box lines
		for _, obj in pairs(esp.Box) do
			if type(obj) == "table" then
				for _, v in pairs(obj) do
					if v and v.Visible then
						v.Color = color
						v.Thickness = Settings.BoxThickness
					end
				end
			else
				if obj and obj.Visible then
					obj.Color = color
					obj.Thickness = Settings.BoxThickness
				end
			end
		end
	end

	-- Tracer
	if Settings.TracerESP then
		esp.Tracer.From = GetTracerOrigin()
		esp.Tracer.To = Vector2.new(pos.X, pos.Y)
		esp.Tracer.Color = color
		esp.Tracer.Visible = true
	else
		esp.Tracer.Visible = false
	end

	-- Health
	if Settings.HealthESP then
		local health = humanoid.Health
		local maxHealth = humanoid.MaxHealth
		local healthPercent = 0
		if maxHealth > 0 then healthPercent = math.clamp(health / maxHealth, 0, 1) end

		local barHeight = math.max(screenSize * 0.8, 8)
		local barWidth = 4
		local barPos = Vector2.new(
			boxPosition.X - barWidth - 6,
			boxPosition.Y + (screenSize - barHeight)/2
		)

		esp.HealthBar.Outline.Size = Vector2.new(barWidth, barHeight)
		esp.HealthBar.Outline.Position = barPos
		esp.HealthBar.Outline.Visible = true

		esp.HealthBar.Fill.Size = Vector2.new(barWidth - 2, barHeight * healthPercent)
		esp.HealthBar.Fill.Position = Vector2.new(barPos.X + 1, barPos.Y + barHeight * (1 - healthPercent))
		esp.HealthBar.Fill.Color = Color3.fromRGB(math.clamp(255 - (255 * healthPercent),0,255), math.clamp(255 * healthPercent,0,255), 0)
		esp.HealthBar.Fill.Visible = true

		if Settings.HealthStyle == "Both" or Settings.HealthStyle == "Text" then
			local text = ""
			if Settings.HealthTextFormat == "Number" then
				text = tostring(math.floor(health)) .. Settings.HealthTextSuffix
			elseif Settings.HealthTextFormat == "Percentage" then
				text = tostring(math.floor(healthPercent * 100)) .. "%"
			else
				text = tostring(math.floor(health)) .. " / " .. tostring(math.floor(maxHealth)) .. " " .. Settings.HealthTextSuffix
			end

			esp.HealthBar.Text.Text = text
			esp.HealthBar.Text.Position = Vector2.new(barPos.X + barWidth + 6, barPos.Y + barHeight / 2)
			esp.HealthBar.Text.Visible = true
		else
			esp.HealthBar.Text.Visible = false
		end
	else
		for _, obj in pairs(esp.HealthBar) do
			if obj then obj.Visible = false end
		end
	end

	-- Name & Distance (distance above the name)
	if Settings.NameESP then
		local nameText = (Settings.NameMode == "DisplayName" and player.DisplayName) or player.Name
		-- Distance text (uses precomputed 'distance' local)
		local distText = tostring(math.floor(distance)) .. " " .. tostring(Settings.DistanceUnit or "studs")

		-- Distance: above the name
		esp.Info.Distance.Text = distText
		esp.Info.Distance.Position = Vector2.new(boxPosition.X + boxWidth/2, boxPosition.Y - 30) -- tweak offset here
		esp.Info.Distance.Color = Colors.Distance
		esp.Info.Distance.Size = Settings.TextSize
		esp.Info.Distance.Visible = Settings.ShowDistance

		-- Name: below distance
		esp.Info.Name.Text = nameText
		esp.Info.Name.Position = Vector2.new(boxPosition.X + boxWidth/2, boxPosition.Y - 14) -- tweak offset here
		esp.Info.Name.Color = color
		esp.Info.Name.Visible = true
	else
		esp.Info.Name.Visible = false
		esp.Info.Distance.Visible = false
	end

	-- Snapline
	if Settings.Snaplines then
		esp.Snapline.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
		esp.Snapline.To = Vector2.new(pos.X, pos.Y)
		esp.Snapline.Color = color
		esp.Snapline.Visible = true
	else
		esp.Snapline.Visible = false
	end

	-- Highlight (chams)
	local highlight = Highlights[player]
	if highlight then
		if Settings.ChamsEnabled and character then
			highlight.Parent = character
			highlight.FillColor = Settings.ChamsFillColor
			highlight.OutlineColor = Settings.ChamsOutlineColor
			highlight.FillTransparency = Settings.ChamsTransparency
			highlight.OutlineTransparency = Settings.ChamsOutlineTransparency
			highlight.Enabled = true
		else
			highlight.Enabled = false
		end
	end

	-- Skeleton
	if Settings.SkeletonESP then
		local function getBonePositions(char)
			if not char then return nil end
			local bones = {
				Head = char:FindFirstChild("Head"),
				UpperTorso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"),
				LowerTorso = char:FindFirstChild("LowerTorso") or char:FindFirstChild("Torso"),
				RootPart = char:FindFirstChild("HumanoidRootPart"),
				LeftUpperArm = char:FindFirstChild("LeftUpperArm") or char:FindFirstChild("Left Arm"),
				LeftLowerArm = char:FindFirstChild("LeftLowerArm") or char:FindFirstChild("Left Arm"),
				LeftHand = char:FindFirstChild("LeftHand") or char:FindFirstChild("Left Arm"),
				RightUpperArm = char:FindFirstChild("RightUpperArm") or char:FindFirstChild("Right Arm"),
				RightLowerArm = char:FindFirstChild("RightLowerArm") or char:FindFirstChild("Right Arm"),
				RightHand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"),
				LeftUpperLeg = char:FindFirstChild("LeftUpperLeg") or char:FindFirstChild("Left Leg"),
				LeftLowerLeg = char:FindFirstChild("LeftLowerLeg") or char:FindFirstChild("Left Leg"),
				LeftFoot = char:FindFirstChild("LeftFoot") or char:FindFirstChild("Left Leg"),
				RightUpperLeg = char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("Right Leg"),
				RightLowerLeg = char:FindFirstChild("RightLowerLeg") or char:FindFirstChild("Right Leg"),
				RightFoot = char:FindFirstChild("RightFoot") or char:FindFirstChild("Right Leg")
			}
			if not (bones.Head and bones.UpperTorso) then return nil end
			return bones
		end

		local function drawBone(from, to, line)
			if not from or not to then
				line.Visible = false
				return
			end
			local fromPos = from.CFrame.Position
			local toPos = to.CFrame.Position
			local fromScreen, fromVisible = Camera:WorldToViewportPoint(fromPos)
			local toScreen, toVisible = Camera:WorldToViewportPoint(toPos)
			if not (fromVisible and toVisible) or fromScreen.Z < 0 or toScreen.Z < 0 then
				line.Visible = false
				return
			end
			local screenBounds = Camera.ViewportSize
			if fromScreen.X < 0 or fromScreen.X > screenBounds.X or fromScreen.Y < 0 or fromScreen.Y > screenBounds.Y or
				toScreen.X < 0 or toScreen.X > screenBounds.X or toScreen.Y < 0 or toScreen.Y > screenBounds.Y then
				line.Visible = false
				return
			end
			line.From = Vector2.new(fromScreen.X, fromScreen.Y)
			line.To = Vector2.new(toScreen.X, toScreen.Y)
			line.Color = Settings.SkeletonColor
			line.Thickness = Settings.SkeletonThickness
			line.Transparency = Settings.SkeletonTransparency
			line.Visible = true
		end

		local bones = getBonePositions(character)
		if bones then
			local skeleton = Drawings.Skeleton[player]
			if skeleton then
				-- Spine & Head
				drawBone(bones.Head, bones.UpperTorso, skeleton.Head)
				drawBone(bones.UpperTorso, bones.LowerTorso, skeleton.UpperSpine)
				-- Left Arm
				drawBone(bones.UpperTorso, bones.LeftUpperArm, skeleton.LeftShoulder)
				drawBone(bones.LeftUpperArm, bones.LeftLowerArm, skeleton.LeftUpperArm)
				drawBone(bones.LeftLowerArm, bones.LeftHand, skeleton.LeftLowerArm)
				-- Right Arm
				drawBone(bones.UpperTorso, bones.RightUpperArm, skeleton.RightShoulder)
				drawBone(bones.RightUpperArm, bones.RightLowerArm, skeleton.RightUpperArm)
				drawBone(bones.RightLowerArm, bones.RightHand, skeleton.RightLowerArm)
				-- Left Leg
				drawBone(bones.LowerTorso, bones.LeftUpperLeg, skeleton.LeftHip)
				drawBone(bones.LeftUpperLeg, bones.LeftLowerLeg, skeleton.LeftUpperLeg)
				drawBone(bones.LeftLowerLeg, bones.LeftFoot, skeleton.LeftLowerLeg)
				-- Right Leg
				drawBone(bones.LowerTorso, bones.RightUpperLeg, skeleton.RightHip)
				drawBone(bones.RightUpperLeg, bones.RightLowerLeg, skeleton.RightUpperLeg)
				drawBone(bones.RightLowerLeg, bones.RightFoot, skeleton.RightLowerLeg)
			end
		end
	else
		local skeleton = Drawings.Skeleton[player]
		if skeleton then for _, line in pairs(skeleton) do line.Visible = false end end
	end
end

local function DisableESP()
	for _, player in ipairs(Players:GetPlayers()) do
		local esp = Drawings.ESP[player]
		if esp then
			for _, obj in pairs(esp.Box) do hideDrawingOrTable(obj) end
			esp.Tracer.Visible = false
			for _, obj in pairs(esp.HealthBar) do if obj then obj.Visible = false end end
			for _, obj in pairs(esp.Info) do if obj then obj.Visible = false end end
			esp.Snapline.Visible = false
		end

		local skeleton = Drawings.Skeleton[player]
		if skeleton then for _, line in pairs(skeleton) do line.Visible = false end end
	end
end

local function CleanupESP()
	for _, player in ipairs(Players:GetPlayers()) do
		RemoveESP(player)
	end
	Drawings.ESP = {}
	Drawings.Skeleton = {}
	Highlights = {}
end

-- UI building (kept from original)
local Window = Fluent:CreateWindow({
	Title = "WA Universal ESP",
	SubTitle = "by WA",
	TabWidth = 160,
	Size = UDim2.fromOffset(580, 460),
	Acrylic = false,
	Theme = "Dark",
	MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
	ESP = Window:AddTab({ Title = "ESP", Icon = "eye" }),
	Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
	Config = Window:AddTab({ Title = "Config", Icon = "save" })
}

-- (the rest of your original UI code stays intact)
-- I did not modify UI callback logic except ensuring Settings table is used consistently.
-- Paste the remainder of your UI-creation code here (unchanged from your original),
-- or use the UI code you already have in the pasted script above.

-- Rainbow updater
task.spawn(function()
	while task.wait(0.1) do
		Colors.Rainbow = Color3.fromHSV((tick() * Settings.RainbowSpeed) % 1, 1, 1)
	end
end)

local lastUpdate = 0
RunService.RenderStepped:Connect(function()
	if not Settings.Enabled then
		DisableESP()
		return
	end

	local currentTime = tick()
	if currentTime - lastUpdate >= Settings.RefreshRate then
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				if not Drawings.ESP[player] then
					CreateESP(player)
				end
				UpdateESP(player)
			end
		end
		lastUpdate = currentTime
	end
end)

Players.PlayerAdded:Connect(function(p) CreateESP(p) end)
Players.PlayerRemoving:Connect(function(p) RemoveESP(p) end)

for _, player in ipairs(Players:GetPlayers()) do
	if player ~= LocalPlayer then
		CreateESP(player)
	end
end

Window:SelectTab(1)

Fluent:Notify({
	Title = "WA Universal ESP",
	Content = "Loaded successfully!",
	Duration = 5
})
