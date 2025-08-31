-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Whitelist / Blacklist
local Whitelist = {}
local Blacklist = {}

-- Colors
local COLORS = {
    Enemy = Color3.fromRGB(255, 0, 0),
    Ally = Color3.fromRGB(0, 255, 0),
    Skeleton = Color3.fromRGB(255, 255, 255)
}

-- ESP container
local ESPObjects = {}

-- ===================== UI =====================
local function CreateUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ESPWhitelistUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 300, 0, 250)
    Frame.Position = UDim2.new(0.5, -150, 0.5, -125)
    Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    Frame.Active = true
    Frame.Draggable = true
    Frame.Parent = ScreenGui

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 30)
    Title.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    Title.Text = "ESP Whitelist / Blacklist"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Parent = Frame

    local InputBox = Instance.new("TextBox")
    InputBox.Size = UDim2.new(1, -20, 0, 30)
    InputBox.Position = UDim2.new(0, 10, 0, 40)
    InputBox.PlaceholderText = "Enter player name"
    InputBox.Text = ""
    InputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    InputBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    InputBox.Parent = Frame

    local WLButton = Instance.new("TextButton")
    WLButton.Size = UDim2.new(0.5, -15, 0, 30)
    WLButton.Position = UDim2.new(0, 10, 0, 80)
    WLButton.Text = "Whitelist"
    WLButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    WLButton.BackgroundColor3 = Color3.fromRGB(0, 128, 0)
    WLButton.Parent = Frame

    local BLButton = Instance.new("TextButton")
    BLButton.Size = UDim2.new(0.5, -15, 0, 30)
    BLButton.Position = UDim2.new(0.5, 5, 0, 80)
    BLButton.Text = "Blacklist"
    BLButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    BLButton.BackgroundColor3 = Color3.fromRGB(128, 0, 0)
    BLButton.Parent = Frame

    local RefreshButton = Instance.new("TextButton")
    RefreshButton.Size = UDim2.new(1, -20, 0, 30)
    RefreshButton.Position = UDim2.new(0, 10, 0, 120)
    RefreshButton.Text = "Refresh ESP"
    RefreshButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    RefreshButton.BackgroundColor3 = Color3.fromRGB(50, 50, 150)
    RefreshButton.Parent = Frame

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
        -- Remove all ESP
        for player, data in pairs(ESPObjects) do
            if data.Name then data.Name:Remove() end
            if data.Distance then data.Distance:Remove() end
            for _, line in pairs(data.Skeleton or {}) do
                line:Remove()
            end
        end
        ESPObjects = {}
        -- Recreate ESP for all players
        for _, p in ipairs(Players:GetPlayers()) do
            setupESP(p)
        end
    end)
end

CreateUI()

-- ===================== Drawing helpers =====================
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

-- ===================== Skeleton bones =====================
local R15Bones = {
    {"Head","UpperTorso"}, {"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"}, {"LeftUpperArm","LeftLowerArm"}, {"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"}, {"RightUpperArm","RightLowerArm"}, {"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"}, {"LeftUpperLeg","LeftLowerLeg"}, {"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"}, {"RightUpperLeg","RightLowerLeg"}, {"RightLowerLeg","RightFoot"}
}

-- ===================== ESP Setup =====================
function setupESP(player)
    if player == LocalPlayer then return end

    -- Connect to CharacterAdded every time
    player.CharacterAdded:Connect(function(char)
        -- Remove old ESP if it exists
        if ESPObjects[player] then
            local old = ESPObjects[player]
            if old.Name then old.Name:Remove() end
            if old.Distance then old.Distance:Remove() end
            for _, line in pairs(old.Skeleton or {}) do
                line:Remove()
            end
            ESPObjects[player] = nil
        end

        -- Create new ESP
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid then
            humanoid = char:WaitForChild("Humanoid", 5)
        end
        if not humanoid then return end

        local nameTag = createText(14)
        local distanceTag = createText(13)
        local skeleton = {}
        for _, pair in ipairs(R15Bones) do
            skeleton[pair[1].."_"..pair[2]] = createLine()
        end

        ESPObjects[player] = {Name=nameTag, Distance=distanceTag, Skeleton=skeleton, Character=char}

        humanoid.Died:Connect(function()
            if ESPObjects[player] then
                local old = ESPObjects[player]
                if old.Name then old.Name:Remove() end
                if old.Distance then old.Distance:Remove() end
                for _, line in pairs(old.Skeleton or {}) do
                    line:Remove()
                end
                ESPObjects[player] = nil
            end
        end)
    end)

    -- Also handle the current character if it exists
    if player.Character then
        player.CharacterAdded:Wait() -- ensure CharacterAdded fires
    end
end

-- Apply to all players
for _, p in ipairs(Players:GetPlayers()) do
    setupESP(p)
end

-- For new players joining
Players.PlayerAdded:Connect(setupESP)
Players.PlayerRemoving:Connect(function(player)
    if ESPObjects[player] then
        local old = ESPObjects[player]
        if old.Name then old.Name:Remove() end
        if old.Distance then old.Distance:Remove() end
        for _, line in pairs(old.Skeleton or {}) do
            line:Remove()
        end
        ESPObjects[player] = nil
    end
end)

-- ===================== ESP Update =====================
local MAX_DISTANCE = 250 -- studs

RunService.RenderStepped:Connect(function()
    local origin = Camera.CFrame.Position

    for player, data in pairs(ESPObjects) do
        local char = data.Character
        if not char or not char.Parent then
            -- Remove ESP if character is gone
            data.Name:Remove()
            data.Distance:Remove()
            for _, line in pairs(data.Skeleton) do
                line:Remove()
            end
            ESPObjects[player] = nil
            continue
        end

        local humanoid = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not (humanoid and hrp) then continue end

        -- Distance check
        local distance = (hrp.Position - origin).Magnitude
        if distance > MAX_DISTANCE then
            data.Name.Visible = false
            data.Distance.Visible = false
            for _, line in pairs(data.Skeleton) do
                line.Visible = false
            end
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
        for _, pair in ipairs(R15Bones) do
            local part1 = char:FindFirstChild(pair[1])
            local part2 = char:FindFirstChild(pair[2])
            local line = data.Skeleton[pair[1].."_"..pair[2]]
            if part1 and part2 then
                local p1, on1 = Camera:WorldToViewportPoint(part1.Position)
                local p2, on2 = Camera:WorldToViewportPoint(part2.Position)
                if on1 and on2 then
                    line.From = Vector2.new(p1.X, p1.Y)
                    line.To = Vector2.new(p2.X, p2.Y)
                    line.Visible = true
                    line.Color = COLORS.Skeleton
                else
                    line.Visible = false
                end
            else
                line.Visible = false
            end
        end

        -- Name & Distance
        local head = char:FindFirstChild("Head")
        if head then
            local headPos, onScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0,0.5,0))
            if onScreen then
                data.Name.Text = player.Name
                data.Name.Position = Vector2.new(headPos.X, headPos.Y - 20)
                data.Name.Color = color
                data.Name.Visible = true

                data.Distance.Text = math.floor(distance).." studs"
                data.Distance.Position = Vector2.new(headPos.X, headPos.Y - 5)
                data.Distance.Color = color
                data.Distance.Visible = true
            else
                data.Name.Visible = false
                data.Distance.Visible = false
            end
        end
    end
end)
