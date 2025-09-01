-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")

-- Settings
local MAX_DISTANCE = 1000
local ESPEnabled = true
local Whitelist = {}
local Blacklist = {}

local COLORS = {
    Enemy = Color3.fromRGB(255,0,0),
    Ally = Color3.fromRGB(0,255,0),
    Skeleton = Color3.fromRGB(255,255,255)
}

local ESPObjects = {}

-- Bones
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

-- Drawing helpers
local function createText(size)
    local t = Drawing.new("Text")
    t.Size = size
    t.Center = true
    t.Outline = true
    t.Visible = true
    return t
end

local function createLine()
    local l = Drawing.new("Line")
    l.Thickness = 2
    l.Color = COLORS.Skeleton
    l.Visible = true
    return l
end

-- Setup ESP
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

        local bones = (humanoid.RigType == Enum.HumanoidRigType.R15) and R15Bones or R6Bones

        local skeleton = {}
        for _, pair in ipairs(bones) do
            skeleton[pair[1].."_"..pair[2]] = createLine()
        end

        local nameTag = createText(14)
        local distanceTag = createText(13)
        local equippedTag = createText(13)

        ESPObjects[player] = {
            Character=char,
            Skeleton=skeleton,
            Name=nameTag,
            Distance=distanceTag,
            Equipped=equippedTag,
            Bones=bones
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

-- Initialize ESP
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

-- ESP Update
RunService.RenderStepped:Connect(function()
    if not ESPEnabled then return end
    local camPos = Camera.CFrame.Position
    for player, data in pairs(ESPObjects) do
        local char = data.Character
        if not char or not char.Parent then
            if data.Name then data.Name:Remove() end
            if data.Distance then data.Distance:Remove() end
            if data.Equipped then data.Equipped:Remove() end
            for _, line in pairs(data.Skeleton or {}) do line:Remove() end
            ESPObjects[player] = nil
            continue
        end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        if not (hrp and head) then continue end

        local distance = (hrp.Position - camPos).Magnitude
        if MAX_DISTANCE and distance > MAX_DISTANCE then
            data.Name.Visible = false
            data.Distance.Visible = false
            data.Equipped.Visible = false
            for _, line in pairs(data.Skeleton) do line.Visible = false end
            continue
        end

        local color = COLORS.Enemy
        if Whitelist[player.Name] then
            color = COLORS.Ally
        elseif Blacklist[player.Name] then
            color = COLORS.Enemy
        elseif LocalPlayer.Team and player.Team == LocalPlayer.Team then
            color = COLORS.Ally
        end

        -- Skeleton
        for _, pair in ipairs(data.Bones) do
            local part1 = char:FindFirstChild(pair[1])
            local part2 = char:FindFirstChild(pair[2])
            local line = data.Skeleton[pair[1].."_"..pair[2]]
            if part1 and part2 then
                local p1,on1 = Camera:WorldToViewportPoint(part1.Position)
                local p2,on2 = Camera:WorldToViewportPoint(part2.Position)
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
            data.Name.Position = Vector2.new(headPos.X, headPos.Y-30)
            data.Name.Color = color
            data.Name.Visible = true

            data.Distance.Text = math.floor(distance).." studs"
            data.Distance.Position = Vector2.new(headPos.X, headPos.Y-15)
            data.Distance.Color = color
            data.Distance.Visible = true

            -- Equipped tool
            local toolName = ""
            for _, tool in ipairs(char:GetChildren()) do
                if tool:IsA("Tool") then
                    toolName = tool.Name
                    break
                end
            end
            data.Equipped.Text = "Holding: "..(toolName ~= "" and toolName or "None")
            data.Equipped.Position = Vector2.new(headPos.X, headPos.Y+5)
            data.Equipped.Color = color
            data.Equipped.Visible = true
        else
            data.Name.Visible = false
            data.Distance.Visible = false
            data.Equipped.Visible = false
        end
    end
end)

-- UI
local function CreateUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ESP_UI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 300, 0, 300)
    Frame.Position = UDim2.new(0.5, -150, 0.5, -150)
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

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1,0,0,30)
    Title.Position = UDim2.new(0,0,0,0)
    Title.BackgroundColor3 = Color3.fromRGB(50,50,50)
    Title.Text = "ESP Control"
    Title.TextColor3 = Color3.fromRGB(255,255,255)
    Title.Parent = Frame

    local InputBox = Instance.new("TextBox")
    InputBox.Size = UDim2.new(1,-20,0,30)
    InputBox.Position = UDim2.new(0,10,0,40)
    InputBox.PlaceholderText = "Player Name"
    InputBox.TextColor3 = Color3.fromRGB(255,255,255)
    InputBox.BackgroundColor3 = Color3.fromRGB(40,40,40)
    InputBox.Parent = Frame

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

    local ToggleESPButton = Instance.new("TextButton")
    ToggleESPButton.Size = UDim2.new(1,-20,0,30)
    ToggleESPButton.Position = UDim2.new(0,10,0,160)
    ToggleESPButton.Text = "Toggle ESP"
    ToggleESPButton.TextColor3 = Color3.fromRGB(255,255,255)
    ToggleESPButton.BackgroundColor3 = Color3.fromRGB(80,80,80)
    ToggleESPButton.Parent = Frame

    -- Button Logic
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
        -- Remove all ESP
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

    ToggleESPButton.MouseButton1Click:Connect(function()
        ESPEnabled = not ESPEnabled
        if not ESPEnabled then
            -- hide all ESP
            for _, data in pairs(ESPObjects) do
                if data.Name then data.Name.Visible = false end
                if data.Distance then data.Distance.Visible = false end
                if data.Equipped then data.Equipped.Visible = false end
                for _, line in pairs(data.Skeleton or {}) do line.Visible = false end
            end
        end
    end)
end

CreateUI()
