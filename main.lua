-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Settings
local MAX_DISTANCE = 250 -- studs, set nil or high to ignore
local Whitelist = {}
local Blacklist = {}

local COLORS = {
    Enemy = Color3.fromRGB(255, 0, 0),
    Ally = Color3.fromRGB(0, 255, 0),
    Skeleton = Color3.fromRGB(255, 255, 255)
}

local ESPObjects = {}

-- Bone definitions
local R15Bones = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"}
}

-- Drawing helpers
local function createText(size)
    local text = Drawing.new("Text")
    text.Size = size
    text.Center = true
    text.Outline = true
    text.Visible = true
    return text
end

local function createLine()
    local line = Drawing.new("Line")
    line.Thickness = 2
    line.Color = COLORS.Skeleton
    line.Visible = true
    return line
end

-- ESP setup
local function setupESP(player)
    if player == LocalPlayer then return end

    local function onCharacter(char)
        -- remove old ESP
        if ESPObjects[player] then
            local old = ESPObjects[player]
            if old.Name then old.Name:Remove() end
            if old.Distance then old.Distance:Remove() end
            for _, line in pairs(old.Skeleton or {}) do line:Remove() end
            ESPObjects[player] = nil
        end

        -- create new ESP
        local humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid",5)
        if not humanoid then return end

        local nameTag = createText(14)
        local distanceTag = createText(13)
        local skeleton = {}
        for _, pair in ipairs(R15Bones) do
            skeleton[pair[1].."_"..pair[2]] = createLine()
        end

        ESPObjects[player] = {Character=char, Name=nameTag, Distance=distanceTag, Skeleton=skeleton}

        -- remove on death
        humanoid.Died:Connect(function()
            if ESPObjects[player] then
                local old = ESPObjects[player]
                if old.Name then old.Name:Remove() end
                if old.Distance then old.Distance:Remove() end
                for _, line in pairs(old.Skeleton or {}) do line:Remove() end
                ESPObjects[player] = nil
            end
        end)
    end

    player.CharacterAdded:Connect(onCharacter)
    if player.Character then
        onCharacter(player.Character)
    end
end

-- Apply to all players
for _, p in ipairs(Players:GetPlayers()) do
    setupESP(p)
end
Players.PlayerAdded:Connect(setupESP)
Players.PlayerRemoving:Connect(function(player)
    if ESPObjects[player] then
        local old = ESPObjects[player]
        if old.Name then old.Name:Remove() end
        if old.Distance then old.Distance:Remove() end
        for _, line in pairs(old.Skeleton or {}) do line:Remove() end
        ESPObjects[player] = nil
    end
end)

-- ESP update
RunService.RenderStepped:Connect(function()
    local camPos = Camera.CFrame.Position

    for player, data in pairs(ESPObjects) do
        local char = data.Character
        if not char or not char.Parent then
            data.Name:Remove()
            data.Distance:Remove()
            for _, line in pairs(data.Skeleton) do line:Remove() end
            ESPObjects[player] = nil
            continue
        end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        if not (hrp and head) then continue end

        -- distance check
        local distance = (hrp.Position - camPos).Magnitude
        if MAX_DISTANCE and distance > MAX_DISTANCE then
            data.Name.Visible = false
            data.Distance.Visible = false
            for _, line in pairs(data.Skeleton) do line.Visible = false end
            continue
        end

        -- determine color
        local color = COLORS.Enemy
        if Whitelist[player.Name] then
            color = COLORS.Ally
        elseif Blacklist[player.Name] then
            color = COLORS.Enemy
        elseif LocalPlayer.Team and player.Team == LocalPlayer.Team then
            color = COLORS.Ally
        end

        -- skeleton
        for _, pair in ipairs(R15Bones) do
            local part1 = char:FindFirstChild(pair[1])
            local part2 = char:FindFirstChild(pair[2])
            local line = data.Skeleton[pair[1].."_"..pair[2]]
            if part1 and part2 then
                local p1,_ = Camera:WorldToViewportPoint(part1.Position)
                local p2,_ = Camera:WorldToViewportPoint(part2.Position)
                line.From = Vector2.new(p1.X,p1.Y)
                line.To = Vector2.new(p2.X,p2.Y)
                line.Visible = true
                line.Color = COLORS.Skeleton
            else
                line.Visible = false
            end
        end

        -- name & distance
        local headPos,_ = Camera:WorldToViewportPoint(head.Position + Vector3.new(0,0.5,0))
        data.Name.Text = player.Name
        data.Name.Position = Vector2.new(headPos.X, headPos.Y-20)
        data.Name.Color = color
        data.Name.Visible = true

        data.Distance.Text = math.floor(distance).." studs"
        data.Distance.Position = Vector2.new(headPos.X, headPos.Y-5)
        data.Distance.Color = color
        data.Distance.Visible = true
    end
end)
