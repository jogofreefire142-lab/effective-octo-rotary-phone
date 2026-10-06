--// MONTAR UM PET - VELOCIDADE
--// Interface simples para Delta Mobile
--// Aba Ovos reservada para depois

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ENV = (getgenv and getgenv()) or _G

--// ENCERRA INSTÂNCIA ANTERIOR
pcall(function()
    if ENV.__MONTAR_UM_PET_VELOCIDADE
        and ENV.__MONTAR_UM_PET_VELOCIDADE.Stop then

        ENV.__MONTAR_UM_PET_VELOCIDADE.Stop()
    end
end)

--// REMOVE QUALQUER GUI ANTIGA
pcall(function()
    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if obj.Name == "MontarUmPetVelocidade" then
            obj:Destroy()
        end
    end
end)

local Estado = {
    Ativo = true,
    Velocidade = 150,
    VelocidadeAtiva = false
}

local Conexoes = {}

local function Registrar(conexao)
    table.insert(Conexoes, conexao)
    return conexao
end

local function DesconectarTudo()
    for _, conexao in ipairs(Conexoes) do
        pcall(function()
            conexao:Disconnect()
        end)
    end

    table.clear(Conexoes)
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MontarUmPetVelocidade"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

--// PAINEL PRINCIPAL
local Painel = Instance.new("Frame")
Painel.Name = "Painel"
Painel.Size = UDim2.fromOffset(290, 205)
Painel.Position = UDim2.new(0.5, -145, 0.5, -100)
Painel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Painel.BorderSizePixel = 0
Painel.Parent = ScreenGui

local Canto = Instance.new("UICorner")
Canto.CornerRadius = UDim.new(0, 10)
Canto.Parent = Painel

--// BARRA DO TOPO
local Topo = Instance.new("Frame")
Topo.Size = UDim2.new(1, 0, 0, 38)
Topo.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
Topo.BorderSizePixel = 0
Topo.Parent = Painel

local Titulo = Instance.new("TextLabel")
Titulo.Size = UDim2.new(1, -45, 1, 0)
Titulo.Position = UDim2.fromOffset(10, 0)
Titulo.BackgroundTransparency = 1
Titulo.Text = "MONTAR UM PET"
Titulo.TextColor3 = Color3.fromRGB(255, 255, 255)
Titulo.TextSize = 16
Titulo.Font = Enum.Font.GothamBold
Titulo.TextXAlignment = Enum.TextXAlignment.Left
Titulo.Parent = Topo

local Fechar = Instance.new("TextButton")
Fechar.Size = UDim2.fromOffset(38, 38)
Fechar.Position = UDim2.new(1, -38, 0, 0)
Fechar.BackgroundTransparency = 1
Fechar.Text = "✕"
Fechar.TextColor3 = Color3.fromRGB(255, 255, 255)
Fechar.TextSize = 18
Fechar.Font = Enum.Font.GothamBold
Fechar.Parent = Topo

--// ABAS
local AbaVelocidade = Instance.new("TextButton")
AbaVelocidade.Size = UDim2.fromOffset(132, 32)
AbaVelocidade.Position = UDim2.fromOffset(10, 45)
AbaVelocidade.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
AbaVelocidade.BorderSizePixel = 0
AbaVelocidade.Text = "⚡ Velocidade"
AbaVelocidade.TextColor3 = Color3.fromRGB(255, 255, 255)
AbaVelocidade.TextSize = 13
AbaVelocidade.Font = Enum.Font.GothamBold
AbaVelocidade.Parent = Painel

local AbaOvos = Instance.new("TextButton")
AbaOvos.Size = UDim2.fromOffset(132, 32)
AbaOvos.Position = UDim2.fromOffset(148, 45)
AbaOvos.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
AbaOvos.BorderSizePixel = 0
AbaOvos.Text = "🥚 Ovos"
AbaOvos.TextColor3 = Color3.fromRGB(180, 180, 180)
AbaOvos.TextSize = 13
AbaOvos.Font = Enum.Font.GothamBold
AbaOvos.Parent = Painel

--// PÁGINA VELOCIDADE
local PaginaVelocidade = Instance.new("Frame")
PaginaVelocidade.Size = UDim2.new(1, -20, 0, 115)
PaginaVelocidade.Position = UDim2.fromOffset(10, 82)
PaginaVelocidade.BackgroundTransparency = 1
PaginaVelocidade.Parent = Painel

local TextoVelocidade = Instance.new("TextLabel")
TextoVelocidade.Size = UDim2.new(1, 0, 0, 25)
TextoVelocidade.BackgroundTransparency = 1
TextoVelocidade.Text = "Velocidade:"
TextoVelocidade.TextColor3 = Color3.fromRGB(220, 220, 220)
TextoVelocidade.TextSize = 13
TextoVelocidade.Font = Enum.Font.Gotham
TextoVelocidade.TextXAlignment = Enum.TextXAlignment.Left
TextoVelocidade.Parent = PaginaVelocidade

local CampoVelocidade = Instance.new("TextBox")
CampoVelocidade.Size = UDim2.fromOffset(120, 34)
CampoVelocidade.Position = UDim2.fromOffset(0, 28)
CampoVelocidade.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
CampoVelocidade.BorderSizePixel = 0
CampoVelocidade.ClearTextOnFocus = false
CampoVelocidade.Text = tostring(Estado.Velocidade)
CampoVelocidade.TextColor3 = Color3.fromRGB(255, 255, 255)
CampoVelocidade.TextSize = 14
CampoVelocidade.Font = Enum.Font.GothamBold
CampoVelocidade.PlaceholderText = "Valor"
CampoVelocidade.Parent = PaginaVelocidade

local Aplicar = Instance.new("TextButton")
Aplicar.Size = UDim2.fromOffset(120, 34)
Aplicar.Position = UDim2.fromOffset(130, 28)
Aplicar.BackgroundColor3 = Color3.fromRGB(65, 65, 65)
Aplicar.BorderSizePixel = 0
Aplicar.Text = "Aplicar"
Aplicar.TextColor3 = Color3.fromRGB(255, 255, 255)
Aplicar.TextSize = 13
Aplicar.Font = Enum.Font.GothamBold
Aplicar.Parent = PaginaVelocidade

local Ativar = Instance.new("TextButton")
Ativar.Size = UDim2.fromOffset(250, 36)
Ativar.Position = UDim2.fromOffset(0, 70)
Ativar.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
Ativar.BorderSizePixel = 0
Ativar.Text = "ATIVAR VELOCIDADE"
Ativar.TextColor3 = Color3.fromRGB(255, 255, 255)
Ativar.TextSize = 13
Ativar.Font = Enum.Font.GothamBold
Ativar.Parent = PaginaVelocidade

--// PÁGINA OVOS
local PaginaOvos = Instance.new("Frame")
PaginaOvos.Size = UDim2.new(1, -20, 0, 115)
PaginaOvos.Position = UDim2.fromOffset(10, 82)
PaginaOvos.BackgroundTransparency = 1
PaginaOvos.Visible = false
PaginaOvos.Parent = Painel

local TextoOvos = Instance.new("TextLabel")
TextoOvos.Size = UDim2.new(1, 0, 1, 0)
TextoOvos.BackgroundTransparency = 1
TextoOvos.Text = ""
TextoOvos.TextColor3 = Color3.fromRGB(255, 255, 255)
TextoOvos.TextSize = 13
TextoOvos.Font = Enum.Font.Gotham
TextoOvos.Parent = PaginaOvos

--// BOTÃO DE REABRIR
local Abrir = Instance.new("TextButton")
Abrir.Size = UDim2.fromOffset(48, 48)
Abrir.Position = UDim2.fromOffset(15, 180)
Abrir.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Abrir.BorderSizePixel = 0
Abrir.Text = "▶"
Abrir.TextColor3 = Color3.fromRGB(255, 255, 255)
Abrir.TextSize = 18
Abrir.Font = Enum.Font.GothamBold
Abrir.Visible = false
Abrir.Parent = ScreenGui

local CantoAbrir = Instance.new("UICorner")
CantoAbrir.CornerRadius = UDim.new(0, 10)
CantoAbrir.Parent = Abrir

--// TROCA DE ABA
Registrar(AbaVelocidade.Activated:Connect(function()
    PaginaVelocidade.Visible = true
    PaginaOvos.Visible = false

    AbaVelocidade.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    AbaVelocidade.TextColor3 = Color3.fromRGB(255, 255, 255)

    AbaOvos.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    AbaOvos.TextColor3 = Color3.fromRGB(180, 180, 180)
end))

Registrar(AbaOvos.Activated:Connect(function()
    PaginaVelocidade.Visible = false
    PaginaOvos.Visible = true

    AbaOvos.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    AbaOvos.TextColor3 = Color3.fromRGB(255, 255, 255)

    AbaVelocidade.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    AbaVelocidade.TextColor3 = Color3.fromRGB(180, 180, 180)
end))

--// APLICAR VELOCIDADE
Registrar(Aplicar.Activated:Connect(function()
    local valor = tonumber(CampoVelocidade.Text)

    if valor then
        Estado.Velocidade = valor
        CampoVelocidade.Text = tostring(valor)
    else
        CampoVelocidade.Text = tostring(Estado.Velocidade)
    end
end))

--// ATIVAR / DESATIVAR
local function AtualizarBotao()
    if Estado.VelocidadeAtiva then
        Ativar.Text = "DESATIVAR VELOCIDADE"
        Ativar.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    else
        Ativar.Text = "ATIVAR VELOCIDADE"
        Ativar.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    end
end

Registrar(Ativar.Activated:Connect(function()
    Estado.VelocidadeAtiva = not Estado.VelocidadeAtiva
    AtualizarBotao()
end))

--// VELOCIDADE
Registrar(RunService.RenderStepped:Connect(function()
    if not Estado.Ativo or not Estado.VelocidadeAtiva then
        return
    end

    local character = LocalPlayer.Character
    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end

    local direcao = humanoid.MoveDirection

    if direcao.Magnitude > 0 then
        pcall(function()
            character:TranslateBy(
                direcao * (Estado.Velocidade / 135)
            )
        end)
    end
end))

--// ABRIR / FECHAR
Registrar(Fechar.Activated:Connect(function()
    Painel.Visible = false
    Abrir.Visible = true
end))

Registrar(Abrir.Activated:Connect(function()
    Painel.Visible = true
    Abrir.Visible = false
end))

--// ARRASTAR NO CELULAR
local Arrastando = false
local InicioToque = nil
local InicioPosicao = nil

Registrar(Topo.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then

        Arrastando = true
        InicioToque = input.Position
        InicioPosicao = Painel.Position
    end
end))

Registrar(UserInputService.InputChanged:Connect(function(input)
    if not Arrastando then
        return
    end

    if input.UserInputType ~= Enum.UserInputType.Touch
        and input.UserInputType ~= Enum.UserInputType.MouseMovement then
        return
    end

    local delta = input.Position - InicioToque

    Painel.Position = UDim2.new(
        InicioPosicao.X.Scale,
        InicioPosicao.X.Offset + delta.X,
        InicioPosicao.Y.Scale,
        InicioPosicao.Y.Offset + delta.Y
    )
end))

Registrar(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then

        Arrastando = false
    end
end))

--// FINALIZAÇÃO GLOBAL
function Estado:Stop()
    if not self.Ativo then
        return
    end

    self.Ativo = false
    self.VelocidadeAtiva = false

    DesconectarTudo()

    pcall(function()
        if ScreenGui then
            ScreenGui:Destroy()
        end
    end)
end

ENV.__MONTAR_UM_PET_VELOCIDADE = Estado

AtualizarBotao()
