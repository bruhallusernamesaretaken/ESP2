-- WA Universal ESP (fixed: name + distance + modern timing)
-- Minor updates:
--  - name + distance text are now updated and positioned
--  - replaced tick() usage with time()
--  - kept task.wait for internal loops (recommended over wait())

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Drawings = {
    ESP = {},
    Tracers = {},
    Boxes = {},
    Healthbars = {},
    Names = {},
    Distances = {},
    Snaplines = {},
    Skeleton = {}
}

local Colors = {
    Enemy = Color3.fromRGB(255, 25, 25),
    Ally = Color3.fromRGB(25, 255, 25),
    Neutral = Color3.fromRGB(255, 255, 255),
    Selected = Color3.fromRGB(255, 210, 0),
    Health = Color3.fromRGB(0, 255, 0),
    Distance = Color3.fromRGB(200, 200, 200),
    Rainbow = nil
}

local Highlights = {}

local Settings = {
    Enabled = false,
    TeamCheck = false,
    ShowTeam = false,
    VisibilityCheck = true,
    BoxESP = false,
    BoxStyle = "Corner",
    BoxOutline = true,
    BoxFilled = false,
    BoxFillTransparency = 0.5,
    BoxThickness = 1,
    TracerESP = false,
    TracerOrigin = "Bottom",
    TracerStyle = "Line",
    TracerThickness = 1,
    HealthESP = false,
    HealthStyle = "Bar",
    HealthBarSide = "Left",
    HealthTextSuffix = "HP",
    NameESP = false,
    NameMode = "DisplayName", -- "DisplayName" or "Username"
    ShowDistance = true,
    DistanceUnit = "studs",
    TextSize = 14,
    TextFont = 2,
    RainbowSpeed = 1,
    MaxDistance = 1000,
    RefreshRate = 1/144,
    Snaplines = false,
    SnaplineStyle = "Straight",
    RainbowEnabled = false,
    RainbowBoxes = false,
    RainbowTracers = false,
    RainbowText = false,
    ChamsEnabled = false,
    ChamsOutlineColor = Color3.fromRGB(255, 255, 255),
    ChamsFillColor = Color3.fromRGB(255, 0, 0),
    ChamsOccludedColor = Color3.fromRGB(150, 0, 0),
    ChamsTransparency = 0.5,
    ChamsOutlineTransparency = 0,
    ChamsOutlineThickness = 0.1,
    SkeletonESP = false,
    SkeletonColor = Color3.fromRGB(255, 255, 255),
    SkeletonThickness = 1.5,
    SkeletonTransparency = 1
}

-- Create drawing objects for a player
local function CreateESP(player)
    if player == LocalPlayer then return end

    -- Box corners / lines (we'll reuse these for all box types)
    local box = {
        TopLeft = Drawing.new("Line"),
        TopRight = Drawing.new("Line"),
        BottomLeft = Drawing.new("Line"),
        BottomRight = Drawing.new("Line"),
        Left = Drawing.new("Line"),
        Right = Drawing.new("Line"),
        Top = Drawing.new("Line"),
        Bottom = Drawing.new("Line")
    }

    for _, line in pairs(box) do
        line.Visible = false
        line.Color = Colors.Enemy
        line.Thickness = Settings.BoxThickness
    end

    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Color = Colors.Enemy
    tracer.Thickness = Settings.TracerThickness

    local healthBar = {
        Outline = Drawing.new("Square"),
        Fill = Drawing.new("Square"),
        Text = Drawing.new("Text")
    }

    healthBar.Outline.Visible = false
    healthBar.Fill.Visible = false
    healthBar.Text.Visible = false
    healthBar.Outline.Filled = false
    healthBar.Fill.Filled = true
    healthBar.Text.Center = true
    healthBar.Text.Size = Settings.TextSize
    healthBar.Text.Font = Settings.TextFont

    local info = {
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text")
    }

    -- Configure Name & Distance text objects
    info.Name.Visible = false
    info.Name.Center = true
    info.Name.Size = Settings.TextSize
    info.Name.Color = Colors.Enemy
    info.Name.Font = Settings.TextFont
    info.Name.Outline = true

    info.Distance.Visible = false
    info.Distance.Center = true
    info.Distance.Size = math.max(10, Settings.TextSize - 2)
    info.Distance.Color = Colors.Distance
    info.Distance.Font = Settings.TextFont
    info.Distance.Outline = true

    local snapline = Drawing.new("Line")
    snapline.Visible = false
    snapline.Color = Colors.Enemy
    snapline.Thickness = 1

    local highlight = Instance.new("Highlight")
    highlight.FillColor = Settings.ChamsFillColor
    highlight.OutlineColor = Settings.ChamsOutlineColor
    highlight.FillTransparency = Settings.ChamsTransparency
    highlight.OutlineTransparency = Settings.ChamsOutlineTransparency
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = Settings.ChamsEnabled

    Highlights[player] = highlight

    -- Skeleton lines
    local skeleton = {
        Head = Drawing.new("Line"),
        Neck = Drawing.new("Line"),
        UpperSpine = Drawing.new("Line"),
        LowerSpine = Drawing.new("Line"),
        LeftShoulder = Drawing.new("Line"),
        LeftUpperArm = Drawing.new("Line"),
        LeftLowerArm = Drawing.new("Line"),
        LeftHand = Drawing.new("Line"),
        RightShoulder = Drawing.new("Line"),
        RightUpperArm = Drawing.new("Line"),
        RightLowerArm = Drawing.new("Line"),
        RightHand = Drawing.new("Line"),
        LeftHip = Drawing.new("Line"),
        LeftUpperLeg = Drawing.new("Line"),
        LeftLowerLeg = Drawing.new("Line"),
        LeftFoot = Drawing.new("Line"),
        RightHip = Drawing.new("Line"),
        RightUpperLeg = Drawing.new("Line"),
        RightLowerLeg = Drawing.new("Line"),
        RightFoot = Drawing.new("Line")
    }

    for _, line in pairs(skeleton) do
        line.Visible = false
        line.Color = Settings.SkeletonColor
        line.Thickness = Settings.SkeletonThickness
        line.Transparency = Settings.SkeletonTransparency
    end

    Drawings.Skeleton[player] = skeleton

    Drawings.ESP[player] = {
        Box = box,
        Tracer = tracer,
        HealthBar = healthBar,
        Info = info,
        Snapline = snapline
    }
end

local function RemoveESP(player)
    local esp = Drawings.ESP[player]
    if esp then
        for _, obj in pairs(esp.Box) do
            pcall(function() obj:Remove() end)
        end
        pcall(function() esp.Tracer:Remove() end)
        for _, obj in pairs(esp.HealthBar) do
            if obj and typeof(obj.Remove) == "function" then pcall(function() obj:Remove() end) end
        end
        for _, obj in pairs(esp.Info) do
            if obj and typeof(obj.Remove) == "function" then pcall(function() obj:Remove() end) end
        end
        if esp.Snapline then pcall(function() esp.Snapline:Remove() end) end
        Drawings.ESP[player] = nil
    end

    local highlight = Highlights[player]
    if highlight then
        highlight:Destroy()
        Highlights[player] = nil
    end

    local skeleton = Drawings.Skeleton[player]
    if skeleton then
        for _, line in pairs(skeleton) do
            pcall(function() line:Remove() end)
        end
        Drawings.Skeleton[player] = nil
    end
end

local function GetPlayerColor(player)
    if Settings.RainbowEnabled then
        if Settings.RainbowBoxes and Settings.BoxESP then return Colors.Rainbow end
        if Settings.RainbowTracers and Settings.TracerESP then return Colors.Rainbow end
        if Settings.RainbowText and (Settings.NameESP or Settings.HealthESP) then return Colors.Rainbow end
    end
    return (player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team) and Colors.Ally or Colors.Enemy
end

local function GetBoxCorners(cf, size)
    local corners = {
        Vector3.new(-size.X/2, -size.Y/2, -size.Z/2),
        Vector3.new(-size.X/2, -size.Y/2, size.Z/2),
        Vector3.new(-size.X/2, size.Y/2, -size.Z/2),
        Vector3.new(-size.X/2, size.Y/2, size.Z/2),
        Vector3.new(size.X/2, -size.Y/2, -size.Z/2),
        Vector3.new(size.X/2, -size.Y/2, size.Z/2),
        Vector3.new(size.X/2, size.Y/2, -size.Z/2),
        Vector3.new(size.X/2, size.Y/2, size.Z/2)
    }

    for i, corner in ipairs(corners) do
        corners[i] = (cf * CFrame.new(corner)).Position
    end

    return corners
end

local function GetTracerOrigin()
    local origin = Settings.TracerOrigin
    if origin == "Bottom" then
        return Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
    elseif origin == "Top" then
        return Vector2.new(Camera.ViewportSize.X/2, 0)
    elseif origin == "Mouse" then
        -- GetMouseLocation returns a Vector2 (in newer APIs)
        local ok, v = pcall(function() return UserInputService:GetMouseLocation() end)
        if ok and typeof(v) == "Vector2" then return v end
        -- fallback
        return Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    else
        return Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    end
end

local function UpdateESP(player)
    if not Settings.Enabled then return end
    if player == LocalPlayer then return end

    local esp = Drawings.ESP[player]
    if not esp then return end

    local character = player.Character
    if not character then
        -- hide
        for _, obj in pairs(esp.Box) do if obj then obj.Visible = false end end
        if esp.Tracer then esp.Tracer.Visible = false end
        for _, obj in pairs(esp.HealthBar) do if obj then obj.Visible = false end end
        for _, obj in pairs(esp.Info) do if obj then obj.Visible = false end end
        if esp.Snapline then esp.Snapline.Visible = false end
        local skeleton = Drawings.Skeleton[player]
        if skeleton then for _, line in pairs(skeleton) do line.Visible = false end end
        return
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        for _, obj in pairs(esp.Box) do if obj then obj.Visible = false end end
        if esp.Tracer then esp.Tracer.Visible = false end
        for _, obj in pairs(esp.HealthBar) do if obj then obj.Visible = false end end
        for _, obj in pairs(esp.Info) do if obj then obj.Visible = false end end
        if esp.Snapline then esp.Snapline.Visible = false end
        local skeleton = Drawings.Skeleton[player]
        if skeleton then for _, line in pairs(skeleton) do line.Visible = false end end
        return
    end

    -- Minor early screen check (WorldToViewportPoint)
    local _posCheck, isOnScreenCheck = Camera:WorldToViewportPoint(rootPart.Position)
    if not isOnScreenCheck then
        for _, obj in pairs(esp.Box) do if obj then obj.Visible = false end end
        if esp.Tracer then esp.Tracer.Visible = false end
        for _, obj in pairs(esp.HealthBar) do if obj then obj.Visible = false end end
        for _, obj in pairs(esp.Info) do if obj then obj.Visible = false end end
        if esp.Snapline then esp.Snapline.Visible = false end
        local skeleton = Drawings.Skeleton[player]
        if skeleton then for _, line in pairs(skeleton) do line.Visible = false end end
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        for _, obj in pairs(esp.Box) do if obj then obj.Visible = false end end
        if esp.Tracer then esp.Tracer.Visible = false end
        for _, obj in pairs(esp.HealthBar) do if obj then obj.Visible = false end end
        for _, obj in pairs(esp.Info) do if obj then obj.Visible = false end end
        if esp.Snapline then esp.Snapline.Visible = false end
        local skeleton = Drawings.Skeleton[player]
        if skeleton then for _, line in pairs(skeleton) do line.Visible = false end end
        return
    end

    local posVec3, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
    local distance = (rootPart.Position - Camera.CFrame.Position).Magnitude

    if not onScreen or distance > Settings.MaxDistance then
        for _, obj in pairs(esp.Box) do if obj then obj.Visible = false end end
        if esp.Tracer then esp.Tracer.Visible = false end
        for _, obj in pairs(esp.HealthBar) do if obj then obj.Visible = false end end
        for _, obj in pairs(esp.Info) do if obj then obj.Visible = false end end
        if esp.Snapline then esp.Snapline.Visible = false end
        return
    end

    if Settings.TeamCheck and player.Team == LocalPlayer.Team and not Settings.ShowTeam then
        for _, obj in pairs(esp.Box) do if obj then obj.Visible = false end end
        if esp.Tracer then esp.Tracer.Visible = false end
        for _, obj in pairs(esp.HealthBar) do if obj then obj.Visible = false end end
        for _, obj in pairs(esp.Info) do if obj then obj.Visible = false end end
        if esp.Snapline then esp.Snapline.Visible = false end
        return
    end

    local color = GetPlayerColor(player)
    local size = character:GetExtentsSize()
    local cf = rootPart.CFrame

    -- Get top and bottom viewport points for box height
    local topVec3, topOn = Camera:WorldToViewportPoint((cf * CFrame.new(0, size.Y/2, 0)).Position)
    local bottomVec3, bottomOn = Camera:WorldToViewportPoint((cf * CFrame.new(0, -size.Y/2, 0)).Position)
    if not topOn or not bottomOn then
        for _, obj in pairs(esp.Box) do if obj then obj.Visible = false end end
        return
    end

    local screenSize = math.abs(bottomVec3.Y - topVec3.Y)
    local boxWidth = screenSize * 0.65
    local boxPosition = Vector2.new(topVec3.X - boxWidth/2, topVec3.Y)
    local boxSize = Vector2.new(boxWidth, screenSize)

    -- Hide all box lines by default
    for _, obj in pairs(esp.Box) do if obj then obj.Visible = false end end

    if Settings.BoxESP then
        if Settings.BoxStyle == "ThreeD" then
            local function w(v3) return Camera:WorldToViewportPoint((cf * v3).Position) end
            local frontTL, frontTLOn = w(Vector3.new(-size.X/2, size.Y/2, -size.Z/2))
            local frontTR, frontTROn = w(Vector3.new(size.X/2, size.Y/2, -size.Z/2))
            local frontBL, frontBLOn = w(Vector3.new(-size.X/2, -size.Y/2, -size.Z/2))
            local frontBR, frontBROn = w(Vector3.new(size.X/2, -size.Y/2, -size.Z/2))

            local backTL, backTLOn = w(Vector3.new(-size.X/2, size.Y/2, size.Z/2))
            local backTR, backTROn = w(Vector3.new(size.X/2, size.Y/2, size.Z/2))
            local backBL, backBLOn = w(Vector3.new(-size.X/2, -size.Y/2, size.Z/2))
            local backBR, backBROn = w(Vector3.new(size.X/2, -size.Y/2, size.Z/2))

            if not (frontTLOn and frontTROn and frontBLOn and frontBROn and backTLOn and backTROn and backBLOn and backBROn) then
                for _, obj in pairs(esp.Box) do if obj then obj.Visible = false end end
                return
            end

            local function toV2(v3) return Vector2.new(v3.X, v3.Y) end
            frontTL, frontTR, frontBL, frontBR = toV2(frontTL), toV2(frontTR), toV2(frontBL), toV2(frontBR)
            backTL, backTR, backBL, backBR = toV2(backTL), toV2(backTR), toV2(backBL), toV2(backBR)

            -- front face
            esp.Box.TopLeft.From = frontTL; esp.Box.TopLeft.To = frontTR; esp.Box.TopLeft.Visible = true
            esp.Box.TopRight.From = frontTR; esp.Box.TopRight.To = frontBR; esp.Box.TopRight.Visible = true
            esp.Box.BottomLeft.From = frontBL; esp.Box.BottomLeft.To = frontBR; esp.Box.BottomLeft.Visible = true
            esp.Box.BottomRight.From = frontTL; esp.Box.BottomRight.To = frontBL; esp.Box.BottomRight.Visible = true
            -- back face
            esp.Box.Left.From = backTL; esp.Box.Left.To = backTR; esp.Box.Left.Visible = true
            esp.Box.Right.From = backTR; esp.Box.Right.To = backBR; esp.Box.Right.Visible = true
            esp.Box.Top.From = backBL; esp.Box.Top.To = backBR; esp.Box.Top.Visible = true
            esp.Box.Bottom.From = backTL; esp.Box.Bottom.To = backBL; esp.Box.Bottom.Visible = true

            -- connectors
            local connectors = {
                Drawing.new("Line"),
                Drawing.new("Line"),
                Drawing.new("Line"),
                Drawing.new("Line")
            }
            local conPoints = {
                {frontTL, backTL}, {frontTR, backTR}, {frontBL, backBL}, {frontBR, backBR}
            }
            for i, c in ipairs(connectors) do
                c.From = conPoints[i][1]
                c.To = conPoints[i][2]
                c.Color = color
                c.Thickness = Settings.BoxThickness
                c.Visible = true
            end
            -- schedule cleanup of connectors after the frame (so they don't persist)
            task.spawn(function()
                task.wait()
                for _, c in ipairs(connectors) do pcall(function() c:Remove() end) end
            end)
        elseif Settings.BoxStyle == "Corner" then
            local cornerSize = boxWidth * 0.2
            esp.Box.TopLeft.From = boxPosition; esp.Box.TopLeft.To = boxPosition + Vector2.new(cornerSize, 0); esp.Box.TopLeft.Visible = true
            esp.Box.TopRight.From = boxPosition + Vector2.new(boxSize.X, 0); esp.Box.TopRight.To = boxPosition + Vector2.new(boxSize.X - cornerSize, 0); esp.Box.TopRight.Visible = true
            esp.Box.BottomLeft.From = boxPosition + Vector2.new(0, boxSize.Y); esp.Box.BottomLeft.To = boxPosition + Vector2.new(cornerSize, boxSize.Y); esp.Box.BottomLeft.Visible = true
            esp.Box.BottomRight.From = boxPosition + Vector2.new(boxSize.X, boxSize.Y); esp.Box.BottomRight.To = boxPosition + Vector2.new(boxSize.X - cornerSize, boxSize.Y); esp.Box.BottomRight.Visible = true

            esp.Box.Left.From = boxPosition; esp.Box.Left.To = boxPosition + Vector2.new(0, cornerSize); esp.Box.Left.Visible = true
            esp.Box.Right.From = boxPosition + Vector2.new(boxSize.X, 0); esp.Box.Right.To = boxPosition + Vector2.new(boxSize.X, cornerSize); esp.Box.Right.Visible = true
            esp.Box.Top.From = boxPosition + Vector2.new(0, boxSize.Y); esp.Box.Top.To = boxPosition + Vector2.new(0, boxSize.Y - cornerSize); esp.Box.Top.Visible = true
            esp.Box.Bottom.From = boxPosition + Vector2.new(boxSize.X, boxSize.Y); esp.Box.Bottom.To = boxPosition + Vector2.new(boxSize.X, boxSize.Y - cornerSize); esp.Box.Bottom.Visible = true
        else -- Full
            esp.Box.Left.From = boxPosition; esp.Box.Left.To = boxPosition + Vector2.new(0, boxSize.Y); esp.Box.Left.Visible = true
            esp.Box.Right.From = boxPosition + Vector2.new(boxSize.X, 0); esp.Box.Right.To = boxPosition + Vector2.new(boxSize.X, boxSize.Y); esp.Box.Right.Visible = true
            esp.Box.Top.From = boxPosition; esp.Box.Top.To = boxPosition + Vector2.new(boxSize.X, 0); esp.Box.Top.Visible = true
            esp.Box.Bottom.From = boxPosition + Vector2.new(0, boxSize.Y); esp.Box.Bottom.To = boxPosition + Vector2.new(boxSize.X, boxSize.Y); esp.Box.Bottom.Visible = true
            esp.Box.TopLeft.Visible = false; esp.Box.TopRight.Visible = false; esp.Box.BottomLeft.Visible = false; esp.Box.BottomRight.Visible = false
        end

        for _, obj in pairs(esp.Box) do
            if obj and obj.Visible then
                obj.Color = color
                obj.Thickness = Settings.BoxThickness
            end
        end
    end

    -- Tracer
    if Settings.TracerESP and esp.Tracer then
        esp.Tracer.From = GetTracerOrigin()
        esp.Tracer.To = Vector2.new(posVec3.X, posVec3.Y)
        esp.Tracer.Color = color
        esp.Tracer.Visible = true
    elseif esp.Tracer then
        esp.Tracer.Visible = false
    end

    -- Health bar
    if Settings.HealthESP and esp.HealthBar then
        local health = humanoid.Health
        local maxHealth = humanoid.MaxHealth
        local healthPercent = math.clamp(health / math.max(1, maxHealth), 0, 1)

        local barHeight = screenSize * 0.8
        local barWidth = 4
        local barPos = Vector2.new(boxPosition.X - barWidth - 2, boxPosition.Y + (screenSize - barHeight) / 2)

        esp.HealthBar.Outline.Size = Vector2.new(barWidth, barHeight)
        esp.HealthBar.Outline.Position = barPos
        esp.HealthBar.Outline.Visible = true

        esp.HealthBar.Fill.Size = Vector2.new(barWidth - 2, barHeight * healthPercent)
        esp.HealthBar.Fill.Position = Vector2.new(barPos.X + 1, barPos.Y + barHeight * (1 - healthPercent))
        esp.HealthBar.Fill.Color = Color3.fromRGB(math.floor(255 - (255 * healthPercent)), math.floor(255 * healthPercent), 0)
        esp.HealthBar.Fill.Visible = true

        if Settings.HealthStyle == "Both" or Settings.HealthStyle == "Text" then
            esp.HealthBar.Text.Text = math.floor(health) .. Settings.HealthTextSuffix
            esp.HealthBar.Text.Position = Vector2.new(barPos.X + barWidth + 2, barPos.Y + barHeight / 2)
            esp.HealthBar.Text.Visible = true
        else
            esp.HealthBar.Text.Visible = false
        end
    else
        if esp.HealthBar then
            for _, obj in pairs(esp.HealthBar) do if obj then obj.Visible = false end end
        end
    end

    -- Name & Distance
    if Settings.NameESP or Settings.ShowDistance then
        -- Choose the name to display
        local nameToShow = nil
        if Settings.NameESP then
            if Settings.NameMode == "DisplayName" and player.DisplayName and player.DisplayName ~= "" then
                nameToShow = player.DisplayName
            else
                nameToShow = player.Name
            end
            esp.Info.Name.Text = nameToShow
            esp.Info.Name.Position = Vector2.new(boxPosition.X + boxWidth / 2, boxPosition.Y - 20)
            esp.Info.Name.Color = color
            esp.Info.Name.Size = Settings.TextSize
            esp.Info.Name.Visible = true
        else
            esp.Info.Name.Visible = false
        end

        if Settings.ShowDistance and esp.Info.Distance then
            -- distance text formatting: rounded, unit appended
            local distStr = tostring(math.floor(distance))
            if Settings.DistanceUnit and Settings.DistanceUnit ~= "" then
                distStr = distStr .. " " .. Settings.DistanceUnit
            end
            esp.Info.Distance.Text = distStr
            -- place it just under the name (or just above the box if name disabled)
            local yOffset = Settings.NameESP and (boxPosition.Y - 6) or (boxPosition.Y - 12)
            esp.Info.Distance.Position = Vector2.new(boxPosition.X + boxWidth / 2, yOffset)
            esp.Info.Distance.Color = Colors.Distance
            esp.Info.Distance.Size = math.max(10, Settings.TextSize - 2)
            esp.Info.Distance.Visible = true
        else
            esp.Info.Distance.Visible = false
        end
    else
        if esp.Info then
            if esp.Info.Name then esp.Info.Name.Visible = false end
            if esp.Info.Distance then esp.Info.Distance.Visible = false end
        end
    end

    -- Snapline
    if Settings.Snaplines and esp.Snapline then
        esp.Snapline.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
        esp.Snapline.To = Vector2.new(posVec3.X, posVec3.Y)
        esp.Snapline.Color = color
        esp.Snapline.Visible = true
    elseif esp.Snapline then
        esp.Snapline.Visible = false
    end

    -- Chams
    local highlight = Highlights[player]
    if highlight then
        if Settings.ChamsEnabled and character then
            highlight.Parent = character
            highlight.FillColor = Settings.ChamsFillColor
            highlight.OutlineColor = Settings.ChamsOutlineColor
            highlight.FillTransparency = Settings.ChamsTransparency
            highlight.OutlineTransparency = Settings.ChamsOutlineTransparency
            highlight.Enabled = true
        else
            highlight.Enabled = false
        end
    end

    -- Skeleton drawing (unchanged, but keep using robust checks)
    if Settings.SkeletonESP then
        local function getBonePositions(c)
            if not c then return nil end
            return {
                Head = c:FindFirstChild("Head"),
                UpperTorso = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso"),
                LowerTorso = c:FindFirstChild("LowerTorso") or c:FindFirstChild("Torso"),
                RootPart = c:FindFirstChild("HumanoidRootPart"),
                LeftUpperArm = c:FindFirstChild("LeftUpperArm") or c:FindFirstChild("Left Arm"),
                LeftLowerArm = c:FindFirstChild("LeftLowerArm") or c:FindFirstChild("Left Arm"),
                LeftHand = c:FindFirstChild("LeftHand") or c:FindFirstChild("Left Arm"),
                RightUpperArm = c:FindFirstChild("RightUpperArm") or c:FindFirstChild("Right Arm"),
                RightLowerArm = c:FindFirstChild("RightLowerArm") or c:FindFirstChild("Right Arm"),
                RightHand = c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm"),
                LeftUpperLeg = c:FindFirstChild("LeftUpperLeg") or c:FindFirstChild("Left Leg"),
                LeftLowerLeg = c:FindFirstChild("LeftLowerLeg") or c:FindFirstChild("Left Leg"),
                LeftFoot = c:FindFirstChild("LeftFoot") or c:FindFirstChild("Left Leg"),
                RightUpperLeg = c:FindFirstChild("RightUpperLeg") or c:FindFirstChild("Right Leg"),
                RightLowerLeg = c:FindFirstChild("RightLowerLeg") or c:FindFirstChild("Right Leg"),
                RightFoot = c:FindFirstChild("RightFoot") or c:FindFirstChild("Right Leg")
            }
        end

        local function drawBone(from, to, line)
            if not from or not to then
                if line then line.Visible = false end
                return
            end
            local fromPos = from.Position
            local toPos = to.Position
            local fromScreen, fromVisible = Camera:WorldToViewportPoint(fromPos)
            local toScreen, toVisible = Camera:WorldToViewportPoint(toPos)

            if not (fromVisible and toVisible) or fromScreen.Z < 0 or toScreen.Z < 0 then
                line.Visible = false
                return
            end

            local screenBounds = Camera.ViewportSize
            if fromScreen.X < 0 or fromScreen.X > screenBounds.X or fromScreen.Y < 0 or fromScreen.Y > screenBounds.Y or
               toScreen.X < 0 or toScreen.X > screenBounds.X or toScreen.Y < 0 or toScreen.Y > screenBounds.Y then
                line.Visible = false
                return
            end

            line.From = Vector2.new(fromScreen.X, fromScreen.Y)
            line.To = Vector2.new(toScreen.X, toScreen.Y)
            line.Color = Settings.SkeletonColor
            line.Thickness = Settings.SkeletonThickness
            line.Transparency = Settings.SkeletonTransparency
            line.Visible = true
        end

        local bones = getBonePositions(character)
        if bones then
            local skeleton = Drawings.Skeleton[player]
            if skeleton then
                drawBone(bones.Head, bones.UpperTorso, skeleton.Head)
                drawBone(bones.UpperTorso, bones.LowerTorso, skeleton.UpperSpine)
                drawBone(bones.UpperTorso, bones.LeftUpperArm, skeleton.LeftShoulder)
                drawBone(bones.LeftUpperArm, bones.LeftLowerArm, skeleton.LeftUpperArm)
                drawBone(bones.LeftLowerArm, bones.LeftHand, skeleton.LeftLowerArm)
                drawBone(bones.UpperTorso, bones.RightUpperArm, skeleton.RightShoulder)
                drawBone(bones.RightUpperArm, bones.RightLowerArm, skeleton.RightUpperArm)
                drawBone(bones.RightLowerArm, bones.RightHand, skeleton.RightLowerArm)
                drawBone(bones.LowerTorso, bones.LeftUpperLeg, skeleton.LeftHip)
                drawBone(bones.LeftUpperLeg, bones.LeftLowerLeg, skeleton.LeftUpperLeg)
                drawBone(bones.LeftLowerLeg, bones.LeftFoot, skeleton.LeftLowerLeg)
                drawBone(bones.LowerTorso, bones.RightUpperLeg, skeleton.RightHip)
                drawBone(bones.RightUpperLeg, bones.RightLowerLeg, skeleton.RightUpperLeg)
                drawBone(bones.RightLowerLeg, bones.RightFoot, skeleton.RightLowerLeg)
            end
        end
    else
        local skeleton = Drawings.Skeleton[player]
        if skeleton then for _, line in pairs(skeleton) do line.Visible = false end end
    end
end

local function DisableESP()
    for _, player in ipairs(Players:GetPlayers()) do
        local esp = Drawings.ESP[player]
        if esp then
            for _, obj in pairs(esp.Box) do if obj then obj.Visible = false end end
            if esp.Tracer then esp.Tracer.Visible = false end
            for _, obj in pairs(esp.HealthBar) do if obj then obj.Visible = false end end
            for _, obj in pairs(esp.Info) do if obj then obj.Visible = false end end
            if esp.Snapline then esp.Snapline.Visible = false end
        end
        local skeleton = Drawings.Skeleton[player]
        if skeleton then for _, line in pairs(skeleton) do line.Visible = false end end
    end
end

local function CleanupESP()
    for _, player in ipairs(Players:GetPlayers()) do
        RemoveESP(player)
    end
    Drawings.ESP = {}
    Drawings.Skeleton = {}
    Highlights = {}
end

-- UI / Window creation (unchanged from your original)
local Window = Fluent:CreateWindow({
    Title = "WA Universal ESP",
    SubTitle = "by WA",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    ESP = Window:AddTab({ Title = "ESP", Icon = "eye" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
    Config = Window:AddTab({ Title = "Config", Icon = "save" })
}

-- Build UI (kept your config but hooked to the updated Settings table)
do
    local MainSection = Tabs.ESP:AddSection("Main ESP")

    local EnabledToggle = MainSection:AddToggle("Enabled", { Title = "Enable ESP", Default = false })
    EnabledToggle:OnChanged(function()
        Settings.Enabled = EnabledToggle.Value
        if not Settings.Enabled then
            CleanupESP()
        else
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    CreateESP(player)
                end
            end
        end
    end)

    local TeamCheckToggle = MainSection:AddToggle("TeamCheck", { Title = "Team Check", Default = false })
    TeamCheckToggle:OnChanged(function() Settings.TeamCheck = TeamCheckToggle.Value end)

    local ShowTeamToggle = MainSection:AddToggle("ShowTeam", { Title = "Show Team", Default = false })
    ShowTeamToggle:OnChanged(function() Settings.ShowTeam = ShowTeamToggle.Value end)

    local BoxSection = Tabs.ESP:AddSection("Box ESP")
    local BoxESPToggle = BoxSection:AddToggle("BoxESP", { Title = "Box ESP", Default = false })
    BoxESPToggle:OnChanged(function() Settings.BoxESP = BoxESPToggle.Value end)

    local BoxStyleDropdown = BoxSection:AddDropdown("BoxStyle", { Title = "Box Style", Values = {"Corner", "Full", "ThreeD"}, Default = "Corner" })
    BoxStyleDropdown:OnChanged(function(Value) Settings.BoxStyle = Value end)

    local TracerSection = Tabs.ESP:AddSection("Tracer ESP")
    local TracerESPToggle = TracerSection:AddToggle("TracerESP", { Title = "Tracer ESP", Default = false })
    TracerESPToggle:OnChanged(function() Settings.TracerESP = TracerESPToggle.Value end)

    local TracerOriginDropdown = TracerSection:AddDropdown("TracerOrigin", { Title = "Tracer Origin", Values = {"Bottom", "Top", "Mouse", "Center"}, Default = "Bottom" })
    TracerOriginDropdown:OnChanged(function(Value) Settings.TracerOrigin = Value end)

    local ChamsSection = Tabs.ESP:AddSection("Chams")
    local ChamsToggle = ChamsSection:AddToggle("ChamsEnabled", { Title = "Enable Chams", Default = false })
    ChamsToggle:OnChanged(function() Settings.ChamsEnabled = ChamsToggle.Value end)

    local ChamsFillColor = ChamsSection:AddColorpicker("ChamsFillColor", { Title = "Fill Color", Description = "Color for visible parts", Default = Settings.ChamsFillColor })
    ChamsFillColor:OnChanged(function(Value) Settings.ChamsFillColor = Value end)

    local ChamsOccludedColor = ChamsSection:AddColorpicker("ChamsOccludedColor", { Title = "Occluded Color", Description = "Color for parts behind walls", Default = Settings.ChamsOccludedColor })
    ChamsOccludedColor:OnChanged(function(Value) Settings.ChamsOccludedColor = Value end)

    local ChamsOutlineColor = ChamsSection:AddColorpicker("ChamsOutlineColor", { Title = "Outline Color", Description = "Color for character outline", Default = Settings.ChamsOutlineColor })
    ChamsOutlineColor:OnChanged(function(Value) Settings.ChamsOutlineColor = Value end)

    local ChamsTransparency = ChamsSection:AddSlider("ChamsTransparency", { Title = "Fill Transparency", Description = "Transparency of the fill color", Default = 0.5, Min = 0, Max = 1, Rounding = 2 })
    ChamsTransparency:OnChanged(function(Value) Settings.ChamsTransparency = Value end)

    local ChamsOutlineTransparency = ChamsSection:AddSlider("ChamsOutlineTransparency", { Title = "Outline Transparency", Description = "Transparency of the outline", Default = 0, Min = 0, Max = 1, Rounding = 2 })
    ChamsOutlineTransparency:OnChanged(function(Value) Settings.ChamsOutlineTransparency = Value end)

    local ChamsOutlineThickness = ChamsSection:AddSlider("ChamsOutlineThickness", { Title = "Outline Thickness", Description = "Thickness of the outline", Default = 0.1, Min = 0, Max = 1, Rounding = 2 })
    ChamsOutlineThickness:OnChanged(function(Value) Settings.ChamsOutlineThickness = Value end)

    local HealthSection = Tabs.ESP:AddSection("Health ESP")
    local HealthESPToggle = HealthSection:AddToggle("HealthESP", { Title = "Health Bar", Default = false })
    HealthESPToggle:OnChanged(function() Settings.HealthESP = HealthESPToggle.Value end)

    local HealthStyleDropdown = HealthSection:AddDropdown("HealthStyle", { Title = "Health Style", Values = {"Bar", "Text", "Both"}, Default = "Bar" })
    HealthStyleDropdown:OnChanged(function(Value) Settings.HealthStyle = Value end)
end

do
    local ColorsSection = Tabs.Settings:AddSection("Colors")
    local EnemyColor = ColorsSection:AddColorpicker("EnemyColor", { Title = "Enemy Color", Description = "Color for enemy players", Default = Colors.Enemy })
    EnemyColor:OnChanged(function(Value) Colors.Enemy = Value end)
    local AllyColor = ColorsSection:AddColorpicker("AllyColor", { Title = "Ally Color", Description = "Color for team members", Default = Colors.Ally })
    AllyColor:OnChanged(function(Value) Colors.Ally = Value end)
    local HealthColor = ColorsSection:AddColorpicker("HealthColor", { Title = "Health Bar Color", Description = "Color for full health", Default = Colors.Health })
    HealthColor:OnChanged(function(Value) Colors.Health = Value end)

    local BoxSection = Tabs.Settings:AddSection("Box Settings")
    local BoxThickness = BoxSection:AddSlider("BoxThickness", { Title = "Box Thickness", Default = 1, Min = 1, Max = 5, Rounding = 1 })
    BoxThickness:OnChanged(function(Value) Settings.BoxThickness = Value end)
    local BoxTransparency = BoxSection:AddSlider("BoxTransparency", { Title = "Box Transparency", Default = 1, Min = 0, Max = 1, Rounding = 2 })
    BoxTransparency:OnChanged(function(Value) Settings.BoxFillTransparency = Value end)

    local ESPSection = Tabs.Settings:AddSection("ESP Settings")
    local MaxDistance = ESPSection:AddSlider("MaxDistance", { Title = "Max Distance", Default = 1000, Min = 100, Max = 5000, Rounding = 0 })
    MaxDistance:OnChanged(function(Value) Settings.MaxDistance = Value end)

    local TextSize = ESPSection:AddSlider("TextSize", { Title = "Text Size", Default = 14, Min = 10, Max = 24, Rounding = 0 })
    TextSize:OnChanged(function(Value) Settings.TextSize = Value end)

    local HealthTextFormat = ESPSection:AddDropdown("HealthTextFormat", { Title = "Health Format", Values = {"Number", "Percentage", "Both"}, Default = "Number" })
    HealthTextFormat:OnChanged(function(Value) Settings.HealthTextFormat = Value end)

    local EffectsSection = Tabs.Settings:AddSection("Effects")
    local RainbowToggle = EffectsSection:AddToggle("RainbowEnabled", { Title = "Rainbow Mode", Default = false })
    RainbowToggle:OnChanged(function() Settings.RainbowEnabled = RainbowToggle.Value end)

    local RainbowSpeed = EffectsSection:AddSlider("RainbowSpeed", { Title = "Rainbow Speed", Default = 1, Min = 0.1, Max = 5, Rounding = 1 })
    RainbowSpeed:OnChanged(function(Value) Settings.RainbowSpeed = Value end)

    local RainbowOptions = EffectsSection:AddDropdown("RainbowParts", { Title = "Rainbow Parts", Values = {"All", "Box Only", "Tracers Only", "Text Only"}, Default = "All", Multi = false })
    RainbowOptions:OnChanged(function(Value)
        if Value == "All" then
            Settings.RainbowBoxes = true; Settings.RainbowTracers = true; Settings.RainbowText = true
        elseif Value == "Box Only" then
            Settings.RainbowBoxes = true; Settings.RainbowTracers = false; Settings.RainbowText = false
        elseif Value == "Tracers Only" then
            Settings.RainbowBoxes = false; Settings.RainbowTracers = true; Settings.RainbowText = false
        elseif Value == "Text Only" then
            Settings.RainbowBoxes = false; Settings.RainbowTracers = false; Settings.RainbowText = true
        end
    end)

    local PerformanceSection = Tabs.Settings:AddSection("Performance")
    local RefreshRate = PerformanceSection:AddSlider("RefreshRate", { Title = "Refresh Rate", Default = 144, Min = 1, Max = 144, Rounding = 0 })
    RefreshRate:OnChanged(function(Value) Settings.RefreshRate = 1 / Value end)
end

do
    SaveManager:SetLibrary(Fluent)
    InterfaceManager:SetLibrary(Fluent)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({})
    InterfaceManager:SetFolder("WAUniversalESP")
    SaveManager:SetFolder("WAUniversalESP/configs")

    InterfaceManager:BuildInterfaceSection(Tabs.Config)
    SaveManager:BuildConfigSection(Tabs.Config)

    local UnloadSection = Tabs.Config:AddSection("Unload")
    local UnloadButton = UnloadSection:AddButton({
        Title = "Unload ESP",
        Description = "Completely remove the ESP",
        Callback = function()
            CleanupESP()
            -- try to disable any RenderStepped connections if possible (best-effort)
            pcall(function()
                for _, connection in pairs(getconnections(RunService.RenderStepped)) do
                    connection:Disable()
                end
            end)
            Window:Destroy()
            Drawings = nil
            Settings = nil
        end
    })
end

-- Rainbow updater (using time() instead of tick())
task.spawn(function()
    while task.wait(0.1) do
        Colors.Rainbow = Color3.fromHSV((time() * Settings.RainbowSpeed) % 1, 1, 1)
    end
end)

local lastUpdate = 0
RunService.RenderStepped:Connect(function()
    if not Settings.Enabled then
        DisableESP()
        return
    end

    local currentTime = time()
    if currentTime - lastUpdate >= Settings.RefreshRate then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                if not Drawings.ESP[player] then
                    CreateESP(player)
                end
                pcall(function() UpdateESP(player) end)
            end
        end
        lastUpdate = currentTime
    end
end)

Players.PlayerAdded:Connect(function(p) CreateESP(p) end)
Players.PlayerRemoving:Connect(function(p) RemoveESP(p) end)

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        CreateESP(player)
    end
end

Window:SelectTab(1)
Fluent:Notify({ Title = "WA Universal ESP", Content = "Loaded successfully!", Duration = 5 })

local SkeletonSection = Tabs.ESP:AddSection("Skeleton ESP")
local SkeletonESPToggle = SkeletonSection:AddToggle("SkeletonESP", { Title = "Skeleton ESP", Default = false })
SkeletonESPToggle:OnChanged(function() Settings.SkeletonESP = SkeletonESPToggle.Value end)

local SkeletonColor = SkeletonSection:AddColorpicker("SkeletonColor", { Title = "Skeleton Color", Default = Settings.SkeletonColor })
SkeletonColor:OnChanged(function(Value)
    Settings.SkeletonColor = Value
    for _, player in ipairs(Players:GetPlayers()) do
        local skeleton = Drawings.Skeleton[player]
        if skeleton then
            for _, line in pairs(skeleton) do line.Color = Value end
        end
    end
end)

local SkeletonThickness = SkeletonSection:AddSlider("SkeletonThickness", { Title = "Line Thickness", Default = 1, Min = 1, Max = 3, Rounding = 1 })
SkeletonThickness:OnChanged(function(Value)
    Settings.SkeletonThickness = Value
    for _, player in ipairs(Players:GetPlayers()) do
        local skeleton = Drawings.Skeleton[player]
        if skeleton then for _, line in pairs(skeleton) do line.Thickness = Value end end
    end
end)

local SkeletonTransparency = SkeletonSection:AddSlider("SkeletonTransparency", { Title = "Transparency", Default = 1, Min = 0, Max = 1, Rounding = 2 })
SkeletonTransparency:OnChanged(function(Value)
    Settings.SkeletonTransparency = Value
    for _, player in ipairs(Players:GetPlayers()) do
        local skeleton = Drawings.Skeleton[player]
        if skeleton then for _, line in pairs(skeleton) do line.Transparency = Value end end
    end
end)
