-- ================================================================
-- MONTAR UM PET / RIDE A PET
-- FASE 1 — VELOCIDADE
-- Interface via PlayerGui
-- ================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ================================================================
-- LIMPA EXECUÇÃO ANTERIOR
-- ================================================================

local antigo = PlayerGui:FindFirstChild("MontarUmPetVelocidade")

if antigo then
    antigo:Destroy()
end

-- ================================================================
-- CONFIGURAÇÃO
-- ================================================================

local Velocidade = 150
local VelocidadeAtiva = false
local Ativo = true

-- ================================================================
-- GUI
-- ================================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MontarUmPetVelocidade"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

local Frame = Instance.new("Frame")
Frame.Size = UDim2.fromOffset(220, 130)
Frame.Position = UDim2.new(0.05, 0, 0.18, 0)
Frame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
Frame.BorderSizePixel = 0
Frame.Active = true
Frame.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 10)
Corner.Parent = Frame

local Stroke = Instance.new("UIStroke")
Stroke.Color = Color3.fromRGB(60, 60, 70)
Stroke.Thickness = 1
Stroke.Parent = Frame

-- ================================================================
-- TÍTULO
-- ================================================================

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -45, 0, 32)
Title.Position = UDim2.fromOffset(10, 3)
Title.BackgroundTransparency = 1
Title.Text = "⚡ Velocidade"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 17
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Frame

-- ================================================================
-- BOTÃO ABRIR / FECHAR
-- ================================================================

local ToggleJanela = Instance.new("TextButton")
ToggleJanela.Size = UDim2.fromOffset(30, 26)
ToggleJanela.Position = UDim2.new(1, -36, 0, 6)
ToggleJanela.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
ToggleJanela.Text = "—"
ToggleJanela.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleJanela.Font = Enum.Font.SourceSansBold
ToggleJanela.TextSize = 17
ToggleJanela.Parent = Frame

local CornerJanela = Instance.new("UICorner")
CornerJanela.CornerRadius = UDim.new(0, 6)
CornerJanela.Parent = ToggleJanela

-- ================================================================
-- CONTEÚDO
-- ================================================================

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, 0, 1, -35)
Content.Position = UDim2.fromOffset(0, 35)
Content.BackgroundTransparency = 1
Content.Parent = Frame

-- ================================================================
-- CAMPO DE VELOCIDADE
-- ================================================================

local Input = Instance.new("TextBox")
Input.Size = UDim2.fromOffset(120, 34)
Input.Position = UDim2.fromOffset(10, 5)
Input.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
Input.Text = tostring(Velocidade)
Input.PlaceholderText = "Velocidade"
Input.TextColor3 = Color3.fromRGB(255, 255, 255)
Input.PlaceholderColor3 = Color3.fromRGB(140, 140, 150)
Input.Font = Enum.Font.SourceSans
Input.TextSize = 14
Input.ClearTextOnFocus = false
Input.Parent = Content

local CornerInput = Instance.new("UICorner")
CornerInput.CornerRadius = UDim.new(0, 7)
CornerInput.Parent = Input

-- ================================================================
-- BOTÃO APLICAR
-- ================================================================

local Aplicar = Instance.new("TextButton")
Aplicar.Size = UDim2.fromOffset(70, 34)
Aplicar.Position = UDim2.fromOffset(138, 5)
Aplicar.BackgroundColor3 = Color3.fromRGB(40, 115, 70)
Aplicar.Text = "Aplicar"
Aplicar.TextColor3 = Color3.fromRGB(255, 255, 255)
Aplicar.Font = Enum.Font.SourceSansBold
Aplicar.TextSize = 13
Aplicar.Parent = Content

local CornerAplicar = Instance.new("UICorner")
CornerAplicar.CornerRadius = UDim.new(0, 7)
CornerAplicar.Parent = Aplicar

-- ================================================================
-- BOTÃO ON / OFF
-- ================================================================

local Ativar = Instance.new("TextButton")
Ativar.Size = UDim2.new(1, -20, 0, 34)
Ativar.Position = UDim2.fromOffset(10, 48)
Ativar.BackgroundColor3 = Color3.fromRGB(48, 48, 58)
Ativar.Text = "Velocidade: DESATIVADA"
Ativar.TextColor3 = Color3.fromRGB(255, 255, 255)
Ativar.Font = Enum.Font.SourceSansBold
Ativar.TextSize = 13
Ativar.Parent = Content

local CornerAtivar = Instance.new("UICorner")
CornerAtivar.CornerRadius = UDim.new(0, 7)
CornerAtivar.Parent = Ativar

-- ================================================================
-- STATUS
-- ================================================================

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -20, 0, 20)
Status.Position = UDim2.fromOffset(10, 88)
Status.BackgroundTransparency = 1
Status.Text = "Valor: 150"
Status.TextColor3 = Color3.fromRGB(180, 180, 190)
Status.Font = Enum.Font.SourceSans
Status.TextSize = 12
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.Parent = Content

-- ================================================================
-- ATUALIZA VISUAL
-- ================================================================

local function AtualizarVisual()
    if VelocidadeAtiva then
        Ativar.Text = "Velocidade: ATIVADA"
        Ativar.BackgroundColor3 = Color3.fromRGB(35, 125, 75)
    else
        Ativar.Text = "Velocidade: DESATIVADA"
        Ativar.BackgroundColor3 = Color3.fromRGB(48, 48, 58)
    end

    Status.Text = "Valor: " .. tostring(Velocidade)
end

AtualizarVisual()

-- ================================================================
-- APLICAR NOVA VELOCIDADE
-- ================================================================

Aplicar.MouseButton1Click:Connect(function()
    local valor = tonumber(Input.Text)

    if not valor then
        Input.Text = tostring(Velocidade)
        return
    end

    Velocidade = math.clamp(valor, 16, 1000)
    Input.Text = tostring(Velocidade)

    AtualizarVisual()
end)

-- ================================================================
-- ATIVAR / DESATIVAR VELOCIDADE
-- ================================================================

Ativar.MouseButton1Click:Connect(function()
    VelocidadeAtiva = not VelocidadeAtiva
    AtualizarVisual()
end)

-- ================================================================
-- MECÂNICA DE VELOCIDADE
-- Igual à fórmula do seu arquivo original
-- ================================================================

RunService.RenderStepped:Connect(function()
    if not Ativo or not VelocidadeAtiva then
        return
    end

    local character = LocalPlayer.Character
    local humanoid = character
        and character:FindFirstChildOfClass("Humanoid")

    if not character or not humanoid then
        return
    end

    local direcao = humanoid.MoveDirection

    if direcao.Magnitude <= 0 then
        return
    end

    pcall(function()
        character:TranslateBy(
            direcao * (Velocidade / 135)
        )
    end)
end)

-- ================================================================
-- ABRIR / FECHAR
-- ================================================================

local Aberto = true

ToggleJanela.MouseButton1Click:Connect(function()
    Aberto = not Aberto

    if Aberto then
        Content.Visible = true
        Frame.Size = UDim2.fromOffset(220, 130)
        ToggleJanela.Text = "—"
    else
        Content.Visible = false
        Frame.Size = UDim2.fromOffset(220, 40)
        ToggleJanela.Text = "+"
    end
end)

-- ================================================================
-- ARRASTAR NO CELULAR
-- ================================================================

local Arrastando = false
local Inicio
local Posicao

Frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then

        Arrastando = true
        Inicio = input.Position
        Posicao = Frame.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not Arrastando then
        return
    end

    if input.UserInputType ~= Enum.UserInputType.Touch
        and input.UserInputType ~= Enum.UserInputType.MouseMovement then

        return
    end

    local Delta = input.Position - Inicio

    Frame.Position = UDim2.new(
        Posicao.X.Scale,
        Posicao.X.Offset + Delta.X,
        Posicao.Y.Scale,
        Posicao.Y.Offset + Delta.Y
    )
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then

        Arrastando = false
    end
end)

-- ================================================================
-- LIMPEZA PARA REEXECUÇÃO
-- ================================================================

ENV.__MONTAR_UM_PET_VELOCIDADE = {
    Stop = function()
        Ativo = false

        pcall(function()
            ScreenGui:Destroy()
        end)
    end
}

print("[MONTAR UM PET] Aba de velocidade carregada.")
