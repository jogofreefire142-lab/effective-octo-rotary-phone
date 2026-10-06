--// MONTAR UM PET - HUB
--// Velocidade + aba Ovos
--// Interface leve para Delta Mobile
--// Sem bibliotecas externas

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local ENV = (getgenv and getgenv()) or _G

local GUI_NAME = "MontarUmPetHub"
local TOKEN_NAME = "__MONTAR_UM_PET_HUB"

--// ENCERRA EXECUÇÃO ANTERIOR
pcall(function()
    local antigo = ENV[TOKEN_NAME]
    if antigo and antigo.Stop then
        antigo.Stop()
    end
end)

--// LIMPA GUI ANTIGA
pcall(function()
    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if obj.Name == GUI_NAME then
            obj:Destroy()
        end
    end
end)

local Estado = {
    Ativo = true,
    VelocidadeAtiva = false,
    Velocidade = 150,
    OvosSelecionados = {},
    IndoParaOvo = false,
}

local Conexoes = {}

local function Conectar(conexao)
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

local function Contar(tabela)
    local total = 0

    for _ in pairs(tabela) do
        total = total + 1
    end

    return total
end

local function PrimeiroSelecionado()
    for nome in pairs(Estado.OvosSelecionados) do
        return nome
    end

    return nil
end

--// OVOS
local EGG_NAMES = {
    "Asteroid Egg",
    "Aurora Egg",
    "Blackhole Egg",
    "Brown Egg",
    "Cherub Egg",
    "Cracked Egg",
    "Crystal Egg",
    "Diamond Egg",
    "Dominus Egg",
    "Easter Egg",
    "Flaming Egg",
    "Flower Egg",
    "Galaxy Egg",
    "Glass Egg",
    "Golden Egg",
    "Ice Egg",
    "Leaf Egg",
    "Mushroom Egg",
    "Sinister Egg",
    "Skull Egg",
    "Slime Egg",
    "Soul Egg",
    "Stone Egg",
    "White Egg",
}

--// GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = GUI_NAME
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

local Painel = Instance.new("Frame")
Painel.Name = "Painel"
Painel.Size = UDim2.fromOffset(300, 285)
Painel.Position = UDim2.new(0.5, -150, 0.5, -142)
Painel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Painel.BorderSizePixel = 0
Painel.Active = true
Painel.Parent = ScreenGui

local CantoPainel = Instance.new("UICorner")
CantoPainel.CornerRadius = UDim.new(0, 10)
CantoPainel.Parent = Painel

local function Arredondar(obj, raio)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, raio or 8)
    c.Parent = obj
end

--// TOPO
local Topo = Instance.new("Frame")
Topo.Size = UDim2.new(1, 0, 0, 40)
Topo.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
Topo.BorderSizePixel = 0
Topo.Active = true
Topo.Parent = Painel

local Titulo = Instance.new("TextLabel")
Titulo.Size = UDim2.new(1, -48, 1, 0)
Titulo.Position = UDim2.fromOffset(10, 0)
Titulo.BackgroundTransparency = 1
Titulo.Text = "MONTAR UM PET"
Titulo.TextColor3 = Color3.fromRGB(255, 255, 255)
Titulo.TextSize = 15
Titulo.Font = Enum.Font.GothamBold
Titulo.TextXAlignment = Enum.TextXAlignment.Left
Titulo.Parent = Topo

local Fechar = Instance.new("TextButton")
Fechar.Size = UDim2.fromOffset(40, 40)
Fechar.Position = UDim2.new(1, -40, 0, 0)
Fechar.BackgroundTransparency = 1
Fechar.Text = "✕"
Fechar.TextColor3 = Color3.fromRGB(255, 255, 255)
Fechar.TextSize = 17
Fechar.Font = Enum.Font.GothamBold
Fechar.Parent = Topo

--// ABAS
local AbaVelocidade = Instance.new("TextButton")
AbaVelocidade.Size = UDim2.fromOffset(135, 34)
AbaVelocidade.Position = UDim2.fromOffset(10, 46)
AbaVelocidade.BackgroundColor3 = Color3.fromRGB(65, 65, 65)
AbaVelocidade.BorderSizePixel = 0
AbaVelocidade.Text = "Velocidade"
AbaVelocidade.TextColor3 = Color3.fromRGB(255, 255, 255)
AbaVelocidade.TextSize = 13
AbaVelocidade.Font = Enum.Font.GothamBold
AbaVelocidade.Parent = Painel
Arredondar(AbaVelocidade, 7)

local AbaOvos = Instance.new("TextButton")
AbaOvos.Size = UDim2.fromOffset(135, 34)
AbaOvos.Position = UDim2.fromOffset(155, 46)
AbaOvos.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
AbaOvos.BorderSizePixel = 0
AbaOvos.Text = "🥚 Ovos"
AbaOvos.TextColor3 = Color3.fromRGB(180, 180, 180)
AbaOvos.TextSize = 13
AbaOvos.Font = Enum.Font.GothamBold
AbaOvos.Parent = Painel
Arredondar(AbaOvos, 7)

--// PAGINA VELOCIDADE
local PaginaVelocidade = Instance.new("Frame")
PaginaVelocidade.Size = UDim2.new(1, -20, 0, 195)
PaginaVelocidade.Position = UDim2.fromOffset(10, 88)
PaginaVelocidade.BackgroundTransparency = 1
PaginaVelocidade.Parent = Painel

local LabelVel = Instance.new("TextLabel")
LabelVel.Size = UDim2.new(1, 0, 0, 24)
LabelVel.BackgroundTransparency = 1
LabelVel.Text = "Velocidade:"
LabelVel.TextColor3 = Color3.fromRGB(225, 225, 225)
LabelVel.TextSize = 13
LabelVel.Font = Enum.Font.GothamBold
LabelVel.TextXAlignment = Enum.TextXAlignment.Left
LabelVel.Parent = PaginaVelocidade

local CampoVel = Instance.new("TextBox")
CampoVel.Size = UDim2.fromOffset(125, 36)
CampoVel.Position = UDim2.fromOffset(0, 30)
CampoVel.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
CampoVel.BorderSizePixel = 0
CampoVel.ClearTextOnFocus = false
CampoVel.Text = tostring(Estado.Velocidade)
CampoVel.TextColor3 = Color3.fromRGB(255, 255, 255)
CampoVel.TextSize = 14
CampoVel.Font = Enum.Font.GothamBold
CampoVel.Parent = PaginaVelocidade
Arredondar(CampoVel, 7)

local AplicarVel = Instance.new("TextButton")
AplicarVel.Size = UDim2.fromOffset(125, 36)
AplicarVel.Position = UDim2.fromOffset(135, 30)
AplicarVel.BackgroundColor3 = Color3.fromRGB(65, 65, 65)
AplicarVel.BorderSizePixel = 0
AplicarVel.Text = "Aplicar"
AplicarVel.TextColor3 = Color3.fromRGB(255, 255, 255)
AplicarVel.TextSize = 13
AplicarVel.Font = Enum.Font.GothamBold
AplicarVel.Parent = PaginaVelocidade
Arredondar(AplicarVel, 7)

local AtivarVel = Instance.new("TextButton")
AtivarVel.Size = UDim2.new(1, 0, 0, 38)
AtivarVel.Position = UDim2.fromOffset(0, 78)
AtivarVel.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
AtivarVel.BorderSizePixel = 0
AtivarVel.Text = "ATIVAR VELOCIDADE"
AtivarVel.TextColor3 = Color3.fromRGB(255, 255, 255)
AtivarVel.TextSize = 13
AtivarVel.Font = Enum.Font.GothamBold
AtivarVel.Parent = PaginaVelocidade
Arredondar(AtivarVel, 7)

local InfoVel = Instance.new("TextLabel")
InfoVel.Size = UDim2.new(1, 0, 0, 45)
InfoVel.Position = UDim2.fromOffset(0, 125)
InfoVel.BackgroundTransparency = 1
InfoVel.Text = "O valor é aplicado quando a velocidade estiver ativa."
InfoVel.TextColor3 = Color3.fromRGB(150, 150, 150)
InfoVel.TextSize = 11
InfoVel.Font = Enum.Font.Gotham
InfoVel.TextWrapped = true
InfoVel.TextXAlignment = Enum.TextXAlignment.Left
InfoVel.TextYAlignment = Enum.TextYAlignment.Top
InfoVel.Parent = PaginaVelocidade

--// PAGINA OVOS
local PaginaOvos = Instance.new("Frame")
PaginaOvos.Size = UDim2.new(1, -20, 0, 195)
PaginaOvos.Position = UDim2.fromOffset(10, 88)
PaginaOvos.BackgroundTransparency = 1
PaginaOvos.Visible = false
PaginaOvos.Parent = Painel

local LabelOvos = Instance.new("TextLabel")
LabelOvos.Size = UDim2.new(1, 0, 0, 24)
LabelOvos.BackgroundTransparency = 1
LabelOvos.Text = "Ovos selecionados: 0"
LabelOvos.TextColor3 = Color3.fromRGB(225, 225, 225)
LabelOvos.TextSize = 13
LabelOvos.Font = Enum.Font.GothamBold
LabelOvos.TextXAlignment = Enum.TextXAlignment.Left
LabelOvos.Parent = PaginaOvos

local SelecionarOvos = Instance.new("TextButton")
SelecionarOvos.Size = UDim2.new(1, 0, 0, 38)
SelecionarOvos.Position = UDim2.fromOffset(0, 30)
SelecionarOvos.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
SelecionarOvos.BorderSizePixel = 0
SelecionarOvos.Text = "SELECIONAR OVOS"
SelecionarOvos.TextColor3 = Color3.fromRGB(255, 255, 255)
SelecionarOvos.TextSize = 13
SelecionarOvos.Font = Enum.Font.GothamBold
SelecionarOvos.Parent = PaginaOvos
Arredondar(SelecionarOvos, 7)

local IrOvo = Instance.new("TextButton")
IrOvo.Size = UDim2.new(1, 0, 0, 38)
IrOvo.Position = UDim2.fromOffset(0, 76)
IrOvo.BackgroundColor3 = Color3.fromRGB(65, 65, 65)
IrOvo.BorderSizePixel = 0
IrOvo.Text = "IR PARA OVO MAIS PRÓXIMO"
IrOvo.TextColor3 = Color3.fromRGB(255, 255, 255)
IrOvo.TextSize = 13
IrOvo.Font = Enum.Font.GothamBold
IrOvo.Parent = PaginaOvos
Arredondar(IrOvo, 7)

local LimparOvos = Instance.new("TextButton")
LimparOvos.Size = UDim2.new(1, 0, 0, 32)
LimparOvos.Position = UDim2.fromOffset(0, 122)
LimparOvos.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
LimparOvos.BorderSizePixel = 0
LimparOvos.Text = "LIMPAR SELEÇÃO"
LimparOvos.TextColor3 = Color3.fromRGB(210, 210, 210)
LimparOvos.TextSize = 12
LimparOvos.Font = Enum.Font.GothamBold
LimparOvos.Parent = PaginaOvos
Arredondar(LimparOvos, 7)

local StatusOvos = Instance.new("TextLabel")
StatusOvos.Size = UDim2.new(1, 0, 0, 30)
StatusOvos.Position = UDim2.fromOffset(0, 161)
StatusOvos.BackgroundTransparency = 1
StatusOvos.Text = "Selecione pelo menos um tipo de ovo."
StatusOvos.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusOvos.TextSize = 11
StatusOvos.Font = Enum.Font.Gotham
StatusOvos.TextWrapped = true
StatusOvos.TextXAlignment = Enum.TextXAlignment.Left
StatusOvos.Parent = PaginaOvos

local function AtualizarOvos()
    local total = Contar(Estado.OvosSelecionados)

    LabelOvos.Text = "Ovos selecionados: " .. total

    if total == 0 then
        StatusOvos.Text = "Selecione pelo menos um tipo de ovo."
    elseif total == 1 then
        StatusOvos.Text = "Selecionado: " .. tostring(PrimeiroSelecionado())
    else
        StatusOvos.Text = total .. " tipos de ovos selecionados."
    end
end

--// TROCAR ABA
Conectar(AbaVelocidade.Activated:Connect(function()
    PaginaVelocidade.Visible = true
    PaginaOvos.Visible = false

    AbaVelocidade.BackgroundColor3 = Color3.fromRGB(65, 65, 65)
    AbaVelocidade.TextColor3 = Color3.fromRGB(255, 255, 255)

    AbaOvos.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    AbaOvos.TextColor3 = Color3.fromRGB(180, 180, 180)
end))

Conectar(AbaOvos.Activated:Connect(function()
    PaginaVelocidade.Visible = false
    PaginaOvos.Visible = true

    AbaOvos.BackgroundColor3 = Color3.fromRGB(65, 65, 65)
    AbaOvos.TextColor3 = Color3.fromRGB(255, 255, 255)

    AbaVelocidade.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    AbaVelocidade.TextColor3 = Color3.fromRGB(180, 180, 180)
end))

--// APLICAR VELOCIDADE
Conectar(AplicarVel.Activated:Connect(function()
    local valor = tonumber(CampoVel.Text)

    if not valor then
        CampoVel.Text = tostring(Estado.Velocidade)
        return
    end

    valor = math.floor(valor)
    valor = math.clamp(valor, 1, 1000)

    Estado.Velocidade = valor
    CampoVel.Text = tostring(valor)
end))

local function AtualizarBotaoVel()
    if Estado.VelocidadeAtiva then
        AtivarVel.Text = "DESATIVAR VELOCIDADE"
        AtivarVel.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    else
        AtivarVel.Text = "ATIVAR VELOCIDADE"
        AtivarVel.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    end
end

Conectar(AtivarVel.Activated:Connect(function()
    Estado.VelocidadeAtiva = not Estado.VelocidadeAtiva
    AtualizarBotaoVel()
end))

--// VELOCIDADE
Conectar(RunService.RenderStepped:Connect(function()
    if not Estado.Ativo
        or not Estado.VelocidadeAtiva
        or Estado.IndoParaOvo then
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
            direcao * (Estado.Velocidade / 135)
        )
    end)
end))

--// PERSONAGEM
local function GetHRP()
    local character = LocalPlayer.Character
    return character
        and character:FindFirstChild("HumanoidRootPart")
end

--// POSIÇÃO DO OVO
local function GetEggPosition(inst)
    if not inst then
        return nil
    end

    if inst:IsA("Model") then
        local ok, pivot = pcall(function()
            return inst:GetPivot()
        end)

        if ok and pivot then
            return pivot.Position
        end
    elseif inst:IsA("BasePart") then
        return inst.Position
    end

    return nil
end

--// ENCONTRA O MAIS PRÓXIMO
local function EncontrarOvoMaisProximo()
    local hrp = GetHRP()

    if not hrp then
        return nil, nil, nil
    end

    local root = workspace:FindFirstChild("RenderedEggs", true)

    if not root then
        return nil, nil, nil
    end

    local maisProximo = nil
    local menorDistancia = nil
    local nomeEncontrado = nil

    for _, child in ipairs(root:GetChildren()) do
        if Estado.OvosSelecionados[child.Name] then
            local pos = GetEggPosition(child)

            if pos then
                local distancia =
                    (pos - hrp.Position).Magnitude

                if not menorDistancia
                    or distancia < menorDistancia then

                    menorDistancia = distancia
                    maisProximo = child
                    nomeEncontrado = child.Name
                end
            end
        end
    end

    return maisProximo, menorDistancia, nomeEncontrado
end

--// MOVIMENTO ATÉ O OVO
local function IrAteOvo(targetPosition)
    local character = LocalPlayer.Character
    local hrp = character
        and character:FindFirstChild("HumanoidRootPart")

    if not character or not hrp then
        return false
    end

    local humanoid =
        character:FindFirstChildOfClass("Humanoid")

    local platformStandOriginal = nil

    if humanoid then
        platformStandOriginal = humanoid.PlatformStand
        humanoid.PlatformStand = true
    end

    local colisaoOriginal = {}

    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            colisaoOriginal[part] = part.CanCollide
            part.CanCollide = false
        end
    end

    local chegou = false

    while Estado.Ativo
        and character.Parent
        and hrp.Parent do

        local atual = hrp.Position
        local diferenca = targetPosition - atual
        local distancia = diferenca.Magnitude

        if distancia < 1 then
            hrp.CFrame = CFrame.new(targetPosition)
            hrp.Velocity = Vector3.new()
            hrp.RotVelocity = Vector3.new()
            chegou = true
            break
        end

        local dt = task.wait()

        local passo = math.min(
            distancia,
            Estado.Velocidade * dt
        )

        local direcao = diferenca.Unit
        local novaPosicao =
            atual + direcao * passo

        hrp.CFrame =
            CFrame.new(
                novaPosicao,
                novaPosicao + direcao
            )

        hrp.Velocity = Vector3.new()
        hrp.RotVelocity = Vector3.new()
    end

    for part, valorOriginal in pairs(colisaoOriginal) do
        if part and part.Parent then
            part.CanCollide = valorOriginal
        end
    end

    if humanoid and humanoid.Parent then
        humanoid.PlatformStand =
            platformStandOriginal
    end

    return chegou
end

--// IR PARA O OVO
Conectar(IrOvo.Activated:Connect(function()
    if Estado.IndoParaOvo then
        return
    end

    if Contar(Estado.OvosSelecionados) == 0 then
        StatusOvos.Text = "Selecione um ovo primeiro."
        return
    end

    local ovo, distancia, nome =
        EncontrarOvoMaisProximo()

    if not ovo then
        StatusOvos.Text =
            "Nenhum ovo selecionado encontrado."
        return
    end

    local posicao = GetEggPosition(ovo)

    if not posicao then
        StatusOvos.Text =
            "Não foi possível obter a posição."
        return
    end

    Estado.IndoParaOvo = true
    StatusOvos.Text = "Indo para: " .. tostring(nome)

    task.spawn(function()
        local chegou = IrAteOvo(posicao)

        if Estado.Ativo then
            if chegou then
                StatusOvos.Text =
                    string.format(
                        "Chegou em %s (%.0f studs)",
                        nome,
                        distancia or 0
                    )
            else
                StatusOvos.Text =
                    "Movimento interrompido."
            end
        end

        Estado.IndoParaOvo = false
    end)
end))

--// LIMPAR
Conectar(LimparOvos.Activated:Connect(function()
    table.clear(Estado.OvosSelecionados)
    AtualizarOvos()
end))

--// SELETOR
local SeletorAberto = false

local function AbrirSeletor()
    if SeletorAberto or not Estado.Ativo then
        return
    end

    SeletorAberto = true

    local Overlay = Instance.new("Frame")
    Overlay.Name = "SeletorOvos"
    Overlay.Size = UDim2.new(1, 0, 1, 0)
    Overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    Overlay.BackgroundTransparency = 0.35
    Overlay.ZIndex = 20
    Overlay.Active = true
    Overlay.Parent = Painel

    local Caixa = Instance.new("Frame")
    Caixa.Size = UDim2.fromOffset(260, 260)
    Caixa.Position = UDim2.new(
        0.5,
        -130,
        0.5,
        -130
    )
    Caixa.BackgroundColor3 =
        Color3.fromRGB(38, 38, 38)

    Caixa.BorderSizePixel = 0
    Caixa.ZIndex = 21
    Caixa.Parent = Overlay

    Arredondar(Caixa, 9)

    local TituloSeletor =
        Instance.new("TextLabel")

    TituloSeletor.Size =
        UDim2.new(1, -45, 0, 30)

    TituloSeletor.Position =
        UDim2.fromOffset(10, 5)

    TituloSeletor.BackgroundTransparency = 1
    TituloSeletor.Text = "Selecionar ovos"
    TituloSeletor.TextColor3 =
        Color3.fromRGB(255, 255, 255)

    TituloSeletor.TextSize = 14
    TituloSeletor.Font = Enum.Font.GothamBold
    TituloSeletor.TextXAlignment =
        Enum.TextXAlignment.Left

    TituloSeletor.ZIndex = 22
    TituloSeletor.Parent = Caixa

    local FecharSeletor =
        Instance.new("TextButton")

    FecharSeletor.Size =
        UDim2.fromOffset(32, 32)

    FecharSeletor.Position =
        UDim2.new(1, -34, 0, 2)

    FecharSeletor.BackgroundTransparency = 1
    FecharSeletor.Text = "✕"
    FecharSeletor.TextColor3 =
        Color3.fromRGB(255, 255, 255)

    FecharSeletor.TextSize = 15
    FecharSeletor.Font = Enum.Font.GothamBold

    FecharSeletor.ZIndex = 22
    FecharSeletor.Parent = Caixa

    local Lista = Instance.new("ScrollingFrame")
    Lista.Size =
        UDim2.new(1, -20, 1, -45)

    Lista.Position = UDim2.fromOffset(10, 38)
    Lista.BackgroundTransparency = 1
    Lista.BorderSizePixel = 0
    Lista.ScrollBarThickness = 4
    Lista.CanvasSize = UDim2.new(0, 0, 0, 0)
    Lista.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Lista.ZIndex = 22
    Lista.Parent = Caixa

    local Layout = Instance.new("UIListLayout")
    Layout.Padding = UDim.new(0, 5)
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Parent = Lista

    local function FecharJanela()
        if Overlay then
            Overlay:Destroy()
        end

        SeletorAberto = false
    end

    FecharSeletor.Activated:Connect(
        FecharJanela
    )

    for i, eggName in ipairs(EGG_NAMES) do
        local Botao =
            Instance.new("TextButton")

        Botao.Size =
            UDim2.new(1, 0, 0, 30)

        Botao.LayoutOrder = i
        Botao.AutoButtonColor = false
        Botao.BorderSizePixel = 0

        if Estado.OvosSelecionados[eggName] then
            Botao.BackgroundColor3 =
                Color3.fromRGB(70, 100, 170)
        else
            Botao.BackgroundColor3 =
                Color3.fromRGB(28, 28, 28)
        end

        Botao.Text = eggName
        Botao.TextColor3 =
            Color3.fromRGB(235, 235, 235)

        Botao.TextSize = 12
        Botao.Font = Enum.Font.Gotham
        Botao.TextXAlignment =
            Enum.TextXAlignment.Left

        Botao.ZIndex = 22
        Botao.Parent = Lista

        Arredondar(Botao, 6)

        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 9)
        padding.Parent = Botao

        Botao.Activated:Connect(function()
            if Estado.OvosSelecionados[eggName] then
                Estado.OvosSelecionados[eggName] = nil
                Botao.BackgroundColor3 =
                    Color3.fromRGB(28, 28, 28)
            else
                Estado.OvosSelecionados[eggName] = true
                Botao.BackgroundColor3 =
                    Color3.fromRGB(70, 100, 170)
            end

            AtualizarOvos()
        end)
    end
end

Conectar(
    SelecionarOvos.Activated:Connect(
        AbrirSeletor
    )
)

--// BOTÃO REABRIR
local Abrir = Instance.new("TextButton")
Abrir.Size = UDim2.fromOffset(48, 48)
Abrir.Position = UDim2.fromOffset(15, 180)
Abrir.BackgroundColor3 =
    Color3.fromRGB(30, 30, 30)

Abrir.BorderSizePixel = 0
Abrir.Text = "▶"
Abrir.TextColor3 =
    Color3.fromRGB(255, 255, 255)

Abrir.TextSize = 18
Abrir.Font = Enum.Font.GothamBold
Abrir.Visible = false
Abrir.Parent = ScreenGui

Arredondar(Abrir, 9)

Conectar(Fechar.Activated:Connect(function()
    Painel.Visible = false
    Abrir.Visible = true
end))

Conectar(Abrir.Activated:Connect(function()
    Painel.Visible = true
    Abrir.Visible = false
end))

--// ARRASTAR
local Arrastando = false
local InicioToque = nil
local InicioPosicao = nil

Conectar(Topo.InputBegan:Connect(function(input)
    if input.UserInputType ==
        Enum.UserInputType.Touch
        or input.UserInputType ==
        Enum.UserInputType.MouseButton1 then

        Arrastando = true
        InicioToque = input.Position
        InicioPosicao = Painel.Position

        local conexao

        conexao = input.Changed:Connect(function()
            if input.UserInputState ==
                Enum.UserInputState.End then

                Arrastando = false

                if conexao then
                    conexao:Disconnect()
                end
            end
        end)
    end
end))

Conectar(
    UserInputService.InputChanged:Connect(
        function(input)
            if not Arrastando then
                return
            end

            if input.UserInputType ~=
                Enum.UserInputType.Touch
                and input.UserInputType ~=
                Enum.UserInputType.MouseMovement then

                return
            end

            local delta =
                input.Position - InicioToque

            Painel.Position = UDim2.new(
                InicioPosicao.X.Scale,
                InicioPosicao.X.Offset + delta.X,
                InicioPosicao.Y.Scale,
                InicioPosicao.Y.Offset + delta.Y
            )
        end
    )
)

--// STOP GLOBAL
function Estado:Stop()
    if not self.Ativo then
        return
    end

    self.Ativo = false
    self.VelocidadeAtiva = false
    self.IndoParaOvo = false

    DesconectarTudo()

    pcall(function()
        if ScreenGui then
            ScreenGui:Destroy()
        end
    end)
end

ENV[TOKEN_NAME] = Estado

AtualizarOvos()
AtualizarBotaoVel()
