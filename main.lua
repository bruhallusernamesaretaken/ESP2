-- Improved WA Universal ESP (distance display removed for performance)
-- Assumes Drawing API + Highlight available (exploit environment)

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Drawings = {}
local Highlights = {}

local Colors = {
    Enemy = Color3.fromRGB(255, 25, 25),
    Ally = Color3.fromRGB(25, 255, 25),
    Neutral = Color3.fromRGB(255, 255, 255),
    Health = Color3.fromRGB(0, 255, 0),
    Rainbow = Color3.fromRGB(255,255,255)
}

local Settings = {
    Enabled = false,
    TeamCheck = false,
    ShowTeam = false,
    VisibilityCheck = true,
    BoxESP = false,
    BoxStyle = "Corner", -- Corner | Full | ThreeD
    BoxThickness = 1,
    TracerESP = false,
    TracerOrigin = "Bottom", -- Bottom | Top | Mouse | Center
    TracerThickness = 1,
    HealthESP = false,
    HealthStyle = "Bar", -- Bar | Text | Both
    HealthTextSuffix = "HP",
    NameESP = false,
    NameMode = "DisplayName", -- DisplayName | Username | Humanoid
    TextSize = 14,
    TextFont = 2,
    RainbowSpeed = 1,
    MaxDistance = 1000,
    RefreshRate = 1/144,
    Snaplines = false,
    RainbowEnabled = false,
    RainbowBoxes = false,
    RainbowTracers = false,
    RainbowText = false,
    ChamsEnabled = false,
    ChamsFillColor = Color3.fromRGB(255,0,0),
    ChamsOutlineColor = Color3.fromRGB(255,255,255),
    ChamsTransparency = 0.5,
    ChamsOutlineTransparency = 0,
    SkeletonESP = false,
    SkeletonColor = Color3.fromRGB(255,255,255),
    SkeletonThickness = 1.5,
    SkeletonTransparency = 1
}

local function GetTracerOrigin()
    local origin = Settings.TracerOrigin
    local vs = Camera.ViewportSize
    if origin == "Bottom" then
        return Vector2.new(vs.X/2, vs.Y)
    elseif origin == "Top" then
        return Vector2.new(vs.X/2, 0)
    elseif origin == "Mouse" then
        local x, y = UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y
        return Vector2.new(x, y)
    else
        return Vector2.new(vs.X/2, vs.Y/2)
    end
end

local function GetPlayerColor(player)
    if Settings.RainbowEnabled then
        if Settings.RainbowBoxes and Settings.BoxESP then return Colors.Rainbow end
        if Settings.RainbowTracers and Settings.TracerESP then return Colors.Rainbow end
        if Settings.RainbowText and (Settings.NameESP or Settings.HealthESP) then return Colors.Rainbow end
    end
    if Settings.TeamCheck and player.Team == LocalPlayer.Team then
        return Colors.Ally
    end
    return Colors.Enemy
end

local function WorldToScreenPoint(worldPos)
    local screenV3, onScreen = Camera:WorldToViewportPoint(worldPos)
    return Vector2.new(screenV3.X, screenV3.Y), onScreen, screenV3.Z
end

local function CreateESP(player)
    if player == LocalPlayer then return end
    if Drawings[player] then return end

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

    local connectors = {
        Drawing.new("Line"), Drawing.new("Line"), Drawing.new("Line"), Drawing.new("Line")
    }

    local tracer = Drawing.new("Line")
    local snapline = Drawing.new("Line")

    local healthOutline = Drawing.new("Square")
    local healthFill = Drawing.new("Square")
    local healthText = Drawing.new("Text")

    local nameText = Drawing.new("Text")

    local skeleton = {
        Head = Drawing.new("Line"),
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

    for _, l in pairs(box) do
        l.Visible = false
        l.Thickness = Settings.BoxThickness
        l.Color = Colors.Enemy
    end
    for _, l in pairs(connectors) do
        l.Visible = false
        l.Thickness = Settings.BoxThickness
        l.Color = Colors.Enemy
    end
    tracer.Visible = false
    tracer.Thickness = Settings.TracerThickness
    tracer.Color = Colors.Enemy

    snapline.Visible = false
    snapline.Thickness = 1
    snapline.Color = Colors.Enemy

    healthOutline.Visible = false
    healthOutline.Filled = false
    healthOutline.Size = Vector2.new(4, 20)
    healthFill.Visible = false
    healthFill.Filled = true
    healthText.Visible = false
    healthText.Center = true
    healthText.Size = Settings.TextSize
    healthText.Font = Settings.TextFont
    healthText.Color = Colors.Health

    nameText.Visible = false
    nameText.Center = true
    nameText.Size = Settings.TextSize
    nameText.Font = Settings.TextFont
    nameText.Outline = true
    nameText.Color = Colors.Enemy

    for _, l in pairs(skeleton) do
        l.Visible = false
        l.Thickness = Settings.SkeletonThickness
        l.Color = Settings.SkeletonColor
        l.Transparency = Settings.SkeletonTransparency
    end

    local highlight = Instance.new("Highlight")
    highlight.FillColor = Settings.ChamsFillColor
    highlight.OutlineColor = Settings.ChamsOutlineColor
    highlight.FillTransparency = Settings.ChamsTransparency
    highlight.OutlineTransparency = Settings.ChamsOutlineTransparency
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = Settings.ChamsEnabled

    Highlights[player] = highlight

    Drawings[player] = {
        Box = box,
        Connectors = connectors,
        Tracer = tracer,
        Snapline = snapline,
        Health = { Outline = healthOutline, Fill = healthFill, Text = healthText },
        Info = { Name = nameText },
        Skeleton = skeleton,
        Highlight = highlight
    }
end

local function RemoveESP(player)
    local d = Drawings[player]
    if not d then
        local h = Highlights[player]
        if h then h:Destroy(); Highlights[player] = nil end
        return
    end

    for _, obj in pairs(d.Box) do pcall(function() obj:Remove() end) end
    for _, obj in pairs(d.Connectors) do pcall(function() obj:Remove() end) end
    pcall(function() d.Tracer:Remove() end)
    pcall(function() d.Snapline:Remove() end)
    pcall(function() d.Health.Outline:Remove() end)
    pcall(function() d.Health.Fill:Remove() end)
    pcall(function() d.Health.Text:Remove() end)
    pcall(function() d.Info.Name:Remove() end)
    for _, l in pairs(d.Skeleton) do pcall(function() l:Remove() end) end

    local highlight = d.Highlight
    if highlight then
        highlight:Destroy()
    end

    Drawings[player] = nil
    Highlights[player] = nil
end

local function GetPlayerDisplayName(player, character)
    if Settings.NameMode == "Humanoid" and character then
        local hum = character:FindFirstChildWhichIsA("Humanoid")
        if hum and hum.DisplayName and hum.DisplayName ~= "" then
            return hum.DisplayName
        end
    end
    if player.DisplayName and player.DisplayName ~= "" then
        return player.DisplayName
    end
    return player.Name or ("Player"..tostring(player.UserId))
end

local function GetCharacterExtents(character)
    if not character then return Vector3.new(2, 5, 1), CFrame.new() end
    local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
    local size = character:GetExtentsSize()
    local cf = (root and root.CFrame) or character:GetModelCFrame()
    return size, cf
end

local function GetBoxCornersWorld(cf, size)
    local corners = {
        cf * CFrame.new(-size.X/2, -size.Y/2, -size.Z/2).p,
        cf * CFrame.new(-size.X/2, -size.Y/2,  size.Z/2).p,
        cf * CFrame.new(-size.X/2,  size.Y/2, -size.Z/2).p,
        cf * CFrame.new(-size.X/2,  size.Y/2,  size.Z/2).p,
        cf * CFrame.new( size.X/2, -size.Y/2, -size.Z/2).p,
        cf * CFrame.new( size.X/2, -size.Y/2,  size.Z/2).p,
        cf * CFrame.new( size.X/2,  size.Y/2, -size.Z/2).p,
        cf * CFrame.new( size.X/2,  size.Y/2,  size.Z/2).p
    }
    return corners
end

local function DrawBoneLine(aPart, bPart, line)
    if not aPart or not bPart or not line then
        if line then line.Visible = false end
        return
    end
    local aScreen, aVisible, aZ = WorldToScreenPoint(aPart.Position)
    local bScreen, bVisible, bZ = WorldToScreenPoint(bPart.Position)
    if not aVisible or not bVisible or aZ < 0 or bZ < 0 then
        line.Visible = false
        return
    end
    local vs = Camera.ViewportSize
    if aScreen.X < 0 or aScreen.X > vs.X or aScreen.Y < 0 or aScreen.Y > vs.Y then line.Visible = false; return end
    if bScreen.X < 0 or bScreen.X > vs.X or bScreen.Y < 0 or bScreen.Y > vs.Y then line.Visible = false; return end
    line.From = aScreen
    line.To = bScreen
    line.Visible = true
    line.Color = Settings.SkeletonColor
    line.Thickness = Settings.SkeletonThickness
    line.Transparency = Settings.SkeletonTransparency
end

local function UpdateESP(player)
    if not Settings.Enabled then return end
    local d = Drawings[player]
    if not d then return end

    local character = player.Character
    if not character then
        for _, obj in pairs(d.Box) do obj.Visible = false end
        for _, obj in pairs(d.Connectors) do obj.Visible = false end
        d.Tracer.Visible = false
        d.Snapline.Visible = false
        for _, obj in pairs(d.Health) do if obj then obj.Visible = false end end
        d.Info.Name.Visible = false
        for _, l in pairs(d.Skeleton) do l.Visible = false end
        if d.Highlight then d.Highlight.Enabled = false end
        return
    end

    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then
        for _, obj in pairs(d.Box) do obj.Visible = false end
        for _, obj in pairs(d.Connectors) do obj.Visible = false end
        d.Tracer.Visible = false
        d.Snapline.Visible = false
        for _, obj in pairs(d.Health) do if obj then obj.Visible = false end end
        d.Info.Name.Visible = false
        for _, l in pairs(d.Skeleton) do l.Visible = false end
        if d.Highlight then d.Highlight.Enabled = false end
        return
    end

    local humanoid = character:FindFirstChildWhichIsA("Humanoid")
    if not humanoid or (humanoid.Health and humanoid.Health <= 0) then
        for _, obj in pairs(d.Box) do obj.Visible = false end
        for _, obj in pairs(d.Connectors) do obj.Visible = false end
        d.Tracer.Visible = false
        d.Snapline.Visible = false
        for _, obj in pairs(d.Health) do if obj then obj.Visible = false end end
        d.Info.Name.Visible = false
        for _, l in pairs(d.Skeleton) do l.Visible = false end
        if d.Highlight then d.Highlight.Enabled = false end
        return
    end

    local pos3 = root.Position
    local screenCenter3, onScreen = Camera:WorldToViewportPoint(pos3)
    local distance = (pos3 - Camera.CFrame.Position).Magnitude
    if not onScreen or distance > Settings.MaxDistance then
        for _, obj in pairs(d.Box) do obj.Visible = false end
        for _, obj in pairs(d.Connectors) do obj.Visible = false end
        d.Tracer.Visible = false
        d.Snapline.Visible = false
        for _, obj in pairs(d.Health) do if obj then obj.Visible = false end end
        d.Info.Name.Visible = false
        for _, l in pairs(d.Skeleton) do l.Visible = false end
        if d.Highlight then d.Highlight.Enabled = false end
        return
    end

    if Settings.TeamCheck and player.Team == LocalPlayer.Team and not Settings.ShowTeam then
        for _, obj in pairs(d.Box) do obj.Visible = false end
        d.Tracer.Visible = false
        d.Snapline.Visible = false
        for _, obj in pairs(d.Health) do if obj then obj.Visible = false end end
        d.Info.Name.Visible = false
        for _, l in pairs(d.Skeleton) do l.Visible = false end
        if d.Highlight then d.Highlight.Enabled = false end
        return
    end

    if Settings.RainbowEnabled then
        Colors.Rainbow = Color3.fromHSV((tick() * Settings.RainbowSpeed) % 1, 1, 1)
    end

    local color = GetPlayerColor(player)

    local size, cf = GetCharacterExtents(character)
    local topV3, topOn = Camera:WorldToViewportPoint(cf.Position + Vector3.new(0, size.Y/2, 0))
    local bottomV3, bottomOn = Camera:WorldToViewportPoint(cf.Position - Vector3.new(0, size.Y/2, 0))
    if not topOn or not bottomOn or topV3.Z < 0 or bottomV3.Z < 0 then
        for _, obj in pairs(d.Box) do obj.Visible = false end
        for _, obj in pairs(d.Connectors) do obj.Visible = false end
    else
        local top2 = Vector2.new(topV3.X, topV3.Y)
        local bottom2 = Vector2.new(bottomV3.X, bottomV3.Y)
        local height = math.abs(bottom2.Y - top2.Y)
        local width = math.clamp(height * 0.5, 20, 400)

        local boxPos = Vector2.new(top2.X - width/2, top2.Y)
        local boxSize = Vector2.new(width, height)

        if Settings.BoxESP then
            if Settings.BoxStyle == "Corner" then
                local cornerSize = math.clamp(width * 0.2, 6, width/2)
                d.Box.TopLeft.From = boxPos
                d.Box.TopLeft.To = boxPos + Vector2.new(cornerSize, 0)
                d.Box.TopLeft.Visible = true

                d.Box.TopRight.From = boxPos + Vector2.new(boxSize.X, 0)
                d.Box.TopRight.To = boxPos + Vector2.new(boxSize.X - cornerSize, 0)
                d.Box.TopRight.Visible = true

                d.Box.BottomLeft.From = boxPos + Vector2.new(0, boxSize.Y)
                d.Box.BottomLeft.To = boxPos + Vector2.new(cornerSize, boxSize.Y)
                d.Box.BottomLeft.Visible = true

                d.Box.BottomRight.From = boxPos + Vector2.new(boxSize.X, boxSize.Y)
                d.Box.BottomRight.To = boxPos + Vector2.new(boxSize.X - cornerSize, boxSize.Y)
                d.Box.BottomRight.Visible = true

                d.Box.Left.From = boxPos
                d.Box.Left.To = boxPos + Vector2.new(0, cornerSize)
                d.Box.Left.Visible = true

                d.Box.Right.From = boxPos + Vector2.new(boxSize.X, 0)
                d.Box.Right.To = boxPos + Vector2.new(boxSize.X, cornerSize)
                d.Box.Right.Visible = true

                d.Box.Top.From = boxPos + Vector2.new(0, boxSize.Y)
                d.Box.Top.To = boxPos + Vector2.new(0, boxSize.Y - cornerSize)
                d.Box.Top.Visible = true

                d.Box.Bottom.From = boxPos + Vector2.new(boxSize.X, boxSize.Y)
                d.Box.Bottom.To = boxPos + Vector2.new(boxSize.X, boxSize.Y - cornerSize)
                d.Box.Bottom.Visible = true

                for _, c in pairs(d.Connectors) do c.Visible = false end

            elseif Settings.BoxStyle == "Full" then
                d.Box.Left.From = boxPos
                d.Box.Left.To = boxPos + Vector2.new(0, boxSize.Y)
                d.Box.Left.Visible = true

                d.Box.Right.From = boxPos + Vector2.new(boxSize.X, 0)
                d.Box.Right.To = boxPos + Vector2.new(boxSize.X, boxSize.Y)
                d.Box.Right.Visible = true

                d.Box.Top.From = boxPos
                d.Box.Top.To = boxPos + Vector2.new(boxSize.X, 0)
                d.Box.Top.Visible = true

                d.Box.Bottom.From = boxPos + Vector2.new(0, boxSize.Y)
                d.Box.Bottom.To = boxPos + Vector2.new(boxSize.X, boxSize.Y)
                d.Box.Bottom.Visible = true

                d.Box.TopLeft.Visible = false
                d.Box.TopRight.Visible = false
                d.Box.BottomLeft.Visible = false
                d.Box.BottomRight.Visible = false
                for _, c in pairs(d.Connectors) do c.Visible = false end

            else -- ThreeD
                local worldCorners = GetBoxCornersWorld(cf, size)
                local screens = {}
                local allVisible = true
                for i = 1, 8 do
                    local sV3, on = Camera:WorldToViewportPoint(worldCorners[i])
                    if not on or sV3.Z < 0 then allVisible = false break end
                    screens[i] = Vector2.new(sV3.X, sV3.Y)
                end
                if allVisible then
                    local frontTL = screens[3]
                    local frontTR = screens[7]
                    local frontBL = screens[1]
                    local frontBR = screens[5]
                    local backTL  = screens[4]
                    local backTR  = screens[8]
                    local backBL  = screens[2]
                    local backBR  = screens[6]

                    d.Box.TopLeft.From = frontTL
                    d.Box.TopLeft.To = frontTR
                    d.Box.TopLeft.Visible = true

                    d.Box.TopRight.From = frontTR
                    d.Box.TopRight.To = frontBR
                    d.Box.TopRight.Visible = true

                    d.Box.BottomLeft.From = frontBL
                    d.Box.BottomLeft.To = frontBR
                    d.Box.BottomLeft.Visible = true

                    d.Box.BottomRight.From = frontTL
                    d.Box.BottomRight.To = frontBL
                    d.Box.BottomRight.Visible = true

                    d.Box.Left.From = backTL
                    d.Box.Left.To = backTR
                    d.Box.Left.Visible = true

                    d.Box.Right.From = backTR
                    d.Box.Right.To = backBR
                    d.Box.Right.Visible = true

                    d.Box.Top.From = backBL
                    d.Box.Top.To = backBR
                    d.Box.Top.Visible = true

                    d.Box.Bottom.From = backTL
                    d.Box.Bottom.To = backBL
                    d.Box.Bottom.Visible = true

                    d.Connectors[1].From = frontTL; d.Connectors[1].To = backTL; d.Connectors[1].Visible = true
                    d.Connectors[2].From = frontTR; d.Connectors[2].To = backTR; d.Connectors[2].Visible = true
                    d.Connectors[3].From = frontBL; d.Connectors[3].To = backBL; d.Connectors[3].Visible = true
                    d.Connectors[4].From = frontBR; d.Connectors[4].To = backBR; d.Connectors[4].Visible = true
                else
                    for _, obj in pairs(d.Box) do obj.Visible = false end
                    for _, c in pairs(d.Connectors) do c.Visible = false end
                end
            end

            for _, obj in pairs(d.Box) do
                if obj.Visible then
                    obj.Color = color
                    obj.Thickness = Settings.BoxThickness
                end
            end
            for _, c in pairs(d.Connectors) do
                if c.Visible then
                    c.Color = color
                    c.Thickness = Settings.BoxThickness
                end
            end
        else
            for _, obj in pairs(d.Box) do obj.Visible = false end
            for _, c in pairs(d.Connectors) do c.Visible = false end
        end
    end

    if Settings.TracerESP then
        local origin = GetTracerOrigin()
        d.Tracer.From = origin
        d.Tracer.To = Vector2.new(screenCenter3.X, screenCenter3.Y)
        d.Tracer.Color = color
        d.Tracer.Thickness = Settings.TracerThickness
        d.Tracer.Visible = true
    else
        d.Tracer.Visible = false
    end

    if Settings.Snaplines then
        local vs = Camera.ViewportSize
        d.Snapline.From = Vector2.new(vs.X/2, vs.Y)
        d.Snapline.To = Vector2.new(screenCenter3.X, screenCenter3.Y)
        d.Snapline.Color = color
        d.Snapline.Visible = true
    else
        d.Snapline.Visible = false
    end

    if Settings.HealthESP and humanoid then
        local hp = humanoid.Health
        local maxhp = humanoid.MaxHealth > 0 and humanoid.MaxHealth or 100
        local hpPercent = math.clamp(hp / maxhp, 0, 1)
        local healthHeight = math.max(10, (math.abs((Camera:WorldToViewportPoint(root.Position - Vector3.new(0, size.Y/2, 0)).Y) - Camera:WorldToViewportPoint(root.Position + Vector3.new(0, size.Y/2, 0)).Y)))
        local barWidth = 6
        local barHeight = math.max(10, healthHeight * 0.9)
        local barPos = Vector2.new((screenCenter3.X - (barWidth/2)) - (math.clamp(size.X, 1, 50)), (screenCenter3.Y - barHeight/2))
        d.Health.Outline.Size = Vector2.new(barWidth, barHeight)
        d.Health.Outline.Position = barPos
        d.Health.Outline.Visible = true

        d.Health.Fill.Size = Vector2.new(barWidth - 2, barHeight * hpPercent)
        d.Health.Fill.Position = Vector2.new(barPos.X + 1, barPos.Y + (barHeight * (1 - hpPercent)))
        d.Health.Fill.Color = Color3.fromRGB(math.floor(255 - (255 * hpPercent)), math.floor(255 * hpPercent), 0)
        d.Health.Fill.Visible = true

        if Settings.HealthStyle == "Both" or Settings.HealthStyle == "Text" then
            local textStr
            if Settings.HealthTextFormat == "Percentage" then
                textStr = tostring(math.floor(hpPercent * 100)).."%"
            elseif Settings.HealthTextFormat == "Both" then
                textStr = tostring(math.floor(hp)).."/"..tostring(math.floor(maxhp)).." ("..tostring(math.floor(hpPercent*100)).."% )"
            else
                textStr = tostring(math.floor(hp))..Settings.HealthTextSuffix
            end
            d.Health.Text.Text = textStr
            d.Health.Text.Position = Vector2.new(barPos.X + barWidth + 6, barPos.Y + barHeight/2)
            d.Health.Text.Size = Settings.TextSize
            d.Health.Text.Color = Colors.Health
            d.Health.Text.Visible = true
        else
            d.Health.Text.Visible = false
        end
    else
        d.Health.Outline.Visible = false
        d.Health.Fill.Visible = false
        d.Health.Text.Visible = false
    end

    if Settings.NameESP then
        local displayName = GetPlayerDisplayName(player, character)
        local head = character:FindFirstChild("Head")
        local nameAnchor = head and head.Position + Vector3.new(0, 0.5, 0) or root.Position + Vector3.new(0, size.Y/2 + 0.2, 0)
        local nameScreenV3, nameOn = Camera:WorldToViewportPoint(nameAnchor)
        if nameOn and nameScreenV3.Z > 0 then
            d.Info.Name.Position = Vector2.new(nameScreenV3.X, nameScreenV3.Y - 18)
        else
            d.Info.Name.Position = Vector2.new(screenCenter3.X, screenCenter3.Y - 35)
        end
        d.Info.Name.Text = displayName
        d.Info.Name.Color = color
        d.Info.Name.Size = Settings.TextSize
        d.Info.Name.Font = Settings.TextFont
        d.Info.Name.Visible = true
    else
        d.Info.Name.Visible = false
    end

    if d.Highlight then
        if Settings.ChamsEnabled and character then
            d.Highlight.Parent = character
            d.Highlight.FillColor = Settings.ChamsFillColor
            d.Highlight.OutlineColor = Settings.ChamsOutlineColor
            d.Highlight.FillTransparency = Settings.ChamsTransparency
            d.Highlight.OutlineTransparency = Settings.ChamsOutlineTransparency
            d.Highlight.Enabled = true
        else
            d.Highlight.Enabled = false
        end
    end

    if Settings.SkeletonESP then
        local function findAnyCharPart(names)
            for _, n in ipairs(names) do
                local p = character:FindFirstChild(n)
                if p then return p end
            end
            return nil
        end
        local bones = {
            Head = character:FindFirstChild("Head"),
            UpperTorso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"),
            LowerTorso = character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso"),
            Root = character:FindFirstChild("HumanoidRootPart"),

            LeftUpperArm = findAnyCharPart({"LeftUpperArm","Left Arm"}),
            LeftLowerArm = findAnyCharPart({"LeftLowerArm","Left Arm"}),
            LeftHand = findAnyCharPart({"LeftHand","Left Arm"}),

            RightUpperArm = findAnyCharPart({"RightUpperArm","Right Arm"}),
            RightLowerArm = findAnyCharPart({"RightLowerArm","Right Arm"}),
            RightHand = findAnyCharPart({"RightHand","Right Arm"}),

            LeftUpperLeg = findAnyCharPart({"LeftUpperLeg","Left Leg"}),
            LeftLowerLeg = findAnyCharPart({"LeftLowerLeg","Left Leg"}),
            LeftFoot = findAnyCharPart({"LeftFoot","Left Leg"}),

            RightUpperLeg = findAnyCharPart({"RightUpperLeg","Right Leg"}),
            RightLowerLeg = findAnyCharPart({"RightLowerLeg","Right Leg"}),
            RightFoot = findAnyCharPart({"RightFoot","Right Leg"})
        }

        DrawBoneLine(bones.Head, bones.UpperTorso, d.Skeleton.Head)
        DrawBoneLine(bones.UpperTorso, bones.LowerTorso, d.Skeleton.UpperSpine)
        DrawBoneLine(bones.UpperTorso, bones.LeftUpperArm, d.Skeleton.LeftShoulder)
        DrawBoneLine(bones.LeftUpperArm, bones.LeftLowerArm, d.Skeleton.LeftUpperArm)
        DrawBoneLine(bones.LeftLowerArm, bones.LeftHand, d.Skeleton.LeftLowerArm)
        DrawBoneLine(bones.UpperTorso, bones.RightUpperArm, d.Skeleton.RightShoulder)
        DrawBoneLine(bones.RightUpperArm, bones.RightLowerArm, d.Skeleton.RightUpperArm)
        DrawBoneLine(bones.RightLowerArm, bones.RightHand, d.Skeleton.RightLowerArm)
        DrawBoneLine(bones.LowerTorso, bones.LeftUpperLeg, d.Skeleton.LeftHip)
        DrawBoneLine(bones.LeftUpperLeg, bones.LeftLowerLeg, d.Skeleton.LeftUpperLeg)
        DrawBoneLine(bones.LeftLowerLeg, bones.LeftFoot, d.Skeleton.LeftLowerLeg)
        DrawBoneLine(bones.LowerTorso, bones.RightUpperLeg, d.Skeleton.RightHip)
        DrawBoneLine(bones.RightUpperLeg, bones.RightLowerLeg, d.Skeleton.RightUpperLeg)
        DrawBoneLine(bones.RightLowerLeg, bones.RightFoot, d.Skeleton.RightLowerLeg)
    else
        for _, l in pairs(d.Skeleton) do l.Visible = false end
    end
end

local function DisableESP()
    for _, player in ipairs(Players:GetPlayers()) do
        local d = Drawings[player]
        if d then
            for _, obj in pairs(d.Box) do obj.Visible = false end
            for _, obj in pairs(d.Connectors) do obj.Visible = false end
            d.Tracer.Visible = false
            d.Snapline.Visible = false
            d.Health.Outline.Visible = false
            d.Health.Fill.Visible = false
            d.Health.Text.Visible = false
            d.Info.Name.Visible = false
            for _, l in pairs(d.Skeleton) do l.Visible = false end
            if d.Highlight then d.Highlight.Enabled = false end
        end
    end
end

local function CleanupESP()
    for _, player in ipairs(Players:GetPlayers()) do
        RemoveESP(player)
    end
    Drawings = {}
    Highlights = {}
end

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
    local EnabledToggle = MainSection:AddToggle("Enabled", { Title = "Enable ESP", Default = false })
    EnabledToggle:OnChanged(function()
        Settings.Enabled = EnabledToggle.Value
        if not Settings.Enabled then
            DisableESP()
        else
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then CreateESP(player) end
            end
        end
    end)

    local NameToggle = MainSection:AddToggle("NameESP", { Title = "Show Names", Default = false })
    NameToggle:OnChanged(function()
        Settings.NameESP = NameToggle.Value
    end)

    local NameModeDD = MainSection:AddDropdown("NameMode", { Title = "Name Mode", Values = {"DisplayName","Username","Humanoid"}, Default = "DisplayName" })
    NameModeDD:OnChanged(function(val)
        Settings.NameMode = val
    end)

    local TeamCheckToggle = MainSection:AddToggle("TeamCheck", { Title = "Team Check", Default = false })
    TeamCheckToggle:OnChanged(function() Settings.TeamCheck = TeamCheckToggle.Value end)

    local ShowTeamToggle = MainSection:AddToggle("ShowTeam", { Title = "Show Team", Default = false })
    ShowTeamToggle:OnChanged(function() Settings.ShowTeam = ShowTeamToggle.Value end)
end

do
    local BoxSection = Tabs.ESP:AddSection("Box ESP")
    local BoxESPToggle = BoxSection:AddToggle("BoxESP", { Title = "Box ESP", Default = false })
    BoxESPToggle:OnChanged(function() Settings.BoxESP = BoxESPToggle.Value end)
    local BoxStyleDropdown = BoxSection:AddDropdown("BoxStyle", { Title = "Box Style", Values = {"Corner","Full","ThreeD"}, Default = "Corner" })
    BoxStyleDropdown:OnChanged(function(v) Settings.BoxStyle = v end)
end

do
    local TracerSection = Tabs.ESP:AddSection("Tracer ESP")
    local TracerESPToggle = TracerSection:AddToggle("TracerESP", { Title = "Tracer ESP", Default = false })
    TracerESPToggle:OnChanged(function() Settings.TracerESP = TracerESPToggle.Value end)
    local TracerOriginDropdown = TracerSection:AddDropdown("TracerOrigin", { Title = "Tracer Origin", Values = {"Bottom","Top","Mouse","Center"}, Default = "Bottom" })
    TracerOriginDropdown:OnChanged(function(Value) Settings.TracerOrigin = Value end)
    local SnaplineToggle = TracerSection:AddToggle("Snaplines", { Title = "Snaplines", Default = false })
    SnaplineToggle:OnChanged(function() Settings.Snaplines = SnaplineToggle.Value end)
end

do
    local ChamsSection = Tabs.ESP:AddSection("Chams")
    local ChamsToggle = ChamsSection:AddToggle("ChamsEnabled", { Title = "Enable Chams", Default = false })
    ChamsToggle:OnChanged(function() Settings.ChamsEnabled = ChamsToggle.Value end)
end

do
    local HealthSection = Tabs.ESP:AddSection("Health ESP")
    local HealthESPToggle = HealthSection:AddToggle("HealthESP", { Title = "Health Bar", Default = false })
    HealthESPToggle:OnChanged(function() Settings.HealthESP = HealthESPToggle.Value end)
    local HealthStyleDropdown = HealthSection:AddDropdown("HealthStyle", { Title = "Health Style", Values = {"Bar","Text","Both"}, Default = "Bar" })
    HealthStyleDropdown:OnChanged(function(Value) Settings.HealthStyle = Value end)
end

do
    local ColorsSection = Tabs.Settings:AddSection("Colors")
    local EnemyColor = ColorsSection:AddColorpicker("EnemyColor", { Title = "Enemy Color", Default = Colors.Enemy })
    EnemyColor:OnChanged(function(Value) Colors.Enemy = Value end)
    local AllyColor = ColorsSection:AddColorpicker("AllyColor", { Title = "Ally Color", Default = Colors.Ally })
    AllyColor:OnChanged(function(Value) Colors.Ally = Value end)

    local Perf = Tabs.Settings:AddSection("Performance")
    local RefreshRate = Perf:AddSlider("RefreshRate", { Title = "Refresh Rate", Default = 144, Min = 1, Max = 144, Rounding = 0 })
    RefreshRate:OnChanged(function(Value) Settings.RefreshRate = 1/Value end)
    local MaxDistance = Perf:AddSlider("MaxDistance", { Title = "Max Distance", Default = 1000, Min = 100, Max = 5000, Rounding = 0 })
    MaxDistance:OnChanged(function(Value) Settings.MaxDistance = Value end)
end

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:SetFolder("WAUniversalESP")
SaveManager:SetFolder("WAUniversalESP/configs")
InterfaceManager:BuildInterfaceSection(Tabs.Config)
SaveManager:BuildConfigSection(Tabs.Config)

task.spawn(function()
    while task.wait(0.05) do
        if Settings.RainbowEnabled then
            Colors.Rainbow = Color3.fromHSV((tick() * Settings.RainbowSpeed) % 1, 1, 1)
        end
    end
end)

local lastUpdate = 0
RunService.RenderStepped:Connect(function()
    if not Settings.Enabled then
        DisableESP()
        return
    end
    local now = tick()
    if now - lastUpdate < Settings.RefreshRate then return end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if not Drawings[player] then CreateESP(player) end
            pcall(function() UpdateESP(player) end)
        end
    end
    lastUpdate = now
end)

Players.PlayerAdded:Connect(function(pl) if pl ~= LocalPlayer then CreateESP(pl) end end)
Players.PlayerRemoving:Connect(function(pl) RemoveESP(pl) end)

for _, pl in ipairs(Players:GetPlayers()) do
    if pl ~= LocalPlayer then CreateESP(pl) end
end

Window:SelectTab(1)
Fluent:Notify({ Title = "WA Universal ESP", Content = "Loaded successfully!", Duration = 5 })
