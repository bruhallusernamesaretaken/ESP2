-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")

-- Settings
local ESPEnabled = true
local MAX_DISTANCE = 1000 -- default distance
local Whitelist = {}
local Blacklist = {}

local COLORS = {
    Enemy = Color3.fromRGB(255,0,0),
    Ally = Color3.fromRGB(0,255,0),
    Skeleton = Color3.fromRGB(255,255,255)
}

local ESPObjects = {}

local R15Bones = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"}
}

-- R6 bone pairs (note R6 part names include spaces)
local R6Bones = {
    {"Head","Torso"},
    {"Torso","Left Arm"},
    {"Torso","Right Arm"},
    {"Torso","Left Leg"},
    {"Torso","Right Leg"},
    -- optional cross connections for a clearer skeleton
    {"Left Arm","Left Leg"},
    {"Right Arm","Right Leg"}
}

-- Drawing helpers
local function createText(size)
    local text = Drawing.new("Text")
    text.Size = size
    text.Center = true
    text.Outline = true
    text.Visible = false -- start hidden until positioned
    return text
end

local function createLine()
    local line = Drawing.new("Line")
    line.Thickness = 2
    line.Color = COLORS.Skeleton
    line.Visible = false -- start hidden until we have valid endpoints
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
        for key, line in pairs(data.Skeleton) do
            if line then
                pcall(function() line:Remove() end)
            end
            data.Skeleton[key] = nil
        end
    end

    ESPObjects[player] = nil
end

-- Setup ESP for a player
local function setupESP(player)
    if player == LocalPlayer then return end

    local function onCharacter(char)
        -- Remove old ESP if present
        if ESPObjects[player] then
            cleanupESPForPlayer(player)
        end

        local humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid",5)
        if not humanoid then return end

        local nameTag = createText(14)
        local equippedTag = createText(12)           -- equipped text (always shows "None" when empty)
        local distanceTag = createText(13)

        -- choose bone set based on rig type (fallback to R15 if unknown)
        local bones = (humanoid.RigType == Enum.HumanoidRigType.R15) and R15Bones or R6Bones

        local skeleton = {}
        for _, pair in ipairs(bones) do
            skeleton[pair[1].."_"..pair[2]] = createLine()
        end

        -- store ESP data
        ESPObjects[player] = {
            Character = char,
            Name = nameTag,
            Equipped = equippedTag,
            Distance = distanceTag,
            Skeleton = skeleton,
            Bones = bones,
            EquippedConns = {}
        }

        local data = ESPObjects[player]

        -- Function to update equipped text (explicitly sets "None" when no tool)
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

        -- Connect to ChildAdded / ChildRemoved to update instantly on equip/unequip/switch
        local connAdded = char.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                pcall(updateEquipped)
            end
        end)
        local connRemoved = char.ChildRemoved:Connect(function(child)
            if child:IsA("Tool") then
                pcall(updateEquipped)
            end
        end)

        -- store connections for cleanup later
        table.insert(data.EquippedConns, connAdded)
        table.insert(data.EquippedConns, connRemoved)

        -- Ensure equipped text is set initially
        pcall(updateEquipped)

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
                    if line then line.Visible = false end
                end
            end
        end
        return
    end

    -- update camera reference (in case it changes)
    Camera = workspace.CurrentCamera
    local camPos = Camera and Camera.CFrame and Camera.CFrame.Position or Vector3.new()

    for player, data in pairs(ESPObjects) do
        -- Basic sanity checks
        if not data then
            ESPObjects[player] = nil
            goto continue_player
        end

        local char = data.Character
        if not char or not char.Parent then
            cleanupESPForPlayer(player)
            goto continue_player
        end

        -- HumanoidRootPart fallback: try HumanoidRootPart, Torso, UpperTorso
        local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        local head = char:FindFirstChild("Head")
        if not (hrp and head) then
            -- hide lines if important parts missing
            if data.Skeleton then
                for _, line in pairs(data.Skeleton) do
                    if line then line.Visible = false end
                end
            end
            if data.Name then data.Name.Visible = false end
            if data.Distance then data.Distance.Visible = false end
            if data.Equipped then data.Equipped.Visible = false end
            goto continue_player
        end

        local distance = (hrp.Position - camPos).Magnitude
        if distance > MAX_DISTANCE then
            if data.Name then data.Name.Visible = false end
            if data.Distance then data.Distance.Visible = false end
            if data.Equipped then data.Equipped.Visible = false end
            if data.Skeleton then
                for _, line in pairs(data.Skeleton) do
                    if line then line.Visible = false end
                end
            end
            goto continue_player
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

        -- Skeleton ESP (use the bone mapping chosen at setup)
        local bones = data.Bones or R15Bones
        for _, pair in ipairs(bones) do
            local part1 = char:FindFirstChild(pair[1])
            local part2 = char:FindFirstChild(pair[2])
            local key = pair[1] .. "_" .. pair[2]
            local line = data.Skeleton and data.Skeleton[key]

            -- if for some reason the line is missing (rare), recreate it
            if not line and data.Skeleton then
                line = createLine()
                data.Skeleton[key] = line
            end

            if part1 and part2 and line then
                local ok1, p1 = pcall(function() return Camera:WorldToViewportPoint(part1.Position) end)
                local ok2, p2 = pcall(function() return Camera:WorldToViewportPoint(part2.Position) end)
                if ok1 and ok2 and p1 and p2 then
                    local on1 = p1.Z > 0
                    local on2 = p2.Z > 0
                    if on1 and on2 then
                        pcall(function()
                            line.From = Vector2.new(p1.X, p1.Y)
                            line.To = Vector2.new(p2.X, p2.Y)
                            line.Color = COLORS.Skeleton
                            line.Visible = true
                        end)
                    else
                        line.Visible = false
                    end
                else
                    line.Visible = false
                end
            elseif line then
                line.Visible = false
            end
        end

        -- Name, equipped & distance positions
        local okHead, headPos = pcall(function() return Camera:WorldToViewportPoint(head.Position + Vector3.new(0,0.5,0)) end)
        if okHead and headPos and headPos.Z > 0 then
            local screenX, screenY = headPos.X, headPos.Y
            -- Equipped (positioned above name). Note: text content is updated via ChildAdded/Removed handlers.
            if data.Equipped then
                data.Equipped.Position = Vector2.new(screenX, screenY - 32)
                data.Equipped.Color = Color3.fromRGB(180, 180, 180)
                data.Equipped.Visible = true
            end

            -- Name
            if data.Name then
                data.Name.Text = player.Name
                data.Name.Position = Vector2.new(screenX, screenY - 18)
                data.Name.Color = color
                data.Name.Visible = true
            end

            -- Distance
            if data.Distance then
                data.Distance.Text = math.floor(distance).." studs"
                data.Distance.Position = Vector2.new(screenX, screenY - 5)
                data.Distance.Color = Color3.fromRGB(180, 180, 180)
                data.Distance.Visible = true
            end
        else
            if data.Name then data.Name.Visible = false end
            if data.Distance then data.Distance.Visible = false end
            if data.Equipped then data.Equipped.Visible = false end
        end

        ::continue_player::
    end
end)

-- UI (unchanged from your original, kept for convenience)
local function CreateUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ESPWhitelistUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0,300,0,250)
    Frame.Position = UDim2.new(0.5,-150,0.5,-125)
    Frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
    Frame.Active = true
    Frame.Parent = ScreenGui

    -- Draggable
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
    InputBox.PlaceholderText = "Enter player name"
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
        -- Remove all existing ESP drawings
        for player, data in pairs(ESPObjects) do
            cleanupESPForPlayer(player)
        end

        -- Clear ESPObjects completely
        ESPObjects = {}

        -- Recreate ESP for all players
        for _, p in ipairs(Players:GetPlayers()) do
            setupESP(p)
        end
    end)

    ToggleESPButton.MouseButton1Click:Connect(function()
        ESPEnabled = not ESPEnabled
        ToggleESPButton.Text = ESPEnabled and "ESP: ON" or "ESP: OFF"
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
