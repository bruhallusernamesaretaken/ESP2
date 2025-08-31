-- Improved WA Universal ESP (chams removed, distance checks removed, names fixed,
-- health bar always visible, text offset when Both)

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
    Snaplines = {},
    Skeleton = {}
}

local Colors = {
    Enemy = Color3.fromRGB(255, 25, 25),
    Ally = Color3.fromRGB(25, 255, 25),
    Neutral = Color3.fromRGB(255, 255, 255),
    Selected = Color3.fromRGB(255, 210, 0),
    Health = Color3.fromRGB(0, 255, 0),
    Rainbow = nil
}

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
    HealthStyle = "Bar", -- "Bar", "Text", "Both"
    HealthBarSide = "Left",
    HealthTextSuffix = "HP",

    NameESP = false,
    NameMode = "DisplayName", -- "DisplayName" or "Name"

    TextSize = 14,
    TextFont = 2,
    RainbowSpeed = 1,
    RefreshRate = 1/144,
    Snaplines = false,
    SnaplineStyle = "Straight",
    RainbowEnabled = false,
    RainbowBoxes = false,
    RainbowTracers = false,
    RainbowText = false,

    SkeletonESP = false,
    SkeletonColor = Color3.fromRGB(255, 255, 255),
    SkeletonThickness = 1.5,
    SkeletonTransparency = 1
}

local function CreateESP(player)
    if player == LocalPlayer then return end

    -- Box lines (8 corner lines reused for different styles)
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

    -- Tracer
    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Color = Colors.Enemy
    tracer.Thickness = Settings.TracerThickness

    -- HealthBar (Outline + Fill + Text)
    local healthBar = {
        Outline = Drawing.new("Square"),
        Fill = Drawing.new("Square"),
        Text = Drawing.new("Text")
    }

    -- IMPORTANT: center = false for health text so we can offset it when needed
    healthBar.Outline.Visible = false
    healthBar.Outline.Filled = false

    healthBar.Fill.Visible = false
    healthBar.Fill.Filled = true
    healthBar.Fill.Color = Colors.Health

    healthBar.Text.Visible = false
    healthBar.Text.Size = Settings.TextSize
    healthBar.Text.Color = Colors.Health
    healthBar.Text.Font = Settings.TextFont
    healthBar.Text.Center = false -- allow offset to the right of the bar
    healthBar.Text.Outline = true

    -- Info: Name
    local info = {
        Name = Drawing.new("Text")
    }

    info.Name.Visible = false
    info.Name.Center = true
    info.Name.Size = Settings.TextSize
    info.Name.Color = Colors.Enemy
    info.Name.Font = Settings.TextFont
    info.Name.Outline = true

    -- Snapline (alias/tracer bottom->player)
    local snapline = Drawing.new("Line")
    snapline.Visible = false
    snapline.Color = Colors.Enemy
    snapline.Thickness = 1

    -- Skeleton (many lines)
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
            if obj then
                pcall(function() obj:Remove() end)
            end
        end

        if esp.Tracer then pcall(function() esp.Tracer:Remove() end) end

        for _, obj in pairs(esp.HealthBar) do
            if obj then pcall(function() obj:Remove() end) end
        end

        for _, obj in pairs(esp.Info) do
            if obj then pcall(function() obj:Remove() end) end
        end

        if esp.Snapline then pcall(function() esp.Snapline:Remove() end) end

        Drawings.ESP[player] = nil
    end

    local skeleton = Drawings.Skeleton[player]
    if skeleton then
        for _, line in pairs(skeleton) do
            if line then pcall(function() line:Remove() end) end
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
    return (player.Team == LocalPlayer.Team) and Colors.Ally or Colors.Enemy
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
        corners[i] = cf:PointToWorldSpace(corner)
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
        return UserInputService:GetMouseLocation()
    else
        return Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    end
end

local function UpdateESP(player)
    if not Settings.Enabled then return end
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

    local rootPart = character:FindFirstChild("HumanoidRootPart")
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

    local humanoid = character:FindFirstChild("Humanoid")
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

    -- Early screen check
    local pos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
    if not onScreen then
        for _, obj in pairs(esp.Box) do if obj then obj.Visible = false end end
        if esp.Tracer then esp.Tracer.Visible = false end
        for _, obj in pairs(esp.HealthBar) do if obj then obj.Visible = false end end
        for _, obj in pairs(esp.Info) do if obj then obj.Visible = false end end
        if esp.Snapline then esp.Snapline.Visible = false end

        local skeleton = Drawings.Skeleton[player]
        if skeleton then for _, line in pairs(skeleton) do line.Visible = false end end
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

    local top, top_onscreen = Camera:WorldToViewportPoint(cf * CFrame.new(0, size.Y/2, 0).Position)
    local bottom, bottom_onscreen = Camera:WorldToViewportPoint(cf * CFrame.new(0, -size.Y/2, 0).Position)

    if not top_onscreen or not bottom_onscreen then
        for _, obj in pairs(esp.Box) do if obj then obj.Visible = false end end
        return
    end

    local screenSize = bottom.Y - top.Y
    local boxWidth = screenSize * 0.65
    local boxPosition = Vector2.new(top.X - boxWidth/2, top.Y)
    local boxSize = Vector2.new(boxWidth, screenSize)

    -- Hide defaults
    for _, obj in pairs(esp.Box) do if obj then obj.Visible = false end end

    if Settings.BoxESP then
        if Settings.BoxStyle == "ThreeD" then
            local function w2v(pos) return Camera:WorldToViewportPoint(pos) end
            local front = {
                TL = w2v((cf * CFrame.new(-size.X/2, size.Y/2, -size.Z/2)).Position),
                TR = w2v((cf * CFrame.new(size.X/2, size.Y/2, -size.Z/2)).Position),
                BL = w2v((cf * CFrame.new(-size.X/2, -size.Y/2, -size.Z/2)).Position),
                BR = w2v((cf * CFrame.new(size.X/2, -size.Y/2, -size.Z/2)).Position)
            }

            local back = {
                TL = w2v((cf * CFrame.new(-size.X/2, size.Y/2, size.Z/2)).Position),
                TR = w2v((cf * CFrame.new(size.X/2, size.Y/2, size.Z/2)).Position),
                BL = w2v((cf * CFrame.new(-size.X/2, -size.Y/2, size.Z/2)).Position),
                BR = w2v((cf * CFrame.new(size.X/2, -size.Y/2, size.Z/2)).Position)
            }

            if not (front.TL.Z > 0 and front.TR.Z > 0 and front.BL.Z > 0 and front.BR.Z > 0 and
                   back.TL.Z > 0 and back.TR.Z > 0 and back.BL.Z > 0 and back.BR.Z > 0) then
                for _, obj in pairs(esp.Box) do if obj then obj.Visible = false end end
                return
            end

            local function toVec2(v3) return Vector2.new(v3.X, v3.Y) end
            front.TL, front.TR = toVec2(front.TL), toVec2(front.TR)
            front.BL, front.BR = toVec2(front.BL), toVec2(front.BR)
            back.TL, back.TR = toVec2(back.TL), toVec2(back.TR)
            back.BL, back.BR = toVec2(back.BL), toVec2(back.BR)

            -- front face
            esp.Box.TopLeft.From = front.TL
            esp.Box.TopLeft.To = front.TR
            esp.Box.TopLeft.Visible = true

            esp.Box.TopRight.From = front.TR
            esp.Box.TopRight.To = front.BR
            esp.Box.TopRight.Visible = true

            esp.Box.BottomLeft.From = front.BL
            esp.Box.BottomLeft.To = front.BR
            esp.Box.BottomLeft.Visible = true

            esp.Box.BottomRight.From = front.TL
            esp.Box.BottomRight.To = front.BL
            esp.Box.BottomRight.Visible = true

            -- back face
            esp.Box.Left.From = back.TL
            esp.Box.Left.To = back.TR
            esp.Box.Left.Visible = true

            esp.Box.Right.From = back.TR
            esp.Box.Right.To = back.BR
            esp.Box.Right.Visible = true

            esp.Box.Top.From = back.BL
            esp.Box.Top.To = back.BR
            esp.Box.Top.Visible = true

            esp.Box.Bottom.From = back.TL
            esp.Box.Bottom.To = back.BL
            esp.Box.Bottom.Visible = true

            -- connectors (temporary lines)
            local function drawConnectingLine(from, to)
                local line = Drawing.new("Line")
                line.Visible = true
                line.Color = color
                line.Thickness = Settings.BoxThickness
                line.From = from
                line.To = to
                return line
            end

            local connectors = {
                drawConnectingLine(front.TL, back.TL),
                drawConnectingLine(front.TR, back.TR),
                drawConnectingLine(front.BL, back.BL),
                drawConnectingLine(front.BR, back.BR)
            }

            task.spawn(function()
                task.wait()
                for _, line in ipairs(connectors) do
                    pcall(function() line:Remove() end)
                end
            end)

        elseif Settings.BoxStyle == "Corner" then
            local cornerSize = boxWidth * 0.2

            esp.Box.TopLeft.From = boxPosition
            esp.Box.TopLeft.To = boxPosition + Vector2.new(cornerSize, 0)
            esp.Box.TopLeft.Visible = true

            esp.Box.TopRight.From = boxPosition + Vector2.new(boxSize.X, 0)
            esp.Box.TopRight.To = boxPosition + Vector2.new(boxSize.X - cornerSize, 0)
            esp.Box.TopRight.Visible = true

            esp.Box.BottomLeft.From = boxPosition + Vector2.new(0, boxSize.Y)
            esp.Box.BottomLeft.To = boxPosition + Vector2.new(cornerSize, boxSize.Y)
            esp.Box.BottomLeft.Visible = true

            esp.Box.BottomRight.From = boxPosition + Vector2.new(boxSize.X, boxSize.Y)
            esp.Box.BottomRight.To = boxPosition + Vector2.new(boxSize.X - cornerSize, boxSize.Y)
            esp.Box.BottomRight.Visible = true

            esp.Box.Left.From = boxPosition
            esp.Box.Left.To = boxPosition + Vector2.new(0, cornerSize)
            esp.Box.Left.Visible = true

            esp.Box.Right.From = boxPosition + Vector2.new(boxSize.X, 0)
            esp.Box.Right.To = boxPosition + Vector2.new(boxSize.X, cornerSize)
            esp.Box.Right.Visible = true

            esp.Box.Top.From = boxPosition + Vector2.new(0, boxSize.Y)
            esp.Box.Top.To = boxPosition + Vector2.new(0, boxSize.Y - cornerSize)
            esp.Box.Top.Visible = true

            esp.Box.Bottom.From = boxPosition + Vector2.new(boxSize.X, boxSize.Y)
            esp.Box.Bottom.To = boxPosition + Vector2.new(boxSize.X, boxSize.Y - cornerSize)
            esp.Box.Bottom.Visible = true

        else -- Full box
            esp.Box.Left.From = boxPosition
            esp.Box.Left.To = boxPosition + Vector2.new(0, boxSize.Y)
            esp.Box.Left.Visible = true

            esp.Box.Right.From = boxPosition + Vector2.new(boxSize.X, 0)
            esp.Box.Right.To = boxPosition + Vector2.new(boxSize.X, boxSize.Y)
            esp.Box.Right.Visible = true

            esp.Box.Top.From = boxPosition
            esp.Box.Top.To = boxPosition + Vector2.new(boxSize.X, 0)
            esp.Box.Top.Visible = true

            esp.Box.Bottom.From = boxPosition + Vector2.new(0, boxSize.Y)
            esp.Box.Bottom.To = boxPosition + Vector2.new(boxSize.X, boxSize.Y)
            esp.Box.Bottom.Visible = true

            esp.Box.TopLeft.Visible = false
            esp.Box.TopRight.Visible = false
            esp.Box.BottomLeft.Visible = false
            esp.Box.BottomRight.Visible = false
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
        esp.Tracer.To = Vector2.new(pos.X, pos.Y)
        esp.Tracer.Color = color
        esp.Tracer.Visible = true
    else
        if esp.Tracer then esp.Tracer.Visible = false end
    end

    -- Health: ALWAYS show bar (per request).
    if esp.HealthBar then
        local health = humanoid.Health
        local maxHealth = humanoid.MaxHealth
        local healthPercent = math.clamp( (health / (maxHealth > 0 and maxHealth or 1)), 0, 1)

        local barHeight = screenSize * 0.8
        local barWidth = 6
        local barPos = Vector2.new(
            boxPosition.X - barWidth - 4,
            boxPosition.Y + (screenSize - barHeight)/2
        )

        -- Outline (background)
        esp.HealthBar.Outline.Size = Vector2.new(barWidth, barHeight)
        esp.HealthBar.Outline.Position = barPos
        esp.HealthBar.Outline.Visible = true
        esp.HealthBar.Outline.Color = Color3.new(0,0,0)

        -- Fill (dynamic)
        esp.HealthBar.Fill.Size = Vector2.new(barWidth - 2, barHeight * healthPercent)
        esp.HealthBar.Fill.Position = Vector2.new(barPos.X + 1, barPos.Y + barHeight * (1 - healthPercent))
        esp.HealthBar.Fill.Color = Color3.fromRGB(
            math.clamp(255 - (255 * healthPercent), 0, 255),
            math.clamp(255 * healthPercent, 0, 255),
            0
        )
        esp.HealthBar.Fill.Visible = true

        -- Text: when "Text" or "Both" -> show text offset to the right of the bar.
        if Settings.HealthStyle == "Text" or Settings.HealthStyle == "Both" then
            local textStr
            if Settings.HealthTextFormat == "Percentage" then
                textStr = math.floor(healthPercent * 100) .. "%" .. (Settings.HealthTextSuffix or "")
            elseif Settings.HealthTextFormat == "Both" then
                textStr = math.floor(health) .. " / " .. math.floor(maxHealth) .. (Settings.HealthTextSuffix or "")
            else -- "Number" or default
                textStr = math.floor(health) .. (Settings.HealthTextSuffix or "")
            end

            esp.HealthBar.Text.Text = textStr
            -- offset to the right of bar
            esp.HealthBar.Text.Position = Vector2.new(barPos.X + barWidth + 6, barPos.Y + (barHeight/2) - (esp.HealthBar.Text.Size/2))
            esp.HealthBar.Text.Color = Colors.Health
            esp.HealthBar.Text.Visible = true
        else
            esp.HealthBar.Text.Visible = false
        end
    end

    -- Name
    if Settings.NameESP and esp.Info and esp.Info.Name then
        local nameText = (Settings.NameMode == "DisplayName" and player.DisplayName and tostring(player.DisplayName) ~= "" and player.DisplayName) or player.Name
        esp.Info.Name.Text = nameText
        esp.Info.Name.Position = Vector2.new(
            boxPosition.X + boxWidth/2,
            boxPosition.Y - 20
        )
        esp.Info.Name.Color = color
        esp.Info.Name.Visible = true
    else
        if esp.Info and esp.Info.Name then esp.Info.Name.Visible = false end
    end

    -- Snapline
    if Settings.Snaplines and esp.Snapline then
        esp.Snapline.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
        esp.Snapline.To = Vector2.new(pos.X, pos.Y)
        esp.Snapline.Color = color
        esp.Snapline.Visible = true
    else
        if esp.Snapline then esp.Snapline.Visible = false end
    end

    -- Skeleton
    if Settings.SkeletonESP then
        local function getBonePositions(character)
            if not character then return nil end

            local bones = {
                Head = character:FindFirstChild("Head"),
                UpperTorso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"),
                LowerTorso = character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso"),
                RootPart = character:FindFirstChild("HumanoidRootPart"),

                LeftUpperArm = character:FindFirstChild("LeftUpperArm") or character:FindFirstChild("Left Arm"),
                LeftLowerArm = character:FindFirstChild("LeftLowerArm") or character:FindFirstChild("Left Arm"),
                LeftHand = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm"),

                RightUpperArm = character:FindFirstChild("RightUpperArm") or character:FindFirstChild("Right Arm"),
                RightLowerArm = character:FindFirstChild("RightLowerArm") or character:FindFirstChild("Right Arm"),
                RightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"),

                LeftUpperLeg = character:FindFirstChild("LeftUpperLeg") or character:FindFirstChild("Left Leg"),
                LeftLowerLeg = character:FindFirstChild("LeftLowerLeg") or character:FindFirstChild("Left Leg"),
                LeftFoot = character:FindFirstChild("LeftFoot") or character:FindFirstChild("Left Leg"),

                RightUpperLeg = character:FindFirstChild("RightUpperLeg") or character:FindFirstChild("Right Leg"),
                RightLowerLeg = character:FindFirstChild("RightLowerLeg") or character:FindFirstChild("Right Leg"),
                RightFoot = character:FindFirstChild("RightFoot") or character:FindFirstChild("Right Leg")
            }

            if not (bones.Head and bones.UpperTorso) then return nil end
            return bones
        end

        local function drawBone(fromPart, toPart, line)
            if not fromPart or not toPart then
                line.Visible = false
                return
            end

            local fromPos = fromPart.Position
            local toPos = toPart.Position

            local fromScreen, fromVisible = Camera:WorldToViewportPoint(fromPos)
            local toScreen, toVisible = Camera:WorldToViewportPoint(toPos)

            if not (fromVisible and toVisible) or fromScreen.Z < 0 or toScreen.Z < 0 then
                line.Visible = false
                return
            end

            local screenBounds = Camera.ViewportSize
            if fromScreen.X < 0 or fromScreen.X > screenBounds.X or
               fromScreen.Y < 0 or fromScreen.Y > screenBounds.Y or
               toScreen.X < 0 or toScreen.X > screenBounds.X or
               toScreen.Y < 0 or toScreen.Y > screenBounds.Y then
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
        local skeleton = Drawings.Skeleton[player]
        if bones and skeleton then
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
        else
            if skeleton then
                for _, line in pairs(skeleton) do
                    line.Visible = false
                end
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
end

-- UI creation (Fluent)
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

do
    local MainSection = Tabs.ESP:AddSection("Main ESP")

    local EnabledToggle = MainSection:AddToggle("Enabled", {
        Title = "Enable ESP",
        Default = false
    })
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

    local TeamCheckToggle = MainSection:AddToggle("TeamCheck", {
        Title = "Team Check",
        Default = false
    })
    TeamCheckToggle:OnChanged(function()
        Settings.TeamCheck = TeamCheckToggle.Value
    end)

    local ShowTeamToggle = MainSection:AddToggle("ShowTeam", {
        Title = "Show Team",
        Default = false
    })
    ShowTeamToggle:OnChanged(function()
        Settings.ShowTeam = ShowTeamToggle.Value
    end)

    -- Name toggle + mode
    local NameToggle = MainSection:AddToggle("NameESP", {
        Title = "Show Name",
        Default = false
    })
    NameToggle:OnChanged(function()
        Settings.NameESP = NameToggle.Value
    end)

    local NameModeDropdown = MainSection:AddDropdown("NameMode", {
        Title = "Name Mode",
        Values = {"DisplayName", "Name"},
        Default = "DisplayName"
    })
    NameModeDropdown:OnChanged(function(val)
        Settings.NameMode = val
    end)
end

do
    local BoxSection = Tabs.ESP:AddSection("Box ESP")

    local BoxESPToggle = BoxSection:AddToggle("BoxESP", {
        Title = "Box ESP",
        Default = false
    })
    BoxESPToggle:OnChanged(function()
        Settings.BoxESP = BoxESPToggle.Value
    end)

    local BoxStyleDropdown = BoxSection:AddDropdown("BoxStyle", {
        Title = "Box Style",
        Values = {"Corner", "Full", "ThreeD"},
        Default = "Corner"
    })
    BoxStyleDropdown:OnChanged(function(Value)
        Settings.BoxStyle = Value
    end)
end

do
    local TracerSection = Tabs.ESP:AddSection("Tracer ESP")

    local TracerESPToggle = TracerSection:AddToggle("TracerESP", {
        Title = "Tracer ESP",
        Default = false
    })
    TracerESPToggle:OnChanged(function()
        Settings.TracerESP = TracerESPToggle.Value
    end)

    local TracerOriginDropdown = TracerSection:AddDropdown("TracerOrigin", {
        Title = "Tracer Origin",
        Values = {"Bottom", "Top", "Mouse", "Center"},
        Default = "Bottom"
    })
    TracerOriginDropdown:OnChanged(function(Value)
        Settings.TracerOrigin = Value
    end)
end

do
    local HealthSection = Tabs.ESP:AddSection("Health ESP")

    local HealthESPToggle = HealthSection:AddToggle("HealthESP", {
        Title = "Health Bar",
        Default = false
    })
    HealthESPToggle:OnChanged(function()
        Settings.HealthESP = HealthESPToggle.Value
    end)

    local HealthStyleDropdown = HealthSection:AddDropdown("HealthStyle", {
        Title = "Health Style",
        Values = {"Bar", "Text", "Both"},
        Default = "Bar"
    })
    HealthStyleDropdown:OnChanged(function(Value)
        Settings.HealthStyle = Value
    end)

    local HealthTextFormat = HealthSection:AddDropdown("HealthTextFormat", {
        Title = "Health Format",
        Values = {"Number", "Percentage", "Both"},
        Default = "Number"
    })
    HealthTextFormat:OnChanged(function(Value)
        Settings.HealthTextFormat = Value
    end)
end

do
    local SkeletonSection = Tabs.ESP:AddSection("Skeleton ESP")

    local SkeletonESPToggle = SkeletonSection:AddToggle("SkeletonESP", {
        Title = "Skeleton ESP",
        Default = false
    })
    SkeletonESPToggle:OnChanged(function()
        Settings.SkeletonESP = SkeletonESPToggle.Value
    end)

    local SkeletonColor = SkeletonSection:AddColorpicker("SkeletonColor", {
        Title = "Skeleton Color",
        Default = Settings.SkeletonColor
    })
    SkeletonColor:OnChanged(function(Value)
        Settings.SkeletonColor = Value
        for _, player in ipairs(Players:GetPlayers()) do
            local skeleton = Drawings.Skeleton[player]
            if skeleton then
                for _, line in pairs(skeleton) do
                    line.Color = Value
                end
            end
        end
    end)

    local SkeletonThickness = SkeletonSection:AddSlider("SkeletonThickness", {
        Title = "Line Thickness",
        Default = 1,
        Min = 1,
        Max = 3,
        Rounding = 1
    })
    SkeletonThickness:OnChanged(function(Value)
        Settings.SkeletonThickness = Value
        for _, player in ipairs(Players:GetPlayers()) do
            local skeleton = Drawings.Skeleton[player]
            if skeleton then
                for _, line in pairs(skeleton) do
                    line.Thickness = Value
                end
            end
        end
    end)

    local SkeletonTransparency = SkeletonSection:AddSlider("SkeletonTransparency", {
        Title = "Transparency",
        Default = 1,
        Min = 0,
        Max = 1,
        Rounding = 2
    })
    SkeletonTransparency:OnChanged(function(Value)
        Settings.SkeletonTransparency = Value
        for _, player in ipairs(Players:GetPlayers()) do
            local skeleton = Drawings.Skeleton[player]
            if skeleton then
                for _, line in pairs(skeleton) do
                    line.Transparency = Value
                end
            end
        end
    end)
end

do
    local ColorsSection = Tabs.Settings:AddSection("Colors")

    local EnemyColor = ColorsSection:AddColorpicker("EnemyColor", {
        Title = "Enemy Color",
        Description = "Color for enemy players",
        Default = Colors.Enemy
    })
    EnemyColor:OnChanged(function(Value)
        Colors.Enemy = Value
    end)

    local AllyColor = ColorsSection:AddColorpicker("AllyColor", {
        Title = "Ally Color",
        Description = "Color for team members",
        Default = Colors.Ally
    })
    AllyColor:OnChanged(function(Value)
        Colors.Ally = Value
    end)

    local HealthColor = ColorsSection:AddColorpicker("HealthColor", {
        Title = "Health Bar Color",
        Description = "Color for full health",
        Default = Colors.Health
    })
    HealthColor:OnChanged(function(Value)
        Colors.Health = Value
    end)
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
            for _, connection in pairs(getconnections(RunService.RenderStepped)) do
                connection:Disable()
            end
            Window:Destroy()
            Drawings = nil
            Settings = nil
            for k, v in pairs(getfenv(1)) do
                getfenv(1)[k] = nil
            end
        end
    })
end

task.spawn(function()
    while task.wait(0.1) do
        Colors.Rainbow = Color3.fromHSV(tick() * Settings.RainbowSpeed % 1, 1, 1)
    end
end)

local lastUpdate = 0
RunService.RenderStepped:Connect(function()
    if not Settings.Enabled then
        DisableESP()
        return
    end

    local currentTime = tick()
    if currentTime - lastUpdate >= Settings.RefreshRate then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                if not Drawings.ESP[player] then
                    CreateESP(player)
                end
                UpdateESP(player)
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

Fluent:Notify({
    Title = "WA Universal ESP",
    Content = "Loaded successfully!",
    Duration = 5
})
