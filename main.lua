local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local ESP = {}

-- Helper: Create Drawing object for lines
local function createLine()
	local line = Drawing.new("Line")
	line.Thickness = 1.5
	line.Color = Color3.new(1, 1, 1)
	line.Visible = false
	return line
end

-- Create ESP visuals for a player
local function setupESP(player)
	if player == LocalPlayer then return end

	local function onCharacterAdded(char)
		local humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
		if not humanoid then return end

		local rigType = humanoid.RigType

		-- Name tag with light red color
		local nameTag = Drawing.new("Text")
		nameTag.Size = 14
		nameTag.Center = true
		nameTag.Outline = true
		nameTag.Color = Color3.fromRGB(255, 255, 255)
		nameTag.Visible = false

		-- Distance tag
		local distanceTag = Drawing.new("Text")
		distanceTag.Size = 13
		distanceTag.Center = true
		distanceTag.Outline = true
		distanceTag.Color = Color3.new(0.6, 0.6, 0.6)
		distanceTag.Visible = false

		-- Skeleton lines
		local skeletonLines = {}

		local bonePairs = {}
		if rigType == Enum.HumanoidRigType.R15 then
			bonePairs = {
				-- spine
				{"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
				-- left arm
				{"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
				-- right arm
				{"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
				-- left leg
				{"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
				-- right leg
				{"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"}
			}
		else -- R6
			bonePairs = {
				{"Head", "Torso"},
				{"Torso", "Left Arm"}, {"Left Arm", "Left Leg"},
				{"Torso", "Right Arm"}, {"Right Arm", "Right Leg"},
			}
		end

		for _, pair in ipairs(bonePairs) do
			local id = table.concat(pair, "_")
			skeletonLines[id] = createLine()
		end

		ESP[player] = {
			Name = nameTag,
			Distance = distanceTag,
			Skeleton = skeletonLines,
			BonePairs = bonePairs,
			Character = char,
		}
	end

	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
end

local function removeESP(player)
	local data = ESP[player]
	if data then
		if data.Name then data.Name:Remove() end
		if data.Distance then data.Distance:Remove() end
		for _, line in pairs(data.Skeleton or {}) do
			line:Remove()
		end
		ESP[player] = nil
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	setupESP(player)
end
Players.PlayerAdded:Connect(setupESP)
Players.PlayerRemoving:Connect(removeESP)

local function drawLine(from, to, line)
	if from and to then
		local p1, on1 = Camera:WorldToViewportPoint(from.Position)
		local p2, on2 = Camera:WorldToViewportPoint(to.Position)
		if on1 and on2 then
			line.From = Vector2.new(p1.X, p1.Y)
			line.To = Vector2.new(p2.X, p2.Y)
			line.Visible = true
			return
		end
	end
	line.Visible = false
end

RunService.RenderStepped:Connect(function()
	for player, data in pairs(ESP) do
		local char = data.Character
		if not char then continue end

		local head = char:FindFirstChild("Head")
		local hrp = char:FindFirstChild("HumanoidRootPart")

		if head and hrp then
			local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
			if onScreen then
				local dist = math.floor((Camera.CFrame.Position - hrp.Position).Magnitude)
				data.Name.Text = player.Name
				data.Name.Position = Vector2.new(screenPos.X, screenPos.Y - 20)
				data.Name.Visible = true

				data.Distance.Text = tostring(dist) .. " studs"
				data.Distance.Position = Vector2.new(screenPos.X, screenPos.Y - 5)
				data.Distance.Visible = true
			else
				data.Name.Visible = false
				data.Distance.Visible = false
			end
		end

		-- Draw valid bone lines
		for _, pair in ipairs(data.BonePairs) do
			local part1 = char:FindFirstChild(pair[1])
			local part2 = char:FindFirstChild(pair[2])
			local line = data.Skeleton[table.concat(pair, "_")]
			drawLine(part1, part2, line)
		end
	end
end)