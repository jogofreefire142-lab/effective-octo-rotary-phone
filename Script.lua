--[[
    RIDE A PET - LAB MULTI-FUNÇÕES
    Revisão completa:
    - Compatibilidade com executor / fallback para PlayerGui
    - GUI duplicada é removida ao executar novamente
    - Arraste melhor em PC e celular
    - Busca segura de RemoteEvent/RemoteFunction
    - Cache de remotes para reduzir FindFirstChild repetitivo
    - Tratamento de respawn
    - Conexões e loops encerrados corretamente
    - Validação da velocidade
    - Status visual para diagnóstico
    - Botão para parar todas as automações
]]

-- =========================================================
-- PARTE 1: SERVIÇOS E COMPATIBILIDADE
-- =========================================================

local function getService(nome)
    local ok, servico = pcall(function()
        return game:GetService(nome)
    end)

    return ok and servico or nil
end

local function getClonedService(nome)
    local servico = getService(nome)

    if not servico then
        return nil
    end

    if type(cloneref) == "function" then
        local ok, clone = pcall(cloneref, servico)
        if ok and clone then
            return clone
        end
    end

    return servico
end

local Players = getClonedService("Players")
local CoreGui = getClonedService("CoreGui")
local RunService = getClonedService("RunService")
local ReplicatedStorage = getClonedService("ReplicatedStorage")
local UserInputService = getClonedService("UserInputService")

if not Players then
    error("[RideAPet] Players não foi encontrado.")
end

local LocalPlayer = Players.LocalPlayer

if not LocalPlayer then
    error("[RideAPet] LocalPlayer não está disponível.")
end

if not RunService then
    error("[RideAPet] RunService não foi encontrado.")
end

if not ReplicatedStorage then
    error("[RideAPet] ReplicatedStorage não foi encontrado.")
end

-- =========================================================
-- PARTE 2: CONFIGURAÇÃO
-- =========================================================

local CONFIG = {
    NomeInterface = "RideAPet_Final",

    LarguraPainel = 240,
    AlturaAberto = 430,
    AlturaFechado = 38,

    VelocidadePadrao = 255,
    VelocidadeMinima = 1,
    VelocidadeMaxima = 1000,

    IntervaloClique = 0.01,
    IntervaloOvo = 0.30,
    IntervaloFusao = 2.00,

    OvoPadrao = "Common Egg",
}

local AutoCliqueAtivado = false
local AutoChocarAtivado = false
local AutoFusaoAtivado = false
local Executando = true

local ConexaoVelocidade = nil
local Conexoes = {}

local RemoteCache = {
    Click = nil,
    Egg = nil,
    Craft = nil,
}

-- =========================================================
-- PARTE 3: GUI / EXECUÇÃO NOVAMENTE
-- =========================================================

local function obterGuiExistente()
    local pais = {}

    if type(gethui) == "function" then
        local ok, gui = pcall(gethui)
        if ok and gui then
            table.insert(pais, gui)
        end
    end

    if CoreGui then
        table.insert(pais, CoreGui)
    end

    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        table.insert(pais, playerGui)
    end

    return pais
end

local function destruirGuiAnterior()
    for _, pai in ipairs(obterGuiExistente()) do
        pcall(function()
            for _, objeto in ipairs(pai:GetChildren()) do
                if objeto:IsA("ScreenGui") and string.sub(objeto.Name, 1, #CONFIG.NomeInterface) == CONFIG.NomeInterface then
                    objeto:Destroy()
                end
            end
        end)
    end
end

destruirGuiAnterior()

local InterfaceRideAPet = Instance.new("ScreenGui")
InterfaceRideAPet.Name = CONFIG.NomeInterface .. "_" .. tostring(math.random(10000, 99999))
InterfaceRideAPet.ResetOnSpawn = false
InterfaceRideAPet.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local function definirParentGui()
    if type(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then
            InterfaceRideAPet.Parent = hui
            return true
        end
    end

    if syn and type(syn.protect_gui) == "function" and CoreGui then
        local ok = pcall(function()
            syn.protect_gui(InterfaceRideAPet)
            InterfaceRideAPet.Parent = CoreGui
        end)

        if ok and InterfaceRideAPet.Parent then
            return true
        end
    end

    if CoreGui then
        local ok = pcall(function()
            InterfaceRideAPet.Parent = CoreGui
        end)

        if ok and InterfaceRideAPet.Parent then
            return true
        end
    end

    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        or LocalPlayer:WaitForChild("PlayerGui")

    InterfaceRideAPet.Parent = playerGui
    return InterfaceRideAPet.Parent ~= nil
end

if not definirParentGui() then
    error("[RideAPet] Não foi possível criar a interface.")
end

-- =========================================================
-- PARTE 4: FUNÇÕES AUXILIARES
-- =========================================================

local function adicionarConexao(conexao)
    if conexao then
        table.insert(Conexoes, conexao)
    end

    return conexao
end

local function desconectar(conexao)
    if conexao then
        pcall(function()
            conexao:Disconnect()
        end)
    end
end

local function pararVelocidade()
    desconectar(ConexaoVelocidade)
    ConexaoVelocidade = nil
end

local function PararTudo()
    AutoCliqueAtivado = false
    AutoChocarAtivado = false
    AutoFusaoAtivado = false
    pararVelocidade()
end

local function limitarNumero(valor, minimo, maximo)
    valor = tonumber(valor) or minimo
    return math.clamp(valor, minimo, maximo)
end

-- Procura primeiro no nível principal e depois dentro de Events.
local function encontrarEmEvents(nome)
    local events = ReplicatedStorage:FindFirstChild("Events")

    if not events then
        return nil
    end

    return events:FindFirstChild(nome)
end

local function encontrarRemote(nomes)
    for _, nome in ipairs(nomes) do
        local direto = ReplicatedStorage:FindFirstChild(nome)

        if direto then
            return direto
        end

        local dentroEvents = encontrarEmEvents(nome)

        if dentroEvents then
            return dentroEvents
        end
    end

    return nil
end

local function obterRemote(cacheKey, nomes)
    local cacheAtual = RemoteCache[cacheKey]

    if cacheAtual and cacheAtual.Parent then
        return cacheAtual
    end

    local encontrado = encontrarRemote(nomes)
    RemoteCache[cacheKey] = encontrado

    return encontrado
end

local function limparCacheRemote(cacheKey)
    RemoteCache[cacheKey] = nil
end

local function executarRemote(remote, ...)
    if not remote or not remote.Parent then
        return false, "Remote não encontrado."
    end

    local args = table.pack(...)

    if remote:IsA("RemoteEvent") then
        local ok, erro = pcall(function()
            remote:FireServer(table.unpack(args, 1, args.n))
        end)

        return ok, ok and nil or tostring(erro)
    end

    if remote:IsA("RemoteFunction") then
        local ok, resultado = pcall(function()
            return remote:InvokeServer(table.unpack(args, 1, args.n))
        end)

        return ok, resultado
    end

    return false, "Objeto encontrado não é RemoteEvent nem RemoteFunction."
end

-- =========================================================
-- PARTE 5: PAINEL
-- =========================================================

local FramePainel = Instance.new("Frame")
FramePainel.Name = "PainelPrincipal"
FramePainel.Size = UDim2.new(0, CONFIG.LarguraPainel, 0, CONFIG.AlturaAberto)
FramePainel.Position = UDim2.new(0.15, 0, 0.15, 0)
FramePainel.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
FramePainel.BorderSizePixel = 0
FramePainel.Active = true
FramePainel.Parent = InterfaceRideAPet

local CantoPainel = Instance.new("UICorner")
CantoPainel.CornerRadius = UDim.new(0, 10)
CantoPainel.Parent = FramePainel

local TituloLab = Instance.new("TextLabel")
TituloLab.Size = UDim2.new(1, -16, 0, 35)
TituloLab.Position = UDim2.new(0, 8, 0, 0)
TituloLab.BackgroundTransparency = 1
TituloLab.Text = "RIDE A PET - LAB MULTI-FUNÇÕES"
TituloLab.TextColor3 = Color3.fromRGB(255, 255, 255)
TituloLab.Font = Enum.Font.SourceSansBold
TituloLab.TextSize = 13
TituloLab.Parent = FramePainel

local StatusLab = Instance.new("TextLabel")
StatusLab.Size = UDim2.new(1, -40, 0, 22)
StatusLab.Position = UDim2.new(0, 20, 0, 330)
StatusLab.BackgroundTransparency = 1
StatusLab.Text = "Status: pronto"
StatusLab.TextColor3 = Color3.fromRGB(180, 180, 190)
StatusLab.Font = Enum.Font.SourceSans
StatusLab.TextSize = 12
StatusLab.TextXAlignment = Enum.TextXAlignment.Left
StatusLab.Parent = FramePainel

local function status(texto)
    if StatusLab and StatusLab.Parent then
        StatusLab.Text = "Status: " .. tostring(texto)
    end
end

-- =========================================================
-- PARTE 6: ARRASTE PC / CELULAR
-- =========================================================

local Arrastando = false
local InicioArraste = nil
local PosicaoInicial = nil
local InputArraste = nil

adicionarConexao(FramePainel.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        Arrastando = true
        InicioArraste = input.Position
        PosicaoInicial = FramePainel.Position
        InputArraste = input
    end
end))

adicionarConexao(FramePainel.InputEnded:Connect(function(input)
    if input == InputArraste then
        Arrastando = false
        InputArraste = nil
    end
end))

if UserInputService then
    adicionarConexao(UserInputService.InputChanged:Connect(function(input)
        if not Arrastando or not InicioArraste or not PosicaoInicial then
            return
        end

        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local deslocamento = input.Position - InicioArraste

        FramePainel.Position = UDim2.new(
            PosicaoInicial.X.Scale,
            PosicaoInicial.X.Offset + deslocamento.X,
            PosicaoInicial.Y.Scale,
            PosicaoInicial.Y.Offset + deslocamento.Y
        )
    end))
end

-- =========================================================
-- PARTE 7: VELOCIDADE
-- =========================================================

local InputConfigVelocidade = Instance.new("TextBox")
InputConfigVelocidade.Size = UDim2.new(0, 200, 0, 35)
InputConfigVelocidade.Position = UDim2.new(0, 20, 0, 45)
InputConfigVelocidade.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
InputConfigVelocidade.Text = tostring(CONFIG.VelocidadePadrao)
InputConfigVelocidade.ClearTextOnFocus = false
InputConfigVelocidade.TextColor3 = Color3.fromRGB(255, 255, 255)
InputConfigVelocidade.Font = Enum.Font.SourceSans
InputConfigVelocidade.TextSize = 14
InputConfigVelocidade.PlaceholderText = "Velocidade"
InputConfigVelocidade.Parent = FramePainel
Instance.new("UICorner", InputConfigVelocidade).CornerRadius = UDim.new(0, 6)

local BotaoAplicarVelocidade = Instance.new("TextButton")
BotaoAplicarVelocidade.Size = UDim2.new(0, 200, 0, 35)
BotaoAplicarVelocidade.Position = UDim2.new(0, 20, 0, 90)
BotaoAplicarVelocidade.BackgroundColor3 = Color3.fromRGB(211, 84, 0)
BotaoAplicarVelocidade.Text = "Aplicar Modificador Física"
BotaoAplicarVelocidade.TextColor3 = Color3.fromRGB(255, 255, 255)
BotaoAplicarVelocidade.Font = Enum.Font.SourceSansBold
BotaoAplicarVelocidade.TextSize = 14
BotaoAplicarVelocidade.Parent = FramePainel
Instance.new("UICorner", BotaoAplicarVelocidade).CornerRadius = UDim.new(0, 6)

adicionarConexao(BotaoAplicarVelocidade.MouseButton1Click:Connect(function()
    local valor = limitarNumero(
        InputConfigVelocidade.Text,
        CONFIG.VelocidadeMinima,
        CONFIG.VelocidadeMaxima
    )

    InputConfigVelocidade.Text = tostring(valor)

    pararVelocidade()

    ConexaoVelocidade = RunService.RenderStepped:Connect(function()
        if not Executando then
            return
        end

        pcall(function()
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")

            if not character or not humanoid then
                return
            end

            if humanoid.Health <= 0 then
                return
            end

            local direcao = humanoid.MoveDirection

            if direcao.Magnitude > 0 then
                character:TranslateBy(direcao * (valor / 135))
            end
        end)
    end)

    status("modificador de física ativo: " .. tostring(valor))
end))

-- =========================================================
-- PARTE 8: AUTO-CLIQUE
-- =========================================================

local BotaoAutoClique = Instance.new("TextButton")
BotaoAutoClique.Size = UDim2.new(0, 200, 0, 35)
BotaoAutoClique.Position = UDim2.new(0, 20, 0, 140)
BotaoAutoClique.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
BotaoAutoClique.Text = "Auto-Clique: DESLIGADO"
BotaoAutoClique.TextColor3 = Color3.fromRGB(255, 255, 255)
BotaoAutoClique.Font = Enum.Font.SourceSansBold
BotaoAutoClique.TextSize = 14
BotaoAutoClique.Parent = FramePainel
Instance.new("UICorner", BotaoAutoClique).CornerRadius = UDim.new(0, 6)

local function atualizarBotaoClique()
    if AutoCliqueAtivado then
        BotaoAutoClique.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
        BotaoAutoClique.Text = "Auto-Clique: ATIVADO"
    else
        BotaoAutoClique.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        BotaoAutoClique.Text = "Auto-Clique: DESLIGADO"
    end
end

adicionarConexao(BotaoAutoClique.MouseButton1Click:Connect(function()
    AutoCliqueAtivado = not AutoCliqueAtivado

    if AutoCliqueAtivado then
        status("auto-clique ativado")
    else
        status("auto-clique desativado")
    end

    atualizarBotaoClique()
end))

task.spawn(function()
    while Executando and InterfaceRideAPet.Parent do
        task.wait(CONFIG.IntervaloClique)

        if AutoCliqueAtivado then
            local remote = obterRemote("Click", {"Click", "ClickEvent"})

            if not remote then
                status("Click/ClickEvent não encontrado")
                limparCacheRemote("Click")
            else
                local ok, erro = executarRemote(remote)

                if not ok then
                    limparCacheRemote("Click")
                    status("falha no Click: " .. tostring(erro))
                end
            end
        end
    end
end)

-- =========================================================
-- PARTE 9: AUTO-CHOCAR
-- =========================================================

local InputNomeOvo = Instance.new("TextBox")
InputNomeOvo.Size = UDim2.new(0, 200, 0, 35)
InputNomeOvo.Position = UDim2.new(0, 20, 0, 185)
InputNomeOvo.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
InputNomeOvo.Text = CONFIG.OvoPadrao
InputNomeOvo.ClearTextOnFocus = false
InputNomeOvo.TextColor3 = Color3.fromRGB(255, 255, 255)
InputNomeOvo.Font = Enum.Font.SourceSans
InputNomeOvo.TextSize = 13
InputNomeOvo.PlaceholderText = "Nome do ovo"
InputNomeOvo.Parent = FramePainel
Instance.new("UICorner", InputNomeOvo).CornerRadius = UDim.new(0, 6)

local BotaoAutoChocar = Instance.new("TextButton")
BotaoAutoChocar.Size = UDim2.new(0, 200, 0, 35)
BotaoAutoChocar.Position = UDim2.new(0, 20, 0, 230)
BotaoAutoChocar.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
BotaoAutoChocar.Text = "Auto-Chocar: DESLIGADO"
BotaoAutoChocar.TextColor3 = Color3.fromRGB(255, 255, 255)
BotaoAutoChocar.Font = Enum.Font.SourceSansBold
BotaoAutoChocar.TextSize = 14
BotaoAutoChocar.Parent = FramePainel
Instance.new("UICorner", BotaoAutoChocar).CornerRadius = UDim.new(0, 6)

local function atualizarBotaoOvo()
    if AutoChocarAtivado then
        BotaoAutoChocar.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
        BotaoAutoChocar.Text = "Auto-Chocar: ATIVADO"
    else
        BotaoAutoChocar.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        BotaoAutoChocar.Text = "Auto-Chocar: DESLIGADO"
    end
end

adicionarConexao(BotaoAutoChocar.MouseButton1Click:Connect(function()
    AutoChocarAtivado = not AutoChocarAtivado

    if AutoChocarAtivado then
        status("auto-chocar ativado")
    else
        status("auto-chocar desativado")
    end

    atualizarBotaoOvo()
end))

task.spawn(function()
    while Executando and InterfaceRideAPet.Parent do
        task.wait(CONFIG.IntervaloOvo)

        if AutoChocarAtivado then
            local nomeOvo = tostring(InputNomeOvo.Text or "")

            if nomeOvo == "" then
                status("informe o nome do ovo")
            else
                local remote = obterRemote("Egg", {"BuyEgg", "OpenEgg"})

                if not remote then
                    status("BuyEgg/OpenEgg não encontrado")
                    limparCacheRemote("Egg")
                else
                    local ok, erro = executarRemote(remote, nomeOvo, 1)

                    if not ok then
                        limparCacheRemote("Egg")
                        status("falha no ovo: " .. tostring(erro))
                    end
                end
            end
        end
    end
end)

-- =========================================================
-- PARTE 10: AUTO-FUSÃO
-- =========================================================

local BotaoAutoFusao = Instance.new("TextButton")
BotaoAutoFusao.Size = UDim2.new(0, 200, 0, 35)
BotaoAutoFusao.Position = UDim2.new(0, 20, 0, 275)
BotaoAutoFusao.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
BotaoAutoFusao.Text = "Auto-Fusão: DESLIGADO"
BotaoAutoFusao.TextColor3 = Color3.fromRGB(255, 255, 255)
BotaoAutoFusao.Font = Enum.Font.SourceSansBold
BotaoAutoFusao.TextSize = 14
BotaoAutoFusao.Parent = FramePainel
Instance.new("UICorner", BotaoAutoFusao).CornerRadius = UDim.new(0, 6)

local function atualizarBotaoFusao()
    if AutoFusaoAtivado then
        BotaoAutoFusao.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
        BotaoAutoFusao.Text = "Auto-Fusão: ATIVADO"
    else
        BotaoAutoFusao.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        BotaoAutoFusao.Text = "Auto-Fusão: DESLIGADO"
    end
end

adicionarConexao(BotaoAutoFusao.MouseButton1Click:Connect(function()
    AutoFusaoAtivado = not AutoFusaoAtivado

    if AutoFusaoAtivado then
        status("auto-fusão ativada")
    else
        status("auto-fusão desativada")
    end

    atualizarBotaoFusao()
end))

task.spawn(function()
    while Executando and InterfaceRideAPet.Parent do
        task.wait(CONFIG.IntervaloFusao)

        if AutoFusaoAtivado then
            local remote = obterRemote("Craft", {"CraftAll", "MergePets"})

            if not remote then
                status("CraftAll/MergePets não encontrado")
                limparCacheRemote("Craft")
            else
                local ok, erro = executarRemote(remote)

                if not ok then
                    limparCacheRemote("Craft")
                    status("falha na fusão: " .. tostring(erro))
                end
            end
        end
    end
end)

-- =========================================================
-- PARTE 11: PARAR TUDO / MINIMIZAR
-- =========================================================

local BotaoPararTudo = Instance.new("TextButton")
BotaoPararTudo.Size = UDim2.new(0, 200, 0, 35)
BotaoPararTudo.Position = UDim2.new(0, 20, 0, 365)
BotaoPararTudo.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
BotaoPararTudo.Text = "PARAR TUDO"
BotaoPararTudo.TextColor3 = Color3.fromRGB(255, 255, 255)
BotaoPararTudo.Font = Enum.Font.SourceSansBold
BotaoPararTudo.TextSize = 14
BotaoPararTudo.Parent = FramePainel
Instance.new("UICorner", BotaoPararTudo).CornerRadius = UDim.new(0, 6)

adicionarConexao(BotaoPararTudo.MouseButton1Click:Connect(function()
    PararTudo()

    atualizarBotaoClique()
    atualizarBotaoOvo()
    atualizarBotaoFusao()

    status("todas as funções foram paradas")
end))

local BotaoMinimizar = Instance.new("TextButton")
BotaoMinimizar.Size = UDim2.new(0, 200, 0, 28)
BotaoMinimizar.Position = UDim2.new(0, 20, 0, 398)
BotaoMinimizar.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
BotaoMinimizar.Text = "Recolher Painel"
BotaoMinimizar.TextColor3 = Color3.fromRGB(180, 180, 190)
BotaoMinimizar.Font = Enum.Font.SourceSans
BotaoMinimizar.TextSize = 13
BotaoMinimizar.Parent = FramePainel
Instance.new("UICorner", BotaoMinimizar).CornerRadius = UDim.new(0, 5)

local Aberto = true

local function definirVisibilidadeAberto(valor)
    Aberto = valor

    if Aberto then
        FramePainel:TweenSize(
            UDim2.new(0, CONFIG.LarguraPainel, 0, CONFIG.AlturaAberto),
            Enum.EasingDirection.Out,
            Enum.EasingStyle.Quart,
            0.25,
            true
        )

        InputConfigVelocidade.Visible = true
        BotaoAplicarVelocidade.Visible = true
        BotaoAutoClique.Visible = true
        InputNomeOvo.Visible = true
        BotaoAutoChocar.Visible = true
        BotaoAutoFusao.Visible = true
        StatusLab.Visible = true
        BotaoPararTudo.Visible = true

        BotaoMinimizar.Text = "Recolher Painel"
        BotaoMinimizar.Position = UDim2.new(0, 20, 0, 398)
        BotaoMinimizar.Size = UDim2.new(0, 200, 0, 28)
    else
        FramePainel:TweenSize(
            UDim2.new(0, CONFIG.LarguraPainel, 0, CONFIG.AlturaFechado),
            Enum.EasingDirection.Out,
            Enum.EasingStyle.Quart,
            0.25,
            true
        )

        InputConfigVelocidade.Visible = false
        BotaoAplicarVelocidade.Visible = false
        BotaoAutoClique.Visible = false
        InputNomeOvo.Visible = false
        BotaoAutoChocar.Visible = false
        BotaoAutoFusao.Visible = false
        StatusLab.Visible = false
        BotaoPararTudo.Visible = false

        BotaoMinimizar.Text = "MENU"
        BotaoMinimizar.Position = UDim2.new(0, 175, 0, 5)
        BotaoMinimizar.Size = UDim2.new(0, 60, 0, 25)
    end
end

adicionarConexao(BotaoMinimizar.MouseButton1Click:Connect(function()
    definirVisibilidadeAberto(not Aberto)
end))

-- =========================================================
-- PARTE 12: LIMPEZA AO DESTRUIR
-- =========================================================

adicionarConexao(InterfaceRideAPet.AncestryChanged:Connect(function(_, parent)
    if parent then
        return
    end

    Executando = false
    PararTudo()

    for _, conexao in ipairs(Conexoes) do
        desconectar(conexao)
    end

    table.clear(Conexoes)
    RemoteCache.Click = nil
    RemoteCache.Egg = nil
    RemoteCache.Craft = nil
end))

-- =========================================================
-- PARTE 13: RESPAWN / DIAGNÓSTICO
-- =========================================================

adicionarConexao(LocalPlayer.CharacterAdded:Connect(function()
    if Executando then
        status("personagem renascido; funções prontas")
    end
end))

status("pronto")
