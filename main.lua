-- Improved ESP (LocalScript)
-- Put in StarterPlayerScripts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- CONFIG
local Config = {
    Enabled = true,
    ToggleKey = Enum.KeyCode.K,        -- toggle ESP on/off
    MaxDistance = 300,                 -- don't draw name/skeleton beyond this many studs (set nil for unlimited)
    NameColor = Color3.fromRGB(255,125,125),
    DistanceColor = Color3.fromRGB(153,153,153),
    SkeletonColor = Color3.new(1,1,1),
    SkeletonThickness = 1.5,
    HighlightOutlineColor = Color3.new(1, 0, 0),
    HighlightFillTransparency = 1,
    HighlightOutlineTransparency = 0,
    UseTeamFiltering = false,          -- if true, hides teammates (shows only enemies)
}

-- State tables
local ESP = {}            -- maps player -> data
local DrawingAvailable = false

-- Try to create a Drawing object once (detect availability)
pcall(function()
    local test = Drawing.new("Text")
    test.Visible = false
    test:Remove()
    DrawingAvailable = true
end)

-- Helper: create a Line drawing (if available)
local function createLine()
    if not DrawingAvailable then return nil end
    local ok, line = pcall(function()
        local l = Drawing.new("Line")
        l.Thickness = Config.SkeletonThickness
        l.Color = Config.SkeletonColor
        l.Visible = false
        return l
    end)
    if ok then return line end
    return nil
end

-- Helper: create Text drawing
local function createText(color, size)
    if not DrawingAvailable then return nil end
    local ok, txt = pcall(function()
        local t = Drawing.new("Text")
        t.Size = size or 14
        t.Center = true
        t.Outline = true
        t.Color = color
        t.Visible = false
        return t
    end)
    if ok then return txt end
    return nil
end

-- Build bone pairs based on rig type
local function getBonePairsForHumanoid(humanoid)
    local rig = humanoid and humanoid.RigType
    if rig == Enum.HumanoidRigType.R15 then
        return {
            {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
            {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
            {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
            {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
            {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
        }
    else
        -- R6
        return {
            {"Head", "Torso"},
            {"Torso", "Left Arm"}, {"Left Arm", "Left Leg"},
            {"Torso", "Right Arm"}, {"Right Arm", "Right Leg"},
        }
    end
end

-- Clean up function
local function removeESP(player)
    local data = ESP[player]
    if not data then return end

    if data.Highlight and data.Highlight.Parent then
        pcall(function() data.Highlight:Destroy() end)
    end

    if data.Name then
        pcall(function() data.Name:Remove() end)
    end

    if data.Distance then
        pcall(function() data.Distance:Remove() end)
    end

    for _, line in pairs(data.Skeleton or {}) do
        if line then
            pcall(function() line:Remove() end)
        end
    end

    -- disconnect connections
    if data.Connections then
        for _, c in pairs(data.Connections) do
            if c then pcall(function() c:Disconnect() end) end
        end
    end

    ESP[player] = nil
end

-- Build ESP visuals for a player's character (when character exists)
local function attachCharacterESP(player, character)
    -- guard
    if not player or not character then return end
    if player == LocalPlayer then return end

    removeESP(player) -- ensure no duplicates

    local data = {
        Player = player,
        Character = character,
        Connections = {},
        Skeleton = {},
        BonePairs = {},
    }

    -- Humanoid (may wait briefly)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        humanoid = character:WaitForChild("Humanoid", 5)
    end
    if not humanoid then
        -- couldn't get humanoid; still create highlight only
        humanoid = nil
    end

    -- Highlight (client-side) - safe parent to CoreGui
    local highlight
    pcall(function()
        highlight = Instance.new("Highlight")
        highlight.Adornee = character
        highlight.FillTransparency = Config.HighlightFillTransparency
        highlight.OutlineColor = Config.HighlightOutlineColor
        highlight.OutlineTransparency = Config.HighlightOutlineTransparency
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        -- Parent to CoreGui for client-only highlight
        highlight.Parent = game:GetService("CoreGui")
    end)
    data.Highlight = highlight

    -- Name and distance drawings (if drawing available)
    data.Name = createText(Config.NameColor, 14)
    data.Distance = createText(Config.DistanceColor, 13)

    -- Build bone pairs & lines
    local bonePairs = {}
    if humanoid then
        bonePairs = getBonePairsForHumanoid(humanoid)
    else
        -- Fallback: try R15-ish bone set (best effort)
        bonePairs = {
            {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
            {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
            {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
            {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
            {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
        }
    end
    data.BonePairs = bonePairs

    for _, pair in ipairs(bonePairs) do
        local id = table.concat(pair, "_")
        data.Skeleton[id] = createLine()
    end

    ESP[player] = data

    -- Connect CharacterRemoving to cleanup
    local removingConn = player.CharacterRemoving:Connect(function()
        removeESP(player)
    end)
    table.insert(data.Connections, removingConn)
end

-- Setup ESP for a player (when they join or already present)
local function setupESP(player)
    if player == LocalPlayer then return end

    -- If player already has character, attach immediately
    if player.Character then
        attachCharacterESP(player, player.Character)
    end

    -- Connect CharacterAdded
    local addedConn = player.CharacterAdded:Connect(function(char)
        attachCharacterESP(player, char)
    end)
    -- store connection to disconnect on removal
    if ESP[player] and ESP[player].Connections then
        table.insert(ESP[player].Connections, addedConn)
    else
        -- create a minimal holder so removal can disconnect this later
        ESP[player] = ESP[player] or {}
        ESP[player].Connections = ESP[player].Connections or {}
        table.insert(ESP[player].Connections, addedConn)
    end
end

-- Player removed: cleanup
Players.PlayerRemoving:Connect(function(player)
    removeESP(player)
end)

-- initialize for existing players
for _, p in ipairs(Players:GetPlayers()) do
    setupESP(p)
end

Players.PlayerAdded:Connect(setupESP)

-- Toggle handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Config.ToggleKey then
        Config.Enabled = not Config.Enabled
        -- hide all drawings/highlights when disabled
        if not Config.Enabled then
            for _, data in pairs(ESP) do
                if data.Name then pcall(function() data.Name.Visible = false end) end
                if data.Distance then pcall(function() data.Distance.Visible = false end) end
                for _, line in pairs(data.Skeleton or {}) do
                    if line then pcall(function() line.Visible = false end) end
                end
                if data.Highlight then pcall(function() data.Highlight.Enabled = false end) end
            end
        end
    end
end)

-- Per-frame render: project all needed part positions once, then draw lines/text
RunService.RenderStepped:Connect(function()
    if not Config.Enabled then return end
    if not Camera then Camera = workspace.CurrentCamera; if not Camera then return end end

    -- Precompute screen positions for each player's tracked parts (avoid multiple WorldToViewportPoint calls)
    for player, data in pairs(ESP) do
        local char = data.Character
        if not char or not player.Parent then
            removeESP(player)
        end
    end

    for player, data in pairs(ESP) do
        local char = data.Character
        if not char then
            -- nothing to draw
            goto continue_player
        end

        -- Team filtering
        if Config.UseTeamFiltering and LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team then
            -- hide teammate visuals
            if data.Name then pcall(function() data.Name.Visible = false end) end
            if data.Distance then pcall(function() data.Distance.Visible = false end) end
            for _, line in pairs(data.Skeleton or {}) do
                if line then pcall(function() line.Visible = false end) end
            end
            if data.Highlight then pcall(function() data.Highlight.Enabled = false end) end
            goto continue_player
        else
            if data.Highlight then pcall(function() data.Highlight.Enabled = true end) end
        end

        local head = char:FindFirstChild("Head")
        local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("HumanoidRoot") -- fallback
        if head and hrp then
            local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
            local dist = math.floor((Camera.CFrame.Position - hrp.Position).Magnitude)
            if onScreen and (not Config.MaxDistance or dist <= Config.MaxDistance) then
                if data.Name then
                    data.Name.Text = player.Name
                    data.Name.Position = Vector2.new(screenPos.X, screenPos.Y - 20)
                    data.Name.Visible = true
                end
                if data.Distance then
                    data.Distance.Text = tostring(dist) .. " studs"
                    data.Distance.Position = Vector2.new(screenPos.X, screenPos.Y - 5)
                    data.Distance.Visible = true
                end
            else
                if data.Name then pcall(function() data.Name.Visible = false end) end
                if data.Distance then pcall(function() data.Distance.Visible = false end) end
            end
        end

        -- Draw skeleton lines: compute each pair's projection once
        local projections = {} -- maps partName -> {pos=Vector2, onScreen=bool}
        for _, pair in ipairs(data.BonePairs or {}) do
            local partNameA, partNameB = pair[1], pair[2]
            local partA = char:FindFirstChild(partNameA)
            local partB = char:FindFirstChild(partNameB)
            local line = data.Skeleton and data.Skeleton[table.concat(pair, "_")]
            if partA and partB and line then
                -- project A
                local aProj = projections[partNameA]
                if not aProj then
                    local pA, onA = Camera:WorldToViewportPoint(partA.Position)
                    projections[partNameA] = {pos = Vector2.new(pA.X, pA.Y), on = onA}
                    aProj = projections[partNameA]
                end
                -- project B
                local bProj = projections[partNameB]
                if not bProj then
                    local pB, onB = Camera:WorldToViewportPoint(partB.Position)
                    projections[partNameB] = {pos = Vector2.new(pB.X, pB.Y), on = onB}
                    bProj = projections[partNameB]
                end

                if aProj.on and bProj.on and (not Config.MaxDistance or (hrp and (Camera.CFrame.Position - hrp.Position).Magnitude <= Config.MaxDistance)) then
                    -- draw
                    pcall(function()
                        line.From = aProj.pos
                        line.To = bProj.pos
                        line.Visible = true
                    end)
                else
                    pcall(function() line.Visible = false end)
                end
            else
                if line then pcall(function() line.Visible = false end) end
            end
        end

        ::continue_player::
    end
end)
