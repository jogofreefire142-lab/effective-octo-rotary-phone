--[[
    RIDE A PET - LAB MULTI-FUNÇÕES
    V3 - revisão completa

    Mantidos os recursos principais:
    • compatibilidade com ambientes que oferecem gethui/cloneref/syn.protect_gui
    • fallback para PlayerGui
    • modificador de física
    • auto-clique
    • auto-chocar
    • auto-fusão
    • escolha do ovo
    • painel arrastável
    • minimizar
    • parada geral
    • diagnóstico dos remotes

    Melhorias:
    • execução repetida não deixa GUIs antigas
    • busca de remotes com cache e cooldown
    • não atualiza o texto de status a cada frame
    • validação de números
    • tratamento de respawn
    • limpeza de conexões
    • arraste somente pela barra de título
    • proteção contra referências destruídas
    • suporte a RemoteEvent e RemoteFunction
]]

-- =========================================================
-- 1. SERVIÇOS
-- =========================================================

local function getService(nome)
    local ok, servico = pcall(function()
        return game:GetService(nome)
    end)

    if ok then
        return servico
    end

    return nil
end

local function getClonedService(nome)
    local servico = getService(nome)

    if not servico then
        return nil
    end

    if type(cloneref) == "function" then
        local ok, clone = pcall(function()
            return cloneref(servico)
        end)

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
    error("[RideAPet] Players não está disponível.")
end

if not RunService then
    error("[RideAPet] RunService não está disponível.")
end

if not ReplicatedStorage then
    error("[RideAPet] ReplicatedStorage não está disponível.")
end

local LocalPlayer = Players.LocalPlayer

if not LocalPlayer then
    error("[RideAPet] LocalPlayer não está disponível.")
end

-- =========================================================
-- 2. CONFIGURAÇÃO
-- =========================================================

local CONFIG = {
    NomeInterface = "RideAPet_Final",

    LarguraPainel = 260,
    AlturaAberto = 475,
    AlturaFechado = 42,

    VelocidadePadrao = 255,
    VelocidadeMinima = 1,
    VelocidadeMaxima = 1000,

    IntervaloClique = 0.05,
    IntervaloOvo = 0.35,
    IntervaloFusao = 2.00,

    IntervaloBuscaRemote = 1.00,
    IntervaloMensagem = 0.20,

    OvoPadrao = "Common Egg",
}

local Executando = true

local AutoCliqueAtivado = false
local AutoChocarAtivado = false
local AutoFusaoAtivado = false

local ConexaoVelocidade = nil
local Conexoes = {}

local Remotes = {
    Click = nil,
    Egg = nil,
    Craft = nil,
}

local UltimaBusca = {
    Click = 0,
    Egg = 0,
    Craft = 0,
}

local UltimoStatus = ""
local UltimoStatusTempo = 0

-- =========================================================
-- 3. CONTROLE DE CONEXÕES
-- =========================================================

local function adicionarConexao(conexao)
    if conexao then
        table.insert(Conexoes, conexao)
    end

    return conexao
end

local function desconectar(conexao)
    if not conexao then
        return
    end

    pcall(function()
        conexao:Disconnect()
    end)
end

local function desconectarTodas()
    for _, conexao in ipairs(Conexoes) do
        desconectar(conexao)
    end

    table.clear(Conexoes)
end

local function pararVelocidade()
    desconectar(ConexaoVelocidade)
    ConexaoVelocidade = nil
end

local function pararTudo()
    AutoCliqueAtivado = false
    AutoChocarAtivado = false
    AutoFusaoAtivado = false

    pararVelocidade()
end

-- =========================================================
-- 4. GUI ANTIGA
-- =========================================================

local function obterPaisGui()
    local pais = {}

    if type(gethui) == "function" then
        local ok, hui = pcall(gethui)

        if ok and hui then
            table.insert(pais, hui)
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

local function apagarGuiAnterior()
    for _, pai in ipairs(obterPaisGui()) do
        pcall(function()
            for _, objeto in ipairs(pai:GetChildren()) do
                if objeto:IsA("ScreenGui")
                    and string.sub(objeto.Name, 1, #CONFIG.NomeInterface) == CONFIG.NomeInterface then

                    objeto:Destroy()
                end
            end
        end)
    end
end

apagarGuiAnterior()

-- =========================================================
-- 5. CRIAÇÃO DA GUI
-- =========================================================

local InterfaceRideAPet = Instance.new("ScreenGui")

InterfaceRideAPet.Name =
    CONFIG.NomeInterface .. "_" .. tostring(math.random(10000, 99999))

InterfaceRideAPet.ResetOnSpawn = false
InterfaceRideAPet.IgnoreGuiInset = true
InterfaceRideAPet.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
InterfaceRideAPet.DisplayOrder = 999999

local function anexarGui()
    if type(gethui) == "function" then
        local ok, hui = pcall(gethui)

        if ok and hui then
            local sucesso = pcall(function()
                InterfaceRideAPet.Parent = hui
            end)

            if sucesso and InterfaceRideAPet.Parent then
                return true
            end
        end
    end

    if syn and type(syn.protect_gui) == "function" and CoreGui then
        local sucesso = pcall(function()
            syn.protect_gui(InterfaceRideAPet)
            InterfaceRideAPet.Parent = CoreGui
        end)

        if sucesso and InterfaceRideAPet.Parent then
            return true
        end
    end

    if CoreGui then
        local sucesso = pcall(function()
            InterfaceRideAPet.Parent = CoreGui
        end)

        if sucesso and InterfaceRideAPet.Parent then
            return true
        end
    end

    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")

    if not playerGui then
        playerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
    end

    if not playerGui then
        return false
    end

    local sucesso = pcall(function()
        InterfaceRideAPet.Parent = playerGui
    end)

    return sucesso and InterfaceRideAPet.Parent ~= nil
end

if not anexarGui() then
    error("[RideAPet] Não foi possível anexar a interface.")
end

-- =========================================================
-- 6. PAINEL E ÁREAS DA INTERFACE
-- =========================================================

local FramePainel = Instance.new("Frame")
FramePainel.Name = "PainelPrincipal"
FramePainel.Size = UDim2.new(0, CONFIG.LarguraPainel, 0, CONFIG.AlturaAberto)
FramePainel.Position = UDim2.new(0.15, 0, 0.15, 0)
FramePainel.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
FramePainel.BorderSizePixel = 0
FramePainel.Parent = InterfaceRideAPet

local CantoPainel = Instance.new("UICorner")
CantoPainel.CornerRadius = UDim.new(0, 10)
CantoPainel.Parent = FramePainel

local BarraTitulo = Instance.new("Frame")
BarraTitulo.Name = "BarraTitulo"
BarraTitulo.Size = UDim2.new(1, -10, 0, 38)
BarraTitulo.Position = UDim2.new(0, 5, 0, 5)
BarraTitulo.BackgroundTransparency = 1
BarraTitulo.Active = true
BarraTitulo.Parent = FramePainel

local TituloLab = Instance.new("TextLabel")
TituloLab.Size = UDim2.new(1, -70, 1, 0)
TituloLab.Position = UDim2.new(0, 8, 0, 0)
TituloLab.BackgroundTransparency = 1
TituloLab.Text = "RIDE A PET - LAB"
TituloLab.TextColor3 = Color3.fromRGB(255, 255, 255)
TituloLab.Font = Enum.Font.SourceSansBold
TituloLab.TextSize = 16
TituloLab.TextXAlignment = Enum.TextXAlignment.Left
TituloLab.Parent = BarraTitulo

local BotaoFechar = Instance.new("TextButton")
BotaoFechar.Size = UDim2.new(0, 42, 0, 30)
BotaoFechar.Position = UDim2.new(1, -48, 0, 3)
BotaoFechar.BackgroundColor3 = Color3.fromRGB(65, 35, 40)
BotaoFechar.Text = "X"
BotaoFechar.TextColor3 = Color3.fromRGB(255, 255, 255)
BotaoFechar.Font = Enum.Font.SourceSansBold
BotaoFechar.TextSize = 16
BotaoFechar.Parent = BarraTitulo

Instance.new("UICorner", BotaoFechar).CornerRadius = UDim.new(0, 6)

-- =========================================================
-- 7. FUNÇÕES DE TEXTO / STATUS
-- =========================================================

local StatusLab = Instance.new("TextLabel")
StatusLab.Size = UDim2.new(1, -40, 0, 25)
StatusLab.Position = UDim2.new(0, 20, 0, 338)
StatusLab.BackgroundTransparency = 1
StatusLab.Text = "Status: pronto"
StatusLab.TextColor3 = Color3.fromRGB(180, 180, 190)
StatusLab.Font = Enum.Font.SourceSans
StatusLab.TextSize = 12
StatusLab.TextXAlignment = Enum.TextXAlignment.Left
StatusLab.TextTruncate = Enum.TextTruncate.AtEnd
StatusLab.Parent = FramePainel

local function status(texto, forcar)
    local agora = os.clock()
    texto = tostring(texto)

    if not forcar then
        if texto == UltimoStatus and (agora - UltimoStatusTempo) < CONFIG.IntervaloMensagem then
            return
        end

        if (agora - UltimoStatusTempo) < CONFIG.IntervaloMensagem then
            return
        end
    end

    UltimoStatus = texto
    UltimoStatusTempo = agora

    pcall(function()
        if StatusLab and StatusLab.Parent then
            StatusLab.Text = "Status: " .. texto
        end
    end)
end

-- =========================================================
-- 8. FUNÇÕES NUMÉRICAS
-- =========================================================

local function normalizarNumero(texto, minimo, maximo, padrao)
    local valor = tonumber(texto)

    if not valor then
        valor = padrao
    end

    if valor ~= valor then
        valor = padrao
    end

    return math.clamp(valor, minimo, maximo)
end

-- =========================================================
-- 9. BUSCA DOS REMOTES
-- =========================================================

local function encontrarDentroEvents(nome)
    local events = ReplicatedStorage:FindFirstChild("Events")

    if not events then
        return nil
    end

    return events:FindFirstChild(nome)
end

local function encontrarRemote(listaNomes)
    for _, nome in ipairs(listaNomes) do
        local direto = ReplicatedStorage:FindFirstChild(nome)

        if direto then
            return direto
        end

        local emEvents = encontrarDentroEvents(nome)

        if emEvents then
            return emEvents
        end
    end

    return nil
end

local function obterRemote(chave, nomes)
    local atual = Remotes[chave]

    if atual then
        local existente = pcall(function()
            return atual.Parent ~= nil
        end)

        if existente then
            local okParent, parent = pcall(function()
                return atual.Parent
            end)

            if okParent and parent then
                return atual
            end
        end

        Remotes[chave] = nil
    end

    local agora = os.clock()

    if (agora - (UltimaBusca[chave] or 0)) < CONFIG.IntervaloBuscaRemote then
        return nil
    end

    UltimaBusca[chave] = agora

    local encontrado = encontrarRemote(nomes)

    if encontrado and (
        encontrado:IsA("RemoteEvent")
        or encontrado:IsA("RemoteFunction")
    ) then
        Remotes[chave] = encontrado
        return encontrado
    end

    return nil
end

local function limparRemote(chave)
    Remotes[chave] = nil
    UltimaBusca[chave] = 0
end

local function executarRemote(remote, ...)
    if not remote then
        return false, "Remote não encontrado."
    end

    local parentOk, parent = pcall(function()
        return remote.Parent
    end)

    if not parentOk or not parent then
        return false, "Remote foi removido."
    end

    local argumentos = table.pack(...)

    if remote:IsA("RemoteEvent") then
        local ok, resultado = pcall(function()
            return remote:FireServer(
                table.unpack(argumentos, 1, argumentos.n)
            )
        end)

        if ok then
            return true, resultado
        end

        return false, resultado
    end

    if remote:IsA("RemoteFunction") then
        local ok, resultado = pcall(function()
            return remote:InvokeServer(
                table.unpack(argumentos, 1, argumentos.n)
            )
        end)

        if ok then
            return true, resultado
        end

        return false, resultado
    end

    return false, "O objeto não é RemoteEvent nem RemoteFunction."
end

-- =========================================================
-- 10. ARRASTE SOMENTE PELA BARRA DE TÍTULO
-- =========================================================

local Arrastando = false
local InicioArraste = nil
local PosicaoInicial = nil
local InputArraste = nil

adicionarConexao(BarraTitulo.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        Arrastando = true
        InicioArraste = input.Position
        PosicaoInicial = FramePainel.Position
        InputArraste = input
    end
end))

adicionarConexao(BarraTitulo.InputEnded:Connect(function(input)
    if input == InputArraste then
        Arrastando = false
        InputArraste = nil
    end
end))

if UserInputService then
    adicionarConexao(UserInputService.InputChanged:Connect(function(input)
        if not Arrastando then
            return
        end

        if not InicioArraste or not PosicaoInicial then
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
-- 11. CRIAÇÃO DE BOTÕES
-- =========================================================

local function criarBotao(nome, texto, posicaoY)
    local botao = Instance.new("TextButton")

    botao.Name = nome
    botao.Size = UDim2.new(0, 220, 0, 35)
    botao.Position = UDim2.new(0, 20, 0, posicaoY)
    botao.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    botao.Text = texto
    botao.TextColor3 = Color3.fromRGB(255, 255, 255)
    botao.Font = Enum.Font.SourceSansBold
    botao.TextSize = 14
    botao.AutoButtonColor = true
    botao.Parent = FramePainel

    Instance.new("UICorner", botao).CornerRadius = UDim.new(0, 6)

    return botao
end

local function criarCampo(nome, texto, posicaoY, placeholder)
    local campo = Instance.new("TextBox")

    campo.Name = nome
    campo.Size = UDim2.new(0, 220, 0, 35)
    campo.Position = UDim2.new(0, 20, 0, posicaoY)
    campo.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    campo.Text = texto
    campo.ClearTextOnFocus = false
    campo.TextColor3 = Color3.fromRGB(255, 255, 255)
    campo.Font = Enum.Font.SourceSans
    campo.TextSize = 14
    campo.PlaceholderText = placeholder or ""
    campo.Parent = FramePainel

    Instance.new("UICorner", campo).CornerRadius = UDim.new(0, 6)

    return campo
end

-- =========================================================
-- 12. VELOCIDADE
-- =========================================================

local InputConfigVelocidade = criarCampo(
    "InputVelocidade",
    tostring(CONFIG.VelocidadePadrao),
    48,
    "Velocidade"
)

local BotaoAplicarVelocidade = criarBotao(
    "BotaoVelocidade",
    "Aplicar Modificador Física",
    90
)

adicionarConexao(BotaoAplicarVelocidade.MouseButton1Click:Connect(function()
    local valor = normalizarNumero(
        InputConfigVelocidade.Text,
        CONFIG.VelocidadeMinima,
        CONFIG.VelocidadeMaxima,
        CONFIG.VelocidadePadrao
    )

    InputConfigVelocidade.Text = tostring(valor)

    pararVelocidade()

    ConexaoVelocidade = RunService.RenderStepped:Connect(function()
        if not Executando then
            return
        end

        pcall(function()
            local character = LocalPlayer.Character

            if not character then
                return
            end

            local humanoid = character:FindFirstChildOfClass("Humanoid")

            if not humanoid or humanoid.Health <= 0 then
                return
            end

            local direcao = humanoid.MoveDirection

            if direcao.Magnitude > 0 then
                character:TranslateBy(
                    direcao * (valor / 135)
                )
            end
        end)
    end)

    status("física ativa: " .. tostring(valor), true)
end))

-- =========================================================
-- 13. AUTO-CLIQUE
-- =========================================================

local BotaoAutoClique = criarBotao(
    "BotaoAutoClique",
    "Auto-Clique: DESLIGADO",
    135
)

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

    atualizarBotaoClique()

    if AutoCliqueAtivado then
        status("auto-clique ativado", true)
    else
        status("auto-clique desativado", true)
    end
end))

task.spawn(function()
    while Executando and InterfaceRideAPet.Parent do
        task.wait(CONFIG.IntervaloClique)

        if AutoCliqueAtivado then
            local remote = obterRemote(
                "Click",
                {"Click", "ClickEvent"}
            )

            if not remote then
                status("procurando Click/ClickEvent")
            else
                local ok, erro = executarRemote(remote)

                if not ok then
                    limparRemote("Click")
                    status("erro no Click: " .. tostring(erro))
                end
            end
        end
    end
end)

-- =========================================================
-- 14. OVO
-- =========================================================

local InputNomeOvo = criarCampo(
    "InputNomeOvo",
    CONFIG.OvoPadrao,
    180,
    "Nome do ovo"
)

local BotaoAutoChocar = criarBotao(
    "BotaoAutoChocar",
    "Auto-Chocar: DESLIGADO",
    225
)

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

    atualizarBotaoOvo()

    if AutoChocarAtivado then
        status("auto-chocar ativado", true)
    else
        status("auto-chocar desativado", true)
    end
end))

adicionarConexao(InputNomeOvo.FocusLost:Connect(function()
    local texto = tostring(InputNomeOvo.Text or "")

    if texto == "" then
        InputNomeOvo.Text = CONFIG.OvoPadrao
        status("ovo vazio; usando " .. CONFIG.OvoPadrao, true)
    else
        status("ovo definido: " .. texto, true)
    end
end))

task.spawn(function()
    while Executando and InterfaceRideAPet.Parent do
        task.wait(CONFIG.IntervaloOvo)

        if AutoChocarAtivado then
            local nomeOvo = tostring(InputNomeOvo.Text or "")

            if nomeOvo == "" then
                InputNomeOvo.Text = CONFIG.OvoPadrao
                nomeOvo = CONFIG.OvoPadrao
            end

            local remote = obterRemote(
                "Egg",
                {"BuyEgg", "OpenEgg"}
            )

            if not remote then
                status("procurando BuyEgg/OpenEgg")
            else
                local ok, erro = executarRemote(
                    remote,
                    nomeOvo,
                    1
                )

                if not ok then
                    limparRemote("Egg")
                    status("erro no ovo: " .. tostring(erro))
                end
            end
        end
    end
end)

-- =========================================================
-- 15. FUSÃO
-- =========================================================

local BotaoAutoFusao = criarBotao(
    "BotaoAutoFusao",
    "Auto-Fusão: DESLIGADO",
    270
)

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

    atualizarBotaoFusao()

    if AutoFusaoAtivado then
        status("auto-fusão ativada", true)
    else
        status("auto-fusão desativada", true)
    end
end))

task.spawn(function()
    while Executando and InterfaceRideAPet.Parent do
        task.wait(CONFIG.IntervaloFusao)

        if AutoFusaoAtivado then
            local remote = obterRemote(
                "Craft",
                {"CraftAll", "MergePets"}
            )

            if not remote then
                status("procurando CraftAll/MergePets")
            else
                local ok, erro = executarRemote(remote)

                if not ok then
                    limparRemote("Craft")
                    status("erro na fusão: " .. tostring(erro))
                end
            end
        end
    end
end)

-- =========================================================
-- 16. DIAGNÓSTICO
-- =========================================================

local BotaoDiagnostico = criarBotao(
    "BotaoDiagnostico",
    "Testar Remotes",
    315
)

adicionarConexao(BotaoDiagnostico.MouseButton1Click:Connect(function()
    limparRemote("Click")
    limparRemote("Egg")
    limparRemote("Craft")

    local click = encontrarRemote({"Click", "ClickEvent"})
    local egg = encontrarRemote({"BuyEgg", "OpenEgg"})
    local craft = encontrarRemote({"CraftAll", "MergePets"})

    local encontrados = 0

    if click then
        encontrados += 1
    end

    if egg then
        encontrados += 1
    end

    if craft then
        encontrados += 1
    end

    if encontrados == 0 then
        status("nenhum remote conhecido foi encontrado", true)
        return
    end

    local partes = {}

    table.insert(
        partes,
        "Click=" .. (click and click.ClassName or "não")
    )

    table.insert(
        partes,
        "Egg=" .. (egg and egg.ClassName or "não")
    )

    table.insert(
        partes,
        "Craft=" .. (craft and craft.ClassName or "não")
    )

    status(table.concat(partes, " | "), true)
end))

-- =========================================================
-- 17. PARAR TUDO
-- =========================================================

local BotaoPararTudo = criarBotao(
    "BotaoPararTudo",
    "PARAR TUDO",
    360
)

BotaoPararTudo.BackgroundColor3 = Color3.fromRGB(160, 50, 50)

adicionarConexao(BotaoPararTudo.MouseButton1Click:Connect(function()
    pararTudo()

    atualizarBotaoClique()
    atualizarBotaoOvo()
    atualizarBotaoFusao()

    status("todas as funções paradas", true)
end))

-- =========================================================
-- 18. MINIMIZAR
-- =========================================================

local BotaoMinimizar = Instance.new("TextButton")
BotaoMinimizar.Size = UDim2.new(0, 220, 0, 30)
BotaoMinimizar.Position = UDim2.new(0, 20, 0, 405)
BotaoMinimizar.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
BotaoMinimizar.Text = "RECOLHER PAINEL"
BotaoMinimizar.TextColor3 = Color3.fromRGB(220, 220, 225)
BotaoMinimizar.Font = Enum.Font.SourceSansBold
BotaoMinimizar.TextSize = 13
BotaoMinimizar.Parent = FramePainel

Instance.new("UICorner", BotaoMinimizar).CornerRadius = UDim.new(0, 6)

local Aberto = true

local Controles = {
    InputConfigVelocidade,
    BotaoAplicarVelocidade,
    BotaoAutoClique,
    InputNomeOvo,
    BotaoAutoChocar,
    BotaoAutoFusao,
    BotaoDiagnostico,
    BotaoPararTudo,
    StatusLab,
}

local function aplicarEstadoPainel(aberto)
    Aberto = aberto

    if Aberto then
        FramePainel:TweenSize(
            UDim2.new(0, CONFIG.LarguraPainel, 0, CONFIG.AlturaAberto),
            Enum.EasingDirection.Out,
            Enum.EasingStyle.Quart,
            0.25,
            true
        )

        for _, objeto in ipairs(Controles) do
            objeto.Visible = true
        end

        BotaoMinimizar.Visible = true
        BotaoMinimizar.Text = "RECOLHER PAINEL"
        BotaoMinimizar.Position = UDim2.new(0, 20, 0, 405)
        BotaoMinimizar.Size = UDim2.new(0, 220, 0, 30)
    else
        for _, objeto in ipairs(Controles) do
            objeto.Visible = false
        end

        FramePainel:TweenSize(
            UDim2.new(0, CONFIG.LarguraPainel, 0, CONFIG.AlturaFechado),
            Enum.EasingDirection.Out,
            Enum.EasingStyle.Quart,
            0.25,
            true
        )

        BotaoMinimizar.Visible = true
        BotaoMinimizar.Text = "MENU"
        BotaoMinimizar.Position = UDim2.new(0, 192, 0, 7)
        BotaoMinimizar.Size = UDim2.new(0, 55, 0, 27)
    end
end

adicionarConexao(BotaoMinimizar.MouseButton1Click:Connect(function()
    aplicarEstadoPainel(not Aberto)
end))

-- =========================================================
-- 19. FECHAR / LIMPEZA
-- =========================================================

local function fecharTudo()
    if not Executando then
        return
    end

    Executando = false

    pararTudo()
    desconectarTodas()

    table.clear(Remotes)
    table.clear(UltimaBusca)

    pcall(function()
        InterfaceRideAPet:Destroy()
    end)
end

adicionarConexao(BotaoFechar.MouseButton1Click:Connect(function()
    fecharTudo()
end))

-- Quando a GUI sair da árvore por outro motivo.
adicionarConexao(InterfaceRideAPet.AncestryChanged:Connect(function(_, parent)
    if parent then
        return
    end

    Executando = false
    pararTudo()

    for _, conexao in ipairs(Conexoes) do
        desconectar(conexao)
    end

    table.clear(Conexoes)
end))

-- =========================================================
-- 20. RESPAWN
-- =========================================================

adicionarConexao(LocalPlayer.CharacterAdded:Connect(function()
    if Executando then
        status("personagem renascido; funções continuam prontas", true)
    end
end))

-- =========================================================
-- 21. ESTADO INICIAL
-- =========================================================

atualizarBotaoClique()
atualizarBotaoOvo()
atualizarBotaoFusao()
status("pronto", true)
