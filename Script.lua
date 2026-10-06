-- ================================================================
-- MONTAR UM PET / RIDE A PET
-- VELOCIDADE
-- EXECUÇÃO DUPLA: mantém somente uma interface
-- ================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ENV = (getgenv and getgenv()) or _G

-- ================================================================
-- STOP DA EXECUÇÃO ANTERIOR
-- ================================================================

pcall(function()
    local antigo = ENV.__MONTAR_UM_PET_VELOCIDADE

    if antigo and antigo.Stop then
        antigo.Stop()
    end
end)

-- Remove qualquer GUI antiga que tenha sobrado
pcall(function()
    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui.Name == "MontarUmPetVelocidade" then
            gui:Destroy()
        end
    end
end)

-- ================================================================
-- ESTADO DA NOVA EXECUÇÃO
-- ================================================================

local Estado = {
    Ativo = true,
    Velocidade = 150,
    VelocidadeAtiva = false,
}

local Conexoes = {}

local function Registrar(conexao)
    if conexao then
        table.insert(Conexoes, conexao)
    end

    return conexao
end

local function PararTudo()
    if not Estado.Ativo then
        return
    end

    Estado.Ativo = false
    Estado.VelocidadeAtiva = false

    for _, conexao in ipairs(Conexoes) do
        pcall(function()
            conexao:Disconnect()
        end)
    end

    table.clear(Conexoes)

    pcall(function()
        local gui = PlayerGui:FindFirstChild(
            "MontarUmPetVelocidade"
        )

        if gui then
            gui:Destroy()
        end
    end)
end

ENV.__MONTAR_UM_PET_VELOCIDADE = {
    Stop = PararTudo,
    Estado = Estado,
}

-- ================================================================
-- PERSONAGEM
-- ================================================================

local function GetCharacter()
    return LocalPlayer.Character
end

local function GetHumanoid()
    local character = GetCharacter()

    if not character then
        return nil
    end

    return character:FindFirstChildOfClass(
        "Humanoid"
    )
end

-- ================================================================
-- VELOCIDADE
-- Mesma fórmula do arquivo original
-- ================================================================

Registrar(
    RunService.RenderStepped:Connect(
        function()

            if not Estado.Ativo then
                return
            end

            if not Estado.VelocidadeAtiva then
                return
            end

            local character = GetCharacter()
            local humanoid = GetHumanoid()

            if not character or not humanoid then
                return
            end

            local direcao =
                humanoid.MoveDirection

            if direcao.Magnitude <= 0 then
                return
            end

            pcall(function()
                character:TranslateBy(
                    direcao
                    * (Estado.Velocidade / 135)
                )
            end)
        end
    )
)

-- ================================================================
-- INTERFACE
-- ================================================================

local ScreenGui = Instance.new("ScreenGui")

ScreenGui.Name =
    "MontarUmPetVelocidade"

ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior =
    Enum.ZIndexBehavior.Sibling

ScreenGui.Parent = PlayerGui

-- ================================================================
-- JANELA
-- ================================================================

local Frame = Instance.new("Frame")

Frame.Size =
    UDim2.fromOffset(
        230,
        135
    )

Frame.Position =
    UDim2.new(
        0.05,
        0,
        0.18,
        0
    )

Frame.BackgroundColor3 =
    Color3.fromRGB(
        18,
        18,
        24
    )

Frame.BorderSizePixel = 0
Frame.Active = true
Frame.Parent = ScreenGui

Instance.new(
    "UICorner",
    Frame
).CornerRadius =
    UDim.new(0, 10)

local Borda = Instance.new("UIStroke")

Borda.Color =
    Color3.fromRGB(
        60,
        60,
        70
    )

Borda.Thickness = 1
Borda.Parent = Frame

-- ================================================================
-- TÍTULO
-- ================================================================

local Titulo = Instance.new("TextLabel")

Titulo.Size =
    UDim2.new(
        1,
        -55,
        0,
        30
    )

Titulo.Position =
    UDim2.fromOffset(
        9,
        3
    )

Titulo.BackgroundTransparency = 1
Titulo.Text =
    "⚡ Velocidade"

Titulo.TextColor3 =
    Color3.new(
        1,
        1,
        1
    )

Titulo.Font =
    Enum.Font.SourceSansBold

Titulo.TextSize = 16
Titulo.TextXAlignment =
    Enum.TextXAlignment.Left

Titulo.Parent = Frame

-- ================================================================
-- BOTÃO FECHAR
-- ================================================================

local Fechar = Instance.new("TextButton")

Fechar.Size =
    UDim2.fromOffset(
        30,
        26
    )

Fechar.Position =
    UDim2.new(
        1,
        -36,
        0,
        5
    )

Fechar.BackgroundColor3 =
    Color3.fromRGB(
        80,
        40,
        40
    )

Fechar.Text = "×"

Fechar.TextColor3 =
    Color3.new(
        1,
        1,
        1
    )

Fechar.Font =
    Enum.Font.SourceSansBold

Fechar.TextSize = 18
Fechar.Parent = Frame

Instance.new(
    "UICorner",
    Fechar
).CornerRadius =
    UDim.new(0, 6)

-- ================================================================
-- BOTÃO ABRIR / FECHAR PAINEL
-- ================================================================

local AbrirFechar = Instance.new("TextButton")

AbrirFechar.Size =
    UDim2.fromOffset(
        30,
        26
    )

AbrirFechar.Position =
    UDim2.new(
        1,
        -72,
        0,
        5
    )

AbrirFechar.BackgroundColor3 =
    Color3.fromRGB(
        45,
        45,
        55
    )

AbrirFechar.Text = "—"

AbrirFechar.TextColor3 =
    Color3.new(
        1,
        1,
        1
    )

AbrirFechar.Font =
    Enum.Font.SourceSansBold

AbrirFechar.TextSize = 17
AbrirFechar.Parent = Frame

Instance.new(
    "UICorner",
    AbrirFechar
).CornerRadius =
    UDim.new(0, 6)

-- ================================================================
-- CONTEÚDO
-- ================================================================

local Conteudo = Instance.new("Frame")

Conteudo.Size =
    UDim2.new(
        1,
        0,
        1,
        -35
    )

Conteudo.Position =
    UDim2.fromOffset(
        0,
        35
    )

Conteudo.BackgroundTransparency = 1
Conteudo.Parent = Frame

-- ================================================================
-- CAMPO
-- ================================================================

local Input = Instance.new("TextBox")

Input.Size =
    UDim2.fromOffset(
        120,
        34
    )

Input.Position =
    UDim2.fromOffset(
        9,
        4
    )

Input.BackgroundColor3 =
    Color3.fromRGB(
        30,
        30,
        38
    )

Input.Text =
    tostring(Estado.Velocidade)

Input.TextColor3 =
    Color3.new(
        1,
        1,
        1
    )

Input.PlaceholderText =
    "Velocidade"

Input.PlaceholderColor3 =
    Color3.fromRGB(
        140,
        140,
        150
    )

Input.Font =
    Enum.Font.SourceSans

Input.TextSize = 14
Input.ClearTextOnFocus = false
Input.Parent = Conteudo

Instance.new(
    "UICorner",
    Input
).CornerRadius =
    UDim.new(0, 7)

-- ================================================================
-- APLICAR
-- ================================================================

local Aplicar = Instance.new("TextButton")

Aplicar.Size =
    UDim2.fromOffset(
        70,
        34
    )

Aplicar.Position =
    UDim2.fromOffset(
        141,
        4
    )

Aplicar.BackgroundColor3 =
    Color3.fromRGB(
        40,
        110,
        70
    )

Aplicar.Text =
    "Aplicar"

Aplicar.TextColor3 =
    Color3.new(
        1,
        1,
        1
    )

Aplicar.Font =
    Enum.Font.SourceSansBold

Aplicar.TextSize = 13
Aplicar.Parent = Conteudo

Instance.new(
    "UICorner",
    Aplicar
).CornerRadius =
    UDim.new(0, 7)

-- ================================================================
-- ATIVAR
-- ================================================================

local Ativar = Instance.new("TextButton")

Ativar.Size =
    UDim2.new(
        1,
        -18,
        0,
        34
    )

Ativar.Position =
    UDim2.fromOffset(
        9,
        46
    )

Ativar.BackgroundColor3 =
    Color3.fromRGB(
        48,
        48,
        58
    )

Ativar.Text =
    "Velocidade: DESATIVADA"

Ativar.TextColor3 =
    Color3.new(
        1,
        1,
        1
    )

Ativar.Font =
    Enum.Font.SourceSansBold

Ativar.TextSize = 13
Ativar.Parent = Conteudo

Instance.new(
    "UICorner",
    Ativar
).CornerRadius =
    UDim.new(0, 7)

-- ================================================================
-- STATUS
-- ================================================================

local Status = Instance.new("TextLabel")

Status.Size =
    UDim2.new(
        1,
        -18,
        0,
        22
    )

Status.Position =
    UDim2.fromOffset(
        9,
        87
    )

Status.BackgroundTransparency = 1
Status.Text =
    "Valor: 150"

Status.TextColor3 =
    Color3.fromRGB(
        180,
        180,
        190
    )

Status.Font =
    Enum.Font.SourceSans

Status.TextSize = 12
Status.TextXAlignment =
    Enum.TextXAlignment.Left

Status.Parent = Conteudo

-- ================================================================
-- VISUAL
-- ================================================================

local function AtualizarVisual()

    Status.Text =
        "Valor: "
        .. tostring(
            Estado.Velocidade
        )

    if Estado.VelocidadeAtiva then

        Ativar.Text =
            "Velocidade: ATIVADA"

        Ativar.BackgroundColor3 =
            Color3.fromRGB(
                35,
                125,
                75
            )

    else

        Ativar.Text =
            "Velocidade: DESATIVADA"

        Ativar.BackgroundColor3 =
            Color3.fromRGB(
                48,
                48,
                58
            )
    end
end

AtualizarVisual()

-- ================================================================
-- APLICAR VALOR
-- ================================================================

Registrar(
    Aplicar.MouseButton1Click:Connect(
        function()

            local valor =
                tonumber(Input.Text)

            if not valor then
                Input.Text =
                    tostring(
                        Estado.Velocidade
                    )
                return
            end

            Estado.Velocidade =
                math.clamp(
                    valor,
                    16,
                    1000
                )

            Input.Text =
                tostring(
                    Estado.Velocidade
                )

            AtualizarVisual()
        end
    )
)

-- ================================================================
-- ON / OFF
-- ================================================================

Registrar(
    Ativar.MouseButton1Click:Connect(
        function()

            Estado.VelocidadeAtiva =
                not Estado.VelocidadeAtiva

            AtualizarVisual()
        end
    )
)

-- ================================================================
-- ABRIR / FECHAR
-- ================================================================

local Aberto = true

Registrar(
    AbrirFechar.MouseButton1Click:Connect(
        function()

            Aberto = not Aberto

            if Aberto then

                Conteudo.Visible = true

                Frame.Size =
                    UDim2.fromOffset(
                        230,
                        135
                    )

                AbrirFechar.Text =
                    "—"

            else

                Conteudo.Visible = false

                Frame.Size =
                    UDim2.fromOffset(
                        230,
                        40
                    )

                AbrirFechar.Text =
                    "+"
            end
        end
    )
)

-- ================================================================
-- ARRASTAR
-- ================================================================

local Arrastando = false
local Inicio
local PosicaoInicial

Registrar(
    Frame.InputBegan:Connect(
        function(input)

            if input.UserInputType
                == Enum.UserInputType.Touch
                or input.UserInputType
                == Enum.UserInputType.MouseButton1 then

                Arrastando = true
                Inicio = input.Position
                PosicaoInicial =
                    Frame.Position
            end
        end
    )
)

Registrar(
    UserInputService.InputChanged:Connect(
        function(input)

            if not Arrastando then
                return
            end

            if input.UserInputType
                ~= Enum.UserInputType.Touch
                and input.UserInputType
                ~= Enum.UserInputType.MouseMovement then

                return
            end

            local Delta =
                input.Position
                - Inicio

            Frame.Position =
                UDim2.new(
                    PosicaoInicial.X.Scale,
                    PosicaoInicial.X.Offset
                        + Delta.X,

                    PosicaoInicial.Y.Scale,
                    PosicaoInicial.Y.Offset
                        + Delta.Y
                )
        end
    )
)

Registrar(
    UserInputService.InputEnded:Connect(
        function(input)

            if input.UserInputType
                == Enum.UserInputType.Touch
                or input.UserInputType
                == Enum.UserInputType.MouseButton1 then

                Arrastando = false
            end
        end
    )
)

print(
    "[MONTAR UM PET] Apenas uma interface de velocidade está ativa."
)
