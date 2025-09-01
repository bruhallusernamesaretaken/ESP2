-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character
local Camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")

-- Settings
local MAX_DISTANCE = 1000
local Whitelist = {}
local Blacklist = {}
local ESPEnabled = true

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

local R6Bones = {
    {"Head","Torso"},
    {"Torso","Left Arm"},{"Left Arm","Left Leg"},
    {"Torso","Right Arm"},{"Right Arm","Right Leg"}
}

-- ===================== Drawing Helpers =====================
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

-- Helper to get equipped tool name (reliable)
local function updateTool()
    local tool = nil
    if Character then
        tool = Character:FindFirstChildOfClass("Tool")
    end
    if not tool then
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            tool = backpack:FindFirstChildOfClass("Tool")
        end
    end
    data.Equipped.Text = (tool and tool.Name or "None")
end

-- Connect signals so the text updates LIVE
Character.ChildAdded:Connect(function(obj)
    if obj:IsA("Tool") then
        updateTool()
    end
end)

Character.ChildRemoved:Connect(function(obj)
    if obj:IsA("Tool") then
        updateTool()
    end
end)

local backpack = player:FindFirstChild("Backpack")
if backpack then
    backpack.ChildAdded:Connect(function(obj)
        if obj:IsA("Tool") then
            updateTool()
        end
    end)
    backpack.ChildRemoved:Connect(function(obj)
        if obj:IsA("Tool") then
            updateTool()
        end
    end)
end

-- Run once immediately
updateTool()

-- ===================== ESP Setup =====================
local function setupESP(player)
    if player == LocalPlayer then return end

    local function onCharacter(char)
        if ESPObjects[player] then
            local old = ESPObjects[player]
            if old.Name then old.Name:Remove() end
            if old.Distance then old.Distance:Remove() end
            if old.Equipped then old.Equipped:Remove() end
            for _, line in pairs(old.Skeleton or {}) do line:Remove() end
            ESPObjects[player] = nil
        end

        local humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid",5)
        if not humanoid then return end

        local nameTag = createText(14)
        local distanceTag = createText(13)
        local equippedTag = createText(13)

        -- Determine which bones to use
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
            if ESPObjects[player] then
                local old = ESPObjects[player]
                if old.Name then old.Name:Remove() end
                if old.Distance then old.Distance:Remove() end
                if old.Equipped then old.Equipped:Remove() end
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
        if old.Equipped then old.Equipped:Remove() end
        for _, line in pairs(old.Skeleton or {}) do line:Remove() end
        ESPObjects[player] = nil
    end
end)

-- ===================== ESP Update =====================
RunService.RenderStepped:Connect(function()
    if not ESPEnabled then return end
    local camPos = Camera.CFrame.Position

    for player, data in pairs(ESPObjects) do
        local char = data.Character
        if not char or not char.Parent then
            if data.Name then data.Name:Remove() end
            if data.Distance then data.Distance:Remove() end
            if data.Equipped then data.Equipped:Remove() end
            for _, line in pairs(data.Skeleton) do line:Remove() end
            ESPObjects[player] = nil
            continue
        end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not (hrp and head and humanoid) then continue end

        local distance = (hrp.Position - camPos).Magnitude
        if distance > MAX_DISTANCE then
            data.Name.Visible = false
            data.Distance.Visible = false
            data.Equipped.Visible = false
            for _, line in pairs(data.Skeleton) do line.Visible = false end
            continue
        end

        -- Determine color
        local color = COLORS.Enemy
        if Whitelist[player.Name] then
            color = COLORS.Ally
        elseif Blacklist[player.Name] then
            color = COLORS.Enemy
        elseif LocalPlayer.Team and player.Team == LocalPlayer.Team then
            color = COLORS.Ally
        end

        -- Skeleton ESP
        for _, pair in ipairs(data.BonePairs) do
            local part1 = char:FindFirstChild(pair[1])
            local part2 = char:FindFirstChild(pair[2])
            local line = data.Skeleton[pair[1].."_"..pair[2]]
            if part1 and part2 then
                local p1, on1 = Camera:WorldToViewportPoint(part1.Position)
                local p2, on2 = Camera:WorldToViewportPoint(part2.Position)
                if on1 and on2 then
                    line.From = Vector2.new(p1.X,p1.Y)
                    line.To = Vector2.new(p2.X,p2.Y)
                    line.Visible = true
                    line.Color = COLORS.Skeleton
                else
                    line.Visible = false
                end
            else
                line.Visible = false
            end
        end

        -- Name & distance
        local headPos,onScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0,0.5,0))
        if onScreen then
            data.Name.Text = player.Name
            data.Name.Position = Vector2.new(headPos.X, headPos.Y-20)
            data.Name.Color = color
            data.Name.Visible = true

            data.Distance.Text = math.floor(distance).." studs"
            data.Distance.Position = Vector2.new(headPos.X, headPos.Y-5)
            data.Distance.Color = Color3.fromRGB(180, 180, 180)
            data.Distance.Visible = true

            -- Equipped tool
            data.Equipped.Position = Vector2.new(headPos.X, headPos.Y + 10)
            data.Equipped.Color = Color3.fromRGB(180, 180, 180)
            data.Equipped.Visible = true
        else
            data.Name.Visible = false
            data.Distance.Visible = false
            data.Equipped.Visible = false
        end
    end
end)

-- ===================== UI =====================
local function CreateUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ESPWhitelistUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 300, 0, 330)
    Frame.Position = UDim2.new(0.5, -150, 0.5, -165)
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
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    Frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - mousePos
            Frame.Position = framePos + UDim2.new(0, delta.X, 0, delta.Y)
        end
    end)

    -- Title
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1,0,0,30)
    Title.BackgroundColor3 = Color3.fromRGB(50,50,50)
    Title.Text = "ESP Whitelist / Blacklist"
    Title.TextColor3 = Color3.fromRGB(255,255,255)
    Title.Parent = Frame

    -- Input
    local InputBox = Instance.new("TextBox")
    InputBox.Size = UDim2.new(1,-20,0,30)
    InputBox.Position = UDim2.new(0,10,0,40)
    InputBox.PlaceholderText = "Enter player name"
    InputBox.TextColor3 = Color3.fromRGB(255,255,255)
    InputBox.BackgroundColor3 = Color3.fromRGB(40,40,40)
    InputBox.ClearTextOnFocus = false
    InputBox.Parent = Frame

    -- Buttons
    local WLButton = Instance.new("TextButton")
    WLButton.Size = UDim2.new(0.5,-15,0,30)
    WLButton.Position = UDim2.new(0,10,0,80)
    WLButton.Text = "Whitelist"
    WLButton.TextColor3 = Color3.fromRGB(255,255,255)
    WLButton.BackgroundColor3 = Color3.fromRGB(0,128,0)
    WLButton.Parent = Frame

    local BLButton = Instance.new("TextButton")
    BLButton.Size = UDim2.new(0.5,-15,0,30)
    BLButton.Position = UDim2.new(0.5,5,0,80)
    BLButton.Text = "Blacklist"
    BLButton.TextColor3 = Color3.fromRGB(255,255,255)
    BLButton.BackgroundColor3 = Color3.fromRGB(128,0,0)
    BLButton.Parent = Frame

    local RefreshButton = Instance.new("TextButton")
    RefreshButton.Size = UDim2.new(1,-20,0,30)
    RefreshButton.Position = UDim2.new(0,10,0,120)
    RefreshButton.Text = "Refresh ESP"
    RefreshButton.TextColor3 = Color3.fromRGB(255,255,255)
    RefreshButton.BackgroundColor3 = Color3.fromRGB(50,50,150)
    RefreshButton.Parent = Frame

    local ToggleESP = Instance.new("TextButton")
    ToggleESP.Size = UDim2.new(1,-20,0,30)
    ToggleESP.Position = UDim2.new(0,10,0,160)
    ToggleESP.Text = "Toggle ESP"
    ToggleESP.TextColor3 = Color3.fromRGB(255,255,255)
    ToggleESP.BackgroundColor3 = Color3.fromRGB(80,80,80)
    ToggleESP.Parent = Frame

    -- Max distance
    local DistanceBox = Instance.new("TextBox")
    DistanceBox.Size = UDim2.new(1,-20,0,30)
    DistanceBox.Position = UDim2.new(0,10,0,200)
    DistanceBox.PlaceholderText = "Max Distance (studs)"
    DistanceBox.Text = tostring(MAX_DISTANCE)
    DistanceBox.TextColor3 = Color3.fromRGB(255,255,255)
    DistanceBox.BackgroundColor3 = Color3.fromRGB(40,40,40)
    DistanceBox.Parent = Frame

    -- Button logic
    WLButton.MouseButton1Click:Connect(function()
        local name = InputBox.Text
        if name ~= "" then
            Whitelist[name] = true
            Blacklist[name] = nil
        end
    end)
    BLButton.MouseButton1Click:Connect(function()
        local name = InputBox.Text
        if name ~= "" then
            Blacklist[name] = true
            Whitelist[name] = nil
        end
    end)
    RefreshButton.MouseButton1Click:Connect(function()
        for player, data in pairs(ESPObjects) do
            if data.Name then data.Name:Remove() end
            if data.Distance then data.Distance:Remove() end
            if data.Equipped then data.Equipped:Remove() end
            for _, line in pairs(data.Skeleton or {}) do line:Remove() end
        end
        ESPObjects = {}
        for _, p in ipairs(Players:GetPlayers()) do
            setupESP(p)
        end
    end)
    ToggleESP.MouseButton1Click:Connect(function()
        ESPEnabled = not ESPEnabled
        if not ESPEnabled then
            for _, data in pairs(ESPObjects) do
                if data.Name then data.Name.Visible = false end
                if data.Distance then data.Distance.Visible = false end
                if data.Equipped then data.Equipped.Visible = false end
                for _, line in pairs(data.Skeleton or {}) do line.Visible = false end
            end
        end
    end)
    DistanceBox.FocusLost:Connect(function(enterPressed)
        local value = tonumber(DistanceBox.Text)
        if value and value > 0 then
            MAX_DISTANCE = value
        else
            DistanceBox.Text = tostring(MAX_DISTANCE)
        end
    end)
end

CreateUI()