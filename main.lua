-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")

-- Settings
local ESPEnabled = true
local MAX_DISTANCE = 1000
local Whitelist = {}
local Blacklist = {}

local COLORS = {
    Enemy = Color3.fromRGB(255,0,0),
    Ally = Color3.fromRGB(0,255,0),
    Skeleton = Color3.fromRGB(255,255,255),
    Line = Color3.fromRGB(0,0,255)
}

local ESPObjects = {}

local R15Bones = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"}
}

local R6Bones = {
    {"Head","Torso"},
    {"Torso","Left Arm"},
    {"Torso","Right Arm"},
    {"Torso","Left Leg"},
    {"Torso","Right Leg"}
}

local UseDisplayNameForESP = false

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

-- Helper to safely cleanup an ESP entry
local function cleanupESPForPlayer(player)
    local data = ESPObjects[player]
    if not data then return end

    if data.Name then
        pcall(function() data.Name:Remove() end)
    end
    if data.Distance then
        pcall(function() data.Distance:Remove() end)
    end
    if data.Equipped then
        pcall(function() data.Equipped:Remove() end)
    end

    if data.EquippedConns then
        for _, conn in pairs(data.EquippedConns) do
            if conn and conn.Disconnect then
                pcall(function() conn:Disconnect() end)
            end
        end
    end

    if data.Skeleton then
        for _, line in pairs(data.Skeleton) do
            pcall(function() line:Remove() end)
        end
    end

    -- remove facing line if present
    if data.FacingLine then
        pcall(function() data.FacingLine:Remove() end)
    end

    ESPObjects[player] = nil
end

-- Helper functions for whitelist/blacklist matching (accept username OR displayname)
local function isWhitelisted(player)
    if not player then return false end
    local n = player.Name
    local d = player.DisplayName
    return (Whitelist[n] ~= nil) or (Whitelist[d] ~= nil)
end

local function isBlacklisted(player)
    if not player then return false end
    local n = player.Name
    local d = player.DisplayName
    return (Blacklist[n] ~= nil) or (Blacklist[d] ~= nil)
end

-- Helper to get the name shown on ESP depending on toggle
local function getESPName(player)
    if UseDisplayNameForESP then
        return (player.DisplayName ~= "" and player.DisplayName) or player.Name
    else
        return player.Name
    end
end

-- Setup ESP for a player
local function setupESP(player)
    if player == LocalPlayer then return end

    local function onCharacter(char)
        if ESPObjects[player] then
            cleanupESPForPlayer(player)
        end

        local humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid",5)
        if not humanoid then return end

        local nameTag = createText(14)
        local equippedTag = createText(12)
        local distanceTag = createText(13)
        local skeleton = {}

        local bonesTable = R15Bones
        if humanoid and humanoid.RigType == Enum.HumanoidRigType.R6 then
            bonesTable = R6Bones
        end

        for _, pair in ipairs(bonesTable) do
            skeleton[pair[1].."_"..pair[2]] = createLine()
        end

        -- create facing line (will use camera look vector when available)
        local facingLine = createLine()

        ESPObjects[player] = {
            Character = char,
            Name = nameTag,
            Equipped = equippedTag,
            Distance = distanceTag,
            Skeleton = skeleton,
            EquippedConns = {},
            Bones = bonesTable,
            FacingLine = facingLine
        }

        local data = ESPObjects[player]

        local function updateEquipped()
            if not ESPObjects[player] then return end
            local c = ESPObjects[player].Character
            if not c then return end
            local equippedTool = c:FindFirstChildOfClass("Tool")
            local equippedText = equippedTool and equippedTool.Name or "None"
            if ESPObjects[player] and ESPObjects[player].Equipped then
                ESPObjects[player].Equipped.Text = equippedText
            end
        end

        local connAdded = char.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                updateEquipped()
            end
        end)
        local connRemoved = char.ChildRemoved:Connect(function(child)
            if child:IsA("Tool") then
                pcall(updateEquipped)
            end
        end)

        table.insert(data.EquippedConns, connAdded)
        table.insert(data.EquippedConns, connRemoved)

        updateEquipped()

        humanoid.Died:Connect(function()
            cleanupESPForPlayer(player)
        end)
    end

    player.CharacterAdded:Connect(onCharacter)
    if player.Character then
        onCharacter(player.Character)
    end
end

-- Initialize ESP for all players
for _, p in ipairs(Players:GetPlayers()) do
    setupESP(p)
end
Players.PlayerAdded:Connect(setupESP)
Players.PlayerRemoving:Connect(function(player)
    cleanupESPForPlayer(player)
end)

-- ESP update (render loop)
RunService.RenderStepped:Connect(function()
    if not ESPEnabled then
        for _, data in pairs(ESPObjects) do
            if data.Name then data.Name.Visible = false end
            if data.Distance then data.Distance.Visible = false end
            if data.Equipped then data.Equipped.Visible = false end
            if data.Skeleton then
                for _, line in pairs(data.Skeleton) do
                    line.Visible = false
                end
            end
            if data.FacingLine then
                data.FacingLine.Visible = false
            end
        end
        return
    end

    local camPos = Camera.CFrame.Position
    for player, data in pairs(ESPObjects) do
        local char = data.Character
        if not char or not char.Parent then
            cleanupESPForPlayer(player)
            continue
        end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        if not (hrp and head) then continue end

        local distance = (hrp.Position - camPos).Magnitude
        if distance > MAX_DISTANCE then
            if data.Name then data.Name.Visible = false end
            if data.Distance then data.Distance.Visible = false end
            if data.Equipped then data.Equipped.Visible = false end
            for _, line in pairs(data.Skeleton) do line.Visible = false end
            if data.FacingLine then data.FacingLine.Visible = false end
            continue
        end

        local color = COLORS.Enemy
        if isWhitelisted(player) then
            color = COLORS.Ally
        elseif isBlacklisted(player) then
            color = COLORS.Enemy
        elseif LocalPlayer.Team and player.Team == LocalPlayer.Team then
            color = COLORS.Ally
        end

        for _, pair in ipairs(data.Bones or R15Bones) do
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
                if line then line.Visible = false end
            end
        end

        -- Facing line (prefer replicated camera look vector if present)
        if data.FacingLine then
            local headPos3 = head.Position + Vector3.new(0,0.5,0)

            -- Try to read a replicated Vector3Value named "CameraLookVector" under the character.
            -- If your game replicates each player's camera look direction into that value, it'll be used.
            -- Otherwise fall back to HumanoidRootPart.CFrame.LookVector, then Head.CFrame.LookVector.
            local lookVector
            local camLookValue = char:FindFirstChild("CameraLookVector")
            if camLookValue and camLookValue.Value and typeof(camLookValue.Value) == "Vector3" then
                if camLookValue.Value.Magnitude > 0 then
                    lookVector = camLookValue.Value.Unit
                end
            end

            if not lookVector then
                if hrp and hrp.CFrame then
                    lookVector = hrp.CFrame.LookVector
                end
            end

            if not lookVector then
                lookVector = head.CFrame.LookVector
            end

            -- final target 5 studs along chosen look vector
            local targetWorld = headPos3 + (lookVector * 5)

            local p_head, on_head = Camera:WorldToViewportPoint(headPos3)
            local p_target, on_target = Camera:WorldToViewportPoint(targetWorld)
            if on_head and on_target then
                data.FacingLine.From = Vector2.new(p_head.X, p_head.Y)
                data.FacingLine.To = Vector2.new(p_target.X, p_target.Y)
                data.FacingLine.Visible = true
                -- use team/enemy color to match name
                data.FacingLine.Color = color
            else
                data.FacingLine.Visible = false
            end
        end

        local headPos,onScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0,0.5,0))
        if onScreen then
            if data.Equipped then
                data.Equipped.Position = Vector2.new(headPos.X, headPos.Y - 32)
                data.Equipped.Color = Color3.fromRGB(180, 180, 180)
                data.Equipped.Visible = true
            end

            if data.Name then
                data.Name.Text = getESPName(player)
                data.Name.Position = Vector2.new(headPos.X, headPos.Y - 18)
                data.Name.Color = color
                data.Name.Visible = true
            end

            -- Distance
            if data.Distance then
                data.Distance.Text = math.floor(distance).." studs"
                data.Distance.Position = Vector2.new(headPos.X, headPos.Y - 5)
                data.Distance.Color = Color3.fromRGB(180, 180, 180)
                data.Distance.Visible = true
            end
        else
            if data.Name then data.Name.Visible = false end
            if data.Distance then data.Distance.Visible = false end
            if data.Equipped then data.Equipped.Visible = false end
        end
    end
end)

-- UI
local function CreateUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ESPWhitelistUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0,300,0,290)
    Frame.Position = UDim2.new(0.5,-150,0.5,-145)
    Frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
    Frame.Active = true
    Frame.Parent = ScreenGui

    local dragging = false
    local dragInput, mousePos, framePos
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
            Frame.Position = framePos + UDim2.new(0,delta.X,0,delta.Y)
        end
    end)

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1,0,0,30)
    Title.BackgroundColor3 = Color3.fromRGB(50,50,50)
    Title.Text = "ESP Whitelist / Blacklist"
    Title.TextColor3 = Color3.fromRGB(255,255,255)
    Title.Parent = Frame

    local InputBox = Instance.new("TextBox")
    InputBox.Size = UDim2.new(1,-20,0,30)
    InputBox.Position = UDim2.new(0,10,0,40)
    InputBox.PlaceholderText = "Enter player username or display name"
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

    local NameModeButton = Instance.new("TextButton")
    NameModeButton.Size = UDim2.new(1,-20,0,30)
    NameModeButton.Position = UDim2.new(0,10,0,200)
    NameModeButton.Text = UseDisplayNameForESP and "Name Mode: DisplayName" or "Name Mode: Username"
    NameModeButton.TextColor3 = Color3.fromRGB(255,255,255)
    NameModeButton.BackgroundColor3 = Color3.fromRGB(70,70,70)
    NameModeButton.Parent = Frame

    local DistanceBox = Instance.new("TextBox")
    DistanceBox.Size = UDim2.new(1,-20,0,30)
    DistanceBox.Position = UDim2.new(0,10,0,240)
    DistanceBox.PlaceholderText = "Max Distance (studs)"
    DistanceBox.Text = tostring(MAX_DISTANCE)
    DistanceBox.TextColor3 = Color3.fromRGB(255,255,255)
    DistanceBox.BackgroundColor3 = Color3.fromRGB(40,40,40)
    DistanceBox.Parent = Frame

    WLButton.MouseButton1Click:Connect(function()
        local name = tostring(InputBox.Text or ""):gsub("^%s*(.-)%s*$", "%1")
        if name ~= "" then
            Whitelist[name] = true
            Blacklist[name] = nil
        end
    end)

    BLButton.MouseButton1Click:Connect(function()
        local name = tostring(InputBox.Text or ""):gsub("^%s*(.-)%s*$", "%1")
        if name ~= "" then
            Blacklist[name] = true
            Whitelist[name] = nil
        end
    end)

    RefreshButton.MouseButton1Click:Connect(function()
        for player, data in pairs(ESPObjects) do
            cleanupESPForPlayer(player)
        end

        ESPObjects = {}

        for _, p in ipairs(Players:GetPlayers()) do
            setupESP(p)
        end
    end)

    ToggleESPButton.MouseButton1Click:Connect(function()
        ESPEnabled = not ESPEnabled
        ToggleESPButton.Text = ESPEnabled and "ESP: ON" or "ESP: OFF"
    end)

    NameModeButton.MouseButton1Click:Connect(function()
        UseDisplayNameForESP = not UseDisplayNameForESP
        NameModeButton.Text = UseDisplayNameForESP and "Name Mode: DisplayName" or "Name Mode: Username"
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
