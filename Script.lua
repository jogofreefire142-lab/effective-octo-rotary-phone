repeat task.wait() until game:IsLoaded()

-- =================================================================
-- ⭐ AKAIL HUB - INTERFACE PREMIUM (DELTA OTIMIZADO)
-- =================================================================
if getgenv().AkailHubLoaded then return end
getgenv().AkailHubLoaded = true

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

if not LocalPlayer then return end

getgenv().Config = {
    FastAttack = false,
    InfiniteStamina = false
}

-- Limpar interface anterior se já existir
if PlayerGui:FindFirstChild("AkailHub_Delta") then
    PlayerGui.AkailHub_Delta:Destroy()
end

-- CRIAR TELA PRINCIPAL
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AkailHub_Delta"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

-- BOTÃO FLUTUANTE (☰)
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 52, 0, 52)
ToggleBtn.Position = UDim2.new(0.02, 0, 0.15, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
ToggleBtn.Text = "☰"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 100, 200)
ToggleBtn.TextSize = 24
ToggleBtn.Parent = ScreenGui

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 14)
btnCorner.Parent = ToggleBtn

local btnStroke = Instance.new("UIStroke")
btnStroke.Color = Color3.fromRGB(255, 100, 200)
btnStroke.Thickness = 2
btnStroke.Parent = ToggleBtn

-- PAINEL PRINCIPAL
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 400, 0, 280)
MainFrame.Position = UDim2.new(0.5, -200, 0.5, -140)
MainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
MainFrame.Visible = false
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = MainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(255, 100, 200)
mainStroke.Thickness = 2
mainStroke.Parent = MainFrame

-- TÍTULO
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 45)
Title.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
Title.Text = "   🔥 AKAIL HUB - VIP PREMIUM"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = Title

-- ABRIR E FECHAR O MENU
ToggleBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- FUNÇÃO PARA CRIAR OS BOTÕES DO MENU COM SEGURANÇA
local function AddToggle(name, callback, posY)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.92, 0, 0, 38)
    btn.Position = UDim2.new(0.04, 0, 0, posY)
    btn.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    btn.Text = "  " .. name .. ": [ OFF ❌ ]"
    btn.TextColor3 = Color3.fromRGB(180, 180, 200)
    btn.TextSize = 12
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = MainFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn

    local state = false
    btn.MouseButton1Click:Connect(function()
        state = not state
        if state then
            btn.Text = "  " .. name .. ": [ ON ✅ ]"
            btn.TextColor3 = Color3.fromRGB(255, 100, 200)
        else
            btn.Text = "  " .. name .. ": [ OFF ❌ ]"
            btn.TextColor3 = Color3.fromRGB(180, 180, 200)
        end
        pcall(function() callback(state) end)
    end)
end

-- ADICIONANDO AS OPÇÕES NA TELA
AddToggle("Fast Attack", function(v) getgenv().Config.FastAttack = v end, 60)
AddToggle("Infinite Stamina", function(v) getgenv().Config.InfiniteStamina = v end, 110)

-- SISTEMA DE STAMINA INFINITA
task.spawn(function()
    while task.wait(0.2) do
        if getgenv().Config.InfiniteStamina and LocalPlayer.Character then
            pcall(function()
                local stamina = LocalPlayer.Character:FindFirstChild("Stamina")
                if stamina then stamina.Value = 100 end
            end)
        end
    end
end)

-- SISTEMA DE FAST ATTACK
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

print("✅ Akail Hub Carregado com Sucesso!")
