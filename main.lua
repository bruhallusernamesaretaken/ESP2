-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
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
    Skeleton = Color3.fromRGB(255, 255, 255),
    DistanceGray = Color3.fromRGB(180,180,180)
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
    local ok, text = pcall(function() return Drawing.new("Text") end)
    if not ok then return nil end
    text.Size = size
    text.Center = true
    text.Outline = true
    text.Visible = false
    return text
end

local function createLine()
    local ok, line = pcall(function() return Drawing.new("Line") end)
    if not ok then return nil end
    line.Thickness = 2
    line.Color = COLORS.Skeleton
    line.Visible = false
    return line
end

-- Helper: reliable equipped tool detection (checks character then backpack)
local function getEquippedToolName(player, char)
    if char and char.Parent then
        -- Prefer tool parented to character (equipped)
        local t = char:FindFirstChildWhichIsA and char:FindFirstChildWhichIsA("Tool", true)
        if t and t:IsA("Tool") then return t.Name end
        -- fallback to FindFirstChildOfClass
        local t2 = char:FindFirstChildOfClass("Tool")
        if t2 then return t2.Name end
    end

    -- check humanoid's child (some setups)
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local ht = humanoid:FindFirstChildOfClass("Tool")
            if ht then return ht.Name end
        end
    end

    -- finally check backpack (unequipped)
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        local btool = backpack:FindFirstChildWhichIsA and backpack:FindFirstChildWhichIsA("Tool", true)
        if btool and btool:IsA("Tool") then return btool.Name end
        local btool2 = backpack:FindFirstChildOfClass("Tool")
        if btool2 then return btool2.Name end
    end

    return "None"
end

-- ===================== ESP Setup =====================
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

local function setupESP(player)
    if player == LocalPlayer then return end

    local function onCharacterAdded(char)
        -- clean previous if any
        cleanupESPForPlayer(player)

        local humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
        if not humanoid then return end

        local nameTag = createText(14)
        local distanceTag = createText(13)
        local equippedTag = createText(13)

        -- select bones set
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

        -- ensure cleanup on death
        humanoid.Died:Connect(function()
            cleanupESPForPlayer(player)
        end)
    end

    player.CharacterAdded:Connect(onCharacterAdded)
    if player.Character then
        onCharacterAdded(player.Character)
    end
end

-- Initialize ESP for existing players and connect events
for _, p in ipairs(Players:GetPlayers()) do
    setupESP(p)
end
Players.PlayerAdded:Connect(setupESP)
Players.PlayerRemoving:Connect(function(player)
    cleanupESPForPlayer(player)
end)

-- ===================== ESP Update (per-frame, reliable tool detection) =====================
RunService.RenderStepped:Connect(function()
    local camPos = Camera.CFrame.Position

    for player, data in pairs(ESPObjects) do
        if not ESPEnabled then
            -- keep them hidden quickly
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
        if not (hrp and head and humanoid) then
            -- keep hidden until character fully loaded
            if data.Name then data.Name.Visible = false end
            if data.Distance then data.Distance.Visible = false end
            if data.Equipped then data.Equipped.Visible = false end
            for _, ln in pairs(data.Skeleton) do if ln then ln.Visible = false end end
            continue
        end

        local distance = (hrp.Position - camPos).Magnitude
        if MAX_DISTANCE and distance > MAX_DISTANCE then
            if data.Name then data.Name.Visible = false end
            if data.Distance then data.Distance.Visible = false end
            if data.Equipped then data.Equipped.Visible = false end
            for _, ln in pairs(data.Skeleton) do if ln then ln.Visible = false end end
            continue
        end

        -- color logic (whitelist overrides everything)
        local color = COLORS.Enemy
        if Whitelist[player.Name] then
            color = COLORS.Ally
        elseif Blacklist[player.Name] then
            color = COLORS.Enemy
        elseif LocalPlayer.Team and player.Team == LocalPlayer.Team then
            color = COLORS.Ally
        end

        -- skeleton (only show if both points are on screen)
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

        -- UI texts: only when head is on screen
        local headPos, onScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0,0.5,0))
        if onScreen then
            -- Name
            if data.Name then
                data.Name.Text = player.Name
                data.Name.Position = Vector2.new(headPos.X, headPos.Y - 28)
                data.Name.Color = color
                data.Name.Visible = true
            end

            -- Distance
            if data.Distance then
                data.Distance.Text = math.floor(distance).." studs"
                data.Distance.Position = Vector2.new(headPos.X, headPos.Y - 12)
                data.Distance.Color = COLORS.DistanceGray
                data.Distance.Visible = true
            end

            -- Equipped tool (recompute every frame for reliability)
            if data.Equipped then
                local toolName = getEquippedToolName(player, char) or "None"
                data.Equipped.Text = (toolName ~= "" and toolName or "None")
                data.Equipped.Position = Vector2.new(headPos.X, headPos.Y + 6)
                data.Equipped.Color = color
                data.Equipped.Visible = true
            end
        else
            if data.Name then data.Name.Visible = false end
            if data.Distance then data.Distance.Visible = false end
            if data.Equipped then data.Equipped.Visible = false end
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

    -- Whitelist / Blacklist buttons
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

    -- Refresh
    local RefreshButton = Instance.new("TextButton")
    RefreshButton.Size = UDim2.new(1,-20,0,30)
    RefreshButton.Position = UDim2.new(0,10,0,122)
    RefreshButton.Text = "Refresh ESP"
    RefreshButton.TextColor3 = Color3.fromRGB(255,255,255)
    RefreshButton.BackgroundColor3 = Color3.fromRGB(50,50,150)
    RefreshButton.Parent = Frame

    -- Toggle ESP
    local ToggleESP = Instance.new("TextButton")
    ToggleESP.Size = UDim2.new(1,-20,0,30)
    ToggleESP.Position = UDim2.new(0,10,0,162)
    ToggleESP.Text = "Toggle ESP (On)"
    ToggleESP.TextColor3 = Color3.fromRGB(255,255,255)
    ToggleESP.BackgroundColor3 = Color3.fromRGB(80,80,80)
    ToggleESP.Parent = Frame

    -- Max distance
    local DistanceLabel = Instance.new("TextLabel")
    DistanceLabel.Size = UDim2.new(1,-20,0,28)
    DistanceLabel.Position = UDim2.new(0,10,0,202)
    DistanceLabel.BackgroundColor3 = Color3.fromRGB(50,50,50)
    DistanceLabel.TextColor3 = Color3.fromRGB(255,255,255)
    DistanceLabel.Text = "Max Distance: "..MAX_DISTANCE
    DistanceLabel.TextScaled = true
    DistanceLabel.Parent = Frame

    local DistanceBox = Instance.new("TextBox")
    DistanceBox.Size = UDim2.new(1,-20,0,30)
    DistanceBox.Position = UDim2.new(0,10,0,232)
    DistanceBox.PlaceholderText = "Enter max distance (studs)"
    DistanceBox.Text = tostring(MAX_DISTANCE)
    DistanceBox.TextColor3 = Color3.fromRGB(255,255,255)
    DistanceBox.BackgroundColor3 = Color3.fromRGB(40,40,40)
    DistanceBox.ClearTextOnFocus = false
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
        -- fully remove existing drawings & clear table
        for player, data in pairs(ESPObjects) do
            cleanupESPForPlayer(player)
        end
        ESPObjects = {}
        -- recreate for all players
        for _, p in ipairs(Players:GetPlayers()) do
            setupESP(p)
        end
    end)
    ToggleESP.MouseButton1Click:Connect(function()
        ESPEnabled = not ESPEnabled
        ToggleESP.Text = ESPEnabled and "Toggle ESP (On)" or "Toggle ESP (Off)"
        if not ESPEnabled then
            for _, data in pairs(ESPObjects) do
                if data.Name then data.Name.Visible = false end
                if data.Distance then data.Distance.Visible = false end
                if data.Equipped then data.Equipped.Visible = false end
                for _, ln in pairs(data.Skeleton or {}) do
                    if ln then ln.Visible = false end
                end
            end
        end
    end)
    DistanceBox.FocusLost:Connect(function()
        local value = tonumber(DistanceBox.Text)
        if value and value > 0 then
            MAX_DISTANCE = value
            DistanceLabel.Text = "Max Distance: "..MAX_DISTANCE
        else
            DistanceBox.Text = tostring(MAX_DISTANCE)
        end
    end)
end

CreateUI()