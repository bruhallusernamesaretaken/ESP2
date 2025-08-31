-- WA Universal ESP (v2.1) — fixes 3D update + perf tweaks

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local function clamp(v,a,b) if v < a then return a elseif v > b then return b else return v end end

local Drawings = {}
Drawings.ESP = {}
Drawings.Skeleton = {}

local Colors = {
    Enemy = Color3.fromRGB(255,25,25),
    Ally = Color3.fromRGB(25,255,25),
    Distance = Color3.fromRGB(200,200,200)
}

local Settings = {
    Enabled = true,
    MaxDistance = 1000,
    RefreshRate = 1/60,
    BoxESP = true,
    BoxStyle = "Corner", -- "Corner", "Full", "ThreeD"
    TracerESP = true,
    TracerOrigin = "Bottom",
    HealthESP = true,
    NameESP = true,
    ShowDistance = true,
    SkeletonESP = false,
    BoxThickness = 1,
    TextSize = 14,
    TextFont = 2
}

-- Create once per-player, reuse forever
local function CreateESP(player)
    if player == LocalPlayer then return end
    if Drawings.ESP[player] then return end

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
    for _, l in pairs(box) do
        l.Visible = false
        l.Thickness = Settings.BoxThickness
        l.Color = Colors.Enemy
    end

    local connectors = {}
    for i = 1, 4 do
        local c = Drawing.new("Line")
        c.Visible = false
        c.Thickness = Settings.BoxThickness
        c.Color = Colors.Enemy
        connectors[i] = c
    end

    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Thickness = 1
    tracer.Color = Colors.Enemy

    local health = {
        Outline = Drawing.new("Square"),
        Fill = Drawing.new("Square"),
        Text = Drawing.new("Text")
    }
    health.Outline.Visible = false
    health.Fill.Visible = false
    health.Fill.Filled = true
    health.Text.Visible = false
    health.Text.Center = true
    health.Text.Size = Settings.TextSize
    health.Text.Font = Settings.TextFont

    local info = {
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text")
    }
    info.Name.Visible = false; info.Name.Center = true; info.Name.Size = Settings.TextSize; info.Name.Font = Settings.TextFont; info.Name.Outline = true
    info.Distance.Visible = false; info.Distance.Center = true; info.Distance.Size = math.max(10, Settings.TextSize-2); info.Distance.Font = Settings.TextFont; info.Distance.Outline = true

    local skeleton = {}
    for i = 1, 20 do
        local ln = Drawing.new("Line")
        ln.Visible = false
        ln.Thickness = 1
        ln.Color = Color3.new(1,1,1)
        skeleton[i] = ln
    end

    Drawings.ESP[player] = {
        Box = box,
        Connectors = connectors,
        Tracer = tracer,
        Health = health,
        Info = info,
        Skeleton = skeleton,
        _boxPos = nil,
        _boxWidth = nil,
        _boxHeight = nil
    }
end

local function RemoveESP(player)
    local esp = Drawings.ESP[player]
    if not esp then return end
    for _, v in pairs(esp.Box) do pcall(function() v:Remove() end) end
    for _, v in pairs(esp.Connectors) do pcall(function() v:Remove() end) end
    pcall(function() esp.Tracer:Remove() end)
    for _, v in pairs(esp.Health) do pcall(function() v:Remove() end) end
    for _, v in pairs(esp.Info) do pcall(function() v:Remove() end) end
    for _, v in pairs(esp.Skeleton) do pcall(function() v:Remove() end) end
    Drawings.ESP[player] = nil
end

-- best-name fallback
local function getBestName(player, character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.DisplayName and humanoid.DisplayName ~= "" then return humanoid.DisplayName end
    if player.DisplayName and player.DisplayName ~= "" then return player.DisplayName end
    return player.Name or "Player"
end

-- faster dot product squared distance
local function squaredDistance(a, b)
    local d = a - b
    return d:Dot(d)
end

-- main UpdateESP with fixed ThreeD case
local function UpdateESP(player)
    if not Settings.Enabled then return end
    if player == LocalPlayer then return end
    local esp = Drawings.ESP[player]
    if not esp then return end

    local character = player.Character
    if not character then
        -- hide quickly
        for _, l in pairs(esp.Box) do l.Visible = false end
        for _, c in pairs(esp.Connectors) do c.Visible = false end
        esp.Tracer.Visible = false
        esp.Health.Outline.Visible = false; esp.Health.Fill.Visible = false; esp.Health.Text.Visible = false
        esp.Info.Name.Visible = false; esp.Info.Distance.Visible = false
        for _, l in pairs(esp.Skeleton) do l.Visible = false end
        esp._boxPos = nil
        return
    end

    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then
        for _, l in pairs(esp.Box) do l.Visible = false end
        for _, c in pairs(esp.Connectors) do c.Visible = false end
        esp.Tracer.Visible = false
        esp.Health.Outline.Visible = false; esp.Health.Fill.Visible = false; esp.Health.Text.Visible = false
        esp.Info.Name.Visible = false; esp.Info.Distance.Visible = false
        for _, l in pairs(esp.Skeleton) do l.Visible = false end
        esp._boxPos = nil
        return
    end

    -- cheap squared-distance cull
    local camPos = Camera.CFrame.Position
    local distSq = squaredDistance(root.Position, camPos)
    if distSq > (Settings.MaxDistance * Settings.MaxDistance) then
        for _, l in pairs(esp.Box) do l.Visible = false end
        for _, c in pairs(esp.Connectors) do c.Visible = false end
        esp.Tracer.Visible = false
        esp.Health.Outline.Visible = false; esp.Health.Fill.Visible = false; esp.Health.Text.Visible = false
        esp.Info.Name.Visible = false; esp.Info.Distance.Visible = false
        for _, l in pairs(esp.Skeleton) do l.Visible = false end
        esp._boxPos = nil
        return
    end

    -- world->viewport once for root
    local rootScreenPos, rootOnScreen = Camera:WorldToViewportPoint(root.Position)
    if not rootOnScreen or rootScreenPos.Z < 0 then
        for _, l in pairs(esp.Box) do l.Visible = false end
        for _, c in pairs(esp.Connectors) do c.Visible = false end
        esp.Tracer.Visible = false
        esp.Health.Outline.Visible = false; esp.Health.Fill.Visible = false; esp.Health.Text.Visible = false
        esp.Info.Name.Visible = false; esp.Info.Distance.Visible = false
        for _, l in pairs(esp.Skeleton) do l.Visible = false end
        esp._boxPos = nil
        return
    end

    local isAlly = (player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team)
    local color = isAlly and Colors.Ally or Colors.Enemy

    -- BOX handling (including fixed ThreeD case)
    if Settings.BoxESP then
        local size = character:GetExtentsSize()
        local cf = root.CFrame

        if Settings.BoxStyle == "ThreeD" then
            -- compute 8 corners
            local corners = {
                (cf * CFrame.new(-size.X/2, size.Y/2, -size.Z/2)).Position, -- front TL (0)
                (cf * CFrame.new(size.X/2, size.Y/2, -size.Z/2)).Position,  -- front TR (1)
                (cf * CFrame.new(-size.X/2, -size.Y/2, -size.Z/2)).Position, -- front BL (2)
                (cf * CFrame.new(size.X/2, -size.Y/2, -size.Z/2)).Position,  -- front BR (3)
                (cf * CFrame.new(-size.X/2, size.Y/2, size.Z/2)).Position, -- back TL (4)
                (cf * CFrame.new(size.X/2, size.Y/2, size.Z/2)).Position,  -- back TR (5)
                (cf * CFrame.new(-size.X/2, -size.Y/2, size.Z/2)).Position, -- back BL (6)
                (cf * CFrame.new(size.X/2, -size.Y/2, size.Z/2)).Position   -- back BR (7)
            }

            -- project all corners
            local projected = {}
            local anyBehind = false
            for i=1,8 do
                local p, on = Camera:WorldToViewportPoint(corners[i])
                projected[i] = {p = p, on = on}
                if p.Z < 0 then anyBehind = true end
            end

            -- require all visible (front+back) to draw 3D box
            if not (projected[1].on and projected[2].on and projected[3].on and projected[4].on
                    and projected[5].on and projected[6].on and projected[7].on and projected[8].on)
            then
                -- don't draw 3D if not fully on screen
                for _, l in pairs(esp.Box) do l.Visible = false end
                for _, c in pairs(esp.Connectors) do c.Visible = false end
                esp._boxPos = nil
            else
                -- convert to Vector2
                local function to2(v) return Vector2.new(v.X, v.Y) end
                local frontTL, frontTR, frontBL, frontBR = to2(projected[1].p), to2(projected[2].p), to2(projected[3].p), to2(projected[4].p)
                local backTL, backTR, backBL, backBR = to2(projected[5].p), to2(projected[6].p), to2(projected[7].p), to2(projected[8].p)

                -- front face (use TopLeft/TopRight/BottomLeft/BottomRight)
                esp.Box.TopLeft.From = frontTL; esp.Box.TopLeft.To = frontTR; esp.Box.TopLeft.Color = color; esp.Box.TopLeft.Thickness = Settings.BoxThickness; esp.Box.TopLeft.Visible = true
                esp.Box.TopRight.From = frontTR; esp.Box.TopRight.To = frontBR; esp.Box.TopRight.Color = color; esp.Box.TopRight.Visible = true
                esp.Box.BottomLeft.From = frontBL; esp.Box.BottomLeft.To = frontBR; esp.Box.BottomLeft.Color = color; esp.Box.BottomLeft.Visible = true
                esp.Box.BottomRight.From = frontTL; esp.Box.BottomRight.To = frontBL; esp.Box.BottomRight.Color = color; esp.Box.BottomRight.Visible = true

                -- back face (use Left/Right/Top/Bottom)
                esp.Box.Left.From = backTL; esp.Box.Left.To = backTR; esp.Box.Left.Color = color; esp.Box.Left.Thickness = Settings.BoxThickness; esp.Box.Left.Visible = true
                esp.Box.Right.From = backTR; esp.Box.Right.To = backBR; esp.Box.Right.Color = color; esp.Box.Right.Visible = true
                esp.Box.Top.From = backBL; esp.Box.Top.To = backBR; esp.Box.Top.Color = color; esp.Box.Top.Visible = true
                esp.Box.Bottom.From = backTL; esp.Box.Bottom.To = backBL; esp.Box.Bottom.Color = color; esp.Box.Bottom.Visible = true

                -- connectors (reuse esp.Connectors lines)
                local cons = esp.Connectors
                cons[1].From = frontTL; cons[1].To = backTL; cons[1].Color = color; cons[1].Thickness = Settings.BoxThickness; cons[1].Visible = true
                cons[2].From = frontTR; cons[2].To = backTR; cons[2].Color = color; cons[2].Visible = true
                cons[3].From = frontBL; cons[3].To = backBL; cons[3].Color = color; cons[3].Visible = true
                cons[4].From = frontBR; cons[4].To = backBR; cons[4].Color = color; cons[4].Visible = true

                -- compute rough 2D bounding box for name/health placement (use front extents)
                local minX = math.min(frontTL.X, frontTR.X, frontBL.X, frontBR.X)
                local maxX = math.max(frontTL.X, frontTR.X, frontBL.X, frontBR.X)
                local minY = math.min(frontTL.Y, frontTR.Y, frontBL.Y, frontBR.Y)
                local maxY = math.max(frontTL.Y, frontTR.Y, frontBL.Y, frontBR.Y)
                esp._boxPos = Vector2.new(minX, minY)
                esp._boxWidth = maxX - minX
                esp._boxHeight = maxY - minY
            end

        else
            -- Corner or Full (2D box)
            local topV3, topOn = Camera:WorldToViewportPoint((cf * CFrame.new(0, size.Y/2, 0)).Position)
            local bottomV3, bottomOn = Camera:WorldToViewportPoint((cf * CFrame.new(0, -size.Y/2, 0)).Position)
            if not topOn or not bottomOn or topV3.Z < 0 or bottomV3.Z < 0 then
                for _, l in pairs(esp.Box) do l.Visible = false end
                for _, c in pairs(esp.Connectors) do c.Visible = false end
                esp._boxPos = nil
            else
                local top2 = Vector2.new(topV3.X, topV3.Y)
                local bottom2 = Vector2.new(bottomV3.X, bottomV3.Y)
                local height = math.abs(bottom2.Y - top2.Y)
                local width = height * 0.65
                local pos = Vector2.new(top2.X - width/2, top2.Y)

                if Settings.BoxStyle == "Corner" then
                    local cs = width * 0.2
                    esp.Box.TopLeft.From = pos; esp.Box.TopLeft.To = pos + Vector2.new(cs, 0); esp.Box.TopLeft.Color = color; esp.Box.TopLeft.Visible = true
                    esp.Box.TopRight.From = pos + Vector2.new(width, 0); esp.Box.TopRight.To = pos + Vector2.new(width - cs, 0); esp.Box.TopRight.Color = color; esp.Box.TopRight.Visible = true
                    esp.Box.BottomLeft.From = pos + Vector2.new(0, height); esp.Box.BottomLeft.To = pos + Vector2.new(cs, height); esp.Box.BottomLeft.Color = color; esp.Box.BottomLeft.Visible = true
                    esp.Box.BottomRight.From = pos + Vector2.new(width, height); esp.Box.BottomRight.To = pos + Vector2.new(width - cs, height); esp.Box.BottomRight.Color = color; esp.Box.BottomRight.Visible = true
                    esp.Box.Left.Visible = false; esp.Box.Right.Visible = false; esp.Box.Top.Visible = false; esp.Box.Bottom.Visible = false
                    for _, c in pairs(esp.Connectors) do c.Visible = false end
                else
                    esp.Box.Left.From = pos; esp.Box.Left.To = pos + Vector2.new(0, height); esp.Box.Left.Color = color; esp.Box.Left.Visible = true
                    esp.Box.Right.From = pos + Vector2.new(width, 0); esp.Box.Right.To = pos + Vector2.new(width, height); esp.Box.Right.Color = color; esp.Box.Right.Visible = true
                    esp.Box.Top.From = pos; esp.Box.Top.To = pos + Vector2.new(width, 0); esp.Box.Top.Color = color; esp.Box.Top.Visible = true
                    esp.Box.Bottom.From = pos + Vector2.new(0, height); esp.Box.Bottom.To = pos + Vector2.new(width, height); esp.Box.Bottom.Color = color; esp.Box.Bottom.Visible = true
                    esp.Box.TopLeft.Visible = false; esp.Box.TopRight.Visible = false; esp.Box.BottomLeft.Visible = false; esp.Box.BottomRight.Visible = false
                    for _, c in pairs(esp.Connectors) do c.Visible = false end
                end

                esp._boxPos = pos
                esp._boxWidth = width
                esp._boxHeight = height
            end
        end
    else
        -- not drawing boxes
        for _, l in pairs(esp.Box) do l.Visible = false end
        for _, c in pairs(esp.Connectors) do c.Visible = false end
        esp._boxPos = nil
    end

    -- Tracer
    if Settings.TracerESP then
        local vs = Camera.ViewportSize
        local origin
        if Settings.TracerOrigin == "Bottom" then origin = Vector2.new(vs.X/2, vs.Y) elseif Settings.TracerOrigin == "Top" then origin = Vector2.new(vs.X/2, 0) elseif Settings.TracerOrigin == "Mouse" then origin = UserInputService:GetMouseLocation() else origin = Vector2.new(vs.X/2, vs.Y/2) end
        esp.Tracer.From = origin
        esp.Tracer.To = Vector2.new(rootScreenPos.X, rootScreenPos.Y)
        esp.Tracer.Color = color
        esp.Tracer.Visible = true
    else
        esp.Tracer.Visible = false
    end

    -- Health
    if Settings.HealthESP and esp._boxPos then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local hp = clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1)
            local barHeight = esp._boxHeight * 0.8
            local barWidth = 4
            local barPos = Vector2.new(esp._boxPos.X - barWidth - 2, esp._boxPos.Y + (esp._boxHeight - barHeight)/2)
            esp.Health.Outline.Position = barPos
            esp.Health.Outline.Size = Vector2.new(barWidth, barHeight)
            esp.Health.Outline.Visible = true

            esp.Health.Fill.Position = Vector2.new(barPos.X + 1, barPos.Y + barHeight * (1 - hp))
            esp.Health.Fill.Size = Vector2.new(barWidth - 2, barHeight * hp)
            esp.Health.Fill.Color = Color3.fromRGB(math.floor(255 - 255*hp), math.floor(255*hp), 0)
            esp.Health.Fill.Visible = true

            esp.Health.Text.Text = tostring(math.floor(humanoid.Health)) .. "HP"
            esp.Health.Text.Position = Vector2.new(barPos.X + barWidth + 12, barPos.Y + barHeight/2)
            esp.Health.Text.Visible = true
        else
            esp.Health.Outline.Visible = false; esp.Health.Fill.Visible = false; esp.Health.Text.Visible = false
        end
    else
        esp.Health.Outline.Visible = false; esp.Health.Fill.Visible = false; esp.Health.Text.Visible = false
    end

    -- Name & Distance
    if Settings.NameESP or Settings.ShowDistance then
        local nameText = getBestName(player, character)
        if Settings.NameESP then
            if esp._boxPos then
                esp.Info.Name.Text = nameText
                esp.Info.Name.Position = Vector2.new(esp._boxPos.X + (esp._boxWidth/2), esp._boxPos.Y - 18)
            else
                esp.Info.Name.Text = nameText
                esp.Info.Name.Position = Vector2.new(rootScreenPos.X, rootScreenPos.Y - 30)
            end
            esp.Info.Name.Color = color
            esp.Info.Name.Visible = true
        else
            esp.Info.Name.Visible = false
        end

        if Settings.ShowDistance then
            local dist = math.floor(math.sqrt(distSq))
            esp.Info.Distance.Text = tostring(dist) .. " studs"
            if esp._boxPos then
                esp.Info.Distance.Position = Vector2.new(esp._boxPos.X + (esp._boxWidth/2), esp._boxPos.Y - 6)
            else
                esp.Info.Distance.Position = Vector2.new(rootScreenPos.X, rootScreenPos.Y - 12)
            end
            esp.Info.Distance.Color = Colors.Distance
            esp.Info.Distance.Visible = true
        else
            esp.Info.Distance.Visible = false
        end
    else
        esp.Info.Name.Visible = false; esp.Info.Distance.Visible = false
    end

    -- Skeleton (only when enabled)
    if Settings.SkeletonESP then
        local function partScreen(part)
            if not part then return nil, false end
            local s, on = Camera:WorldToViewportPoint(part.Position)
            if not on or s.Z < 0 then return nil, false end
            return Vector2.new(s.X, s.Y), true
        end

        local head = character:FindFirstChild("Head")
        local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
        local lower = character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso")
        local LUp = character:FindFirstChild("LeftUpperArm"); local LLo = character:FindFirstChild("LeftLowerArm"); local LHand = character:FindFirstChild("LeftHand")
        local RUp = character:FindFirstChild("RightUpperArm"); local RLo = character:FindFirstChild("RightLowerArm"); local RHand = character:FindFirstChild("RightHand")
        local LTh = character:FindFirstChild("LeftUpperLeg"); local LSh = character:FindFirstChild("LeftLowerLeg"); local LFoot = character:FindFirstChild("LeftFoot")
        local RTh = character:FindFirstChild("RightUpperLeg"); local RSh = character:FindFirstChild("RightLowerLeg"); local RFoot = character:FindFirstChild("RightFoot")

        local pairsToDraw = {
            {head, upper}, {upper, lower},
            {upper, LUp}, {LUp, LLo}, {LLo, LHand},
            {upper, RUp}, {RUp, RLo}, {RLo, RHand},
            {lower, LTh}, {LTh, LSh}, {LSh, LFoot},
            {lower, RTh}, {RTh, RSh}, {RSh, RFoot}
        }

        local idx = 1
        for _, p in ipairs(pairsToDraw) do
            local a, b = p[1], p[2]
            local aPos, aVis = partScreen(a)
            local bPos, bVis = partScreen(b)
            local line = esp.Skeleton[idx]
            if aVis and bVis then
                line.From = aPos; line.To = bPos; line.Color = color; line.Visible = true
            else
                line.Visible = false
            end
            idx = idx + 1
        end
        for i = idx, #esp.Skeleton do esp.Skeleton[i].Visible = false end
    else
        for _, l in pairs(esp.Skeleton) do l.Visible = false end
    end
end

-- optimized update loop
local lastUpdate = 0
RunService.Heartbeat:Connect(function()
    if not Settings.Enabled then
        for _, esp in pairs(Drawings.ESP) do
            for _, l in pairs(esp.Box) do l.Visible = false end
            for _, c in pairs(esp.Connectors) do c.Visible = false end
            esp.Tracer.Visible = false
            esp.Health.Outline.Visible = false; esp.Health.Fill.Visible = false; esp.Health.Text.Visible = false
            esp.Info.Name.Visible = false; esp.Info.Distance.Visible = false
        end
        return
    end

    local now = time()
    if now - lastUpdate < Settings.RefreshRate then return end
    lastUpdate = now

    local players = Players:GetPlayers()
    for i = 1, #players do
        local p = players[i]
        if p ~= LocalPlayer then
            if not Drawings.ESP[p] then CreateESP(p) end
            UpdateESP(p)
        end
    end
end)

Players.PlayerAdded:Connect(function(p) CreateESP(p) end)
Players.PlayerRemoving:Connect(function(p) RemoveESP(p) end)

for _, p in pairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then CreateESP(p) end
end
