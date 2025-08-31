-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Whitelist & Blacklist
local Whitelist = {}
local Blacklist = {}

-- Colors
local COLORS = {
    Enemy = Color3.fromRGB(255, 0, 0),
    Ally = Color3.fromRGB(0, 255, 0),
    Skeleton = Color3.fromRGB(255, 255, 255),
    Text = Color3.fromRGB(255,255,255)
}

-- ESP container
local ESPObjects = {}

-- Create UI
local function CreateUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ESPWhitelistUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 250, 0, 200)
    Frame.Position = UDim2.new(0.5, -125, 0.5, -100)
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
            if Whitelist[name] then
                Whitelist[name] = nil
            else
                Blacklist[name] = true
            end
        end
    end)
end

CreateUI()

-- Helper: Create Drawing objects
local function createLine()
    local line = Drawing.new("Line")
    line.Color = COLORS.Skeleton
    line.Thickness = 2
    line.Visible = false
    return line
end

local function createBox()
    local box = Drawing.new("Square")
    box.Thickness = 2
    box.Filled = false
    box.Visible = false
    return box
end

local function createText(size)
    local text = Drawing.new("Text")
    text.Text = ""
    text.Size = size
    text.Center = true
    text.Outline = true
    text.Color = COLORS.Text
    text.Visible = false
    return text
end

-- Bone pairs for skeleton
local R15Bones = {
    {"Head","UpperTorso"}, {"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"}, {"LeftUpperArm","LeftLowerArm"}, {"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"}, {"RightUpperArm","RightLowerArm"}, {"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"}, {"LeftUpperLeg","LeftLowerLeg"}, {"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"}, {"RightUpperLeg","RightLowerLeg"}, {"RightLowerLeg","RightFoot"}
}

-- Setup ESP for a player
local function setupESP(player)
    if player == LocalPlayer then return end

    local function onChar(char)
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end

        local box = createBox()
        local nameTag = createText(14)
        local distanceTag = createText(13)

        local skeleton = {}
        for _, pair in ipairs(R15Bones) do
            skeleton[pair[1].."_"..pair[2]] = createLine()
        end

        ESPObjects[player] = {Box=box, Skeleton=skeleton, Character=char, Name=nameTag, Distance=distanceTag}

        -- Remove ESP on death
        humanoid.Died:Connect(function()
            box:Remove()
            nameTag:Remove()
            distanceTag:Remove()
            for _, line in pairs(skeleton) do
                line:Remove()
            end
            ESPObjects[player] = nil
        end)
    end

    if player.Character then
        onChar(player.Character)
    end
    player.CharacterAdded:Connect(onChar)
end

-- Add ESP for all players
for _, p in ipairs(Players:GetPlayers()) do
    setupESP(p)
end
Players.PlayerAdded:Connect(setupESP)

-- Update ESP each frame
RunService.RenderStepped:Connect(function()
    for player, data in pairs(ESPObjects) do
        local char = data.Character
        if not char then continue end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not (humanoid and hrp) then continue end

        -- Box ESP scaling
        local topPos = hrp.Position + Vector3.new(0, humanoid.HipHeight+2,0)
        local bottomPos = hrp.Position - Vector3.new(0,2,0)
        local top, on1 = Camera:WorldToViewportPoint(topPos)
        local bottom, on2 = Camera:WorldToViewportPoint(bottomPos)
        local box = data.Box
        local nameTag = data.Name
        local distanceTag = data.Distance

        if on1 and on2 then
            local height = math.abs(top.Y - bottom.Y)
            local width = height/2
            box.Size = Vector2.new(width,height)
            box.Position = Vector2.new(top.X-width/2, top.Y)

            -- Name & distance
            nameTag.Text = player.Name
            nameTag.Position = Vector2.new(top.X, top.Y-20)
            nameTag.Visible = true

            local dist = math.floor((Camera.CFrame.Position - hrp.Position).Magnitude)
            distanceTag.Text = dist.." studs"
            distanceTag.Position = Vector2.new(top.X, top.Y-5)
            distanceTag.Visible = true

            -- Color logic
            local color = COLORS.Enemy
            if Whitelist[player.Name] then
                color = COLORS.Ally
            elseif Blacklist[player.Name] then
                color = COLORS.Enemy
            elseif LocalPlayer.Team and player.Team == LocalPlayer.Team then
                color = COLORS.Ally
            end
            box.Color = color
        else
            box.Visible = false
            nameTag.Visible = false
            distanceTag.Visible = false
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
                    line.From = Vector2.new(p1.X,p1.Y)
                    line.To = Vector2.new(p2.X,p2.Y)
                    line.Visible = true
                else
                    line.Visible = false
                end
            else
                line.Visible = false
            end
        end
    end
end)
