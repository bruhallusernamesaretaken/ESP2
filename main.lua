-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Settings
local MAX_DISTANCE = 1000
local ESPEnabled = true
local Whitelist = {}
local Blacklist = {}

local COLORS = {
    Enemy = Color3.fromRGB(255,0,0),
    Ally = Color3.fromRGB(0,255,0),
    Skeleton = Color3.fromRGB(255,255,255),
    Text = Color3.fromRGB(180,180,180)
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

local R6Bones = {
    {"Head","Torso"},
    {"Torso","Left Arm"},{"Left Arm","Left Leg"},
    {"Torso","Right Arm"},{"Right Arm","Right Leg"}
}

-- Drawing Helpers
local function createText(size)
    local text = Drawing.new("Text")
    text.Size = size
    text.Center = true
    text.Outline = true
    text.Visible = false
    return text
end

local function createLine()
    local line = Drawing.new("Line")
    line.Thickness = 2
    line.Color = COLORS.Skeleton
    line.Visible = false
    return line
end

-- Get currently equipped tool reliably
local function getEquippedTool(player, char)
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then return tool.Name end
    end
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        local tool = backpack:FindFirstChildOfClass("Tool")
        if tool then return tool.Name end
    end
    return "None"
end

-- Cleanup ESP for a player
local function cleanupESPForPlayer(player)
    local old = ESPObjects[player]
    if not old then return end
    if old.Name then pcall(function() old.Name:Remove() end) end
    if old.Distance then pcall(function() old.Distance:Remove() end) end
    if old.Equipped then pcall(function() old.Equipped:Remove() end) end
    for _, line in pairs(old.Skeleton or {}) do
        if line then pcall(function() line:Remove() end) end
    end
    ESPObjects[player] = nil
end

-- Setup ESP for a player
local function setupESP(player)
    if player == LocalPlayer then return end

    local function onCharacterAdded(char)
        cleanupESPForPlayer(player)

        local humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid",5)
        if not humanoid then return end

        local nameTag = createText(14)
        local distanceTag = createText(13)
        local equippedTag = createText(13)

        local bonePairs = humanoid.RigType == Enum.HumanoidRigType.R15 and R15Bones or R6Bones
        local skeleton = {}
        for _, pair in ipairs(bonePairs) do
            skeleton[pair[1].."_"..pair[2]] = createLine()
        end

        ESPObjects[player] = {
            Character = char,
            Name = nameTag,
            Distance = distanceTag,
            Equipped = equippedTag,
            Skeleton = skeleton,
            BonePairs = bonePairs
        }

        humanoid.Died:Connect(function()
            cleanupESPForPlayer(player)
        end)
    end

    player.CharacterAdded:Connect(onCharacterAdded)
    if player.Character then
        onCharacterAdded(player.Character)
    end
end

-- Initialize ESP for existing players
for _, p in ipairs(Players:GetPlayers()) do
    setupESP(p)
end
Players.PlayerAdded:Connect(setupESP)
Players.PlayerRemoving:Connect(function(player)
    cleanupESPForPlayer(player)
end)

-- ESP Update (per-frame)
RunService.RenderStepped:Connect(function()
    local camPos = Camera.CFrame.Position
    for player, data in pairs(ESPObjects) do
        if not ESPEnabled then
            if data.Name then data.Name.Visible = false end
            if data.Distance then data.Distance.Visible = false end
            if data.Equipped then data.Equipped.Visible = false end
            for _, ln in pairs(data.Skeleton) do if ln then ln.Visible = false end end
            continue
        end

        local char = data.Character
        if not char or not char.Parent then
            cleanupESPForPlayer(player)
            continue
        end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not (hrp and head and humanoid) then continue end

        local distance = (hrp.Position - camPos).Magnitude
        if distance > MAX_DISTANCE then
            if data.Name then data.Name.Visible = false end
            if data.Distance then data.Distance.Visible = false end
            if data.Equipped then data.Equipped.Visible = false end
            for _, ln in pairs(data.Skeleton) do if ln then ln.Visible = false end end
            continue
        end

        -- Color logic
        local color = COLORS.Enemy
        if Whitelist[player.Name] then
            color = COLORS.Ally
        elseif Blacklist[player.Name] then
            color = COLORS.Enemy
        elseif LocalPlayer.Team and player.Team == LocalPlayer.Team then
            color = COLORS.Ally
        end

        -- Skeleton
        for _, pair in ipairs(data.BonePairs) do
            local part1 = char:FindFirstChild(pair[1])
            local part2 = char:FindFirstChild(pair[2])
            local ln = data.Skeleton[pair[1].."_"..pair[2]]
            if part1 and part2 and ln then
                local p1, on1 = Camera:WorldToViewportPoint(part1.Position)
                local p2, on2 = Camera:WorldToViewportPoint(part2.Position)
                if on1 and on2 then
                    ln.From = Vector2.new(p1.X, p1.Y)
                    ln.To = Vector2.new(p2.X, p2.Y)
                    ln.Color = COLORS.Skeleton
                    ln.Visible = true
                else
                    ln.Visible = false
                end
            elseif ln then
                ln.Visible = false
            end
        end

        -- UI texts
        local headPos, onScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0,0.5,0))
        if onScreen then
            data.Name.Text = player.Name
            data.Name.Position = Vector2.new(headPos.X, headPos.Y-28)
            data.Name.Color = color
            data.Name.Visible = true

            data.Distance.Text = math.floor(distance).." studs"
            data.Distance.Position = Vector2.new(headPos.X, headPos.Y-12)
            data.Distance.Color = COLORS.Text
            data.Distance.Visible = true

            -- Equipped tool
            local toolName = getEquippedTool(player, char)
            data.Equipped.Text = "Equipped: "..toolName
            data.Equipped.Position = Vector2.new(headPos.X, headPos.Y + 6)
            data.Equipped.Color = COLORS.Text
            data.Equipped.Visible = true
        else
            data.Name.Visible = false
            data.Distance.Visible = false
            data.Equipped.Visible = false
        end
    end
end)

-- UI Creation
local function CreateUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ESPWhitelistUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 320, 0, 360)
    Frame.Position = UDim2.new(0.5, -160, 0.5, -180)
    Frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
    Frame.Active = true
    Frame.Parent = ScreenGui

    -- Draggable
    local dragging, dragInput, mousePos, framePos = false, nil, nil, nil
    Frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            mousePos = input.Position
            framePos = Frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging=false end
            end)
        end
    end)
    Frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput=input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input==dragInput and dragging then
            local delta = input.Position - mousePos
            Frame.Position = framePos + UDim2.new(0,delta.X,0,delta.Y)
        end
    end)

    -- Title
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1,0,0,32)
    Title.Position = UDim2.new(0,0,0,0)
    Title.BackgroundColor3 = Color3.fromRGB(50,50,50)
    Title.Text = "ESP Control"
    Title.TextColor3 = Color3.fromRGB(255,255,255)
    Title.Parent = Frame

    -- Input
    local InputBox = Instance.new("TextBox")
    InputBox.Size = UDim2.new(1,-20,0,30)
    InputBox.Position = UDim2.new(0,10,0,42)
    InputBox.PlaceholderText = "Enter player name"
    InputBox.TextColor3 = Color3.fromRGB(255,255,255)
    InputBox.BackgroundColor3 = Color3.fromRGB(40,40,40)
    InputBox.ClearTextOnFocus = false
    InputBox.Parent = Frame

    -- Buttons
    local WLButton = Instance.new("TextButton")
    WLButton.Size = UDim2.new(0.5,-15,0,30)
    WLButton.Position = UDim2.new(0,10,0,82)
    WLButton.Text = "Whitelist"
    WLButton.TextColor3 = Color3.fromRGB(255,255,255)
    WLButton.BackgroundColor3 = Color3.fromRGB(0,128,0)
    WLButton.Parent = Frame

    local BLButton = Instance.new("TextButton")
    BLButton.Size = UDim2.new(0.5,-15,0,30)
    BLButton.Position = UDim2.new(0.5,5,0,82)
    BLButton.Text = "Blacklist"
    BLButton.TextColor3 = Color3.fromRGB(255,255,255)
    BLButton.BackgroundColor3 = Color3.fromRGB(128,0,0)
    BLButton.Parent = Frame

    local RefreshButton = Instance.new("TextButton")
    RefreshButton.Size = UDim2.new(1,-20,0,30)
    RefreshButton.Position = UDim2.new(0,10,0,122)
    RefreshButton.Text = "Refresh ESP"
    RefreshButton.TextColor3 = Color3.fromRGB(255,255,255)
    RefreshButton.BackgroundColor3 = Color3.fromRGB(50,50,150)
    RefreshButton.Parent = Frame

    local ToggleESPButton = Instance.new("TextButton")
    ToggleESPButton.Size = UDim2.new(1,-20,0,30)
    ToggleESPButton.Position = UDim2.new(0,10,0,162)
    ToggleESPButton.Text = "Toggle ESP"
    ToggleESPButton.TextColor3 = Color3.fromRGB(255,255,255)
    ToggleESPButton.BackgroundColor3 = Color3.fromRGB(80,80,80)
    ToggleESPButton.Parent = Frame

    local DistanceBox = Instance.new("TextBox")
    DistanceBox.Size = UDim2.new(1,-20,0,30)
    DistanceBox.Position = UDim2.new(0,10,0,202)
    DistanceBox.PlaceholderText = "Max Distance (studs)"
    DistanceBox.Text = tostring(MAX_DISTANCE)
    DistanceBox.TextColor3 = Color3.fromRGB(255,255,255)
    DistanceBox.BackgroundColor3 = Color3.fromRGB(40,40,40)
    DistanceBox.Parent = Frame

    -- Button logic
    WLButton.MouseButton1Click:Connect(function()
        local name = InputBox.Text
        if name~="" then
            Whitelist[name]=true
            Blacklist[name]=nil
        end
    end)
    BLButton.MouseButton1Click:Connect(function()
        local name = InputBox.Text
        if name~="" then
            Blacklist[name]=true
            Whitelist[name]=nil
        end
    end)
    RefreshButton.MouseButton1Click:Connect(function()
        for player, _ in pairs(ESPObjects) do
            cleanupESPForPlayer(player)
            setupESP(player)
        end
    end)
    ToggleESPButton.MouseButton1Click:Connect(function()
        ESPEnabled = not ESPEnabled
    end)
    DistanceBox.FocusLost:Connect(function()
        local val = tonumber(DistanceBox.Text)
        if val and val>0 then MAX_DISTANCE=val
        else DistanceBox.Text=tostring(MAX_DISTANCE) end
    end)
end

CreateUI()
