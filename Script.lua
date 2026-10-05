--[[
    RIDE A PET - LAB MAX v8
    Foco: teste/diagnóstico do sistema de pets do "Monter um Pet".

    Abas:
      • INÍCIO      - visão geral, métricas, atalhos e log
      • PETS        - movimento, auto-clique e auto-fusão
      • OVOS        - configuração e auto-chocar
      • INVENTÁRIO  - inspeção local de estruturas relacionadas a pets
      • REMOTES     - scanner, filtros, seleção, caminho e teste 1x
      • CONFIG      - intervalos, manutenção e reinício seguro

    Importante:
      O jogo determina quais argumentos os RemoteEvents/RemoteFunctions exigem.
      O painel não tenta adivinhar estruturas desconhecidas nem burlar validações.
      O modo "TESTAR 1X" usa apenas os argumentos já configurados no laboratório.
]]

-- =========================================================
-- SERVIÇOS
-- =========================================================
local Workspace = cloneref and cloneref(game:GetService("Workspace")) or game:GetService("Workspace")
local Players = cloneref and cloneref(game:GetService("Players")) or game:GetService("Players")
local CoreGui = cloneref and cloneref(game:GetService("CoreGui")) or game:GetService("CoreGui")
local RunService = cloneref and cloneref(game:GetService("RunService")) or game:GetService("RunService")
local ReplicatedStorage = cloneref and cloneref(game:GetService("ReplicatedStorage")) or game:GetService("ReplicatedStorage")
local UserInputService = cloneref and cloneref(game:GetService("UserInputService")) or game:GetService("UserInputService")
local TweenService = cloneref and cloneref(game:GetService("TweenService")) or game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

-- =========================================================
-- INSTÂNCIA ÚNICA
-- =========================================================
local AmbienteGlobal = (getgenv and getgenv()) or _G
local CHAVE_INSTANCIA = "__RideAPet_COMPLETO_v8"

if AmbienteGlobal[CHAVE_INSTANCIA] and type(AmbienteGlobal[CHAVE_INSTANCIA]) == "function" then
    pcall(AmbienteGlobal[CHAVE_INSTANCIA])
end

local InstanciaEncerrada = false
local Conexoes = {}
local ConexaoVelocidade = nil
local CharacterConnection = nil
local InterfaceRideAPet = nil
local EncerrarInstanciaAtual

local AutoCliqueAtivado = false
local AutoChocarAtivado = false
local AutoFusaoAtivado = false
local VelocidadeAtivada = false
local Minimizado = false

local Config = {
    velocidade = 255,
    clickIntervalo = 0.05,
    ovoIntervalo = 0.30,
    fusaoIntervalo = 2.0,
    nomeOvo = "Common Egg",
    quantidadeOvo = 1,
    limiteListaRemotes = 250,
}

local Metricas = {
    clicks = 0,
    ovos = 0,
    fusoes = 0,
    erros = 0,
    testesManuais = 0,
    ultimoResultado = "Nenhuma ação executada.",
}

local RemoteCache = {
    todos = {},
    porNome = {},
    porCategoria = {
        Pet = {}, Egg = {}, Equip = {}, Unequip = {}, Merge = {}, Inventory = {}, Click = {}, Outro = {}
    },
    total = 0,
    atualizadoEm = 0,
}

local RemoteSelecionado = nil
local FiltroCategoria = "Todos"
local RemoteWatchAtivo = true
local UltimoScanMs = 0
local ScanEmAndamento = false
local RemoteRoots = {}
local UltimoStatus = "Pronto."
local StatusLog = {}

local function RegistrarConexao(connection)
    if connection then
        table.insert(Conexoes, connection)
    end
    return connection
end

local function DesconectarTudo()
    for _, connection in ipairs(Conexoes) do
        pcall(function() connection:Disconnect() end)
    end
    Conexoes = {}

    if ConexaoVelocidade then
        pcall(function() ConexaoVelocidade:Disconnect() end)
        ConexaoVelocidade = nil
    end

    if CharacterConnection then
        pcall(function() CharacterConnection:Disconnect() end)
        CharacterConnection = nil
    end
end

EncerrarInstanciaAtual = function()
    if InstanciaEncerrada then return end
    InstanciaEncerrada = true

    AutoCliqueAtivado = false
    AutoChocarAtivado = false
    AutoFusaoAtivado = false
    VelocidadeAtivada = false

    DesconectarTudo()

    if InterfaceRideAPet then
        pcall(function()
            if InterfaceRideAPet.Parent then
                InterfaceRideAPet:Destroy()
            end
        end)
    end
end

AmbienteGlobal[CHAVE_INSTANCIA] = EncerrarInstanciaAtual

-- Limpa interfaces de versões anteriores.
local function RemoverInterfacesAntigas()
    local containers = {}
    pcall(function() if gethui then table.insert(containers, gethui()) end end)
    pcall(function() table.insert(containers, CoreGui) end)
    pcall(function() table.insert(containers, LocalPlayer:FindFirstChildOfClass("PlayerGui")) end)

    local nomes = {
        ["RideAPet_COMPLETO_SINGLETON"] = true,
        ["RideAPet_COMPLETO_V4"] = true,
        ["RideAPet_COMPLETO_V5"] = true,
        ["RideAPet_COMPLETO_V6"] = true,
        ["RideAPet_COMPLETO_V7"] = true,
        ["RideAPet_COMPLETO_V8"] = true,
    }

    for _, container in ipairs(containers) do
        if container then
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("ScreenGui") and (nomes[child.Name] or string.match(child.Name, "^RideAPet_Final_%d+$")) then
                    pcall(function() child:Destroy() end)
                end
            end
        end
    end
end

RemoverInterfacesAntigas()

-- =========================================================
-- UTILITÁRIOS
-- =========================================================
local function SafeFind(parent, name)
    if not parent then return nil end
    local ok, result = pcall(function() return parent:FindFirstChild(name) end)
    return ok and result or nil
end

local function GetFullPath(instance)
    local ok, path = pcall(function() return instance:GetFullName() end)
    return ok and path or instance.Name
end

local function ClasseRemote(obj)
    if obj:IsA("RemoteEvent") then return "RemoteEvent" end
    if obj:IsA("RemoteFunction") then return "RemoteFunction" end
    return obj.ClassName
end

local function ClassificarRemote(nome, caminho)
    local texto = string.lower((nome or "") .. " " .. (caminho or ""))

    if string.find(texto, "click") or string.find(texto, "tap") then
        return "Click"
    elseif string.find(texto, "egg") or string.find(texto, "hatch") or string.find(texto, "chocar") then
        return "Egg"
    elseif string.find(texto, "unequip") or string.find(texto, "removeequip") or string.find(texto, "remove_pet") then
        return "Unequip"
    elseif string.find(texto, "equip") or string.find(texto, "selectpet") or string.find(texto, "setpet") then
        return "Equip"
    elseif string.find(texto, "merge") or string.find(texto, "craft") or string.find(texto, "fuse") then
        return "Merge"
    elseif string.find(texto, "inventory") or string.find(texto, "storage") or string.find(texto, "backpack") then
        return "Inventory"
    elseif string.find(texto, "pet") or string.find(texto, "companion") then
        return "Pet"
    end

    return "Outro"
end

local function NormalizarIntervalo(texto, padrao, minimo, maximo)
    local n = tonumber(texto)
    if not n then return padrao end
    return math.clamp(n, minimo, maximo)
end

local function LogStatus(texto)
    UltimoStatus = tostring(texto)
    table.insert(StatusLog, os.date("%H:%M:%S") .. "  " .. UltimoStatus)
    if #StatusLog > 80 then
        table.remove(StatusLog, 1)
    end
end

local function CopiarTexto(texto)
    local ok = false
    if setclipboard then
        ok = pcall(function() setclipboard(texto) end)
    elseif toclipboard then
        ok = pcall(function() toclipboard(texto) end)
    end

    if ok then
        LogStatus("Caminho copiado para a área de transferência.")
    else
        LogStatus("Área de transferência não disponível neste ambiente.")
    end
end

-- =========================================================
-- REMOTE SCANNER / CACHE
-- =========================================================
local function ObterFontesScan()
    local fontes = {
        {nome = "ReplicatedStorage", obj = ReplicatedStorage},
        {nome = "Workspace", obj = Workspace},
    }

    local playerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        table.insert(fontes, {nome = "PlayerGui", obj = playerGui})
    end

    return fontes
end

local function ScanRemotes(force)
    if ScanEmAndamento then
        return RemoteCache.total
    end

    local agora = os.clock() * 1000
    if not force and (agora - UltimoScanMs) < 350 then
        return RemoteCache.total
    end

    ScanEmAndamento = true
    local novos = {
        todos = {},
        porNome = {},
        porCategoria = {
            Pet = {}, Egg = {}, Equip = {}, Unequip = {}, Merge = {}, Inventory = {}, Click = {}, Outro = {}
        },
        total = 0,
        atualizadoEm = os.time(),
        fontes = {},
    }

    local vistos = {}
    local fontes = ObterFontesScan()
    RemoteRoots = fontes

    for _, fonte in ipairs(fontes) do
        if fonte.obj then
            novos.fontes[fonte.nome] = true
            local ok, descendants = pcall(function()
                return fonte.obj:GetDescendants()
            end)

            if ok and descendants then
                for _, obj in ipairs(descendants) do
                    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                        local caminho = GetFullPath(obj)
                        if not vistos[obj] then
                            vistos[obj] = true
                            local item = {
                                objeto = obj,
                                nome = obj.Name,
                                tipo = ClasseRemote(obj),
                                caminho = caminho,
                                categoria = ClassificarRemote(obj.Name, caminho),
                                fonte = fonte.nome,
                            }

                            novos.total = novos.total + 1
                            table.insert(novos.todos, item)

                            local chave = string.lower(obj.Name)
                            novos.porNome[chave] = novos.porNome[chave] or {}
                            table.insert(novos.porNome[chave], item)
                            table.insert(novos.porCategoria[item.categoria], item)
                        end
                    end
                end
            end
        end
    end

    table.sort(novos.todos, function(a, b)
        if a.categoria == b.categoria then
            return string.lower(a.caminho) < string.lower(b.caminho)
        end
        return a.categoria < b.categoria
    end)

    RemoteCache = novos
    UltimoScanMs = agora
    ScanEmAndamento = false

    if RemoteSelecionado and RemoteSelecionado.objeto then
        local aindaExiste = RemoteSelecionado.objeto.Parent ~= nil
        if not aindaExiste then
            RemoteSelecionado = nil
        end
    end

    LogStatus(string.format("Scanner atualizado: %d remote(s) em %d fonte(s).", RemoteCache.total, #fontes))
    return RemoteCache.total
end

local function RegistrarWatchersRemotes()
    if not RemoteWatchAtivo then return end

    for _, fonte in ipairs(ObterFontesScan()) do
        if fonte.obj then
            RegistrarConexao(fonte.obj.DescendantAdded:Connect(function(obj)
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                    task.delay(0.15, function()
                        if not InstanciaEncerrada then
                            ScanRemotes(true)
                        end
                    end)
                end
            end))

            RegistrarConexao(fonte.obj.DescendantRemoving:Connect(function(obj)
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                    task.delay(0.15, function()
                        if not InstanciaEncerrada then
                            ScanRemotes(true)
                        end
                    end)
                end
            end))
        end
    end
end

local function FindRemoteByNames(nomes, categoriaPreferida)
    if RemoteCache.total == 0 then
        ScanRemotes(true)
    end

    for _, nome in ipairs(nomes) do
        local lista = RemoteCache.porNome[string.lower(nome)]
        if lista then
            if categoriaPreferida then
                for _, item in ipairs(lista) do
                    if item.categoria == categoriaPreferida and item.objeto and item.objeto.Parent then
                        return item.objeto, item
                    end
                end
            end
            if lista[1] and lista[1].objeto and lista[1].objeto.Parent then
                return lista[1].objeto, lista[1]
            end
        end
    end

    if categoriaPreferida and RemoteCache.porCategoria[categoriaPreferida] then
        local lista = RemoteCache.porCategoria[categoriaPreferida]
        for _, alvo in ipairs(nomes) do
            local busca = string.lower(alvo)
            for _, item in ipairs(lista) do
                if item.objeto and item.objeto.Parent and string.find(string.lower(item.nome), busca, 1, true) then
                    return item.objeto, item
                end
            end
        end
    end

    return nil, nil
end

local function ExecutarRemote(objeto, ...)
    if not objeto or not objeto.Parent then
        return false, "Remote indisponível."
    end

    local ok, resultado = pcall(function(...)
        if objeto:IsA("RemoteEvent") then
            return objeto:FireServer(...)
        elseif objeto:IsA("RemoteFunction") then
            return objeto:InvokeServer(...)
        end
    end, ...)

    if not ok then
        Metricas.erros = Metricas.erros + 1
        Metricas.ultimoResultado = "ERRO: " .. tostring(resultado)
        return false, tostring(resultado)
    end

    Metricas.ultimoResultado = "OK: " .. objeto.Name
    return true, resultado
end

local function ExecutarAcaoPorCategoria(item)
    if not item or not item.objeto then
        return false, "Nenhum remote selecionado."
    end

    local categoria = item.categoria
    Metricas.testesManuais = Metricas.testesManuais + 1

    if categoria == "Egg" then
        return ExecutarRemote(item.objeto, Config.nomeOvo, Config.quantidadeOvo)
    elseif categoria == "Click" or categoria == "Merge" or categoria == "Pet" or categoria == "Equip" or categoria == "Unequip" or categoria == "Inventory" then
        return ExecutarRemote(item.objeto)
    end

    return false, "Categoria 'Outro' bloqueada no teste 1x; confirme o remote antes de executar."
end

ScanRemotes(true)
RegistrarWatchersRemotes()

-- =========================================================
-- GUI / TEMA
-- =========================================================
local Theme = {
    bg = Color3.fromRGB(9, 11, 17),
    sidebar = Color3.fromRGB(14, 17, 25),
    card = Color3.fromRGB(18, 22, 32),
    card2 = Color3.fromRGB(23, 28, 40),
    field = Color3.fromRGB(27, 32, 45),
    stroke = Color3.fromRGB(44, 51, 68),
    text = Color3.fromRGB(244, 246, 250),
    subtext = Color3.fromRGB(163, 171, 187),
    muted = Color3.fromRGB(105, 115, 131),
    accent = Color3.fromRGB(102, 124, 255),
    accent2 = Color3.fromRGB(76, 97, 215),
    success = Color3.fromRGB(61, 194, 120),
    warning = Color3.fromRGB(235, 173, 77),
    danger = Color3.fromRGB(220, 78, 92),
}

local Camera = Workspace.CurrentCamera
local viewport = Camera and Camera.ViewportSize or Vector2.new(900, 650)
local painelW = math.floor(math.clamp(viewport.X * 0.92, 350, 760))
local painelH = math.floor(math.clamp(viewport.Y * 0.84, 420, 560))

InterfaceRideAPet = Instance.new("ScreenGui")
InterfaceRideAPet.Name = "RideAPet_COMPLETO_V8"
InterfaceRideAPet.ResetOnSpawn = false
InterfaceRideAPet.IgnoreGuiInset = true
InterfaceRideAPet.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local SucessoInjecao = pcall(function()
    if gethui then
        InterfaceRideAPet.Parent = gethui()
    elseif syn and syn.protect_gui then
        syn.protect_gui(InterfaceRideAPet)
        InterfaceRideAPet.Parent = CoreGui
    else
        InterfaceRideAPet.Parent = CoreGui
    end
end)

if not SucessoInjecao then
    InterfaceRideAPet.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local FramePainel = Instance.new("Frame")
FramePainel.Size = UDim2.fromOffset(painelW, painelH)
FramePainel.Position = UDim2.new(0.5, -painelW / 2, 0.5, -painelH / 2)
FramePainel.BackgroundColor3 = Theme.bg
FramePainel.BorderSizePixel = 0
FramePainel.Active = true
FramePainel.Parent = InterfaceRideAPet
Instance.new("UICorner", FramePainel).CornerRadius = UDim.new(0, 13)
local StrokePainel = Instance.new("UIStroke")
StrokePainel.Color = Theme.stroke
StrokePainel.Thickness = 1
StrokePainel.Parent = FramePainel

-- =========================================================
-- HELPERS GUI
-- =========================================================
local function Corner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 7)
    c.Parent = obj
    return c
end

local function Stroke(obj, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.stroke
    s.Thickness = thickness or 1
    s.Transparency = 0.35
    s.Parent = obj
    return s
end

local function Label(parent, text, size, pos, fontSize, color, xalign)
    local l = Instance.new("TextLabel")
    l.Size = size
    l.Position = pos or UDim2.new()
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color or Theme.text
    l.Font = Enum.Font.Gotham
    l.TextSize = fontSize or 13
    l.TextWrapped = true
    l.TextXAlignment = xalign or Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local function Button(parent, text, size, pos, callback, primary)
    local b = Instance.new("TextButton")
    b.Size = size
    b.Position = pos or UDim2.new()
    b.BackgroundColor3 = primary and Theme.accent or Theme.card2
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Theme.text
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 11
    b.AutoButtonColor = false
    b.Parent = parent
    Corner(b, 7)
    Stroke(b, Theme.stroke, 1)

    b.MouseEnter:Connect(function()
        if not b:GetAttribute("Active") then
            b.BackgroundColor3 = primary and Color3.fromRGB(117, 138, 255) or Color3.fromRGB(31, 37, 53)
        end
    end)
    b.MouseLeave:Connect(function()
        if not b:GetAttribute("Active") then
            b.BackgroundColor3 = primary and Theme.accent or Theme.card2
        end
    end)

    if callback then
        b.MouseButton1Click:Connect(function()
            local ok, err = pcall(callback)
            if not ok then
                Metricas.erros = Metricas.erros + 1
                LogStatus("Erro no botão: " .. tostring(err))
            end
        end)
    end
    return b
end

local function Input(parent, text, placeholder, size, pos)
    local t = Instance.new("TextBox")
    t.Size = size
    t.Position = pos or UDim2.new()
    t.BackgroundColor3 = Theme.field
    t.BorderSizePixel = 0
    t.Text = text or ""
    t.PlaceholderText = placeholder or ""
    t.PlaceholderColor3 = Theme.muted
    t.TextColor3 = Theme.text
    t.Font = Enum.Font.Gotham
    t.TextSize = 11
    t.ClearTextOnFocus = false
    t.Parent = parent
    Corner(t, 7)
    Stroke(t, Theme.stroke, 1)
    return t
end

local function Card(parent, size, pos)
    local f = Instance.new("Frame")
    f.Size = size
    f.Position = pos or UDim2.new()
    f.BackgroundColor3 = Theme.card
    f.BorderSizePixel = 0
    f.Parent = parent
    Corner(f, 9)
    Stroke(f, Theme.stroke, 1)
    return f
end

local function EstadoBotao(botao, ativo, textoAtivo, textoInativo)
    botao:SetAttribute("Active", ativo)
    botao.Text = ativo and textoAtivo or textoInativo
    botao.BackgroundColor3 = ativo and Theme.success or Theme.card2
end

-- =========================================================
-- HEADER / DRAG
-- =========================================================
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 50)
Header.BackgroundColor3 = Theme.sidebar
Header.BorderSizePixel = 0
Header.Parent = FramePainel
Corner(Header, 12)

local HeaderMask = Instance.new("Frame")
HeaderMask.Size = UDim2.new(1, 0, 0, 15)
HeaderMask.Position = UDim2.new(0, 0, 1, -15)
HeaderMask.BackgroundColor3 = Theme.sidebar
HeaderMask.BorderSizePixel = 0
HeaderMask.Parent = Header

local Logo = Label(Header, "RIDE A PET", UDim2.new(0, 190, 0, 20), UDim2.new(0, 16, 0, 7), 14, Theme.text)
local Subtitle = Label(Header, "LAB MAX  •  MONTER UM PET  •  v8", UDim2.new(0, 300, 0, 16), UDim2.new(0, 16, 0, 27), 9, Theme.subtext)

local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.fromOffset(9, 9)
StatusDot.Position = UDim2.new(1, -160, 0, 20)
StatusDot.BackgroundColor3 = Theme.subtext
StatusDot.BorderSizePixel = 0
StatusDot.Parent = Header
Corner(StatusDot, 10)

local HeaderStatus = Label(Header, "PRONTO", UDim2.fromOffset(72, 20), UDim2.new(1, -148, 0, 15), 9, Theme.subtext)
local BtnMin = Button(Header, "—", UDim2.fromOffset(32, 28), UDim2.new(1, -90, 0, 11), nil, false)
local BtnClose = Button(Header, "×", UDim2.fromOffset(32, 28), UDim2.new(1, -52, 0, 11), nil, false)

local Arrastando = false
local InicioArraste
local PosicaoInicial

RegistrarConexao(Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        Arrastando = true
        InicioArraste = input.Position
        PosicaoInicial = FramePainel.Position
    end
end))
RegistrarConexao(Header.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        Arrastando = false
    end
end))
RegistrarConexao(UserInputService.InputChanged:Connect(function(input)
    if Arrastando and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - InicioArraste
        FramePainel.Position = UDim2.new(
            PosicaoInicial.X.Scale,
            PosicaoInicial.X.Offset + delta.X,
            PosicaoInicial.Y.Scale,
            PosicaoInicial.Y.Offset + delta.Y
        )
    end
end))

-- =========================================================
-- SIDEBAR / PÁGINAS
-- =========================================================
local SidebarWidth = math.max(112, math.floor(painelW * 0.18))
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, SidebarWidth, 1, -50)
Sidebar.Position = UDim2.new(0, 0, 0, 50)
Sidebar.BackgroundColor3 = Theme.sidebar
Sidebar.BorderSizePixel = 0
Sidebar.Parent = FramePainel

local SidebarPad = Instance.new("UIPadding")
SidebarPad.PaddingTop = UDim.new(0, 10)
SidebarPad.PaddingLeft = UDim.new(0, 8)
SidebarPad.PaddingRight = UDim.new(0, 8)
SidebarPad.Parent = Sidebar

local Tabs = {}
local Pages = {}
local AbaAtual = "Início"

local Conteudo = Instance.new("Frame")
Conteudo.Size = UDim2.new(1, -SidebarWidth, 1, -50)
Conteudo.Position = UDim2.new(0, SidebarWidth, 0, 50)
Conteudo.BackgroundColor3 = Theme.bg
Conteudo.BorderSizePixel = 0
Conteudo.Parent = FramePainel

local function CriarPagina(nome)
    local p = Instance.new("ScrollingFrame")
    p.Name = "Page_" .. nome
    p.Size = UDim2.new(1, -18, 1, -16)
    p.Position = UDim2.new(0, 9, 0, 8)
    p.BackgroundTransparency = 1
    p.BorderSizePixel = 0
    p.ScrollBarThickness = 4
    p.ScrollBarImageColor3 = Theme.stroke
    p.CanvasSize = UDim2.fromOffset(0, 0)
    p.Visible = false
    p.Parent = Conteudo

    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 9)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = p

    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        p.CanvasSize = UDim2.fromOffset(0, list.AbsoluteContentSize.Y + 16)
    end)

    Pages[nome] = p
    return p
end

local function CriarAba(nome, simbolo, pagina)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 38)
    b.BackgroundColor3 = Theme.sidebar
    b.BorderSizePixel = 0
    b.Text = simbolo .. "  " .. nome
    b.TextColor3 = Theme.subtext
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 10
    b.AutoButtonColor = false
    b.Parent = Sidebar
    Corner(b, 7)

    b.MouseEnter:Connect(function()
        if AbaAtual ~= pagina then b.BackgroundColor3 = Theme.card2 end
    end)
    b.MouseLeave:Connect(function()
        if AbaAtual ~= pagina then b.BackgroundColor3 = Theme.sidebar end
    end)

    b.MouseButton1Click:Connect(function()
        for nomePagina, framePagina in pairs(Pages) do
            framePagina.Visible = (nomePagina == pagina)
        end
        for _, item in pairs(Tabs) do
            item.BackgroundColor3 = Theme.sidebar
            item.TextColor3 = Theme.subtext
        end
        b.BackgroundColor3 = Theme.card2
        b.TextColor3 = Theme.text
        AbaAtual = pagina
    end)

    Tabs[pagina] = b
    return b
end

local PagInicio = CriarPagina("Início")
local PagPets = CriarPagina("Pets")
local PagOvos = CriarPagina("Ovos")
local PagInventario = CriarPagina("Inventário")
local PagRemotes = CriarPagina("Remotes")
local PagConfig = CriarPagina("Config")

CriarAba("Início", "◆", "Início")
CriarAba("Pets", "◆", "Pets")
CriarAba("Ovos", "◈", "Ovos")
CriarAba("Inventário", "▦", "Inventário")
CriarAba("Remotes", "⌁", "Remotes")
CriarAba("Config", "⚙", "Config")

Pages["Início"].Visible = true
Tabs["Início"].BackgroundColor3 = Theme.card2
Tabs["Início"].TextColor3 = Theme.text

-- =========================================================
-- REFERÊNCIAS DE STATUS
-- =========================================================
local LblStatusGrande
local LblMetricas
local LblLog
local LblRemotesResumo
local LblInventarioResumo
local ListaLog

-- =========================================================
-- ABA INÍCIO
-- =========================================================
local CardHero = Card(PagInicio, UDim2.new(1, -4, 0, 92))
Label(CardHero, "Laboratório de testes", UDim2.new(1, -24, 0, 24), UDim2.new(0, 12, 0, 9), 16, Theme.text)
Label(CardHero, "Monter um Pet • diagnóstico + automação controlada", UDim2.new(1, -24, 0, 18), UDim2.new(0, 12, 0, 31), 10, Theme.subtext)
LblStatusGrande = Label(CardHero, "Pronto.", UDim2.new(1, -24, 0, 24), UDim2.new(0, 12, 0, 54), 11, Theme.success)

local CardMetricas = Card(PagInicio, UDim2.new(1, -4, 0, 88))
Label(CardMetricas, "Métricas da sessão", UDim2.new(1, -24, 0, 20), UDim2.new(0, 12, 0, 8), 13, Theme.text)
LblMetricas = Label(CardMetricas, "Remotes: 0  •  Ativos: 0  •  Cliques: 0  •  Ovos: 0  •  Fusões: 0", UDim2.new(1, -24, 0, 22), UDim2.new(0, 12, 0, 34), 10, Theme.text)
Label(CardMetricas, "Erros: 0  •  Testes manuais: 0", UDim2.new(1, -24, 0, 20), UDim2.new(0, 12, 0, 57), 9, Theme.subtext)

local CardQuick = Card(PagInicio, UDim2.new(1, -4, 0, 126))
Label(CardQuick, "Atalhos", UDim2.new(1, -24, 0, 20), UDim2.new(0, 12, 0, 9), 13, Theme.text)
local BtnQuickClick = Button(CardQuick, "Auto-Clique", UDim2.new(0.48, -7, 0, 34), UDim2.new(0, 10, 0, 37), nil, false)
local BtnQuickEgg = Button(CardQuick, "Auto-Chocar", UDim2.new(0.48, -7, 0, 34), UDim2.new(0.52, -3, 0, 37), nil, false)
local BtnQuickMerge = Button(CardQuick, "Auto-Fusão", UDim2.new(0.48, -7, 0, 34), UDim2.new(0, 10, 0, 77), nil, false)
local BtnQuickStop = Button(CardQuick, "PARAR TUDO", UDim2.new(0.48, -7, 0, 34), UDim2.new(0.52, -3, 0, 77), nil, false)

local CardLog = Card(PagInicio, UDim2.new(1, -4, 0, 174))
Label(CardLog, "Log da sessão", UDim2.new(1, -24, 0, 20), UDim2.new(0, 12, 0, 9), 13, Theme.text)
ListaLog = Instance.new("ScrollingFrame")
ListaLog.Size = UDim2.new(1, -24, 0, 125)
ListaLog.Position = UDim2.new(0, 12, 0, 36)
ListaLog.BackgroundColor3 = Theme.field
ListaLog.BorderSizePixel = 0
ListaLog.ScrollBarThickness = 3
ListaLog.ScrollBarImageColor3 = Theme.stroke
ListaLog.Parent = CardLog
Corner(ListaLog, 7)
local LogLayout = Instance.new("UIListLayout")
LogLayout.Padding = UDim.new(0, 2)
LogLayout.Parent = ListaLog

local function AtualizarLogVisual()
    for _, c in ipairs(ListaLog:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    for i = math.max(1, #StatusLog - 25), #StatusLog do
        local line = StatusLog[i]
        if line then
            local l = Label(ListaLog, line, UDim2.new(1, -10, 0, 19), UDim2.new(0, 5, 0, 0), 9, Theme.subtext)
            l.TextWrapped = false
        end
    end
    task.defer(function()
        ListaLog.CanvasSize = UDim2.fromOffset(0, LogLayout.AbsoluteContentSize.Y + 8)
        ListaLog.CanvasPosition = Vector2.new(0, math.max(0, ListaLog.CanvasSize.Y.Offset))
    end)
end

-- =========================================================
-- ABA PETS
-- =========================================================
local CardMov = Card(PagPets, UDim2.new(1, -4, 0, 128))
Label(CardMov, "Movimento", UDim2.new(1, -24, 0, 20), UDim2.new(0, 12, 0, 9), 13, Theme.text)
Label(CardMov, "Velocidade", UDim2.new(0, 90, 0, 18), UDim2.new(0, 12, 0, 36), 10, Theme.subtext)
local InputVel = Input(CardMov, tostring(Config.velocidade), "255", UDim2.new(0, 110, 0, 31), UDim2.new(0, 12, 0, 56))
local BtnVel = Button(CardMov, "Ativar", UDim2.new(0, 112, 0, 31), UDim2.new(0, 130, 0, 56), nil, true)
Label(CardMov, "Somente movimentação do personagem enquanto estiver andando.", UDim2.new(1, -24, 0, 20), UDim2.new(0, 12, 0, 96), 9, Theme.subtext)

local CardClique = Card(PagPets, UDim2.new(1, -4, 0, 118))
Label(CardClique, "Auto-Clique", UDim2.new(1, -24, 0, 20), UDim2.new(0, 12, 0, 9), 13, Theme.text)
local BtnClique = Button(CardClique, "DESLIGADO", UDim2.new(0, 132, 0, 34), UDim2.new(0, 12, 0, 39), nil, false)
Label(CardClique, "Candidatos: Click / ClickEvent / Tap / TapEvent", UDim2.new(1, -162, 0, 35), UDim2.new(0, 155, 0, 39), 9, Theme.subtext)

local CardFusao = Card(PagPets, UDim2.new(1, -4, 0, 118))
Label(CardFusao, "Auto-Fusão", UDim2.new(1, -24, 0, 20), UDim2.new(0, 12, 0, 9), 13, Theme.text)
local BtnFusao = Button(CardFusao, "DESLIGADO", UDim2.new(0, 132, 0, 34), UDim2.new(0, 12, 0, 39), nil, false)
Label(CardFusao, "Candidatos: CraftAll / MergePets / MergePet / Craft", UDim2.new(1, -162, 0, 35), UDim2.new(0, 155, 0, 39), 9, Theme.subtext)

-- =========================================================
-- ABA OVOS
-- =========================================================
local CardOvo = Card(PagOvos, UDim2.new(1, -4, 0, 196))
Label(CardOvo, "Auto-Chocar", UDim2.new(1, -24, 0, 20), UDim2.new(0, 12, 0, 9), 13, Theme.text)
Label(CardOvo, "Nome do ovo", UDim2.new(0, 95, 0, 18), UDim2.new(0, 12, 0, 37), 10, Theme.subtext)
local InputOvo = Input(CardOvo, Config.nomeOvo, "Common Egg", UDim2.new(0.59, -16, 0, 31), UDim2.new(0, 12, 0, 57))
Label(CardOvo, "Qtd", UDim2.new(0, 35, 0, 18), UDim2.new(0.62, 0, 0, 37), 10, Theme.subtext)
local InputQtd = Input(CardOvo, tostring(Config.quantidadeOvo), "1", UDim2.new(0.31, -10, 0, 31), UDim2.new(0.68, 0, 0, 57))
local BtnOvo = Button(CardOvo, "DESLIGADO", UDim2.new(0.47, -10, 0, 34), UDim2.new(0, 12, 0, 104), nil, false)
Label(CardOvo, "Intervalo", UDim2.new(0, 70, 0, 18), UDim2.new(0.51, 0, 0, 109), 10, Theme.subtext)
local InputIntervaloOvo = Input(CardOvo, tostring(Config.ovoIntervalo), "0.30", UDim2.new(0.40, -12, 0, 31), UDim2.new(0.61, 0, 0, 104))
Label(CardOvo, "Candidatos: BuyEgg / OpenEgg / HatchEgg / Egg", UDim2.new(1, -24, 0, 18), UDim2.new(0, 12, 0, 145), 9, Theme.subtext)
Label(CardOvo, "Dica: use a aba Remotes para confirmar qual candidato existe no jogo.", UDim2.new(1, -24, 0, 18), UDim2.new(0, 12, 0, 164), 9, Theme.muted)

-- =========================================================
-- ABA INVENTÁRIO / ESTRUTURA
-- =========================================================
local CardInvTopo = Card(PagInventario, UDim2.new(1, -4, 0, 102))
Label(CardInvTopo, "Inventário / Estrutura", UDim2.new(1, -24, 0, 20), UDim2.new(0, 12, 0, 9), 13, Theme.text)
LblInventarioResumo = Label(CardInvTopo, "Nenhuma inspeção executada.", UDim2.new(1, -24, 0, 36), UDim2.new(0, 12, 0, 37), 10, Theme.subtext)
local BtnScanEstrutura = Button(CardInvTopo, "INSPECIONAR", UDim2.new(0, 120, 0, 30), UDim2.new(1, -132, 0, 35), nil, true)

local ListaEstrutura = Instance.new("ScrollingFrame")
ListaEstrutura.Size = UDim2.new(1, -4, 0, 350)
ListaEstrutura.BackgroundColor3 = Theme.card
ListaEstrutura.BorderSizePixel = 0
ListaEstrutura.ScrollBarThickness = 4
ListaEstrutura.ScrollBarImageColor3 = Theme.stroke
ListaEstrutura.Parent = PagInventario
Corner(ListaEstrutura, 9)
Stroke(ListaEstrutura, Theme.stroke, 1)
local EstruturaLayout = Instance.new("UIListLayout")
EstruturaLayout.Padding = UDim.new(0, 4)
EstruturaLayout.Parent = ListaEstrutura

local function NomeInteressante(nome)
    local t = string.lower(nome or "")
    return string.find(t, "pet", 1, true) or string.find(t, "egg", 1, true)
        or string.find(t, "inventory", 1, true) or string.find(t, "equip", 1, true)
        or string.find(t, "merge", 1, true) or string.find(t, "craft", 1, true)
        or string.find(t, "storage", 1, true) or string.find(t, "backpack", 1, true)
end

local function InspecionarEstrutura()
    for _, c in ipairs(ListaEstrutura:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end

    local fontes = {
        {nome = "ReplicatedStorage", obj = ReplicatedStorage},
        {nome = "Workspace", obj = Workspace},
        {nome = "LocalPlayer", obj = LocalPlayer},
        {nome = "PlayerGui", obj = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")},
    }

    local resultados = {}
    local vistos = {}

    for _, fonte in ipairs(fontes) do
        if fonte.obj then
            local ok, descendants = pcall(function() return fonte.obj:GetDescendants() end)
            if ok and descendants then
                for _, obj in ipairs(descendants) do
                    if NomeInteressante(obj.Name) then
                        local path = GetFullPath(obj)
                        if not vistos[path] then
                            vistos[path] = true
                            table.insert(resultados, {
                                fonte = fonte.nome,
                                nome = obj.Name,
                                classe = obj.ClassName,
                                caminho = path,
                            })
                        end
                    end
                    if #resultados >= 250 then break end
                end
            end
        end
        if #resultados >= 250 then break end
    end

    table.sort(resultados, function(a, b)
        return string.lower(a.caminho) < string.lower(b.caminho)
    end)

    for _, item in ipairs(resultados) do
        local l = Label(ListaEstrutura, string.format("[%s] %s • %s\n%s", item.fonte, item.nome, item.classe, item.caminho), UDim2.new(1, -12, 0, 46), UDim2.new(0, 6, 0, 0), 9, Theme.subtext)
        l.TextYAlignment = Enum.TextYAlignment.Center
        l.TextWrapped = true
    end

    LblInventarioResumo.Text = string.format("Encontrados %d objetos relacionados a Pet/Egg/Inventory/Equip/Merge.", #resultados)
    LogStatus("Inspeção concluída: " .. tostring(#resultados) .. " objeto(s).")
    task.defer(function()
        ListaEstrutura.CanvasSize = UDim2.fromOffset(0, EstruturaLayout.AbsoluteContentSize.Y + 10)
    end)
end

-- =========================================================
-- ABA REMOTES
-- =========================================================
local CardRemotesTopo = Card(PagRemotes, UDim2.new(1, -4, 0, 208))
Label(CardRemotesTopo, "Diagnóstico de Remotes", UDim2.new(1, -24, 0, 20), UDim2.new(0, 12, 0, 8), 13, Theme.text)
local InputBusca = Input(CardRemotesTopo, "", "Buscar nome, caminho ou categoria...", UDim2.new(1, -152, 0, 31), UDim2.new(0, 12, 0, 35))
local BtnScan = Button(CardRemotesTopo, "ESCANEAR", UDim2.new(0, 122, 0, 31), UDim2.new(1, -134, 0, 35), nil, true)
local LblScanResumo = Label(CardRemotesTopo, "0 remotes • monitoramento ativo", UDim2.new(1, -24, 0, 16), UDim2.new(0, 12, 1, -22), 8, Theme.muted)

local Filtros = {"Todos", "Pet", "Egg", "Equip", "Unequip", "Merge", "Inventory", "Click", "Outro"}
local BotoesFiltro = {}
for i, nomeFiltro in ipairs(Filtros) do
    local coluna = (i - 1) % 2
    local linha = math.floor((i - 1) / 2)
    local b = Button(CardRemotesTopo, nomeFiltro, UDim2.new(0, 84, 0, 25), UDim2.new(0, 12 + coluna * 92, 0, 76 + linha * 27), nil, false)
    b.Size = UDim2.new(0, 84, 0, 25)
    b.Position = UDim2.new(0, 12 + coluna * 92, 0, 76 + linha * 27)
    b.TextSize = 9
    BotoesFiltro[nomeFiltro] = b
end

local ListaRemotes = Instance.new("ScrollingFrame")
ListaRemotes.Size = UDim2.new(1, -4, 0, 260)
ListaRemotes.BackgroundColor3 = Theme.card
ListaRemotes.BorderSizePixel = 0
ListaRemotes.ScrollBarThickness = 4
ListaRemotes.ScrollBarImageColor3 = Theme.stroke
ListaRemotes.Parent = PagRemotes
Corner(ListaRemotes, 9)
Stroke(ListaRemotes, Theme.stroke, 1)
local ListaLayout = Instance.new("UIListLayout")
ListaLayout.Padding = UDim.new(0, 5)
ListaLayout.Parent = ListaRemotes

local CardSelecionado = Card(PagRemotes, UDim2.new(1, -4, 0, 184))
Label(CardSelecionado, "Remote selecionado", UDim2.new(1, -24, 0, 20), UDim2.new(0, 12, 0, 8), 13, Theme.text)
local LblRemoteSelecionado = Label(CardSelecionado, "Nenhum remote selecionado.", UDim2.new(1, -24, 0, 60), UDim2.new(0, 12, 0, 34), 9, Theme.subtext)
LblRemoteSelecionado.TextYAlignment = Enum.TextYAlignment.Top
local BtnTestarRemote = Button(CardSelecionado, "TESTAR 1X", UDim2.new(0.31, -8, 0, 32), UDim2.new(0, 12, 0, 116), nil, true)
local BtnCopiarPath = Button(CardSelecionado, "COPIAR CAMINHO", UDim2.new(0.31, -8, 0, 32), UDim2.new(0.345, 0, 0, 116), nil, false)
local BtnLimparSelecao = Button(CardSelecionado, "LIMPAR", UDim2.new(0.31, -8, 0, 32), UDim2.new(0.69, 0, 0, 116), nil, false)

local function LimparListaRemotes()
    for _, child in ipairs(ListaRemotes:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
end

local function AtualizarFiltros()
    for nome, b in pairs(BotoesFiltro) do
        local ativo = nome == FiltroCategoria
        b.BackgroundColor3 = ativo and Theme.accent or Theme.card2
        b:SetAttribute("Active", ativo)
    end
end

local function AtualizarListaRemotes()
    LimparListaRemotes()

    local busca = string.lower(InputBusca.Text or "")
    local categorias = FiltroCategoria == "Todos" and {"Click", "Egg", "Pet", "Equip", "Unequip", "Merge", "Inventory", "Outro"} or {FiltroCategoria}
    local totalVisiveis = 0

    for _, categoria in ipairs(categorias) do
        for _, item in ipairs(RemoteCache.porCategoria[categoria] or {}) do
            local alvo = string.lower(item.nome .. " " .. item.caminho .. " " .. item.categoria)
            if busca == "" or string.find(alvo, busca, 1, true) then
                local b = Instance.new("TextButton")
                b.Size = UDim2.new(1, -10, 0, 50)
                b.BackgroundColor3 = Theme.card2
                b.BorderSizePixel = 0
                b.AutoButtonColor = false
                b.Text = string.format("[%s]  %s  •  %s\n%s", item.categoria, item.nome, item.tipo, item.caminho)
                b.TextColor3 = Theme.text
                b.Font = Enum.Font.Code
                b.TextSize = 9
                b.TextWrapped = true
                b.TextXAlignment = Enum.TextXAlignment.Left
                b.TextYAlignment = Enum.TextYAlignment.Center
                b.Parent = ListaRemotes
                Corner(b, 6)
                Stroke(b, Theme.stroke, 1)

                b.MouseEnter:Connect(function() b.BackgroundColor3 = Theme.field end)
                b.MouseLeave:Connect(function() b.BackgroundColor3 = Theme.card2 end)
                b.MouseButton1Click:Connect(function()
                    RemoteSelecionado = item
                    LblRemoteSelecionado.Text = string.format(
                        "%s\nNome: %s\nTipo: %s\nCategoria: %s",
                        item.caminho, item.nome, item.tipo, item.categoria
                    )
                    LogStatus("Selecionado: " .. item.nome)
                end)

                totalVisiveis = totalVisiveis + 1
                if totalVisiveis >= Config.limiteListaRemotes then break end
            end
        end
        if totalVisiveis >= Config.limiteListaRemotes then break end
    end

    task.defer(function()
        ListaRemotes.CanvasSize = UDim2.fromOffset(0, ListaLayout.AbsoluteContentSize.Y + 10)
    end)
end

AtualizarFiltros()

-- =========================================================
-- ABA CONFIG
-- =========================================================
local CardTaxas = Card(PagConfig, UDim2.new(1, -4, 0, 198))
Label(CardTaxas, "Intervalos e desempenho", UDim2.new(1, -24, 0, 20), UDim2.new(0, 12, 0, 8), 13, Theme.text)
Label(CardTaxas, "Clique (seg)", UDim2.new(0.28, 0, 0, 18), UDim2.new(0, 12, 0, 37), 10, Theme.subtext)
local InputClickInterval = Input(CardTaxas, tostring(Config.clickIntervalo), "0.05", UDim2.new(0.25, -10, 0, 31), UDim2.new(0, 12, 0, 56))
Label(CardTaxas, "Fusão (seg)", UDim2.new(0.28, 0, 0, 18), UDim2.new(0.34, 0, 0, 37), 10, Theme.subtext)
local InputMergeInterval = Input(CardTaxas, tostring(Config.fusaoIntervalo), "2.0", UDim2.new(0.27, -10, 0, 31), UDim2.new(0.34, 0, 0, 56))
Label(CardTaxas, "Ovo (seg)", UDim2.new(0.28, 0, 0, 18), UDim2.new(0.68, 0, 0, 37), 10, Theme.subtext)
local InputOvoInterval2 = Input(CardTaxas, tostring(Config.ovoIntervalo), "0.30", UDim2.new(0.27, -10, 0, 31), UDim2.new(0.68, 0, 0, 56))
local BtnAplicarConfig = Button(CardTaxas, "APLICAR CONFIGURAÇÃO", UDim2.new(1, -24, 0, 34), UDim2.new(0, 12, 0, 100), nil, true)
Label(CardTaxas, "Clique: 0.01–5 • Ovo/Fusão: 0.05–10", UDim2.new(1, -24, 0, 18), UDim2.new(0, 12, 0, 143), 9, Theme.subtext)
Label(CardTaxas, "As faixas são apenas limites do painel; o jogo ainda controla o que aceita.", UDim2.new(1, -24, 0, 18), UDim2.new(0, 12, 0, 161), 9, Theme.muted)

local CardManutencao = Card(PagConfig, UDim2.new(1, -4, 0, 150))
Label(CardManutencao, "Manutenção", UDim2.new(1, -24, 0, 20), UDim2.new(0, 12, 0, 8), 13, Theme.text)
local BtnReScan = Button(CardManutencao, "REVARrer REMOTES", UDim2.new(0.48, -8, 0, 32), UDim2.new(0, 12, 0, 37), nil, false)
local BtnResetConfig = Button(CardManutencao, "RESETAR CONFIG", UDim2.new(0.48, -8, 0, 32), UDim2.new(0.52, -4, 0, 37), nil, false)
local BtnParar = Button(CardManutencao, "PARAR TUDO", UDim2.new(0.48, -8, 0, 32), UDim2.new(0, 12, 0, 82), nil, false)
local BtnFecharConfig = Button(CardManutencao, "FECHAR LABORATÓRIO", UDim2.new(0.48, -8, 0, 32), UDim2.new(0.52, -4, 0, 82), nil, false)

local CardAviso = Card(PagConfig, UDim2.new(1, -4, 0, 98))
Label(CardAviso, "Diagnóstico", UDim2.new(1, -24, 0, 20), UDim2.new(0, 12, 0, 8), 13, Theme.text)
Label(CardAviso, "Use a aba Remotes para confirmar nomes e caminhos antes de automatizar.", UDim2.new(1, -24, 0, 34), UDim2.new(0, 12, 0, 34), 9, Theme.subtext)

-- =========================================================
-- STATUS / UI
-- =========================================================
local BottomBar = Instance.new("Frame")
BottomBar.Size = UDim2.new(1, -18, 0, 25)
BottomBar.Position = UDim2.new(0, 9, 1, -30)
BottomBar.BackgroundTransparency = 1
BottomBar.Parent = FramePainel
LblLog = Label(BottomBar, UltimoStatus, UDim2.new(1, -10, 1, 0), UDim2.new(0, 4, 0, 0), 9, Theme.muted)

local function AtualizarCabecalho()
    local algoAtivo = AutoCliqueAtivado or AutoChocarAtivado or AutoFusaoAtivado or VelocidadeAtivada
    HeaderStatus.Text = algoAtivo and "RODANDO" or "PRONTO"
    HeaderStatus.TextColor3 = algoAtivo and Theme.success or Theme.subtext
    StatusDot.BackgroundColor3 = algoAtivo and Theme.success or Theme.subtext
end

local function AtualizarUIStatus()
    if LblStatusGrande then LblStatusGrande.Text = UltimoStatus end
    if LblLog then LblLog.Text = UltimoStatus end
    if LblScanResumo then
        local estadoMonitor = RemoteWatchAtivo and "monitoramento ativo" or "monitoramento pausado"
        LblScanResumo.Text = string.format("%d remotes • %s", RemoteCache.total, estadoMonitor)
    end
    if LblMetricas then
        local ativos = 0
        if AutoCliqueAtivado then ativos = ativos + 1 end
        if AutoChocarAtivado then ativos = ativos + 1 end
        if AutoFusaoAtivado then ativos = ativos + 1 end
        if VelocidadeAtivada then ativos = ativos + 1 end
        LblMetricas.Text = string.format(
            "Remotes: %d  •  Ativos: %d  •  Cliques: %d  •  Ovos: %d  •  Fusões: %d",
            RemoteCache.total, ativos, Metricas.clicks, Metricas.ovos, Metricas.fusoes
        )
    end
    AtualizarCabecalho()
end

-- =========================================================
-- AÇÕES
-- =========================================================
local function PararTudo()
    AutoCliqueAtivado = false
    AutoChocarAtivado = false
    AutoFusaoAtivado = false
    VelocidadeAtivada = false

    if ConexaoVelocidade then
        pcall(function() ConexaoVelocidade:Disconnect() end)
        ConexaoVelocidade = nil
    end

    EstadoBotao(BtnClique, false, "ATIVADO", "DESLIGADO")
    EstadoBotao(BtnFusao, false, "ATIVADO", "DESLIGADO")
    EstadoBotao(BtnOvo, false, "ATIVADO", "DESLIGADO")
    EstadoBotao(BtnVel, false, "ATIVADO", "Ativar")
    EstadoBotao(BtnQuickClick, false, "Auto-Clique: ON", "Auto-Clique")
    EstadoBotao(BtnQuickEgg, false, "Auto-Chocar: ON", "Auto-Chocar")
    EstadoBotao(BtnQuickMerge, false, "Auto-Fusão: ON", "Auto-Fusão")

    LogStatus("Todas as automações foram paradas.")
    AtualizarLogVisual()
    AtualizarUIStatus()
end

local function AlternarVelocidade()
    Config.velocidade = math.clamp(tonumber(InputVel.Text) or 255, 1, 5000)
    InputVel.Text = tostring(Config.velocidade)
    VelocidadeAtivada = not VelocidadeAtivada

    if VelocidadeAtivada then
        if ConexaoVelocidade then
            pcall(function() ConexaoVelocidade:Disconnect() end)
        end

        ConexaoVelocidade = RunService.RenderStepped:Connect(function()
            if not VelocidadeAtivada then return end
            pcall(function()
                local character = LocalPlayer.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                if character and humanoid and humanoid.MoveDirection.Magnitude > 0 then
                    character:TranslateBy(humanoid.MoveDirection * (Config.velocidade / 135))
                end
            end)
        end)

        EstadoBotao(BtnVel, true, "ATIVADO", "Ativar")
        LogStatus("Movimento ativado: " .. tostring(Config.velocidade))
    else
        if ConexaoVelocidade then
            pcall(function() ConexaoVelocidade:Disconnect() end)
            ConexaoVelocidade = nil
        end
        EstadoBotao(BtnVel, false, "ATIVADO", "Ativar")
        LogStatus("Movimento desativado.")
    end
    AtualizarLogVisual()
    AtualizarUIStatus()
end

local function AlternarClick()
    AutoCliqueAtivado = not AutoCliqueAtivado
    EstadoBotao(BtnClique, AutoCliqueAtivado, "ATIVADO", "DESLIGADO")
    EstadoBotao(BtnQuickClick, AutoCliqueAtivado, "Auto-Clique: ON", "Auto-Clique")
    LogStatus(AutoCliqueAtivado and "Auto-Clique ativado." or "Auto-Clique desativado.")
    AtualizarLogVisual()
    AtualizarUIStatus()
end

local function AlternarOvo()
    Config.nomeOvo = InputOvo.Text ~= "" and InputOvo.Text or "Common Egg"
    Config.quantidadeOvo = math.max(1, math.floor(tonumber(InputQtd.Text) or 1))
    Config.ovoIntervalo = NormalizarIntervalo(InputIntervaloOvo.Text, 0.30, 0.05, 10)

    InputOvo.Text = Config.nomeOvo
    InputQtd.Text = tostring(Config.quantidadeOvo)
    InputIntervaloOvo.Text = tostring(Config.ovoIntervalo)

    AutoChocarAtivado = not AutoChocarAtivado
    EstadoBotao(BtnOvo, AutoChocarAtivado, "ATIVADO", "DESLIGADO")
    EstadoBotao(BtnQuickEgg, AutoChocarAtivado, "Auto-Chocar: ON", "Auto-Chocar")
    LogStatus((AutoChocarAtivado and "Auto-Chocar ativado: " or "Auto-Chocar desativado: ") .. Config.nomeOvo)
    AtualizarLogVisual()
    AtualizarUIStatus()
end

local function AlternarFusao()
    AutoFusaoAtivado = not AutoFusaoAtivado
    EstadoBotao(BtnFusao, AutoFusaoAtivado, "ATIVADO", "DESLIGADO")
    EstadoBotao(BtnQuickMerge, AutoFusaoAtivado, "Auto-Fusão: ON", "Auto-Fusão")
    LogStatus(AutoFusaoAtivado and "Auto-Fusão ativada." or "Auto-Fusão desativada.")
    AtualizarLogVisual()
    AtualizarUIStatus()
end

-- =========================================================
-- EVENTOS DOS BOTÕES
-- =========================================================
local function RestaurarConfiguracaoPadrao()
    Config.velocidade = 255
    Config.clickIntervalo = 0.05
    Config.ovoIntervalo = 0.30
    Config.fusaoIntervalo = 2.0
    Config.nomeOvo = "Common Egg"
    Config.quantidadeOvo = 1

    InputVel.Text = tostring(Config.velocidade)
    InputClickInterval.Text = tostring(Config.clickIntervalo)
    InputOvoInterval2.Text = tostring(Config.ovoIntervalo)
    InputIntervaloOvo.Text = tostring(Config.ovoIntervalo)
    InputMergeInterval.Text = tostring(Config.fusaoIntervalo)
    InputOvo.Text = Config.nomeOvo
    InputQtd.Text = tostring(Config.quantidadeOvo)

    LogStatus("Configuração restaurada para os valores padrão.")
    AtualizarLogVisual()
    AtualizarUIStatus()
end

BtnVel.MouseButton1Click:Connect(AlternarVelocidade)
BtnClique.MouseButton1Click:Connect(AlternarClick)
BtnOvo.MouseButton1Click:Connect(AlternarOvo)
BtnFusao.MouseButton1Click:Connect(AlternarFusao)
BtnQuickClick.MouseButton1Click:Connect(AlternarClick)
BtnQuickEgg.MouseButton1Click:Connect(AlternarOvo)
BtnQuickMerge.MouseButton1Click:Connect(AlternarFusao)
BtnQuickStop.MouseButton1Click:Connect(PararTudo)
BtnParar.MouseButton1Click:Connect(PararTudo)
BtnScanEstrutura.MouseButton1Click:Connect(InspecionarEstrutura)

BtnReScan.MouseButton1Click:Connect(function()
    ScanRemotes(true)
    AtualizarListaRemotes()
    AtualizarFiltros()
    AtualizarUIStatus()
    AtualizarLogVisual()
end)

BtnResetConfig.MouseButton1Click:Connect(RestaurarConfiguracaoPadrao)

BtnScan.MouseButton1Click:Connect(function()
    ScanRemotes(true)
    AtualizarListaRemotes()
    AtualizarFiltros()
    AtualizarUIStatus()
    AtualizarLogVisual()
end)

InputBusca:GetPropertyChangedSignal("Text"):Connect(function()
    AtualizarListaRemotes()
end)

for nomeFiltro, botao in pairs(BotoesFiltro) do
    botao.MouseButton1Click:Connect(function()
        FiltroCategoria = nomeFiltro
        AtualizarFiltros()
        AtualizarListaRemotes()
    end)
end

BtnTestarRemote.MouseButton1Click:Connect(function()
    if not RemoteSelecionado then
        LogStatus("Selecione um remote primeiro.")
        AtualizarLogVisual()
        return
    end

    local ok, resultado = ExecutarAcaoPorCategoria(RemoteSelecionado)
    if ok then
        LogStatus("Teste 1x OK: " .. RemoteSelecionado.nome)
        if RemoteSelecionado.categoria == "Click" then
            Metricas.clicks = Metricas.clicks + 1
        elseif RemoteSelecionado.categoria == "Egg" then
            Metricas.ovos = Metricas.ovos + 1
        elseif RemoteSelecionado.categoria == "Merge" then
            Metricas.fusoes = Metricas.fusoes + 1
        end
    else
        LogStatus("Teste 1x falhou: " .. tostring(resultado))
    end
    AtualizarLogVisual()
    AtualizarUIStatus()
end)

BtnCopiarPath.MouseButton1Click:Connect(function()
    if RemoteSelecionado then
        CopiarTexto(RemoteSelecionado.caminho)
    else
        LogStatus("Nenhum remote selecionado.")
        AtualizarLogVisual()
    end
end)

BtnLimparSelecao.MouseButton1Click:Connect(function()
    RemoteSelecionado = nil
    LblRemoteSelecionado.Text = "Nenhum remote selecionado."
    LogStatus("Seleção limpa.")
    AtualizarLogVisual()
end)

BtnAplicarConfig.MouseButton1Click:Connect(function()
    Config.clickIntervalo = NormalizarIntervalo(InputClickInterval.Text, 0.05, 0.01, 5)
    Config.fusaoIntervalo = NormalizarIntervalo(InputMergeInterval.Text, 2.0, 0.05, 10)
    Config.ovoIntervalo = NormalizarIntervalo(InputOvoInterval2.Text, 0.30, 0.05, 10)

    InputClickInterval.Text = tostring(Config.clickIntervalo)
    InputMergeInterval.Text = tostring(Config.fusaoIntervalo)
    InputOvoInterval2.Text = tostring(Config.ovoIntervalo)
    InputIntervaloOvo.Text = tostring(Config.ovoIntervalo)

    LogStatus("Configuração aplicada.")
    AtualizarLogVisual()
    AtualizarUIStatus()
end)

BtnFecharConfig.MouseButton1Click:Connect(function()
    EncerrarInstanciaAtual()
    if AmbienteGlobal[CHAVE_INSTANCIA] == EncerrarInstanciaAtual then
        AmbienteGlobal[CHAVE_INSTANCIA] = nil
    end
end)

BtnClose.MouseButton1Click:Connect(function()
    EncerrarInstanciaAtual()
    if AmbienteGlobal[CHAVE_INSTANCIA] == EncerrarInstanciaAtual then
        AmbienteGlobal[CHAVE_INSTANCIA] = nil
    end
end)

-- =========================================================
-- MINIMIZAR
-- =========================================================
BtnMin.MouseButton1Click:Connect(function()
    Minimizado = not Minimizado
    Sidebar.Visible = not Minimizado
    Conteudo.Visible = not Minimizado
    BottomBar.Visible = not Minimizado

    local alvo = Minimizado and UDim2.fromOffset(math.min(painelW, 280), 50) or UDim2.fromOffset(painelW, painelH)
    pcall(function()
        TweenService:Create(FramePainel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = alvo}):Play()
    end)

    BtnMin.Text = Minimizado and "+" or "—"
    Subtitle.Visible = not Minimizado
end)

-- =========================================================
-- LOOPS DE AUTOMAÇÃO
-- =========================================================
task.spawn(function()
    while InterfaceRideAPet and InterfaceRideAPet.Parent and not InstanciaEncerrada do
        task.wait(Config.clickIntervalo)
        if AutoCliqueAtivado then
            pcall(function()
                local evento = FindRemoteByNames({"Click", "ClickEvent", "Tap", "TapEvent"}, "Click")
                if evento then
                    local ok = ExecutarRemote(evento)
                    if ok then Metricas.clicks = Metricas.clicks + 1 end
                end
            end)
        end
    end
end)

task.spawn(function()
    while InterfaceRideAPet and InterfaceRideAPet.Parent and not InstanciaEncerrada do
        task.wait(Config.ovoIntervalo)
        if AutoChocarAtivado then
            pcall(function()
                local remoteOvo = FindRemoteByNames({"BuyEgg", "OpenEgg", "HatchEgg", "Egg"}, "Egg")
                if remoteOvo then
                    local ok = ExecutarRemote(remoteOvo, Config.nomeOvo, Config.quantidadeOvo)
                    if ok then Metricas.ovos = Metricas.ovos + 1 end
                end
            end)
        end
    end
end)

task.spawn(function()
    while InterfaceRideAPet and InterfaceRideAPet.Parent and not InstanciaEncerrada do
        task.wait(Config.fusaoIntervalo)
        if AutoFusaoAtivado then
            pcall(function()
                local remoteCraft = FindRemoteByNames({"CraftAll", "MergePets", "MergePet", "Craft"}, "Merge")
                if remoteCraft then
                    local ok = ExecutarRemote(remoteCraft)
                    if ok then Metricas.fusoes = Metricas.fusoes + 1 end
                end
            end)
        end
    end
end)

-- Atualização leve da interface.
task.spawn(function()
    while InterfaceRideAPet and InterfaceRideAPet.Parent and not InstanciaEncerrada do
        task.wait(0.35)
        AtualizarUIStatus()
        if RemoteWatchAtivo and (os.clock() * 1000 - UltimoScanMs) > 2500 then
            ScanRemotes(false)
            AtualizarListaRemotes()
        end
        if #StatusLog > 0 then
            AtualizarLogVisual()
        end
    end
end)

-- =========================================================
-- RESPAWN
-- =========================================================
CharacterConnection = RegistrarConexao(LocalPlayer.CharacterAdded:Connect(function()
    if VelocidadeAtivada then
        LogStatus("Personagem renascido; modificador de movimento continua pronto.")
        AtualizarLogVisual()
    end
end))

-- =========================================================
-- INICIALIZAÇÃO
-- =========================================================
AtualizarFiltros()
AtualizarListaRemotes()
LogStatus("Laboratório v8 carregado com sucesso.")
AtualizarLogVisual()
AtualizarUIStatus()

print("[RideAPet] LAB MAX v8 carregado. Instância única ativa.")
