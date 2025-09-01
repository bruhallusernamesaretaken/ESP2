-- Drawing-only ESP with robust equipped-tool tracking
-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")

-- Settings
local MAX_DISTANCE = 250
local Whitelist = {}
local Blacklist = {}
local ESPEnabled = true

local COLORS = {
    Enemy = Color3.fromRGB(255, 0, 0),
    Ally = Color3.fromRGB(0, 255, 0),
    Skeleton = Color3.fromRGB(255, 255, 255),
    TextGray = Color3.fromRGB(180,180,180)
}

-- Storage
local ESPObjects = {}
local ESPConns = {} -- per-player: { charConn, diedConn, charChildAdded, charChildRemoved, backpackAdded, backpackRemoved, toolConns = {tool = {eq,uneq,anc}} }

-- Bone sets
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

-- Safe Drawing creators
local function createText(size)
    local ok, obj = pcall(function() return Drawing.new("Text") end)
    if not ok or not obj then return nil end
    obj.Size = size
    obj.Center = true
    obj.Outline = true
    obj.Visible = false
    return obj
end

local function createLine()
    local ok, obj = pcall(function() return Drawing.new("Line") end)
    if not ok or not obj then return nil end
    obj.Thickness = 2
    obj.Color = COLORS.Skeleton
    obj.Visible = false
    return obj
end

local function safeRemove(obj)
    if not obj then return end
    pcall(function() obj:Remove() end)
end

-- Reliable tool name detection (character first, then humanoid child, then backpack)
local function getEquippedToolName(player, char)
    if char and char.Parent then
        local ok1, t1 = pcall(function() return char:FindFirstChildWhichIsA("Tool", true) end)
        if ok1 and t1 and t1:IsA("Tool") then return t1.Name end
        local ok2, t2 = pcall(function() return char:FindFirstChildOfClass("Tool") end)
        if ok2 and t2 then return t2.Name end
    end

    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local ok3, ht = pcall(function() return humanoid:FindFirstChildOfClass("Tool") end)
            if ok3 and ht then return ht.Name end
        end
    end

    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        local ok4, bt = pcall(function() return backpack:FindFirstChildWhichIsA("Tool", true) end)
        if ok4 and bt and bt:IsA("Tool") then return bt.Name end
        local ok5, bt2 = pcall(function() return backpack:FindFirstChildOfClass("Tool") end)
        if ok5 and bt2 then return bt2.Name end
    end

    return "None"
end

-- Connect Tool events for instant update, store conns in ESPConns[player].toolConns[tool] = {eq,uneq,anc}
local function monitorTool(player, tool, data)
    if not tool or not tool:IsA("Tool") then return nil end
    ESPConns[player] = ESPConns[player] or {}
    ESPConns[player].toolConns = ESPConns[player].toolConns or {}

    -- avoid double-monitoring
    if ESPConns[player].toolConns[tool] then return end

    local conns = {}

    -- Equipped event (may not fire for other players on some setups, but if it does, update instantly)
    conns.eq = tool.Equipped:Connect(function()
        local d = ESPObjects[player]
        if d and d.Equipped then
            d.Equipped.Text = "Holding: " .. (tool.Name or "None")
        end
    end)

    -- Unequipped event
    conns.uneq = tool.Unequipped:Connect(function()
        local d = ESPObjects[player]
        if d and d.Equipped then
            -- per-frame will fix if tool moved; but set None immediately
            d.Equipped.Text = "Holding: None"
        end
    end)

    -- AncestryChanged: detect parent change (backpack <-> character)
    conns.anc = tool.AncestryChanged:Connect(function(child, parent)
        local d = ESPObjects[player]
        if d and d.Equipped then
            -- recompute immediately from current locations
            local name = getEquippedToolName(player, d.Character) or "None"
            d.Equipped.Text = "Holding: " .. (name ~= "" and name or "None")
        end
    end)

    ESPConns[player].toolConns[tool] = conns
end

local function disconnectToolMonitors(player)
    local tconns = ESPConns[player] and ESPConns[player].toolConns
    if not tconns then return end
    for tool, conns in pairs(tconns) do
        if conns then
            pcall(function() if conns.eq and conns.eq.Disconnect then conns.eq:Disconnect() end end)
            pcall(function() if conns.uneq and conns.uneq.Disconnect then conns.uneq:Disconnect() end end)
            pcall(function() if conns.anc and conns.anc.Disconnect then conns.anc:Disconnect() end end)
        end
    end
    ESPConns[player].toolConns = nil
end

-- Cleanup per player: drawings + disconnects + tool monitors
local function cleanupESPForPlayer(player)
    local old = ESPObjects[player]
    if old then
        safeRemove(old.Name)
        safeRemove(old.Distance)
        safeRemove(old.Equipped)
        for _, ln in pairs(old.Skeleton or {}) do safeRemove(ln) end
        ESPObjects[player] = nil
    end

    local c = ESPConns[player]
    if c then
        -- disconnect stored conns
        if c.charConn and type(c.charConn.Disconnect) == "function" then pcall(function() c.charConn:Disconnect() end) end
        if c.diedConn and type(c.diedConn.Disconnect) == "function" then pcall(function() c.diedConn:Disconnect() end) end
        if c.charChildAdded and type(c.charChildAdded.Disconnect) == "function" then pcall(function() c.charChildAdded:Disconnect() end) end
        if c.charChildRemoved and type(c.charChildRemoved.Disconnect) == "function" then pcall(function() c.charChildRemoved:Disconnect() end) end
        if c.backpackAdded and type(c.backpackAdded.Disconnect) == "function" then pcall(function() c.backpackAdded:Disconnect() end) end
        if c.backpackRemoved and type(c.backpackRemoved.Disconnect) == "function" then pcall(function() c.backpackRemoved:Disconnect() end) end
        -- disconnect any tool monitors
        disconnectToolMonitors(player)
        ESPConns[player] = nil
    end
end

-- Setup ESP for a player (handles character added)
local function setupESP(player)
    if not player or player == LocalPlayer then return end

    -- disconnect existing charConn if present (prevents duplicates)
    if ESPConns[player] and ESPConns[player].charConn then
        pcall(function() ESPConns[player].charConn:Disconnect() end)
        ESPConns[player] = nil
    end
    ESPConns[player] = {}

    local function onCharacterAdded(char)
        -- Clean previous data (drawings + conns)
        cleanupESPForPlayer(player)

        if not char or not char.Parent then return end
        local humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
        if not humanoid then return end

        -- create drawings
        local nameTag = createText(14)
        local distTag = createText(13)
        local equippedTag = createText(13)

        local bonePairs = (humanoid.RigType == Enum.HumanoidRigType.R15) and R15Bones or R6Bones
        local skeleton = {}
        for _, pair in ipairs(bonePairs) do
            skeleton[pair[1].."_"..pair[2]] = createLine()
        end

        ESPObjects[player] = {
            Character = char,
            Name = nameTag,
            Distance = distTag,
            Equipped = equippedTag,
            Skeleton = skeleton,
            BonePairs = bonePairs
        }

        -- died connection
        local diedConn = humanoid.Died:Connect(function()
            cleanupESPForPlayer(player)
        end)

        -- child added/removed on character to update equipped immediately & monitor tools when they appear in char
        local charChildAdded = char.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                -- immediate visible update
                local data = ESPObjects[player]
                if data and data.Equipped then data.Equipped.Text = "Holding: " .. (child.Name or "None") end
                -- monitor this tool
                monitorTool(player, child, data)
            end
        end)
        local charChildRemoved = char.ChildRemoved:Connect(function(child)
            if child:IsA("Tool") then
                local data = ESPObjects[player]
                if data and data.Equipped then data.Equipped.Text = "Holding: None" end
                -- disconnect monitor for that tool if present
                if ESPConns[player] and ESPConns[player].toolConns and ESPConns[player].toolConns[child] then
                    local conns = ESPConns[player].toolConns[child]
                    pcall(function() if conns.eq then conns.eq:Disconnect() end end)
                    pcall(function() if conns.uneq then conns.uneq:Disconnect() end end)
                    pcall(function() if conns.anc then conns.anc:Disconnect() end end)
                    ESPConns[player].toolConns[child] = nil
                end
            end
        end)

        -- backpack child events (tools moved between backpack/char)
        local backpack = player:FindFirstChild("Backpack")
        local backpackAdded, backpackRemoved
        if backpack then
            backpackAdded = backpack.ChildAdded:Connect(function(child)
                if child:IsA("Tool") then
                    -- monitor any tool that appears in backpack
                    monitorTool(player, child, ESPObjects[player])
                end
            end)
            backpackRemoved = backpack.ChildRemoved:Connect(function(child)
                if child:IsA("Tool") then
                    -- if removed from backpack (likely moved to char), we will monitor it when it appears in char
                    -- but disconnect previous monitor for safety & reconnect later if needed
                    if ESPConns[player] and ESPConns[player].toolConns and ESPConns[player].toolConns[child] then
                        local conns = ESPConns[player].toolConns[child]
                        pcall(function() if conns.eq then conns.eq:Disconnect() end end)
                        pcall(function() if conns.uneq then conns.uneq:Disconnect() end end)
                        pcall(function() if conns.anc then conns.anc:Disconnect() end end)
                        ESPConns[player].toolConns[child] = nil
                    end
                end
            end)
        end

        ESPConns[player] = {
            charConn = ESPConns[player].charConn, -- preserved if stored earlier
            diedConn = diedConn,
            charChildAdded = charChildAdded,
            charChildRemoved = charChildRemoved,
            backpackAdded = backpackAdded,
            backpackRemoved = backpackRemoved,
            toolConns = ESPConns[player].toolConns or {} -- keep any pre-existing monitors
        }

        -- Initially monitor any existing tools in character & backpack
        -- character:
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") then
                monitorTool(player, child, ESPObjects[player])
            end
        end
        -- backpack:
        if backpack then
            for _, child in ipairs(backpack:GetChildren()) do
                if child:IsA("Tool") then
                    monitorTool(player, child, ESPObjects[player])
                end
            end
        end

        -- immediate equipped fill
        if ESPObjects[player] and ESPObjects[player].Equipped then
            local toolName = getEquippedToolName(player, char) or "None"
            ESPObjects[player].Equipped.Text = "Holding: " .. (toolName ~= "" and toolName or "None")
        end
    end

    -- connect CharacterAdded (store conn)
    local charConn = player.CharacterAdded:Connect(onCharacterAdded)
    ESPConns[player].charConn = charConn

    -- if character exists now, call handler
    if player.Character and player.Character.Parent then
        pcall(function() onCharacterAdded(player.Character) end)
    end
end

-- initialize existing players
for _, p in ipairs(Players:GetPlayers()) do setupESP(p) end
Players.PlayerAdded:Connect(setupESP)
Players.PlayerRemoving:Connect(function(player) cleanupESPForPlayer(player) end)

-- Frame update: draws skeleton, name, distance, equipped (per-frame tool recompute for reliability)
RunService.RenderStepped:Connect(function()
    local camPos = Camera.CFrame.Position

    for player, data in pairs(ESPObjects) do
        -- quick hide when disabled
        if not ESPEnabled then
            if data.Name then data.Name.Visible = false end
            if data.Distance then data.Distance.Visible = false end
            if data.Equipped then data.Equipped.Visible = false end
            for _, ln in pairs(data.Skeleton or {}) do if ln then ln.Visible = false end end
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
            if data.Name then data.Name.Visible = false end
            if data.Distance then data.Distance.Visible = false end
            if data.Equipped then data.Equipped.Visible = false end
            for _, ln in pairs(data.Skeleton or {}) do if ln then ln.Visible = false end end
            continue
        end

        local distance = (hrp.Position - camPos).Magnitude
        if MAX_DISTANCE and distance > MAX_DISTANCE then
            if data.Name then data.Name.Visible = false end
            if data.Distance then data.Distance.Visible = false end
            if data.Equipped then data.Equipped.Visible = false end
            for _, ln in pairs(data.Skeleton or {}) do if ln then ln.Visible = false end end
            continue
        end

        -- color logic (whitelist overrides)
        local color = COLORS.Enemy
        if Whitelist[player.Name] then
            color = COLORS.Ally
        elseif Blacklist[player.Name] then
            color = COLORS.Enemy
        elseif LocalPlayer.Team and player.Team == LocalPlayer.Team then
            color = COLORS.Ally
        end

        -- skeleton
        for _, pair in ipairs(data.BonePairs) do
            local p1part = char:FindFirstChild(pair[1])
            local p2part = char:FindFirstChild(pair[2])
            local ln = data.Skeleton[pair[1].."_"..pair[2]]
            if p1part and p2part and ln then
                local p1, on1 = Camera:WorldToViewportPoint(p1part.Position)
                local p2, on2 = Camera:WorldToViewportPoint(p2part.Position)
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

        -- texts (head on-screen)
        local headPos, onScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0,0.5,0))
        if onScreen then
            -- name
            if data.Name then
                data.Name.Text = player.Name
                data.Name.Position = Vector2.new(headPos.X, headPos.Y - 28)
                data.Name.Color = color
                data.Name.Visible = true
            end

            -- distance
            if data.Distance then
                data.Distance.Text = math.floor(distance) .. " studs"
                data.Distance.Position = Vector2.new(headPos.X, headPos.Y - 12)
                data.Distance.Color = COLORS.TextGray
                data.Distance.Visible = true
            end

            -- equipped (recompute every frame for reliability; but we also monitor Tool events)
            if data.Equipped then
                local toolName = getEquippedToolName(player, char) or "None"
                data.Equipped.Text = "Holding: " .. (toolName ~= "" and toolName or "None")
                data.Equipped.Position = Vector2.new(headPos.X, headPos.Y + 6)
                data.Equipped.Color = COLORS.TextGray
                data.Equipped.Visible = true
            end
        else
            if data.Name then data.Name.Visible = false end
            if data.Distance then data.Distance.Visible = false end
            if data.Equipped then data.Equipped.Visible = false end
        end
    end
end)

-- UI (unchanged)
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

    -- Controls
    local Title = Instance.new("TextLabel", Frame)
    Title.Size = UDim2.new(1,0,0,32)
    Title.Position = UDim2.new(0,0,0,0)
    Title.BackgroundColor3 = Color3.fromRGB(50,50,50)
    Title.Text = "ESP Control"
    Title.TextColor3 = Color3.fromRGB(255,255,255)

    local InputBox = Instance.new("TextBox", Frame)
    InputBox.Size = UDim2.new(1,-20,0,30)
    InputBox.Position = UDim2.new(0,10,0,42)
    InputBox.PlaceholderText = "Enter player name"
    InputBox.TextColor3 = Color3.fromRGB(255,255,255)
    InputBox.BackgroundColor3 = Color3.fromRGB(40,40,40)
    InputBox.ClearTextOnFocus = false

    local WLButton = Instance.new("TextButton", Frame)
    WLButton.Size = UDim2.new(0.5,-15,0,30)
    WLButton.Position = UDim2.new(0,10,0,82)
    WLButton.Text = "Whitelist"
    WLButton.TextColor3 = Color3.fromRGB(255,255,255)
    WLButton.BackgroundColor3 = Color3.fromRGB(0,128,0)

    local BLButton = Instance.new("TextButton", Frame)
    BLButton.Size = UDim2.new(0.5,-15,0,30)
    BLButton.Position = UDim2.new(0.5,5,0,82)
    BLButton.Text = "Blacklist"
    BLButton.TextColor3 = Color3.fromRGB(255,255,255)
    BLButton.BackgroundColor3 = Color3.fromRGB(128,0,0)

    local RefreshButton = Instance.new("TextButton", Frame)
    RefreshButton.Size = UDim2.new(1,-20,0,30)
    RefreshButton.Position = UDim2.new(0,10,0,122)
    RefreshButton.Text = "Refresh ESP"
    RefreshButton.TextColor3 = Color3.fromRGB(255,255,255)
    RefreshButton.BackgroundColor3 = Color3.fromRGB(50,50,150)

    local ToggleESP = Instance.new("TextButton", Frame)
    ToggleESP.Size = UDim2.new(1,-20,0,30)
    ToggleESP.Position = UDim2.new(0,10,0,162)
    ToggleESP.Text = "Toggle ESP (On)"
    ToggleESP.TextColor3 = Color3.fromRGB(255,255,255)
    ToggleESP.BackgroundColor3 = Color3.fromRGB(80,80,80)

    local DistanceBox = Instance.new("TextBox", Frame)
    DistanceBox.Size = UDim2.new(1,-20,0,30)
    DistanceBox.Position = UDim2.new(0,10,0,192)
    DistanceBox.PlaceholderText = "Enter max distance (studs)"
    DistanceBox.Text = tostring(MAX_DISTANCE)
    DistanceBox.TextColor3 = Color3.fromRGB(255,255,255)
    DistanceBox.BackgroundColor3 = Color3.fromRGB(40,40,40)
    DistanceBox.ClearTextOnFocus = false

    -- Buttons logic
    WLButton.MouseButton1Click:Connect(function()
        local name = InputBox.Text
        if name ~= "" then Whitelist[name] = true Blacklist[name] = nil end
    end)
    BLButton.MouseButton1Click:Connect(function()
        local name = InputBox.Text
        if name ~= "" then Blacklist[name] = true Whitelist[name] = nil end
    end)

    RefreshButton.MouseButton1Click:Connect(function()
        for player, _ in pairs(ESPObjects) do cleanupESPForPlayer(player) end
        ESPObjects = {}
        for _, p in ipairs(Players:GetPlayers()) do setupESP(p) end
    end)

    ToggleESP.MouseButton1Click:Connect(function()
        ESPEnabled = not ESPEnabled
        ToggleESP.Text = ESPEnabled and "Toggle ESP (On)" or "Toggle ESP (Off)"
        if not ESPEnabled then
            for _, data in pairs(ESPObjects) do
                if data.Name then data.Name.Visible = false end
                if data.Distance then data.Distance.Visible = false end
                if data.Equipped then data.Equipped.Visible = false end
                for _, ln in pairs(data.Skeleton or {}) do if ln then ln.Visible = false end end
            end
        end
    end)

    DistanceBox.FocusLost:Connect(function()
        local value = tonumber(DistanceBox.Text)
        if value and value > 0 then
            MAX_DISTANCE = value
        else
            DistanceBox.Text = tostring(MAX_DISTANCE)
        end
    end)
end

CreateUI()
