-- ================================================================
-- MONTAR UM PET / RIDE A PET
-- FASE 1:
--   ⚡ ABA VELOCIDADE
--   🥚 ABA OVOS (reservada para depois)
-- ================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- ================================================================
-- LIMPEZA DE EXECUÇÃO ANTERIOR
-- ================================================================

local ENV = (getgenv and getgenv()) or _G

pcall(function()
    if ENV.__MONTAR_UM_PET_TABS
        and ENV.__MONTAR_UM_PET_TABS.Stop then

        ENV.__MONTAR_UM_PET_TABS.Stop()
    end
end)

local Ativo = true
local Velocidade = 150
local VelocidadeAtiva = false

local Conexoes = {}

local function Registrar(conexao)
    if conexao then
        table.insert(Conexoes, conexao)
    end

    return conexao
end

local function PararTudo()
    Ativo = false

    for _, conexao in ipairs(Conexoes) do
        pcall(function()
            conexao:Disconnect()
        end)
    end

    table.clear(Conexoes)

    pcall(function()
        local gui = CoreGui:FindFirstChild(
            "MontarUmPetTabs"
        )

        if gui then
            gui:Destroy()
        end
    end)

    pcall(function()
        if gethui then
            local hui = gethui()

            local gui = hui:FindFirstChild(
                "MontarUmPetTabs"
            )

            if gui then
                gui:Destroy()
            end
        end
    end)
end

ENV.__MONTAR_UM_PET_TABS = {
    Stop = PararTudo
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
-- MESMA FÓRMULA DO ARQUIVO ORIGINAL
-- ================================================================

Registrar(
    RunService.RenderStepped:Connect(
        function()

            if not Ativo
                or not VelocidadeAtiva then

                return
            end

            local character = GetCharacter()
            local humanoid = GetHumanoid()

            if not character
                or not humanoid then

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
                    * (Velocidade / 135)
                )
            end)
        end
    )
)

-- ================================================================
-- PARENT DA INTERFACE
-- ================================================================

local function GetGuiParent()

    if gethui then
        local ok, hui = pcall(gethui)

        if ok and hui then
            return hui
        end
    end

    return CoreGui
end

local GuiParent = GetGuiParent()

if not GuiParent then
    warn(
        "[MONTAR UM PET] Não foi possível criar a interface."
    )

    PararTudo()
    return
end

-- ================================================================
-- GUI PRINCIPAL
-- ================================================================

local ScreenGui = Instance.new("ScreenGui")

ScreenGui.Name = "MontarUmPetTabs"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior =
    Enum.ZIndexBehavior.Sibling

ScreenGui.Parent = GuiParent

local Main = Instance.new("Frame")

Main.Size = UDim2.fromOffset(270, 190)
Main.Position = UDim2.new(
    0.05,
    0,
    0.18,
    0
)

Main.BackgroundColor3 =
    Color3.fromRGB(15, 15, 20)

Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = ScreenGui

Instance.new(
    "UICorner",
    Main
).CornerRadius =
    UDim.new(0, 10)

local Stroke = Instance.new("UIStroke")

Stroke.Color =
    Color3.fromRGB(55, 55, 65)

Stroke.Thickness = 1
Stroke.Parent = Main

-- ================================================================
-- CABEÇALHO
-- ================================================================

local Header = Instance.new("Frame")

Header.Size = UDim2.new(
    1,
    0,
    0,
    34
)

Header.BackgroundTransparency = 1
Header.Parent = Main

local Title = Instance.new("TextLabel")

Title.Size = UDim2.new(
    1,
    -50,
    1,
    0
)

Title.Position =
    UDim2.fromOffset(
        10,
        0
    )

Title.BackgroundTransparency = 1
Title.Text = "⚡ MONTAR UM PET"
Title.TextColor3 =
    Color3.new(1, 1, 1)

Title.Font =
    Enum.Font.SourceSansBold

Title.TextSize = 15
Title.TextXAlignment =
    Enum.TextXAlignment.Left

Title.Parent = Header

local Fechar = Instance.new("TextButton")

Fechar.Size =
    UDim2.fromOffset(
        28,
        26
    )

Fechar.Position =
    UDim2.new(
        1,
        -34,
        0,
        4
    )

Fechar.BackgroundColor3 =
    Color3.fromRGB(85, 40, 40)

Fechar.Text = "×"

Fechar.TextColor3 =
    Color3.new(1, 1, 1)

Fechar.Font =
    Enum.Font.SourceSansBold

Fechar.TextSize = 18
Fechar.Parent = Header

Instance.new(
    "UICorner",
    Fechar
).CornerRadius =
    UDim.new(0, 6)

-- ================================================================
-- ÁREA DAS ABAS
-- ================================================================

local TabsBar = Instance.new("Frame")

TabsBar.Size = UDim2.new(
    1,
    -12,
    0,
    34
)

TabsBar.Position =
    UDim2.fromOffset(
        6,
        37
    )

TabsBar.BackgroundTransparency = 1
TabsBar.Parent = Main

local VelTab = Instance.new("TextButton")

VelTab.Size =
    UDim2.new(
        0.5,
        -3,
        1,
        0
    )

VelTab.Position =
    UDim2.fromOffset(
        0,
        0
    )

VelTab.BackgroundColor3 =
    Color3.fromRGB(
        40,
        110,
        70
    )

VelTab.Text =
    "⚡ Velocidade"

VelTab.TextColor3 =
    Color3.new(1, 1, 1)

VelTab.Font =
    Enum.Font.SourceSansBold

VelTab.TextSize = 13
VelTab.Parent = TabsBar

Instance.new(
    "UICorner",
    VelTab
).CornerRadius =
    UDim.new(0, 7)

local OvoTab = Instance.new("TextButton")

OvoTab.Size =
    UDim2.new(
        0.5,
        -3,
        1,
        0
    )

OvoTab.Position =
    UDim2.new(
        0.5,
        3,
        0,
        0
    )

OvoTab.BackgroundColor3 =
    Color3.fromRGB(
        45,
        45,
        55
    )

OvoTab.Text =
    "🥚 Ovos"

OvoTab.TextColor3 =
    Color3.new(1, 1, 1)

OvoTab.Font =
    Enum.Font.SourceSansBold

OvoTab.TextSize = 13
OvoTab.Parent = TabsBar

Instance.new(
    "UICorner",
    OvoTab
).CornerRadius =
    UDim.new(0, 7)

-- ================================================================
-- PÁGINA VELOCIDADE
-- ================================================================

local VelPage = Instance.new("Frame")

VelPage.Size = UDim2.new(
    1,
    -12,
    1,
    -80
)

VelPage.Position =
    UDim2.fromOffset(
        6,
        76
    )

VelPage.BackgroundTransparency = 1
VelPage.Parent = Main

local Input = Instance.new("TextBox")

Input.Size =
    UDim2.new(
        0.60,
        -4,
        0,
        34
    )

Input.Position =
    UDim2.fromOffset(
        0,
        5
    )

Input.BackgroundColor3 =
    Color3.fromRGB(
        28,
        28,
        36
    )

Input.Text =
    tostring(Velocidade)

Input.TextColor3 =
    Color3.new(1, 1, 1)

Input.PlaceholderText =
    "Velocidade"

Input.PlaceholderColor3 =
    Color3.fromRGB(
        130,
        130,
        140
    )

Input.Font =
    Enum.Font.SourceSans

Input.TextSize = 14
Input.ClearTextOnFocus = false
Input.Parent = VelPage

Instance.new(
    "UICorner",
    Input
).CornerRadius =
    UDim.new(0, 7)

local Aplicar = Instance.new("TextButton")

Aplicar.Size =
    UDim2.new(
        0.40,
        -4,
        0,
        34
    )

Aplicar.Position =
    UDim2.new(
        0.60,
        4,
        0,
        5
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
    Color3.new(1, 1, 1)

Aplicar.Font =
    Enum.Font.SourceSansBold

Aplicar.TextSize = 13
Aplicar.Parent = VelPage

Instance.new(
    "UICorner",
    Aplicar
).CornerRadius =
    UDim.new(0, 7)

local Toggle = Instance.new("TextButton")

Toggle.Size =
    UDim2.new(
        1,
        0,
        0,
        34
    )

Toggle.Position =
    UDim2.fromOffset(
        0,
        48
    )

Toggle.Font =
    Enum.Font.SourceSansBold

Toggle.TextSize = 13
Toggle.TextColor3 =
    Color3.new(1, 1, 1)

Toggle.Parent = VelPage

Instance.new(
    "UICorner",
    Toggle
).CornerRadius =
    UDim.new(0, 7)

local Status = Instance.new("TextLabel")

Status.Size =
    UDim2.new(
        1,
        0,
        0,
        25
    )

Status.Position =
    UDim2.fromOffset(
        0,
        86
    )

Status.BackgroundTransparency = 1
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

Status.Parent = VelPage

local function AtualizarVelocidade()

    if VelocidadeAtiva then

        Toggle.Text =
            "Velocidade: ATIVADA"

        Toggle.BackgroundColor3 =
            Color3.fromRGB(
                35,
                125,
                75
            )

        Status.Text =
            "Valor atual: "
            .. tostring(Velocidade)

    else

        Toggle.Text =
            "Velocidade: DESATIVADA"

        Toggle.BackgroundColor3 =
            Color3.fromRGB(
                48,
                48,
                58
            )

        Status.Text =
            "Valor salvo: "
            .. tostring(Velocidade)
    end
end

AtualizarVelocidade()

-- ================================================================
-- PÁGINA OVOS
-- Somente espaço reservado por enquanto.
-- ================================================================

local OvoPage = Instance.new("Frame")

OvoPage.Size = VelPage.Size
OvoPage.Position = VelPage.Position
OvoPage.BackgroundTransparency = 1
OvoPage.Visible = false
OvoPage.Parent = Main

local OvoStatus = Instance.new("TextLabel")

OvoStatus.Size =
    UDim2.new(
        1,
        0,
        0,
        50
    )

OvoStatus.Position =
    UDim2.fromOffset(
        0,
        15
    )

OvoStatus.BackgroundTransparency = 1
OvoStatus.Text =
    "🥚 Radar de ovos\nEm desenvolvimento"

OvoStatus.TextColor3 =
    Color3.fromRGB(
        180,
        180,
        190
    )

OvoStatus.Font =
    Enum.Font.SourceSans

OvoStatus.TextSize = 14
OvoStatus.Parent = OvoPage

-- ================================================================
-- TROCA DE ABA
-- ================================================================

Registrar(
    VelTab.MouseButton1Click:Connect(
        function()

            VelPage.Visible = true
            OvoPage.Visible = false

            VelTab.BackgroundColor3 =
                Color3.fromRGB(
                    40,
                    110,
                    70
                )

            OvoTab.BackgroundColor3 =
                Color3.fromRGB(
                    45,
                    45,
                    55
                )
        end
    )
)

Registrar(
    OvoTab.MouseButton1Click:Connect(
        function()

            VelPage.Visible = false
            OvoPage.Visible = true

            OvoTab.BackgroundColor3 =
                Color3.fromRGB(
                    40,
                    110,
                    70
                )

            VelTab.BackgroundColor3 =
                Color3.fromRGB(
                    45,
                    45,
                    55
                )
        end
    )
)

-- ================================================================
-- APLICAR VELOCIDADE
-- ================================================================

Registrar(
    Aplicar.MouseButton1Click:Connect(
        function()

            local valor =
                tonumber(
                    Input.Text
                )

            if not valor then

                Input.Text =
                    tostring(
                        Velocidade
                    )

                return
            end

            Velocidade =
                math.clamp(
                    valor,
                    16,
                    1000
                )

            Input.Text =
                tostring(
                    Velocidade
                )

            AtualizarVelocidade()
        end
    )
)

-- ================================================================
-- ATIVAR / DESATIVAR
-- ================================================================

Registrar(
    Toggle.MouseButton1Click:Connect(
        function()

            VelocidadeAtiva =
                not VelocidadeAtiva

            AtualizarVelocidade()
        end
    )
)

-- ================================================================
-- FECHAR
-- ================================================================

Registrar(
    Fechar.MouseButton1Click:Connect(
        function()
            PararTudo()
        end
    )
)

-- ================================================================
-- ARRASTAR NO CELULAR
-- ================================================================

local Arrastando = false
local InicioArraste
local PosicaoInicial

Registrar(
    Header.InputBegan:Connect(
        function(input)

            if input.UserInputType
                == Enum.UserInputType.MouseButton1
                or input.UserInputType
                == Enum.UserInputType.Touch then

                Arrastando = true

                InicioArraste =
                    input.Position

                PosicaoInicial =
                    Main.Position
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
                ~= Enum.UserInputType.MouseMovement
                and input.UserInputType
                ~= Enum.UserInputType.Touch then

                return
            end

            local delta =
                input.Position
                - InicioArraste

            Main.Position =
                UDim2.new(
                    PosicaoInicial.X.Scale,
                    PosicaoInicial.X.Offset
                        + delta.X,

                    PosicaoInicial.Y.Scale,
                    PosicaoInicial.Y.Offset
                        + delta.Y
                )
        end
    )
)

Registrar(
    UserInputService.InputEnded:Connect(
        function(input)

            if input.UserInputType
                == Enum.UserInputType.MouseButton1
                or input.UserInputType
                == Enum.UserInputType.Touch then

                Arrastando = false
            end
        end
    )
)

print(
    "[MONTAR UM PET] Abas + velocidade carregadas."
)
