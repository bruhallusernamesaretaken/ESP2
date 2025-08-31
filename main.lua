--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

--// Whitelist & Blacklist
local Whitelist = {}
local Blacklist = {}

--// ESP Container
local ESPFolder = Instance.new("Folder", game.CoreGui)
ESPFolder.Name = "ESP"

--// UI Creation
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
ScreenGui.Name = "ESP_UI"
ScreenGui.ResetOnSpawn = false

local Frame = Instance.new("Frame", ScreenGui)
Frame.Size = UDim2.new(0, 250, 0, 150)
Frame.Position = UDim2.new(0.3, 0, 0.3, 0)
Frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
Frame.Active = true
Frame.Draggable = true

local Title = Instance.new("TextLabel", Frame)
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(45,45,45)
Title.Text = "Whitelist / Blacklist"
Title.TextColor3 = Color3.fromRGB(255,255,255)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 16

local NameBox = Instance.new("TextBox", Frame)
NameBox.Size = UDim2.new(1, -20, 0, 30)
NameBox.Position = UDim2.new(0, 10, 0, 40)
NameBox.PlaceholderText = "Enter Player Name..."
NameBox.Text = ""
NameBox.BackgroundColor3 = Color3.fromRGB(50,50,50)
NameBox.TextColor3 = Color3.fromRGB(255,255,255)

local WhitelistBtn = Instance.new("TextButton", Frame)
WhitelistBtn.Size = UDim2.new(0.5, -15, 0, 30)
WhitelistBtn.Position = UDim2.new(0, 10, 0, 80)
WhitelistBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
WhitelistBtn.Text = "Whitelist"
WhitelistBtn.TextColor3 = Color3.new(1,1,1)

local BlacklistBtn = Instance.new("TextButton", Frame)
BlacklistBtn.Size = UDim2.new(0.5, -15, 0, 30)
BlacklistBtn.Position = UDim2.new(0.5, 5, 0, 80)
BlacklistBtn.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
BlacklistBtn.Text = "Blacklist"
BlacklistBtn.TextColor3 = Color3.new(1,1,1)

--// Handle whitelist & blacklist logic
local function UpdateList(name, listType)
    name = name:lower()
    if listType == "Whitelist" then
        Blacklist[name] = nil
        Whitelist[name] = true
    elseif listType == "Blacklist" then
        Whitelist[name] = nil
        Blacklist[name] = true
    end
end

WhitelistBtn.MouseButton1Click:Connect(function()
    if NameBox.Text ~= "" then
        UpdateList(NameBox.Text, "Whitelist")
    end
end)

BlacklistBtn.MouseButton1Click:Connect(function()
    if NameBox.Text ~= "" then
        UpdateList(NameBox.Text, "Blacklist")
    end
end)

--// Function to create ESP
local function CreateESP(player)
    if player == LocalPlayer then return end
    if ESPFolder:FindFirstChild(player.Name) then return end

    local Billboard = Instance.new("BillboardGui", ESPFolder)
    Billboard.Name = player.Name
    Billboard.AlwaysOnTop = true
    Billboard.Size = UDim2.new(4,0,6,0) -- better sized box
    Billboard.Adornee = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

    local Box = Instance.new("Frame", Billboard)
    Box.Size = UDim2.new(1,0,1,0)
    Box.BackgroundTransparency = 1
    Box.BorderSizePixel = 2
    Box.BorderColor3 = Color3.new(1,0,0)

    -- Skeleton ESP (white lines)
    local function DrawSkeleton(char)
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then
                local adorn = Instance.new("BoxHandleAdornment", Billboard)
                adorn.Size = part.Size
                adorn.Adornee = part
                adorn.AlwaysOnTop = true
                adorn.ZIndex = 1
                adorn.Color3 = Color3.new(1,1,1)
                adorn.Transparency = 0.5
            end
        end
    end

    if player.Character then
        DrawSkeleton(player.Character)
        player.CharacterAdded:Connect(DrawSkeleton)
    end
end

--// ESP updater
RunService.RenderStepped:Connect(function()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local esp = ESPFolder:FindFirstChild(player.Name)
            if not esp then
                CreateESP(player)
                esp = ESPFolder:FindFirstChild(player.Name)
            end
            if esp and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                esp.Adornee = player.Character.HumanoidRootPart

                local box = esp:FindFirstChildOfClass("Frame")
                local lowerName = player.Name:lower()

                if Whitelist[lowerName] then
                    box.BorderColor3 = Color3.new(0,1,0) -- Green
                elseif Blacklist[lowerName] then
                    box.BorderColor3 = Color3.new(1,0,0) -- Red (forced)
                elseif #Players:GetPlayers() == 1 then
                    box.BorderColor3 = Color3.new(1,0,0) -- Single team → Red
                elseif player.Team == LocalPlayer.Team then
                    box.BorderColor3 = Color3.new(0,0,1) -- Blue (same team)
                else
                    box.BorderColor3 = Color3.new(1,0,0) -- Red (enemy)
                end
            end
        end
    end
end)
