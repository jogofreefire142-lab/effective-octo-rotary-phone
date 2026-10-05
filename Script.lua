-- ================================================================
-- MONTAR UM PET / RIDE A PET - HUB LIMPO
-- Base: interface própria + execução com token + radar/farm por RenderedEggs
-- Sem Orion / sem webhook / sem envio de dados
-- PlaceId: 124216119978534
-- ================================================================

local GAME_ID = 124216119978534

if game.PlaceId ~= GAME_ID then
    warn("[MONTAR UM PET] Este script foi feito para o jogo Ride A Pet.")
    return
end

local ENV = (getgenv and getgenv()) or _G

-- ================================================================
-- LIMPEZA DE EXECUÇÕES ANTERIORES
-- ================================================================

pcall(function()
    if ENV.__MONTAR_UM_PET_HUB and ENV.__MONTAR_UM_PET_HUB.Stop then
        ENV.__MONTAR_UM_PET_HUB.Stop()
    end
end)

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local Estado = {
    Ativo = true,
    Velocidade = false,
    VelocidadeValor = 255,
    AutoClique = false,
    AutoChocar = false,
    AutoFusao = false,
    AutoFarm = false,
    EggAlvo = "Cherub Egg",
    FarmDelay = 0.20,
    GlideSpeed = 500,
}

local Conexoes = {}
local TasksAtivas = {}

local function RegistrarConexao(conexao)
    if conexao then
        table.insert(Conexoes, conexao)
    end
    return conexao
end

local function RegistrarTask(thread)
    if thread then
        table.insert(TasksAtivas, thread)
    end
    return thread
end

local function PararTudo()
    Estado.Ativo = false

    for _, conexao in ipairs(Conexoes) do
        pcall(function()
            conexao:Disconnect()
        end)
    end

    table.clear(Conexoes)
    table.clear(TasksAtivas)

    pcall(function()
        local gui = CoreGui:FindFirstChild("MontarUmPetHub")
        if gui then
            gui:Destroy()
        end
    end)

    pcall(function()
        if gethui then
            local hui = gethui()
            local gui = hui:FindFirstChild("MontarUmPetHub")
            if gui then
                gui:Destroy()
            end
        end
    end)
end

ENV.__MONTAR_UM_PET_HUB = {
    Stop = PararTudo
}

-- ================================================================
-- FUNÇÕES BÁSICAS
-- ================================================================

local function GetCharacter()
    return LocalPlayer.Character
end

local function GetHumanoid()
    local char = GetCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function GetRoot()
    local char = GetCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetPlayerGui()
    return LocalPlayer:FindFirstChildOfClass("PlayerGui")
end

local function SafeName(value)
    return string.lower(tostring(value or ""))
end

local function IsRemote(obj)
    return obj
        and (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction"))
end

local function FindRemote(names)
    local events = ReplicatedStorage:FindFirstChild("Events")

    if events then
        for _, name in ipairs(names) do
            local obj = events:FindFirstChild(name)
            if IsRemote(obj) then
                return obj
            end
        end
    end

    for _, name in ipairs(names) do
        local obj = ReplicatedStorage:FindFirstChild(name)
        if IsRemote(obj) then
            return obj
        end
    end

    for _, name in ipairs(names) do
        local obj = ReplicatedStorage:FindFirstChild(name, true)
        if IsRemote(obj) then
            return obj
        end
    end

    return nil
end

local function CallRemote(remote, ...)
    if not IsRemote(remote) then
        return false
    end

    local args = table.pack(...)

    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(table.unpack(args, 1, args.n))
        else
            remote:InvokeServer(table.unpack(args, 1, args.n))
        end
    end)

    return ok
end

-- ================================================================
-- LISTA ATUAL DE OVOS + ORDENAÇÃO POR SORTE
-- ================================================================

local Luck = {
    ["Cherub Egg"] = 1e12,
    ["Blackhole Egg"] = 1e11,
    ["Galaxy Egg"] = 1.5e9,
    ["Aurora Egg"] = 3e8,
    ["Soul Egg"] = 7e6,
    ["Sinister Egg"] = 3e6,
    ["Flaming Egg"] = 1e6,
    ["Dominus Egg"] = 7e5,
    ["Asteroid Egg"] = 5e5,
    ["Skull Egg"] = 2.5e5,
    ["Crystal Egg"] = 1.5e5,
    ["Diamond Egg"] = 9e4,
    ["Golden Egg"] = 3e4,
    ["Glass Egg"] = 1e4,
    ["Ice Egg"] = 3e3,
    ["Slime Egg"] = 1e3,
    ["Flower Egg"] = 750,
    ["Mushroom Egg"] = 500,
    ["Leaf Egg"] = 200,
    ["Stone Egg"] = 100,
    ["Easter Egg"] = 50,
    ["Cracked Egg"] = 30,
    ["Brown Egg"] = 5,
    ["White Egg"] = 1,
}

local EggNames = {
    "Cherub Egg",
    "Blackhole Egg",
    "Galaxy Egg",
    "Aurora Egg",
    "Soul Egg",
    "Sinister Egg",
    "Flaming Egg",
    "Dominus Egg",
    "Asteroid Egg",
    "Skull Egg",
    "Crystal Egg",
    "Diamond Egg",
    "Golden Egg",
    "Glass Egg",
    "Ice Egg",
    "Slime Egg",
    "Flower Egg",
    "Mushroom Egg",
    "Leaf Egg",
    "Stone Egg",
    "Easter Egg",
    "Cracked Egg",
    "Brown Egg",
    "White Egg",
}

local function ClassificarRaridade(nome)
    local n = SafeName(nome)

    if string.find(n, "secret", 1, true)
        or string.find(n, "divine", 1, true)
        or string.find(n, "celestial", 1, true)
        or string.find(n, "ethereal", 1, true)
        or string.find(n, "godly", 1, true) then
        return "🌌 Secreto / Divino", 5
    end

    if string.find(n, "mythic", 1, true)
        or string.find(n, "mythical", 1, true)
        or string.find(n, "ancient", 1, true) then
        return "🔥 Mítico / Antigo", 4
    end

    if string.find(n, "legendary", 1, true)
        or string.find(n, "legend", 1, true) then
        return "👑 Lendário", 3
    end

    if string.find(n, "epic", 1, true) then
        return "🔮 Épico", 2
    end

    if string.find(n, "rare", 1, true) then
        return "🔵 Raro", 1.5
    end

    if n == "white egg" or n == "brown egg" then
        return "⚪ Comum", 1
    end

    return "⚪ Comum", 1
end

local function GetEggLuck(nome)
    return Luck[nome] or 0
end

local function GetRarityFromIndex(eggName)
    local gui = GetPlayerGui()

    if not gui then
        return nil
    end

    local main = gui:FindFirstChild("Main")
    local index = main and main:FindFirstChild("Index")
    local holders = index and index:FindFirstChild("Holders")
    local eggHolder = holders and holders:FindFirstChild("EggsHolder")
    local card = eggHolder and eggHolder:FindFirstChild(eggName)

    if not card then
        return nil
    end

    local keywords = {
        "common",
        "uncommon",
        "rare",
        "epic",
        "legendary",
        "mythic",
        "mythical",
        "secret",
        "divine",
        "celestial",
        "ethereal",
        "ancient",
        "godly",
        "exotic",
        "exclusive",
        "limited",
        "special",
        "unique",
        "vip",
    }

    for _, child in ipairs(card:GetChildren()) do
        local childName = SafeName(child.Name)

        for _, keyword in ipairs(keywords) do
            if string.find(childName, keyword, 1, true) then
                return child.Name
            end
        end
    end

    return nil
end

-- ================================================================
-- LOCALIZAÇÃO DOS OVOS
-- ================================================================

local function GetEggPosition(inst)
    if not inst or not inst.Parent then
        return nil
    end

    if inst:IsA("Model") then
        local ok, pivot = pcall(function()
            return inst:GetPivot()
        end)

        if ok and pivot then
            return pivot.Position
        end

        local part = inst.PrimaryPart
            or inst:FindFirstChildWhichIsA("BasePart", true)

        return part and part.Position or nil
    end

    if inst:IsA("BasePart") then
        return inst.Position
    end

    return nil
end

local function GetEggRoot()
    return Workspace:FindFirstChild("RenderedEggs", true)
        or Workspace:FindFirstChild("EggSpawns", true)
end

local function IsEggLike(inst)
    if not inst then
        return false
    end

    local name = SafeName(inst.Name)

    if Luck[inst.Name] then
        return true
    end

    if string.find(name, "egg", 1, true)
        or string.find(name, "ovo", 1, true) then
        return true
    end

    return false
end

local function GetEggCandidates(filterName)
    local root = GetEggRoot()

    if not root then
        return {}
    end

    local hrp = GetRoot()
    local origin = hrp and hrp.Position or Vector3.zero
    local candidates = {}
    local seen = {}

    local children = root:GetChildren()

    for _, child in ipairs(children) do
        if IsEggLike(child) then
            local key = child

            if not seen[key] then
                seen[key] = true

                local pos = GetEggPosition(child)

                if pos then
                    local eggName = child.Name

                    local accepted =
                        (not filterName)
                        or filterName == ""
                        or eggName == filterName

                    if accepted then
                        local rarity, rarityWeight =
                            ClassificarRaridade(eggName)

                        local indexRarity =
                            GetRarityFromIndex(eggName)

                        candidates[#candidates + 1] = {
                            Instance = child,
                            Name = eggName,
                            Position = pos,
                            Distance = (pos - origin).Magnitude,
                            Luck = GetEggLuck(eggName),
                            Rarity = indexRarity or rarity,
                            RarityWeight = rarityWeight,
                        }
                    end
                end
            end
        end
    end

    table.sort(candidates, function(a, b)
        if a.Luck ~= b.Luck then
            return a.Luck > b.Luck
        end

        if a.RarityWeight ~= b.RarityWeight then
            return a.RarityWeight > b.RarityWeight
        end

        return a.Distance < b.Distance
    end)

    return candidates
end

local function FindBestEgg(filterName)
    local list = GetEggCandidates(filterName)

    if #list > 0 then
        return list[1], list
    end

    return nil, {}
end

-- ================================================================
-- GLIDE
-- ================================================================

local glideLock = false

local function GlideTo(targetPosition, speed)
    local character = GetCharacter()
    local root = GetRoot()

    if not character or not root or not targetPosition then
        return false
    end

    if glideLock then
        return false
    end

    glideLock = true

    local humanoid = GetHumanoid()
    local originalPlatformStand =
        humanoid and humanoid.PlatformStand or false

    local originalCollision = {}

    if humanoid then
        humanoid.PlatformStand = true
    end

    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            originalCollision[part] = part.CanCollide
            part.CanCollide = false
        end
    end

    local reached = false
    local startTime = os.clock()
    local maxTime = 15
    local moveSpeed = tonumber(speed) or 500

    while Estado.Ativo and character.Parent and root.Parent do
        local current = root.Position
        local delta = targetPosition - current
        local distance = delta.Magnitude

        if distance <= 2 then
            reached = true
            break
        end

        if os.clock() - startTime > maxTime then
            break
        end

        local dt = task.wait()
        local step = math.min(distance, moveSpeed * dt)
        local direction = delta.Unit
        local newPos = current + direction * step

        pcall(function()
            root.CFrame = CFrame.new(newPos, newPos + direction)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    for part, canCollide in pairs(originalCollision) do
        if part and part.Parent then
            pcall(function()
                part.CanCollide = canCollide
            end)
        end
    end

    if humanoid and humanoid.Parent then
        humanoid.PlatformStand = originalPlatformStand
    end

    glideLock = false

    return reached
end

-- ================================================================
-- INTERFACE
-- ================================================================

local function GetGuiParent()
    if gethui then
        local ok, hui = pcall(gethui)

        if ok and hui then
            return hui
        end
    end

    local ok, gui = pcall(function()
        return CoreGui
    end)

    if ok and gui then
        return gui
    end

    return GetPlayerGui()
end

local ParentGui = GetGuiParent()

if not ParentGui then
    warn("[MONTAR UM PET] Não foi possível obter um container de UI.")
    return
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MontarUmPetHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = ParentGui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(300, 430)
Main.Position = UDim2.new(0.05, 0, 0.12, 0)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = ScreenGui

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)

local Stroke = Instance.new("UIStroke")
Stroke.Color = Color3.fromRGB(60, 60, 70)
Stroke.Thickness = 1
Stroke.Parent = Main

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundTransparency = 1
Header.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -85, 1, 0)
Title.Position = UDim2.fromOffset(12, 0)
Title.BackgroundTransparency = 1
Title.Text = "⚡ MONTAR UM PET"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 17
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Close = Instance.new("TextButton")
Close.Size = UDim2.fromOffset(32, 28)
Close.Position = UDim2.new(1, -38, 0, 6)
Close.BackgroundColor3 = Color3.fromRGB(90, 40, 40)
Close.Text = "×"
Close.TextColor3 = Color3.new(1, 1, 1)
Close.Font = Enum.Font.SourceSansBold
Close.TextSize = 20
Close.Parent = Header

Instance.new("UICorner", Close).CornerRadius = UDim.new(0, 7)

local Minimize = Instance.new("TextButton")
Minimize.Size = UDim2.fromOffset(32, 28)
Minimize.Position = UDim2.new(1, -74, 0, 6)
Minimize.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
Minimize.Text = "—"
Minimize.TextColor3 = Color3.new(1, 1, 1)
Minimize.Font = Enum.Font.SourceSansBold
Minimize.TextSize = 18
Minimize.Parent = Header

Instance.new("UICorner", Minimize).CornerRadius = UDim.new(0, 7)

local dragging = false
local dragStart
local startPos

RegistrarConexao(
    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            dragging = true
            dragStart = input.Position
            startPos = Main.Position
        end
    end)
)

RegistrarConexao(
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end

        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local delta = input.Position - dragStart

        Main.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end)
)

RegistrarConexao(
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            dragging = false
        end
    end)
)

local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, -16, 1, -55)
Content.Position = UDim2.fromOffset(8, 47)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 4
Content.CanvasSize = UDim2.new()
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.Parent = Main

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 7)
Layout.Parent = Content

local Padding = Instance.new("UIPadding")
Padding.PaddingLeft = UDim.new(0, 4)
Padding.PaddingRight = UDim.new(0, 4)
Padding.PaddingBottom = UDim.new(0, 8)
Padding.Parent = Content

local function AddLabel(text, height)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -8, 0, height or 28)
    label.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    label.Text = text
    label.TextColor3 = Color3.fromRGB(205, 205, 215)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 14
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = Content

    Instance.new("UICorner", label).CornerRadius = UDim.new(0, 8)

    return label
end

local function AddButton(text, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -8, 0, 35)
    button.BackgroundColor3 = Color3.fromRGB(34, 34, 43)
    button.Text = text
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = Enum.Font.SourceSansBold
    button.TextSize = 14
    button.AutoButtonColor = true
    button.Parent = Content

    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)

    RegistrarConexao(
        button.MouseButton1Click:Connect(function()
            pcall(callback)
        end)
    )

    return button
end

local function AddToggle(text, initial, callback)
    local active = initial

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -8, 0, 35)
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = Enum.Font.SourceSansBold
    button.TextSize = 14
    button.Parent = Content

    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)

    local function refresh()
        button.Text =
            text .. (active and "  [ON]" or "  [OFF]")

        button.BackgroundColor3 = active
            and Color3.fromRGB(35, 125, 75)
            or Color3.fromRGB(34, 34, 43)
    end

    refresh()

    RegistrarConexao(
        button.MouseButton1Click:Connect(function()
            active = not active
            callback(active)
            refresh()
        end)
    )

    return button
end

local function AddTextBox(labelText, defaultText, callback)
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -8, 0, 35)
    box.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    box.Text = defaultText
    box.PlaceholderText = labelText
    box.TextColor3 = Color3.new(1, 1, 1)
    box.PlaceholderColor3 = Color3.fromRGB(125, 125, 135)
    box.Font = Enum.Font.SourceSans
    box.TextSize = 14
    box.ClearTextOnFocus = false
    box.Parent = Content

    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)

    RegistrarConexao(
        box.FocusLost:Connect(function()
            callback(box.Text)
        end)
    )

    return box
end

-- ================================================================
-- CONTEÚDO DA UI
-- ================================================================

AddLabel("Farm / movimento", 27)

AddTextBox(
    "Velocidade (ex.: 255)",
    tostring(Estado.VelocidadeValor),
    function(value)
        local number = tonumber(value)

        if number then
            Estado.VelocidadeValor =
                math.clamp(number, 16, 1000)
        end
    end
)

AddToggle(
    "⚡ Velocidade",
    false,
    function(value)
        Estado.Velocidade = value
    end
)

AddToggle(
    "🔥 Auto-Clique",
    false,
    function(value)
        Estado.AutoClique = value
    end
)

AddLabel(
    "Egg alvo: use o nome exato do ovo.",
    27
)

AddTextBox(
    "Nome do ovo",
    Estado.EggAlvo,
    function(value)
        if value and value ~= "" then
            Estado.EggAlvo = value
        end
    end
)

AddButton(
    "🔎 Ver melhor ovo disponível",
    function()
        local egg = FindBestEgg(nil)

        if not egg then
            AddLabel(
                "Nenhum ovo encontrado em RenderedEggs/EggSpawns.",
                42
            )
            return
        end

        AddLabel(
            string.format(
                "Melhor: %s\nSorte: %s | Raridade: %s | Dist.: %.0f",
                egg.Name,
                tostring(egg.Luck),
                tostring(egg.Rarity),
                egg.Distance
            ),
            58
        )
    end
)

AddToggle(
    "🥚 Auto-Chocar",
    false,
    function(value)
        Estado.AutoChocar = value
    end
)

AddToggle(
    "🔄 Auto-Fusão",
    false,
    function(value)
        Estado.AutoFusao = value
    end
)

AddToggle(
    "🚜 Auto Farm do Egg Alvo",
    false,
    function(value)
        Estado.AutoFarm = value
    end
)

AddButton(
    "⚡ Ir até o melhor ovo",
    function()
        local egg = FindBestEgg(nil)

        if not egg then
            return
        end

        GlideTo(
            egg.Position + Vector3.new(0, 2.5, 0),
            Estado.GlideSpeed
        )
    end
)

AddButton(
    "🎯 Ir até o Egg Alvo",
    function()
        local egg = FindBestEgg(Estado.EggAlvo)

        if not egg then
            return
        end

        GlideTo(
            egg.Position + Vector3.new(0, 2.5, 0),
            Estado.GlideSpeed
        )
    end
)

AddButton(
    "🏠 Salvar base",
    function()
        local root = GetRoot()

        if root then
            ENV.__MONTAR_UM_PET_BASE = root.CFrame
        end
    end
)

AddButton(
    "↩️ Voltar para a base",
    function()
        local root = GetRoot()
        local base = ENV.__MONTAR_UM_PET_BASE

        if root and base then
            GlideTo(
                base.Position,
                Estado.GlideSpeed
            )
        end
    end
)

AddButton(
    "📋 Listar ovos próximos",
    function()
        local list = GetEggCandidates(nil)
        local lines = {}

        for i = 1, math.min(8, #list) do
            local egg = list[i]

            lines[#lines + 1] = string.format(
                "%d. %s | %.0f studs",
                i,
                egg.Name,
                egg.Distance
            )
        end

        AddLabel(
            #lines > 0
                and table.concat(lines, "\n")
                or "Nenhum ovo encontrado.",
            math.clamp(
                26 + (#lines * 20),
                42,
                190
            )
        )
    end
)

AddLabel(
    "Sem Orion: a interface é local e não depende de biblioteca externa. " ..
    "Os remotes só são usados quando encontrados no jogo.",
    55
)

-- ================================================================
-- MINIMIZAR / FECHAR
-- ================================================================

local minimized = false
local savedSize = Main.Size

RegistrarConexao(
    Minimize.MouseButton1Click:Connect(function()
        minimized = not minimized

        if minimized then
            savedSize = Main.Size
            Content.Visible = false
            Main.Size = UDim2.fromOffset(300, 42)
            Minimize.Text = "+"
        else
            Main.Size = savedSize
            Content.Visible = true
            Minimize.Text = "—"
        end
    end)
)

RegistrarConexao(
    Close.MouseButton1Click:Connect(function()
        PararTudo()
    end)
)

-- ================================================================
-- VELOCIDADE
-- ================================================================

RegistrarConexao(
    RunService.RenderStepped:Connect(function()
        if not Estado.Ativo or not Estado.Velocidade then
            return
        end

        local humanoid = GetHumanoid()
        local character = GetCharacter()

        if not humanoid or not character then
            return
        end

        local direction = humanoid.MoveDirection

        if direction.Magnitude <= 0 then
            return
        end

        pcall(function()
            character:TranslateBy(
                direction * (Estado.VelocidadeValor / 135)
            )
        end)
    end)
)

-- ================================================================
-- AUTO-CLIQUE
-- ================================================================

RegistrarTask(
    task.spawn(function()
        local remote = nil

        while Estado.Ativo do
            task.wait(0.05)

            if Estado.AutoClique then
                if not remote or not remote.Parent then
                    remote = FindRemote({
                        "Click",
                        "ClickEvent",
                        "Tap",
                    })
                end

                if remote then
                    CallRemote(remote)
                end
            end
        end
    end)
)

-- ================================================================
-- AUTO-CHOCAR
-- ================================================================

RegistrarTask(
    task.spawn(function()
        local remote = nil

        while Estado.Ativo do
            task.wait(0.35)

            if Estado.AutoChocar then
                if not remote or not remote.Parent then
                    remote = FindRemote({
                        "BuyEgg",
                        "OpenEgg",
                        "PurchaseEgg",
                    })
                end

                if remote then
                    CallRemote(
                        remote,
                        Estado.EggAlvo,
                        1
                    )
                end
            end
        end
    end)
)

-- ================================================================
-- AUTO-FUSÃO
-- ================================================================

RegistrarTask(
    task.spawn(function()
        local remote = nil

        while Estado.Ativo do
            task.wait(2)

            if Estado.AutoFusao then
                if not remote or not remote.Parent then
                    remote = FindRemote({
                        "CraftAll",
                        "MergePets",
                    })
                end

                if remote then
                    CallRemote(remote)
                end
            end
        end
    end)
)

-- ================================================================
-- AUTO FARM
-- ================================================================

RegistrarTask(
    task.spawn(function()
        while Estado.Ativo do
            task.wait(Estado.FarmDelay)

            if Estado.AutoFarm and not glideLock then
                local target =
                    FindBestEgg(Estado.EggAlvo)

                if not target then
                    target = FindBestEgg(nil)
                end

                if target then
                    GlideTo(
                        target.Position
                            + Vector3.new(0, 2.5, 0),
                        Estado.GlideSpeed
                    )
                end
            end
        end
    end)
)

-- ================================================================
-- RESPAWN
-- ================================================================

RegistrarConexao(
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        glideLock = false
    end)
)

-- ================================================================
-- FINAL
-- ================================================================

print("[MONTAR UM PET] Hub iniciado.")
