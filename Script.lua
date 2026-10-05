-- ================================================================
-- MONTAR UM PET / RIDE A PET
-- SOMENTE:
-- 1. VELOCIDADE
-- 2. RADAR DE OVOS + RARIDADE
-- 3. POSIÇÃO EXATA X/Y/Z + DISTÂNCIA ATUALIZADA
-- ================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- ================================================================
-- CONFIGURAÇÃO
-- ================================================================

local Velocidade = 150
local VelocidadeAtiva = true

local IntervaloScan = 1
local IntervaloAtualizacao = 0.20

-- ================================================================
-- LIMPEZA DE EXECUÇÃO ANTERIOR
-- ================================================================

local ENV = (getgenv and getgenv()) or _G

pcall(function()
    if ENV.__MONTAR_UM_PET_MINI
        and ENV.__MONTAR_UM_PET_MINI.Stop then

        ENV.__MONTAR_UM_PET_MINI.Stop()
    end
end)

local Ativo = true
local Conexoes = {}
local OvosRadar = {}

local function Registrar(conexao)
    if conexao then
        table.insert(Conexoes, conexao)
    end

    return conexao
end

local function LimparRadar()
    for _, dados in pairs(OvosRadar) do

        pcall(function()
            if dados.Marker
                and dados.Marker.Parent then

                dados.Marker:Destroy()
            end
        end)

    end

    table.clear(OvosRadar)
end

local function PararTudo()
    Ativo = false

    for _, conexao in ipairs(Conexoes) do
        pcall(function()
            conexao:Disconnect()
        end)
    end

    table.clear(Conexoes)
    LimparRadar()

    pcall(function()
        local gui =
            CoreGui:FindFirstChild(
                "MontarUmPetMini"
            )

        if gui then
            gui:Destroy()
        end
    end)

    pcall(function()
        if gethui then
            local hui = gethui()

            local gui =
                hui:FindFirstChild(
                    "MontarUmPetMini"
                )

            if gui then
                gui:Destroy()
            end
        end
    end)
end

ENV.__MONTAR_UM_PET_MINI = {
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

local function GetRoot()
    local character = GetCharacter()

    if not character then
        return nil
    end

    return character:FindFirstChild(
        "HumanoidRootPart"
    )
end

-- ================================================================
-- RARIDADE
-- ================================================================

local function ClassificarRaridade(nome)
    local n =
        string.lower(tostring(nome or ""))

    if string.find(n, "secret", 1, true)
        or string.find(n, "divine", 1, true)
        or string.find(n, "god", 1, true) then

        return "🌌 Secreto",
            Color3.fromRGB(255, 0, 255)

    elseif string.find(n, "myth", 1, true)
        or string.find(n, "mitic", 1, true) then

        return "🔥 Mítico",
            Color3.fromRGB(255, 60, 60)

    elseif string.find(n, "legend", 1, true)
        or string.find(n, "lend", 1, true) then

        return "👑 Lendário",
            Color3.fromRGB(255, 170, 0)

    elseif string.find(n, "epic", 1, true)
        or string.find(n, "epico", 1, true) then

        return "🔮 Épico",
            Color3.fromRGB(170, 60, 255)

    elseif string.find(n, "rare", 1, true)
        or string.find(n, "raro", 1, true) then

        return "🔵 Raro",
            Color3.fromRGB(60, 160, 255)
    end

    return "⚪ Comum",
        Color3.fromRGB(220, 220, 220)
end

-- ================================================================
-- LOCALIZAÇÃO DOS OVOS
-- ================================================================

local function EhOvo(nome)
    local n =
        string.lower(tostring(nome or ""))

    return string.find(
        n,
        "egg",
        1,
        true
    ) ~= nil
        or string.find(
            n,
            "ovo",
            1,
            true
        ) ~= nil
end

local function EncontrarModeloOvo(obj)
    local atual = obj
    local encontrado = nil

    while atual do

        if atual:IsA("Model")
            and EhOvo(atual.Name) then

            encontrado = atual
        end

        atual = atual.Parent
    end

    return encontrado
end

local function ObterParte(modelo)
    if not modelo then
        return nil
    end

    if modelo:IsA("BasePart") then
        return modelo
    end

    if modelo:IsA("Model") then

        if modelo.PrimaryPart then
            return modelo.PrimaryPart
        end

        return modelo:FindFirstChildWhichIsA(
            "BasePart",
            true
        )
    end

    return nil
end

local function ObterPosicao(modelo)
    if not modelo
        or not modelo.Parent then

        return nil
    end

    if modelo:IsA("Model") then

        local ok, pivot =
            pcall(function()
                return modelo:GetPivot()
            end)

        if ok and pivot then
            return pivot.Position
        end
    end

    local parte = ObterParte(modelo)

    return parte and parte.Position
        or nil
end

-- ================================================================
-- CRIAÇÃO DO ESP
-- ================================================================

local function CriarRadar(modelo)
    if OvosRadar[modelo] then
        return
    end

    local parte = ObterParte(modelo)

    if not parte then
        return
    end

    local raridade, cor =
        ClassificarRaridade(modelo.Name)

    local marker = Instance.new("Folder")
    marker.Name = "RadarOvo"
    marker.Parent = parte

    -- Caixa através da parede
    local box =
        Instance.new("BoxHandleAdornment")

    box.Name = "OvoBox"
    box.Adornee = parte
    box.Size =
        parte.Size
        + Vector3.new(0.3, 0.3, 0.3)

    box.Color3 = cor
    box.Transparency = 0.60
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Parent = marker

    -- Texto
    local billboard =
        Instance.new("BillboardGui")

    billboard.Name = "OvoInfo"
    billboard.Adornee = parte
    billboard.Size =
        UDim2.fromOffset(260, 90)

    billboard.StudsOffset =
        Vector3.new(0, 4, 0)

    billboard.AlwaysOnTop = true
    billboard.Parent = marker

    local label =
        Instance.new("TextLabel")

    label.Size =
        UDim2.fromScale(1, 1)

    label.BackgroundTransparency = 1

    label.TextColor3 = cor
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 =
        Color3.fromRGB(0, 0, 0)

    label.Font =
        Enum.Font.SourceSansBold

    label.TextSize = 14
    label.TextWrapped = true

    label.Parent = billboard

    OvosRadar[modelo] = {
        Marker = marker,
        Box = box,
        Billboard = billboard,
        Label = label,
        Part = parte,
        Raridade = raridade,
    }
end

local function RemoverRadar(modelo)
    local dados =
        OvosRadar[modelo]

    if not dados then
        return
    end

    pcall(function()
        if dados.Marker
            and dados.Marker.Parent then

            dados.Marker:Destroy()
        end
    end)

    OvosRadar[modelo] = nil
end

-- ================================================================
-- SCAN DOS OVOS
-- ================================================================

local function ScanContainer(container, encontrados)
    if not container then
        return
    end

    for _, objeto in ipairs(
        container:GetDescendants()
    ) do

        local modeloOvo =
            EncontrarModeloOvo(objeto)

        if modeloOvo then

            encontrados[modeloOvo] = true

            if not OvosRadar[modeloOvo] then
                CriarRadar(modeloOvo)
            end
        end
    end
end

local function ScanOvos()
    if not Ativo then
        return
    end

    local encontrados = {}

    local renderedEggs =
        Workspace:FindFirstChild(
            "RenderedEggs",
            true
        )

    local eggSpawns =
        Workspace:FindFirstChild(
            "EggSpawns",
            true
        )

    ScanContainer(
        renderedEggs,
        encontrados
    )

    ScanContainer(
        eggSpawns,
        encontrados
    )

    -- Remove ovos que desapareceram
    for modelo in pairs(OvosRadar) do

        if not encontrados[modelo]
            or not modelo.Parent then

            RemoverRadar(modelo)
        end
    end
end

-- ================================================================
-- ATUALIZAÇÃO CONTÍNUA DAS POSIÇÕES
-- ================================================================

task.spawn(function()

    while Ativo do

        local root = GetRoot()

        if root then

            for modelo, dados in pairs(
                OvosRadar
            ) do

                if modelo.Parent
                    and dados.Part
                    and dados.Part.Parent
                    and dados.Label.Parent then

                    local pos =
                        ObterPosicao(modelo)

                    if pos then

                        local distancia =
                            (
                                root.Position
                                - pos
                            ).Magnitude

                        dados.Label.Text =
                            string.format(
                                "%s\n%s\nX: %.1f  Y: %.1f  Z: %.1f\nDistância: %.1f studs",
                                modelo.Name,
                                dados.Raridade,
                                pos.X,
                                pos.Y,
                                pos.Z,
                                distancia
                            )
                    end
                else

                    RemoverRadar(modelo)
                end
            end
        end

        task.wait(
            IntervaloAtualizacao
        )
    end
end)

-- ================================================================
-- SCAN PERIÓDICO
-- ================================================================

task.spawn(function()

    while Ativo do

        pcall(ScanOvos)

        task.wait(
            IntervaloScan
        )
    end
end)

-- ================================================================
-- VELOCIDADE
-- Fórmula do arquivo original
-- ================================================================

Registrar(
    RunService.RenderStepped:Connect(
        function()

            if not Ativo
                or not VelocidadeAtiva then

                return
            end

            local character =
                GetCharacter()

            local humanoid =
                GetHumanoid()

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
-- PEQUENO PAINEL DE VELOCIDADE
-- ================================================================

local function GetGuiParent()

    if gethui then

        local ok, hui =
            pcall(gethui)

        if ok and hui then
            return hui
        end
    end

    return CoreGui
end

local guiParent =
    GetGuiParent()

if guiParent then

    local ScreenGui =
        Instance.new("ScreenGui")

    ScreenGui.Name =
        "MontarUmPetMini"

    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = guiParent

    local Frame =
        Instance.new("Frame")

    Frame.Size =
        UDim2.fromOffset(190, 115)

    Frame.Position =
        UDim2.new(
            0.04,
            0,
            0.20,
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
        UDim.new(0, 9)

    local Title =
        Instance.new("TextLabel")

    Title.Size =
        UDim2.new(
            1,
            -10,
            0,
            28
        )

    Title.Position =
        UDim2.fromOffset(8, 3)

    Title.BackgroundTransparency = 1
    Title.Text =
        "⚡ Velocidade"

    Title.TextColor3 =
        Color3.new(1, 1, 1)

    Title.Font =
        Enum.Font.SourceSansBold

    Title.TextSize = 15
    Title.TextXAlignment =
        Enum.TextXAlignment.Left

    Title.Parent = Frame

    local Input =
        Instance.new("TextBox")

    Input.Size =
        UDim2.fromOffset(105, 32)

    Input.Position =
        UDim2.fromOffset(8, 35)

    Input.BackgroundColor3 =
        Color3.fromRGB(
            30,
            30,
            38
        )

    Input.Text =
        tostring(Velocidade)

    Input.TextColor3 =
        Color3.new(1, 1, 1)

    Input.Font =
        Enum.Font.SourceSans

    Input.TextSize = 14
    Input.ClearTextOnFocus = false
    Input.Parent = Frame

    Instance.new(
        "UICorner",
        Input
    ).CornerRadius =
        UDim.new(0, 6)

    local Aplicar =
        Instance.new("TextButton")

    Aplicar.Size =
        UDim2.fromOffset(60, 32)

    Aplicar.Position =
        UDim2.fromOffset(120, 35)

    Aplicar.BackgroundColor3 =
        Color3.fromRGB(
            35,
            115,
            70
        )

    Aplicar.Text = "Aplicar"

    Aplicar.TextColor3 =
        Color3.new(1, 1, 1)

    Aplicar.Font =
        Enum.Font.SourceSansBold

    Aplicar.TextSize = 13
    Aplicar.Parent = Frame

    Instance.new(
        "UICorner",
        Aplicar
    ).CornerRadius =
        UDim.new(0, 6)

    local Toggle =
        Instance.new("TextButton")

    Toggle.Size =
        UDim2.new(
            1,
            -16,
            0,
            30
        )

    Toggle.Position =
        UDim2.fromOffset(8, 76)

    Toggle.TextColor3 =
        Color3.new(1, 1, 1)

    Toggle.Font =
        Enum.Font.SourceSansBold

    Toggle.TextSize = 13
    Toggle.Parent = Frame

    Instance.new(
        "UICorner",
        Toggle
    ).CornerRadius =
        UDim.new(0, 6)

    local function AtualizarToggle()

        if VelocidadeAtiva then

            Toggle.Text =
                "Velocidade: ATIVADA"

            Toggle.BackgroundColor3 =
                Color3.fromRGB(
                    35,
                    125,
                    75
                )

        else

            Toggle.Text =
                "Velocidade: DESATIVADA"

            Toggle.BackgroundColor3 =
                Color3.fromRGB(
                    50,
                    50,
                    58
                )
        end
    end

    AtualizarToggle()

    Registrar(
        Aplicar.MouseButton1Click:Connect(
            function()

                local valor =
                    tonumber(
                        Input.Text
                    )

                if valor then

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
                end
            end
        )
    )

    Registrar(
        Toggle.MouseButton1Click:Connect(
            function()

                VelocidadeAtiva =
                    not VelocidadeAtiva

                AtualizarToggle()
            end
        )
    )

    -- Arrastar painel
    local arrastando = false
    local inicio
    local posInicial

    Registrar(
        Frame.InputBegan:Connect(
            function(input)

                if input.UserInputType
                    == Enum.UserInputType.MouseButton1
                    or input.UserInputType
                    == Enum.UserInputType.Touch then

                    arrastando = true
                    inicio = input.Position
                    posInicial =
                        Frame.Position
                end
            end
        )
    )

    Registrar(
        UserInputService.InputChanged:Connect(
            function(input)

                if not arrastando then
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
                    - inicio

                Frame.Position =
                    UDim2.new(
                        posInicial.X.Scale,
                        posInicial.X.Offset
                            + delta.X,

                        posInicial.Y.Scale,
                        posInicial.Y.Offset
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

                    arrastando = false
                end
            end
        )
    )
end

-- ================================================================
-- PRIMEIRO SCAN
-- ================================================================

pcall(ScanOvos)

print(
    "[RIDE A PET] Velocidade + radar de ovos ativos."
)
