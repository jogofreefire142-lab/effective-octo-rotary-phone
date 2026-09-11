repeat task.wait() until game:IsLoaded()

-- =================================================================
-- ⭐ AKAIL HUB VIP PREMIUM — BLOX FRUITS (OTIMIZADO PARA DELTA)
-- =================================================================
if getgenv().AkailHubUltimateLoaded then return end
getgenv().AkailHubUltimateLoaded = true

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

if not LocalPlayer then return end

getgenv().Config = {
    AutoFarm = false,
    FastAttack = true,
    FastAttackSpeed = 0.001,
    BringMob = true,
    AutoHaki = true,
    AntiLag = true,
    InfiniteStamina = true,
    SpeedBoost = false,
    SpeedMultiplier = 1.2,
    ShowNotifications = true,
    ShowStats = true
}

-- Notificação leve
local function ShowNotification(title, message)
    if not getgenv().Config.ShowNotifications then return end
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title,
            Text = message,
            Duration = 3
        })
    end)
end

task.wait(1) -- Pequeno atraso para estabilizar no Delta

-- =================================================================
-- UI MOBILE OTIMIZADA
-- =================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AkailHub_Delta"
ScreenGui.ResetOnSpawn = false

pcall(function()
    if syn and syn.protect_gui then
        syn.protect_gui(ScreenGui)
        ScreenGui.Parent = CoreGui
    else
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end)

-- BOTÃO FLUTUANTE (☰)
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 50, 0, 50)
ToggleBtn.Position = UDim2.new(0.02, 0, 0.15, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
ToggleBtn.Text = "☰"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 100, 200)
ToggleBtn.TextSize = FONT_SIZE_OR_VAL or 24
ToggleBtn.Parent = ScreenGui

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 12)
btnCorner.Parent = ToggleBtn

local btnStroke = Instance.new("UIStroke")
btnStroke.Color = Color3.fromRGB(255, 100, 200)
btnStroke.Thickness = 2
btnStroke.Parent = ToggleBtn

-- PAINEL PRINCIPAL
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 420, 0, 350)
MainFrame.Position = UDim2.new(0.5, -210, 0.5, -175)
MainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
MainFrame.Visible = false
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = MainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(255, 100, 200)
mainStroke.Thickness = 2
mainStroke.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
Title.Text = " 🔥 AKAIL HUB - BLOX FRUITS"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = Title

-- ABRIR/FECHAR MENU
ToggleBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- FUNÇÃO DE CRIAR BOTÕES DE TOGGLE NO MENU
local function AddToggle(name, callback, posY)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 35)
    btn.Position = UDim2.new(0.05, 0, 0, posY)
    btn.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    btn.Text = "  " .. name .. ": [ OFF ]"
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.TextSize = 12
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = MainFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    local state = false
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = "  " .. name .. (state and ": [ ON ✅ ]" : ": [ OFF ❌ ]")
        btn.TextColor3 = state and Color3.fromRGB(255, 100, 200) or Color3.fromRGB(200, 200, 200)
        pcall(function() callback(state) end)
        ShowNotification("Akail Hub", name .. (state and " Ativado" else " Desativado"))
    end)
end

-- ADICIONANDO OPÇÕES BÁSICAS NO PAINEL
AddToggle("Fast Attack", function(v) getgenv().Config.FastAttack = v end, 55)
AddToggle("Infinite Stamina", function(v) getgenv().Config.InfiniteStamina = v end, 95)
AddToggle("Anti-Lag", function(v) 
    if v then
        pcall(function()
            game:GetService("Lighting").GlobalShadows = false
            settings().Rendering.QualityLevel = 1
        end)
    end
end, 135)

-- LOOP DE STAMINA
task.spawn(function()
    while task.wait(0.2) do
        if getgenv().Config.InfiniteStamina and LocalPlayer.Character then
            pcall(function()
                if LocalPlayer.Character:FindFirstChild("Stamina") then
                    LocalPlayer.Character.Stamina.Value = 100
                end
            end)
        end
    end
end)

-- FAST ATTACK LOOP
task.spawn(function()
    while task.wait(0.01) do
        if getgenv().Config.FastAttack then
            pcall(function()
                game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, true, game, 1)
                game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, false, game, 1)
            end)
        end
    end
end)

ShowNotification("Akail Hub", "Carregado com sucesso no Delta!")
