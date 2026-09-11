repeat task.wait() until game:IsLoaded()

-- =================================================================
-- ⭐ AKAIL HUB - OTIMIZADO PARA DELTA
-- =================================================================
if getgenv().AkailHubLoaded then return end
getgenv().AkailHubLoaded = true

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

if not LocalPlayer then return end

-- CONFIGURAÇÕES LEVES
getgenv().Config = {
    FastAttack = false,
    InfiniteStamina = false
}

-- REMOVER UI ANTIGA SE HOUVER
if PlayerGui:FindFirstChild("AkailHub_Delta") then
    PlayerGui.AkailHub_Delta:Destroy()
end

-- =================================================================
-- INTERFACE (UI) DIRETA NA PLAYERGUI
-- =================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AkailHub_Delta"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

-- BOTÃO FLUTUANTE (☰)
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 50, 0, 50)
ToggleBtn.Position = UDim2.new(0.02, 0, 0.15, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
ToggleBtn.Text = "☰"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 100, 200)
ToggleBtn.TextSize = 24
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
MainFrame.Size = UDim2.new(0, 380, 0, 250)
MainFrame.Position = UDim2.new(0.5, -190, 0.5, -125)
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
Title.Text = " 🔥 AKAIL HUB - LEVE"
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

-- FUNÇÃO PARA CRIAR BOTÕES
local function AddToggle(name, callback, posY)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 35)
    btn.Position = UDim2.new(0.05, 0, 0, posY)
    btn.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    btn.Text = "  " + name + ": [ OFF ]"
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
        if state then
            btn.Text = "  " + name + ": [ ON ✅ ]"
            btn.TextColor3 = Color3.fromRGB(255, 100, 200)
        else
            btn.Text = "  " + name + ": [ OFF ❌ ]"
            btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
        pcall(function() callback(state) end)
    end)
end

-- ADICIONANDO RECURSOS
AddToggle("Fast Attack", function(v) getgenv().Config.FastAttack = v end, 55)
AddToggle("Infinite Stamina", function(v) getgenv().Config.InfiniteStamina = v end, 100)

-- LOOPS LEVES E SEGUROS
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

task.spawn(function()
    while task.wait(0.02) do
        if getgenv().Config.FastAttack then
            pcall(function()
                game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, true, game, 1)
                game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, false, game, 1)
            end)
        end
    end
end)

print("✅ Akail Hub Leve Carregado com Sucesso!")
