-- SWILL CANDY BONE PRO (STABLE AUTOFARM)
-- Улучшенный сбор: берет по одной, ждет, не застревает.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Settings = {
    ESPEnabled = false,
    AutoFarmEnabled = false,
    ESPColor = Color3.fromRGB(0, 255, 0),
    ESPTextColor = Color3.fromRGB(255, 255, 255),
    TracerColor = Color3.fromRGB(255, 165, 0),
    MaxDistance = 2000,
    TargetName = "CandyCornBone",
    TeleportDelay = 0.5, -- Задержка между телепортами (увеличена для стабильности)
    MaxAttemptsPerTarget = 3 -- Сколько раз пытаться взять одну конфету
}

local TargetObjects = {}
local ESP_Objects = {}
local Collected = {} -- Черный список
local CurrentTarget = nil
local Attempts = {}
local FarmCooldown = 0

-- ==================== GUI ====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SwillCandyBoneMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 280)
MainFrame.Position = UDim2.new(0, 20, 0, 100)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 35)
Title.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
Title.BorderSizePixel = 0
Title.Text = "SWILL: CandyCornBone Pro"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.Parent = MainFrame
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 8)

local function CreateButton(text, yPos, parent)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 40)
    btn.Position = UDim2.new(0.05, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

local ESPButton = CreateButton("ESP: ВЫКЛ", 50, MainFrame)
local FarmButton = CreateButton("АВТОФАРМ: ВЫКЛ", 100, MainFrame)
local TPButton = CreateButton("ТЕЛЕПОРТ К БЛИЖАЙШЕЙ", 150, MainFrame)
local RefreshButton = CreateButton("ОБНОВИТЬ СПИСОК", 200, MainFrame)
local ClearCollectedButton = CreateButton("ОЧИСТИТЬ СПИСОК ВЗЯТЫХ", 250, MainFrame)

-- ==================== ЛОГИКА ====================

local function FindTargetObjects()
    TargetObjects = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name:lower() == Settings.TargetName:lower() then
            if obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("Bone") or obj:IsA("Model") then
                if not Collected[obj] then
                    table.insert(TargetObjects, obj)
                end
            end
        end
    end
end

local function GetObjectPosition(obj)
    if obj:IsA("Bone") then
        local parentPart = obj.Parent
        if parentPart and (parentPart:IsA("BasePart") or parentPart:IsA("MeshPart")) then
            return (parentPart.CFrame * obj.CFrame).Position
        end
        return nil
    elseif obj:IsA("Model") then
        local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
        if primary then return primary.Position end
    elseif obj:IsA("BasePart") or obj:IsA("MeshPart") then
        return obj.Position
    end
    return nil
end

-- Улучшенный поиск ближайшей цели с проверкой попыток
local function GetBestTarget()
    local best = nil
    local minDist = math.huge
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
    local myPos = char.HumanoidRootPart.Position

    for _, obj in ipairs(TargetObjects) do
        if not Collected[obj] then
            -- Проверка, сколько раз пытались взять
            local attempts = Attempts[obj] or 0
            if attempts < Settings.MaxAttemptsPerTarget then
                local pos = GetObjectPosition(obj)
                if pos then
                    local dist = (myPos - pos).Magnitude
                    -- Берем только те, что в пределах видимости (не за стеной, если возможно)
                    if dist < minDist then
                        minDist = dist
                        best = obj
                    end
                end
            else
                -- Если превышено количество попыток, помечаем как взятый (чтобы не застрять)
                Collected[obj] = true
            end
        end
    end
    return best
end

-- Пометка как взятый
local function MarkAsCollected(obj)
    Collected[obj] = true
    if obj:IsA("Model") then
        for _, child in ipairs(obj:GetDescendants()) do
            Collected[child] = true
        end
    end
    if obj.Parent and obj.Parent:IsA("Model") then
        Collected[obj.Parent] = true
        for _, child in ipairs(obj.Parent:GetDescendants()) do
            Collected[child] = true
        end
    end
end

-- Телепорт и сбор
local function FarmStep()
    if FarmCooldown > tick() then return end
    FarmCooldown = tick() + Settings.TeleportDelay
    
    local target = GetBestTarget()
    if target then
        local pos = GetObjectPosition(target)
        local char = LocalPlayer.Character
        if pos and char and char:FindFirstChild("HumanoidRootPart") then
            -- Телепорт
            char.HumanoidRootPart.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
            
            -- Увеличиваем счетчик попыток
            Attempts[target] = (Attempts[target] or 0) + 1
            
            -- Если это первая попытка, пытаемся нажать ProximityPrompt
            if Attempts[target] == 1 then
                task.wait(0.1) -- Ждем, чтобы игра загрузила триггер
                local checkObj = target
                while checkObj and checkObj ~= Workspace do
                    for _, desc in ipairs(checkObj:GetDescendants()) do
                        if desc:IsA("ProximityPrompt") then
                            fireproximityprompt(desc)
                        end
                    end
                    checkObj = checkObj.Parent
                end
            end
            
            -- Если это последняя попытка, помечаем как взятый, чтобы не застревать
            if Attempts[target] >= Settings.MaxAttemptsPerTarget then
                MarkAsCollected(target)
            end
        end
    else
        -- Если целей нет, просто ждем
        task.wait(0.5)
    end
end

local function ClearCollected()
    Collected = {}
    Attempts = {}
    CurrentTarget = nil
    FarmCooldown = 0
end

local function CreateESPForObject(obj)
    if ESP_Objects[obj] then return end
    local drawings = {
        box = Drawing.new("Square"),
        text = Drawing.new("Text"),
        tracer = Drawing.new("Line")
    }
    drawings.box.Visible = false
    drawings.box.Color = Settings.ESPColor
    drawings.box.Thickness = 2
    drawings.box.Filled = false

    drawings.text.Visible = false
    drawings.text.Color = Settings.ESPTextColor
    drawings.text.Size = 16
    drawings.text.Center = true
    drawings.text.Outline = true

    drawings.tracer.Visible = false
    drawings.tracer.Color = Settings.TracerColor
    drawings.tracer.Thickness = 1

    ESP_Objects[obj] = drawings
end

local function RemoveESP(obj)
    if ESP_Objects[obj] then
        for _, drawing in pairs(ESP_Objects[obj]) do
            drawing:Remove()
        end
        ESP_Objects[obj] = nil
    end
end

ESPButton.MouseButton1Click:Connect(function()
    Settings.ESPEnabled = not Settings.ESPEnabled
    ESPButton.Text = "ESP: " .. (Settings.ESPEnabled and "ВКЛ" or "ВЫКЛ")
    ESPButton.BackgroundColor3 = Settings.ESPEnabled and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(60, 60, 60)
    if not Settings.ESPEnabled then
        for obj, _ in pairs(ESP_Objects) do
            RemoveESP(obj)
        end
    end
end)

FarmButton.MouseButton1Click:Connect(function()
    Settings.AutoFarmEnabled = not Settings.AutoFarmEnabled
    FarmButton.Text = "АВТОФАРМ: " .. (Settings.AutoFarmEnabled and "ВКЛ" or "ВЫКЛ")
    FarmButton.BackgroundColor3 = Settings.AutoFarmEnabled and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(60, 60, 60)
end)

TPButton.MouseButton1Click:Connect(function()
    FarmCooldown = 0 -- Сброс кулдауна для ручного телепорта
    FarmStep()
end)

RefreshButton.MouseButton1Click:Connect(function()
    FindTargetObjects()
end)

ClearCollectedButton.MouseButton1Click:Connect(function()
    ClearCollected()
    ClearCollectedButton.Text = "СПИСОК ОЧИЩЕН"
    task.wait(1)
    ClearCollectedButton.Text = "ОЧИСТИТЬ СПИСОК ВЗЯТЫХ"
end)

-- ==================== ЦИКЛЫ ====================

task.spawn(function()
    while task.wait(0.1) do
        if Settings.AutoFarmEnabled then
            FarmStep()
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if tick() % 1 < 0.016 then
        FindTargetObjects()
    end

    -- Автоочистка удаленных объектов из списка взятых и попыток
    for obj, _ in pairs(Collected) do
        if not obj.Parent then
            Collected[obj] = nil
            Attempts[obj] = nil
        end
    end

    if not Settings.ESPEnabled then
        for _, drawings in pairs(ESP_Objects) do
            for _, d in pairs(drawings) do d.Visible = false end
        end
        return
    end

    for obj, _ in pairs(ESP_Objects) do
        if not obj.Parent or not table.find(TargetObjects, obj) then
            RemoveESP(obj)
        end
    end

    for _, obj in ipairs(TargetObjects) do
        if not ESP_Objects[obj] then
            CreateESPForObject(obj)
        end
    end

    for obj, drawings in pairs(ESP_Objects) do
        local pos = GetObjectPosition(obj)
        if pos then
            local distance = (Camera.CFrame.Position - pos).Magnitude
            if distance <= Settings.MaxDistance then
                local screenPos, onScreen = Camera:WorldToViewportPoint(pos)
                if onScreen then
                    local size = 25
                    drawings.box.Visible = true
                    drawings.box.Size = Vector2.new(size, size)
                    drawings.box.Position = Vector2.new(screenPos.X - size/2, screenPos.Y - size/2)

                    drawings.text.Visible = true
                    drawings.text.Text = "CandyCornBone [" .. math.floor(distance) .. "m]"
                    drawings.text.Position = Vector2.new(screenPos.X, screenPos.Y - size/2 - 20)

                    drawings.tracer.Visible = true
                    drawings.tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    drawings.tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                else
                    drawings.box.Visible = false
                    drawings.text.Visible = false
                    drawings.tracer.Visible = false
                end
            else
                drawings.box.Visible = false
                drawings.text.Visible = false
                drawings.tracer.Visible = false
            end
        end
    end
end)

FindTargetObjects()
