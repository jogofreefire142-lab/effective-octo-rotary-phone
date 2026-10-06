--============================================================--
-- MONTAR UM PET - MASTER v31 • UI ORIGINAL v15 • DELTA STABLE
-- PlaceId: 124216119978534
-- UI: Rayfield Gen2 oficial • estrutura preservada da v15
-- Config: salvamento manual + persistência do Rayfield
-- Foco: Delta Mobile + Auto Farm Seguro 2026 + automações verificadas + UI v15 estável
--
-- Pesquisa cruzada: Bac0nHck, SixZensED, VintHub e Iamdungx.
-- Nesta versão, a UI v15 fica congelada; toda a camada 2026 nova é criada
-- depois da UI e desabilitada por padrão. Se um módulo avançado falhar,
-- a interface e o Auto Farm principal continuam independentes.
--
-- APIs verificadas publicamente e usadas com confirmação de estado:
-- EggPickup, EggPlaced, Hatch, PetDismount, PickupPet, PlacePet,
-- FeedPet, BuyWithCash, FavoritePet, ClaimIndexReward, além de
-- ActiveEggs, Basket, FreeNests, EggTimers e dados de pets/comida.
--============================================================--

-- Espera o cliente Roblox terminar de carregar antes de iniciar a UI.
-- Mantém a interface exatamente no modelo estável da v15.
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

if not LocalPlayer then
    return
end

if game.PlaceId ~= 124216119978534 then
    warn("Montar um Pet: este script foi feito para o PlaceId 124216119978534.")
    return
end

local ENV = (getgenv and getgenv()) or _G

--============================================================--
-- SINGLETON ROBUSTO / ANTI-DUPLICAÇÃO
--============================================================--

local GUARD_NAME = "MontarUmPet_Master_Guard"
local TOKEN_NAMES = {
    "__MONTAR_UM_PET_MASTER_V7",
    "__MONTAR_UM_PET_MASTER_V6",
    "__MONTAR_UM_PET_MASTER_V5",
    "__MONTAR_UM_PET_MASTER_V4",
    "__MONTAR_UM_PET_MASTER_V3",
}

local GUI_HINTS = {
    "MontarUmPet",
    "MontarUmPetHub",
    "MontarUmPetVelocidade",
    "MontarUmPet_Master",
    "MontarUmPet_RayfieldGen2",
}

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Para versões anteriores que já tenham um Stop exposto.
for _, tokenName in ipairs(TOKEN_NAMES) do
    pcall(function()
        local oldToken = ENV[tokenName]
        if oldToken and type(oldToken.Stop) == "function" then
            oldToken:Stop()
        end
    end)
end

-- Compatibilidade com o guard das versões anteriores.
pcall(function()
    local oldGuard = PlayerGui:FindFirstChild(GUARD_NAME)
    if oldGuard then
        local event = oldGuard:FindFirstChild("Shutdown")
        if event and event:IsA("BindableEvent") then
            event:Fire()
            task.wait(0.05)
        end
        oldGuard:Destroy()
    end
end)

-- Remove somente GUIs do nosso hub com nomes conhecidos.
pcall(function()
    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        for _, hint in ipairs(GUI_HINTS) do
            if obj.Name == hint then
                obj:Destroy()
                break
            end
        end
    end
end)

-- Controle persistente para execuções v7+.
local CONTROL_NAME = "MontarUmPet_Singleton_Control"
local ControlFolder = ReplicatedStorage:FindFirstChild(CONTROL_NAME)

if not ControlFolder then
    ControlFolder = Instance.new("Folder")
    ControlFolder.Name = CONTROL_NAME
    ControlFolder.Parent = ReplicatedStorage
end

local ReplaceEvent = ControlFolder:FindFirstChild("Replace")
if not ReplaceEvent or not ReplaceEvent:IsA("BindableEvent") then
    if ReplaceEvent then
        ReplaceEvent:Destroy()
    end

    ReplaceEvent = Instance.new("BindableEvent")
    ReplaceEvent.Name = "Replace"
    ReplaceEvent.Parent = ControlFolder
end

-- Importantíssimo: dispara ANTES de conectar a execução nova.
pcall(function()
    ReplaceEvent:Fire()
end)

-- Dá tempo para a execução anterior destruir explicitamente a janela antes
-- de a nova execução chegar ao CreateWindow.
task.wait(0.20)

pcall(function()
    CleanupOldRayfield(game:GetService("CoreGui"))
end)
pcall(function()
    if typeof(gethui) == "function" then
        CleanupOldRayfield(gethui())
    end
end)
pcall(function()
    CleanupOldRayfield(PlayerGui)
end)

local generation = tonumber(ControlFolder:GetAttribute("Generation")) or 0
generation = generation + 1
ControlFolder:SetAttribute("Generation", generation)
local MY_GENERATION = generation

local Running = true
local StopHandler = nil

local ReplaceConnection = ReplaceEvent.Event:Connect(function()
    if not Running then
        return
    end

    Running = false

    if StopHandler then
        task.spawn(function()
            pcall(StopHandler)
        end)
    end
end)

-- Safety net contra corridas/execuções que perderem o evento.
task.spawn(function()
    while Running do
        task.wait(0.20)

        if not Running then
            break
        end

        local currentGeneration = tonumber(ControlFolder:GetAttribute("Generation")) or 0
        if currentGeneration ~= MY_GENERATION then
            Running = false

            if StopHandler then
                task.spawn(function()
                    pcall(StopHandler)
                end)
            end

            break
        end
    end
end)

-- Guard auxiliar no PlayerGui para compatibilidade com versões antigas.
local Guard = Instance.new("Folder")
Guard.Name = GUARD_NAME
Guard.Parent = PlayerGui

local GuardEvent = Instance.new("BindableEvent")
GuardEvent.Name = "Shutdown"
GuardEvent.Parent = Guard

local GuardConnection = GuardEvent.Event:Connect(function()
    if not Running then
        return
    end

    Running = false

    if StopHandler then
        task.spawn(function()
            pcall(StopHandler)
        end)
    end
end)

if not Running then
    pcall(function()
        if GuardConnection then
            GuardConnection:Disconnect()
        end
        if Guard then
            Guard:Destroy()
        end
    end)
    return
end

-- Rayfield Gen2 usa um ScreenGui de nome aleatório. Para limpar uma
-- janela antiga do nosso próprio hub, conferimos título + subtítulo.
local function LooksLikeOurRayfieldGui(gui)
    if not gui or not gui:IsA("ScreenGui") then
        return false
    end

    local hasTitle = false
    local hasHubSubtitle = false

    for _, child in ipairs(gui:GetDescendants()) do
        if child:IsA("TextLabel") then
            local t = tostring(child.Text or "")

            if t == "Montar um Pet" then
                hasTitle = true
            elseif t:find("MASTER v5", 1, true)
                or t:find("MASTER v6", 1, true)
                or t:find("MASTER v7", 1, true)
                or t:find("MASTER v14", 1, true)
                or t:find("MASTER v27 • Auto Farm Seguro 2026", 1, true)
                or t:find("MASTER v15 • Delta Mobile", 1, true)
                or t:find("MASTER v15", 1, true)
                or t:find("Delta Mobile", 1, true) then
                hasHubSubtitle = true
            end

            if hasTitle and hasHubSubtitle then
                return true
            end
        end
    end

    return false
end

local function CleanupOldRayfield(container)
    if not container then
        return
    end

    pcall(function()
        for _, child in ipairs(container:GetChildren()) do
            if LooksLikeOurRayfieldGui(child) then
                child:Destroy()
            end
        end
    end)
end

pcall(function()
    CleanupOldRayfield(game:GetService("CoreGui"))
end)

pcall(function()
    if typeof(gethui) == "function" then
        CleanupOldRayfield(gethui())
    end
end)

pcall(function()
    CleanupOldRayfield(PlayerGui)
end)

--============================================================--
-- FIM DO SINGLETON
--============================================================--

--============================================================--
-- ESTADO
--============================================================--

local State = {
    SpeedEnabled = false,
    WalkSpeed = 150,

    AutoFarm = false,
    FarmMode = "Rarity",
    SelectedEggs = {},
    -- Em uma instalação nova, o Auto Farm começa aceitando todas as raridades.
    -- O usuário pode restringir isso na aba Farm e salvar a configuração.
    SelectedRarities = {
        Common = true,
        Rare = true,
        Epic = true,
        Legendary = true,
        Mythic = true,
        Ethereal = true,
        Divine = true,
    },
    TargetPriority = "Highest Rarity",
    MinEggWeight = 0,
    MinEggLuck = 0,
    OnlyMutated = false,
    AutoPickup = false,
    AutoMountPet = true,
    ReturnToPlot = true,
    VolcanicSupport = true,
    TravelSpeed = 500,

    -- Auto Farm engine
    FarmMoveMode = "Instant",      -- Instant or Tween
    FarmPickupMode = "Auto",       -- Auto, Prompt, Remote
    FarmPickupRadius = 12,
    FarmReturnInstant = true,
    -- Perfis 2026: combina scanner, coleta remota/prompt e glide.
    FarmEngineProfile = "Hybrid 2026",
    FarmRenderedFallback = true,
    FarmRemoteFallback = true,
    FarmPromptFallback = true,
    FarmAutoRecover = true,
    FarmRetryAfterError = 1.0,

    -- Auto Farm Flight
    FarmFlightSpeed = 300,
    FarmFlightHeight = 90,
    -- Mantém o HumanoidRootPart alguns studs acima do ovo/solo.
    -- Isso evita que os pés atravessem o chão quando o noclip está ativo.
    FarmFlightDescendHeight = 6,
    FarmArrivalPause = 0.45,
    FarmPickupPause = 0.45,
    FarmPickupApproachHeight = 6,
    FarmPickupRetryApproach = true,
    FarmBasePause = 2.50,
    FarmDepositWait = 3.50,
    -- Rota de retorno 2026: chega acima do lado da base, desce ao lado,
    -- faz uma pequena pausa, entra no plot e só então procura o ninho.
    FarmBaseSideOffset = 26,
    FarmBaseSideHeight = 6,
    FarmBaseEntryInset = 14,
    FarmBaseSidePause = 0.60,
    FarmBaseEntryPause = 0.80,
    FarmBaseEntrySpeed = 110,
    FarmNestApproachSpeed = 100,
    FarmBaseConfirmTimeout = 2.50,
    FarmNestWait = 8.0,
    -- Controles internos expostos na UI.
    FarmPickupRetries = 6,
    FarmPickupWait = 0.25,
    FarmRetryDelay = 0.30,
    FarmFlightArriveRadius = 4,
    FarmBaseEntryHeight = 7,
    FarmBaseApproachSpeed = 140,
    FarmNestApproachHeight = 6,
    FarmNestPoll = 0.25,
    -- Proteção adicional contra atravessar o chão.
    FarmFloorGuard = true,
    FarmFloorClearance = 6,
    FarmMaxDescendSpeed = 70,
    FarmPendingEggs = {},

    -- Auto Farm state machine
    FarmPhase = "Idle",
    FarmTargetUID = nil,
    FarmTargetName = nil,
    FarmTargetPosition = nil,
    FarmTargetRetries = 0,
    FarmHoverRadius = 18,
    FarmHoverHeight = 55,
    FarmLoopDelay = 0.10,
    FarmCycleDelay = 1.50,
    FarmNoTargetDelay = 1.00,
    FarmRequireMountedPet = false,


    -- Automacoes 2026 verificadas (desligadas por padrao).
    AutoPlaceEggs = false,
    AutoHatchEggs = false,
    AutoBestPets = false,
    AutoClaimIndex = false,
    AutoBuyFood = false,
    AutoFeedPets = false,
    AutoFavorites = false,
    BestPetMetric = "Income",
    AdvancedInterval = 1.0,
    AdvancedStatus = "Aguardando modulos 2026",

    ESPEnabled = false,
    ESPOnlySelected = false,
    ESPOnlyMutated = false,
    ESPMaxDistance = 1000,
    ESPShowRarity = true,
    ESPShowWeight = true,
    ESPShowLuck = true,
    ESPShowMutation = true,
    ESPShowDistance = true,
    ESPSelectedEggs = {},

    PlayerESP = false,
    HidePlayers = false,

    SavedCFrame = nil,

    Noclip = false,
    InfiniteJump = false,
    AntiAFK = false,

    FPSCap = 60,
    LowGraphics = false,
    LowShadows = false,
    Fullbright = false,
    NoFog = false,
    Disable3D = false,

    Flying = false,
    FlySpeed = 60,
}

local Connections = {}
local ESPObjects = {}
local PlayerESPObjects = {}
local Character = nil
local RootPart = nil
local CurrentFlyVelocity = nil
local CurrentFlyGyro = nil

local ActiveMove = nil
local MovementToken = 0
local NoclipOriginal = {}
local HiddenPlayerObjects = {}

local FailedFarmTargets = {}
local LastFarmStatus = "Idle"

local FarmIsRunning

local OriginalLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows,
}

local OriginalQuality = nil

local function Track(connection)
    if connection then
        table.insert(Connections, connection)
    end
    return connection
end

local function DisconnectAll()
    for _, connection in ipairs(Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(Connections)
end

local function CountSet(set)
    local n = 0
    for _ in pairs(set) do
        n = n + 1
    end
    return n
end

local function CopyArrayToSet(value)
    local set = {}
    if type(value) ~= "table" then
        return set
    end

    for _, item in ipairs(value) do
        if type(item) == "string" then
            set[item] = true
        end
    end

    return set
end

local function GetCharacter()
    local character = LocalPlayer.Character
    if not character then
        return nil, nil
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
        or character.PrimaryPart

    return character, hrp
end

local function RefreshCharacter()
    Character, RootPart = GetCharacter()
end

RefreshCharacter()

Track(LocalPlayer.CharacterAdded:Connect(function(character)
    Character = character
    RootPart = character:WaitForChild("HumanoidRootPart", 5) or character.PrimaryPart
end))

--============================================================--
-- DESCOBERTA DO GAME API
--============================================================--

local function GetGameRemotes()
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    return remotesFolder and remotesFolder:FindFirstChild("Game")
end

local function GetEggPickupRemote()
    local gameRemotes = GetGameRemotes()
    return gameRemotes and gameRemotes:FindFirstChild("EggPickup")
end

local function GetMountRemote()
    local gameRemotes = GetGameRemotes()
    return gameRemotes and gameRemotes:FindFirstChild("Mounting")
end

local function GetEggPlacedRemote()
    local gameRemotes = GetGameRemotes()
    return gameRemotes and gameRemotes:FindFirstChild("EggPlaced")
end

local EggData = {}
local EggNames = {}
local Rarities = {
    "Common",
    "Rare",
    "Epic",
    "Legendary",
    "Mythic",
    "Ethereal",
    "Divine",
}

local FallbackEggNames = {
    "Asteroid Egg",
    "Aurora Egg",
    "Blackhole Egg",
    "Black Hole Egg",
    "Bloom Egg",
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
    "Solaris Egg",
    "Soul Egg",
    "Stone Egg",
    "Volcanic Egg",
    "White Egg",
}

local function SortEggNames()
    table.sort(EggNames, function(a, b)
        return a:lower() < b:lower()
    end)
end

local function ResetRarities()
    local raritySet = {
        Common = true,
        Rare = true,
        Epic = true,
        Legendary = true,
        Mythic = true,
        Ethereal = true,
        Divine = true,
    }

    for _, data in pairs(EggData) do
        if type(data) == "table" and type(data.Rarity) == "string" then
            raritySet[data.Rarity] = true
        end
    end

    table.clear(Rarities)
    for rarity in pairs(raritySet) do
        table.insert(Rarities, rarity)
    end

    local priority = {
        Common = 1,
        Rare = 2,
        Epic = 3,
        Legendary = 4,
        Mythic = 5,
        Ethereal = 6,
        Divine = 7,
    }

    table.sort(Rarities, function(a, b)
        local pa = priority[a] or 999
        local pb = priority[b] or 999
        if pa == pb then
            return a:lower() < b:lower()
        end
        return pa < pb
    end)
end

local function LoadEggData()
    table.clear(EggData)
    table.clear(EggNames)

    local gameData = ReplicatedStorage:FindFirstChild("GameData")
    local eggsModule = gameData and gameData:FindFirstChild("Eggs")

    if eggsModule and eggsModule:IsA("ModuleScript") then
        local ok, data = pcall(require, eggsModule)
        if ok and type(data) == "table" then
            EggData = data
        end
    end

    for eggName in pairs(EggData) do
        if type(eggName) == "string" then
            table.insert(EggNames, eggName)
        end
    end

    if #EggNames == 0 then
        for _, eggName in ipairs(FallbackEggNames) do
            table.insert(EggNames, eggName)
        end
    end

    SortEggNames()
    ResetRarities()
end

LoadEggData()

local RarityPriority = {
    Common = 1,
    Rare = 2,
    Epic = 3,
    Legendary = 4,
    Mythic = 5,
    Ethereal = 6,
    Divine = 7,
}

local KnownEggLuck = {
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

local function GetEggRarity(eggName, instance)
    local data = EggData[eggName]
    if type(data) == "table" and type(data.Rarity) == "string" then
        return data.Rarity
    end

    if instance then
        local value = instance:GetAttribute("Rarity")
        if type(value) == "string" and value ~= "" then
            return value
        end
    end

    return "Unknown"
end


local function GetGameFeatureStatus()
    return {
        EggPickup = (GetEggPickupRemote() and GetEggPickupRemote():IsA("RemoteEvent")) or false,
        Mounting = (GetMountRemote() and GetMountRemote():IsA("RemoteEvent")) or false,
        EggPlaced = (GetEggPlacedRemote() and GetEggPlacedRemote():IsA("RemoteEvent")) or false,
        EggData = next(EggData) ~= nil,
        ActiveEggs = ReplicatedStorage:FindFirstChild("ServerData")
            and ReplicatedStorage.ServerData:FindFirstChild("ActiveEggs") ~= nil,
        Plots = workspace:FindFirstChild("Plots") ~= nil,
        RenderedEggs = workspace:FindFirstChild("RenderedEggs", true) ~= nil,
    }
end

--============================================================--
-- OVOS / CANDIDATOS
--============================================================--

local function GetActiveEggFolder()
    local serverData = ReplicatedStorage:FindFirstChild("ServerData")
    return serverData and serverData:FindFirstChild("ActiveEggs")
end

local function GetRenderedEggFolder()
    return workspace:FindFirstChild("RenderedEggs", true)
end

local function GetEggPosition(instance)
    if not instance then
        return nil
    end

    local positionAttribute = instance:GetAttribute("Position")

    if typeof(positionAttribute) == "Vector3" then
        return positionAttribute
    end

    if typeof(positionAttribute) == "CFrame" then
        return positionAttribute.Position
    end

    if instance:IsA("Model") then
        local ok, pivot = pcall(function()
            return instance:GetPivot()
        end)

        if ok and pivot then
            return pivot.Position
        end
    end

    if instance:IsA("BasePart") then
        return instance.Position
    end

    local part = instance:FindFirstChildWhichIsA("BasePart", true)
    if part then
        return part.Position
    end

    return nil
end

local function GetEggMutation(instance)
    if not instance then
        return nil
    end

    for _, attributeName in ipairs({"Mutation", "SpawnMutation", "MutationType"}) do
        local value = instance:GetAttribute(attributeName)

        if type(value) == "string" and value ~= "" then
            return value
        end

        if value == true then
            return "Mutated"
        end
    end

    return nil
end

local function GetEggWeight(instance)
    if not instance then
        return nil
    end

    local value = instance:GetAttribute("Weight")
    return type(value) == "number" and value or nil
end

local function GetEggLuck(instance)
    if not instance then
        return nil
    end

    local value = instance:GetAttribute("Luck")
    if type(value) == "number" then
        return value
    end

    local eggName = instance:GetAttribute("Egg")
    if type(eggName) == "string" then
        return KnownEggLuck[eggName]
    end

    return KnownEggLuck[instance.Name]
end

local function GetRealRenderedEggName(model)
    if not model then
        return nil
    end

    local directName = model.Name
    if EggData[directName] then
        return directName
    end

    local eggSpawns = workspace:FindFirstChild("EggSpawns")
    local part = model:IsA("BasePart") and model or model:FindFirstChildWhichIsA("BasePart", true)

    if eggSpawns and part then
        for _, spawn in ipairs(eggSpawns:GetChildren()) do
            local spawnPart = spawn:IsA("BasePart")
                and spawn
                or spawn:FindFirstChildWhichIsA("BasePart", true)

            if spawnPart and (spawnPart.Position - part.Position).Magnitude < 15 then
                return spawn.Name
            end
        end
    end

    return directName
end

local function FindActiveEggNear(position, radius)
    local activeEggs = GetActiveEggFolder()
    if not activeEggs or typeof(position) ~= "Vector3" then
        return nil
    end

    local nearest = nil
    local nearestDistance = radius or 15

    for _, egg in ipairs(activeEggs:GetChildren()) do
        if egg:IsA("Configuration") then
            local eggPosition = GetEggPosition(egg)

            if eggPosition then
                local distance = (eggPosition - position).Magnitude

                if distance <= nearestDistance then
                    nearest = egg
                    nearestDistance = distance
                end
            end
        end
    end

    return nearest
end

local function IsMutationMatch(instance)
    if not State.OnlyMutated then
        return true
    end

    return GetEggMutation(instance) ~= nil
end

local function IsSelectedForFarm(eggName)
    if State.FarmMode == "Egg" then
        return State.SelectedEggs[eggName] == true
    end

    return State.SelectedRarities[GetEggRarity(eggName)] == true
end

local function MeetsFilters(instance, eggName)
    if not IsSelectedForFarm(eggName) then
        return false
    end

    if not IsMutationMatch(instance) then
        return false
    end

    local weight = GetEggWeight(instance)
    if State.MinEggWeight > 0 then
        if not weight or weight < State.MinEggWeight then
            return false
        end
    end

    local luck = GetEggLuck(instance)
    if State.MinEggLuck > 0 then
        if not luck or luck < State.MinEggLuck then
            return false
        end
    end

    return true
end

local function GetCandidates()
    local _, root = GetCharacter()
    if not root then
        return {}
    end

    local result = {}
    local seen = {}

    -- Prefer the live ActiveEggs table because it contains the real server UID.
    local activeEggs = GetActiveEggFolder()

    if activeEggs then
        for _, egg in ipairs(activeEggs:GetChildren()) do
            if egg:IsA("Configuration") then
                local eggName = egg:GetAttribute("Egg")

                if type(eggName) == "string"
                    and MeetsFilters(egg, eggName) then

                    local position = GetEggPosition(egg)

                    if position then
                        local distance = (position - root.Position).Magnitude
                        local id = egg.Name

                        if not FailedFarmTargets[id] or os.clock() >= FailedFarmTargets[id] then
                            seen[id] = true

                            table.insert(result, {
                                Instance = egg,
                                Rendered = nil,
                                ID = id,
                                Name = eggName,
                                Position = position,
                                Distance = distance,
                                Weight = GetEggWeight(egg) or 0,
                                Luck = GetEggLuck(egg) or 0,
                                Rarity = GetEggRarity(eggName, egg),
                                RarityScore = RarityPriority[GetEggRarity(eggName, egg)] or 0,
                                Mutation = GetEggMutation(egg),
                            })
                        end
                    end
                end
            end
        end
    end

    -- Enrich candidates with the matching RenderedEgg model for ProximityPrompt pickup.
    local rendered = GetRenderedEggFolder()

    if rendered then
        for _, model in ipairs(rendered:GetChildren()) do
            local position = GetEggPosition(model)

            if position then
                local eggName = GetRealRenderedEggName(model)

                if type(eggName) == "string" and EggData[eggName] then
                    local active = FindActiveEggNear(position, 15)

                    if active then
                        local id = active.Name

                        for _, candidate in ipairs(result) do
                            if candidate.ID == id then
                                candidate.Rendered = model
                                candidate.Position = position
                                candidate.Distance = (position - root.Position).Magnitude

                                local mutation = GetEggMutation(model) or GetEggMutation(active)
                                local weight = GetEggWeight(active) or GetEggWeight(model) or 0
                                local luck = GetEggLuck(active) or GetEggLuck(model) or 0

                                candidate.Mutation = mutation
                                candidate.Weight = weight
                                candidate.Luck = luck
                                break
                            end
                        end
                    else
                        -- Fallback candidate when an ActiveEgg entry is momentarily delayed.
                        if IsSelectedForFarm(eggName) and MeetsFilters(model, eggName) then
                            local syntheticId = model:GetDebugId()
                            if not seen[syntheticId] then
                                seen[syntheticId] = true

                                table.insert(result, {
                                    Instance = model,
                                    Rendered = model,
                                    ID = model.Name,
                                    Name = eggName,
                                    Position = position,
                                    Distance = (position - root.Position).Magnitude,
                                    Weight = GetEggWeight(model) or 0,
                                    Luck = GetEggLuck(model) or 0,
                                    Rarity = GetEggRarity(eggName, model),
                                    RarityScore = RarityPriority[GetEggRarity(eggName, model)] or 0,
                                    Mutation = GetEggMutation(model),
                                    Synthetic = true,
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    return result
end

local function SelectBestCandidate(candidates)
    local best = nil

    for _, candidate in ipairs(candidates) do
        if not best then
            best = candidate
        elseif State.TargetPriority == "Closest" then
            if candidate.Distance < best.Distance then
                best = candidate
            end
        elseif State.TargetPriority == "Highest Weight" then
            if candidate.Weight > best.Weight then
                best = candidate
            elseif candidate.Weight == best.Weight and candidate.Distance < best.Distance then
                best = candidate
            end
        else
            if candidate.RarityScore > best.RarityScore then
                best = candidate
            elseif candidate.RarityScore == best.RarityScore then
                if candidate.Luck > best.Luck then
                    best = candidate
                elseif candidate.Luck == best.Luck and candidate.Distance < best.Distance then
                    best = candidate
                end
            end
        end
    end

    return best
end

--============================================================--
-- AUTO FARM: SCANNER DIRETO DO SERVERDATA.ACTIVEEGGS
--============================================================--

local function GetFarmCandidates()
    local _, root = GetCharacter()
    if not root then
        return {}
    end

    local result = {}
    local seen = {}
    local activeEggs = GetActiveEggFolder()
    local activeCount = 0

    -- Caminho principal: ServerData.ActiveEggs (UID real do servidor).
    if activeEggs then
        for _, egg in ipairs(activeEggs:GetChildren()) do
            if egg:IsA("Configuration") then
                local eggName = egg:GetAttribute("Egg")
                local privateTo = egg:GetAttribute("PrivateTo")
                local collected = tostring(LocalPlayer:GetAttribute("CollectedEggs") or "")
                local alreadyCollected = string.find("," .. collected .. ",", "," .. tostring(egg.Name) .. ",", 1, true) ~= nil
                local privateMismatch = privateTo ~= nil and tostring(privateTo) ~= tostring(LocalPlayer.UserId)

                if type(eggName) == "string"
                    and not alreadyCollected
                    and not privateMismatch
                    and MeetsFilters(egg, eggName) then

                    local position = egg:GetAttribute("Position")
                    if typeof(position) == "CFrame" then
                        position = position.Position
                    end
                    if typeof(position) ~= "Vector3" then
                        position = GetEggPosition(egg)
                    end

                    if position then
                        local uid = egg.Name
                        if not FailedFarmTargets[uid] or os.clock() >= FailedFarmTargets[uid] then
                            activeCount = activeCount + 1
                            seen[uid] = true
                            local rarity = GetEggRarity(eggName, egg)
                            result[#result + 1] = {
                                Instance = egg,
                                UID = uid,
                                ID = uid,
                                Name = eggName,
                                Position = position,
                                Distance = (position - root.Position).Magnitude,
                                Weight = GetEggWeight(egg) or 0,
                                Luck = GetEggLuck(egg) or 0,
                                Rarity = rarity,
                                RarityScore = RarityPriority[rarity] or 0,
                                Mutation = GetEggMutation(egg),
                                Synthetic = false,
                            }
                        end
                    end
                end
            end
        end
    end

    -- Fallback importante: alguns carregamentos/executores expõem RenderedEggs
    -- antes de ActiveEggs. Os hubs públicos de 2026 usam este caminho para
    -- localizar ovos visuais; aqui tentamos recuperar o UID real quando possível.
    if State.FarmRenderedFallback then
        local rendered = GetRenderedEggFolder()
        if rendered and (#result == 0 or State.FarmEngineProfile == "Rendered Eggs") then
            for _, model in ipairs(rendered:GetChildren()) do
                local position = GetEggPosition(model)
                local eggName = GetRealRenderedEggName(model)

                if position and type(eggName) == "string" and EggData[eggName]
                    and IsSelectedForFarm(eggName)
                    and MeetsFilters(model, eggName) then

                    local active = FindActiveEggNear(position, 18)
                    local uid = active and active.Name or model.Name
                    if not seen[uid] and (not FailedFarmTargets[uid] or os.clock() >= FailedFarmTargets[uid]) then
                        seen[uid] = true
                        local source = active or model
                        local rarity = GetEggRarity(eggName, source)
                        result[#result + 1] = {
                            Instance = source,
                            Rendered = model,
                            UID = uid,
                            ID = uid,
                            Name = eggName,
                            Position = position,
                            Distance = (position - root.Position).Magnitude,
                            Weight = GetEggWeight(source) or 0,
                            Luck = GetEggLuck(source) or 0,
                            Rarity = rarity,
                            RarityScore = RarityPriority[rarity] or 0,
                            Mutation = GetEggMutation(source),
                            Synthetic = active == nil,
                        }
                    end
                end
            end
        end
    end

    return result
end

local function SelectBestFarmCandidate(candidates)
    local best = nil

    for _, candidate in ipairs(candidates) do
        if not best then
            best = candidate
        elseif State.TargetPriority == "Closest" then
            if candidate.Distance < best.Distance then
                best = candidate
            end
        elseif State.TargetPriority == "Highest Weight" then
            if candidate.Weight > best.Weight then
                best = candidate
            elseif candidate.Weight == best.Weight
                and candidate.Luck > best.Luck then
                best = candidate
            elseif candidate.Weight == best.Weight
                and candidate.Luck == best.Luck
                and candidate.Distance < best.Distance then
                best = candidate
            end
        elseif State.TargetPriority == "Highest Luck" then
            if candidate.Luck > best.Luck then
                best = candidate
            elseif candidate.Luck == best.Luck
                and candidate.RarityScore > best.RarityScore then
                best = candidate
            elseif candidate.Luck == best.Luck
                and candidate.RarityScore == best.RarityScore
                and candidate.Distance < best.Distance then
                best = candidate
            end
        else
            if candidate.RarityScore > best.RarityScore then
                best = candidate
            elseif candidate.RarityScore == best.RarityScore then
                if candidate.Luck > best.Luck then
                    best = candidate
                elseif candidate.Luck == best.Luck
                    and candidate.Distance < best.Distance then
                    best = candidate
                end
            end
        end
    end

    return best
end

--============================================================--
-- PLOT / CARGA / MONTAR PET
--============================================================--

local function IsCarryingEggs()
    local basket = LocalPlayer:FindFirstChild("Basket")
    if not basket then
        return false
    end
    return #basket:GetChildren() > 0
end

local function GetMyPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then
        return nil
    end

    -- Prefer the same owner representation used by current public scripts.
    for _, plot in ipairs(plots:GetChildren()) do
        local data = plot:FindFirstChild("Data")
        local owner = data and data:FindFirstChild("Owner")
        if owner and owner:IsA("ObjectValue") and owner.Value == LocalPlayer then
            return plot
        end
    end

    -- Fallback for builds exposing only the loaded-owner attribute.
    for _, plot in ipairs(plots:GetChildren()) do
        local loaded = plot:GetAttribute("NestsOwnerLoaded")
        if loaded == LocalPlayer.UserId then
            return plot
        end
    end

    return nil
end

local FarmUtil = {}

function FarmUtil.GetFreeNests()
    local plot = GetMyPlot()
    local nests = plot and plot:FindFirstChild("Nests")
    if not nests then
        return {}
    end

    local result = {}

    for _, nest in ipairs(nests:GetChildren()) do
        local unlocked = nest:GetAttribute("Unlocked")
        local occupied = nest:GetAttribute("Occupied")

        -- Different builds have used either an explicit Unlocked flag or a
        -- nest that is immediately usable when the attribute is absent.
        if unlocked ~= false and occupied ~= true then
            table.insert(result, nest)
        end
    end

    table.sort(result, function(a, b)
        local an = tonumber(a.Name) or math.huge
        local bn = tonumber(b.Name) or math.huge
        if an == bn then
            return tostring(a.Name) < tostring(b.Name)
        end
        return an < bn
    end)

    return result
end

function FarmUtil.GetEggTools()
    local result = {}
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    local character = LocalPlayer.Character

    for _, container in ipairs({backpack, character}) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") and EggData[tool.Name] and not tool:GetAttribute("PetKey") then
                    table.insert(result, tool)
                end
            end
        end
    end

    table.sort(result, function(a, b)
        local al = KnownEggLuck[a.Name] or 0
        local bl = KnownEggLuck[b.Name] or 0
        if al == bl then
            return tostring(a.Name) < tostring(b.Name)
        end
        return al > bl
    end)

    return result
end

function FarmUtil.GetBasketEggNames()
    local basket = LocalPlayer:FindFirstChild("Basket")
    if not basket then
        return {}
    end

    local expected = {}
    for _, egg in ipairs(basket:GetChildren()) do
        local name = egg:GetAttribute("Egg")
        if type(name) == "string" and name ~= "" then
            expected[name] = (expected[name] or 0) + 1
        end
    end
    return expected
end

function FarmUtil.SnapshotEggTools()
    local snapshot = {}
    for _, tool in ipairs(FarmUtil.GetEggTools()) do
        snapshot[tool] = true
    end
    return snapshot
end

function FarmUtil.GetBasketCount()
    local basket = LocalPlayer:FindFirstChild("Basket")
    return basket and #basket:GetChildren() or 0
end

function FarmUtil.WaitForReturnedEggTools(expected, beforeTools, timeout)
    local deadline = os.clock() + (timeout or 5)

    while FarmIsRunning() and os.clock() < deadline do
        local basketCount = FarmUtil.GetBasketCount()
        local currentTools = FarmUtil.GetEggTools()
        local received = {}

        for _, tool in ipairs(currentTools) do
            if not beforeTools[tool] then
                received[tool.Name] = (received[tool.Name] or 0) + 1
            end
        end

        local enough = basketCount <= 0
        if enough then
            for name, count in pairs(expected) do
                if (received[name] or 0) < count then
                    enough = false
                    break
                end
            end
        end

        if enough then
            return true
        end

        task.wait(0.10)
    end

    return false
end

local function IsInVolcano()
    return LocalPlayer:GetAttribute("InVolcano") == true
end

local function IsRidingPet()
    return LocalPlayer:GetAttribute("IsRiding") == true
end

local function MountBestPet()
    local MountRemote = GetMountRemote()
    if not MountRemote or not MountRemote:IsA("RemoteEvent") then
        return false
    end

    local character = LocalPlayer.Character
    if not character then
        return false
    end

    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")

    local selectedPet = nil
    local lowestWeight = math.huge

    local function consider(container)
        if not container then
            return
        end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") and item:GetAttribute("PetName") ~= nil then
                local weight = item:GetAttribute("Weight")

                if type(weight) == "number" and weight < lowestWeight then
                    lowestWeight = weight
                    selectedPet = item
                end
            end
        end
    end

    -- Pode estar no Backpack ou já equipado no Character.
    consider(backpack)
    consider(character)

    if not selectedPet then
        return false
    end

    local ok = pcall(function()
        selectedPet.Parent = character
    end)

    if not ok then
        return false
    end

    local deadline = os.clock() + 2
    while Running and os.clock() < deadline do
        if character:FindFirstChild(selectedPet.Name) then
            break
        end
        task.wait(0.05)
    end

    if not Running then
        return false
    end

    return pcall(function()
        MountRemote:FireServer()
    end)
end

--============================================================--
-- MOVIMENTO: GLIDE SAFE
--============================================================--

local function CancelGlide()
    MovementToken = MovementToken + 1

    if ActiveMove then
        pcall(function()
            ActiveMove:Cancel()
        end)
        ActiveMove = nil
    end
end

local function GlideTo(targetPosition, speed, shouldContinue)
    local character, root = GetCharacter()
    if not character or not root then
        return false
    end

    if typeof(targetPosition) == "CFrame" then
        targetPosition = targetPosition.Position
    end

    if typeof(targetPosition) ~= "Vector3" then
        return false
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return false
    end

    CancelGlide()
    local myToken = MovementToken

    local oldPlatformStand = humanoid.PlatformStand
    local oldAutoRotate = humanoid.AutoRotate
    local oldCollision = {}

    humanoid.PlatformStand = true
    humanoid.AutoRotate = false

    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            oldCollision[part] = part.CanCollide
            part.CanCollide = false
        end
    end

    local distance = (targetPosition - root.Position).Magnitude
    if distance <= 1 then
        pcall(function()
            root.CFrame = CFrame.new(targetPosition)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)

        for part, value in pairs(oldCollision) do
            if part and part.Parent then
                part.CanCollide = value
            end
        end

        humanoid.PlatformStand = oldPlatformStand
        humanoid.AutoRotate = oldAutoRotate
        return true
    end

    local travelSpeed = math.clamp(tonumber(speed) or 500, 25, 2500)
    local duration = math.clamp(distance / travelSpeed, 0.05, 12)
    local targetCFrame = CFrame.new(targetPosition)

    local okTween, tween = pcall(function()
        return TweenService:Create(
            root,
            TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
            {CFrame = targetCFrame}
        )
    end)

    if not okTween or not tween then
        for part, value in pairs(oldCollision) do
            if part and part.Parent then
                part.CanCollide = value
            end
        end
        humanoid.PlatformStand = oldPlatformStand
        humanoid.AutoRotate = oldAutoRotate
        return false
    end

    ActiveMove = tween
    tween:Play()

    local playbackState = Enum.PlaybackState.Canceled
    local completedOk = pcall(function()
        playbackState = tween.Completed:Wait()
    end)

    if ActiveMove == tween then
        ActiveMove = nil
    end

    for part, value in pairs(oldCollision) do
        if part and part.Parent then
            part.CanCollide = value
        end
    end

    if humanoid and humanoid.Parent then
        humanoid.PlatformStand = oldPlatformStand
        humanoid.AutoRotate = oldAutoRotate
    end

    if not completedOk then
        return false
    end

    if myToken ~= MovementToken or not Running then
        return false
    end

    if shouldContinue and not shouldContinue() then
        return false
    end

    return playbackState == Enum.PlaybackState.Completed
end

local function ReturnToPlot()
    local plot = GetMyPlot()
    if not plot then
        return false
    end

    local ok, pivot = pcall(function()
        return plot:GetPivot()
    end)

    if not ok or not pivot then
        return false
    end

    return GlideTo(pivot.Position, State.TravelSpeed)
end

local function ReturnToSaved()
    if not State.SavedCFrame then
        return false
    end

    return GlideTo(State.SavedCFrame.Position, State.TravelSpeed)
end

--============================================================--
-- AUTO FARM FLIGHT ENGINE
-- Modelo de fases: CRUZEIRO = noclip ON; APROXIMAÇÃO/DESCIDA = noclip OFF;
-- PARADO = colisão restaurada. Não usa teleport para o ciclo do farm.
--============================================================--

local FarmFlightVelocity = nil
local FarmFlightGyro = nil
local FarmNoclipConnection = nil
local FarmCollisionOriginal = {}

local function RestoreFarmCollision()
    for part, original in pairs(FarmCollisionOriginal) do
        if part and part.Parent then
            pcall(function()
                part.CanCollide = original
            end)
        end
    end
    table.clear(FarmCollisionOriginal)
end

local function EnforceFarmNoclip()
    local character = LocalPlayer.Character
    if not character then
        return
    end

    for _, obj in ipairs(character:GetDescendants()) do
        if obj:IsA("BasePart") then
            if FarmCollisionOriginal[obj] == nil then
                FarmCollisionOriginal[obj] = obj.CanCollide
            end
            obj.CanCollide = false
        end
    end
end

local function StopFarmNoclip()
    if FarmNoclipConnection then
        pcall(function()
            FarmNoclipConnection:Disconnect()
        end)
        FarmNoclipConnection = nil
    end

    RestoreFarmCollision()
end

local function StartFarmNoclip()
    if FarmNoclipConnection then
        EnforceFarmNoclip()
        return
    end

    EnforceFarmNoclip()

    FarmNoclipConnection = Track(RunService.Stepped:Connect(function()
        if not Running or not State.AutoFarm then
            return
        end

        EnforceFarmNoclip()
    end))
end

local function DestroyFarmFlightMovers()
    if FarmFlightVelocity then
        pcall(function()
            FarmFlightVelocity:Destroy()
        end)
        FarmFlightVelocity = nil
    end

    if FarmFlightGyro then
        pcall(function()
            FarmFlightGyro:Destroy()
        end)
        FarmFlightGyro = nil
    end
end

local function CreateFarmFlightMovers(root)
    DestroyFarmFlightMovers()

    local ok = pcall(function()
        local velocity = Instance.new("BodyVelocity")
        velocity.Name = "MontarUmPetFarmFlightVelocity"
        velocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        velocity.P = 25000
        velocity.Velocity = Vector3.zero
        velocity.Parent = root

        local gyro = Instance.new("BodyGyro")
        gyro.Name = "MontarUmPetFarmFlightGyro"
        gyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
        gyro.P = 50000
        gyro.D = 1500
        gyro.CFrame = root.CFrame
        gyro.Parent = root

        FarmFlightVelocity = velocity
        FarmFlightGyro = gyro
    end)

    return ok and FarmFlightVelocity ~= nil and FarmFlightGyro ~= nil
end

local function GetSafeDescentPosition(targetPosition, extraHeight)
    if typeof(targetPosition) ~= "Vector3" then
        return nil
    end

    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    -- Altura mínima conservadora para não colocar o RootPart dentro do solo.
    local bodyClearance = math.max(3, tonumber(State.FarmFloorClearance) or 6)
    if humanoid then
        bodyClearance = math.max(6, (tonumber(humanoid.HipHeight) or 2) + 3)
    end

    local desiredHeight = math.max(
        tonumber(extraHeight) or State.FarmFlightDescendHeight or 6,
        bodyClearance
    )

    local safeY = targetPosition.Y + desiredHeight

    -- Detecta o piso abaixo da coluna do alvo e nunca desce abaixo dele.
    -- O Raycast serve apenas como proteção de altura; não muda o alvo.
    pcall(function()
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = character and {character} or {}
        params.IgnoreWater = false

        local origin = targetPosition + Vector3.new(0, 160, 0)
        local direction = Vector3.new(0, -320, 0)
        local hit = workspace:Raycast(origin, direction, params)

        if hit and hit.Position then
            safeY = math.max(safeY, hit.Position.Y + bodyClearance)
        end
    end)

    return Vector3.new(
        targetPosition.X,
        safeY,
        targetPosition.Z
    )
end

local function GetFarmFloorY(position, rayLength)
    if typeof(position) ~= "Vector3" then
        return nil
    end

    local character = LocalPlayer.Character
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = character and {character} or {}
    params.IgnoreWater = false

    local origin = position + Vector3.new(0, 18, 0)
    local direction = Vector3.new(0, -(rayLength or 140), 0)
    local ok, hit = pcall(function()
        return workspace:Raycast(origin, direction, params)
    end)

    if ok and hit and hit.Position then
        return hit.Position.Y
    end

    return nil
end

local function EnforceFarmFloorSafety(root)
    if not State.FarmFloorGuard or not root or not root.Parent then
        return
    end

    local floorY = GetFarmFloorY(root.Position, 140)
    if not floorY then
        return
    end

    local clearance = math.max(3, tonumber(State.FarmFloorClearance) or 6)
    local minimumY = floorY + clearance
    local velocity = root.AssemblyLinearVelocity
    local safeVertical = velocity.Y

    -- Nunca deixa a queda passar do limite configurado.
    if safeVertical < -math.abs(tonumber(State.FarmMaxDescendSpeed) or 70) then
        safeVertical = -math.abs(tonumber(State.FarmMaxDescendSpeed) or 70)
    end

    -- Se já estiver muito próximo do chão, corta a componente descendente
    -- e aplica uma pequena correção ascendente via física. Não teleporta.
    if root.Position.Y <= minimumY + 1.5 then
        safeVertical = math.max(safeVertical, 12)
    end

    if safeVertical ~= velocity.Y then
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.new(velocity.X, safeVertical, velocity.Z)
            if FarmFlightVelocity then
                local current = FarmFlightVelocity.Velocity
                FarmFlightVelocity.Velocity = Vector3.new(current.X, safeVertical, current.Z)
            end
        end)
    end
end

local function FarmFlightSegment(targetPosition, speed, timeoutMultiplier, allowNoclip)
    local character, root = GetCharacter()

    if not character or not root then
        return false
    end

    if typeof(targetPosition) ~= "Vector3" then
        return false
    end

    if not FarmIsRunning() then
        return false
    end

    local useNoclip = allowNoclip == true
    if useNoclip then
        StartFarmNoclip()
    else
        StopFarmNoclip()
    end

    local maxSpeed = math.clamp(
        tonumber(speed) or State.FarmFlightSpeed,
        50,
        1200
    )

    local arrivedRadius = math.clamp(
        tonumber(State.FarmFlightArriveRadius) or 3,
        1.5,
        8
    )

    local distance = (targetPosition - root.Position).Magnitude
    local timeout = math.clamp(
        (distance / math.max(maxSpeed, 1)) * (timeoutMultiplier or 2.5) + 2,
        3,
        45
    )

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local oldPlatformStand = humanoid and humanoid.PlatformStand or nil
    local oldAutoRotate = humanoid and humanoid.AutoRotate or nil

    if humanoid then
        humanoid.PlatformStand = true
        humanoid.AutoRotate = false
    end

    local started = os.clock()
    local lastSamplePosition = root.Position
    local lastSampleTime = started
    local stalledFor = 0
    local rescueCount = 0

    -- VintHub-style glide: move in small frame-sized steps instead of doing
    -- a single teleport. During active flight collision is disabled, and the
    -- caller restores collision only after the flight has actually stopped.
    while FarmIsRunning()
        and character.Parent
        and root.Parent
        and os.clock() - started < timeout do

        if useNoclip then
            EnforceFarmNoclip()
        end
        EnforceFarmFloorSafety(root)

        local currentPos = root.Position
        local delta = targetPosition - currentPos
        local remaining = delta.Magnitude

        if remaining <= arrivedRadius then
            pcall(function()
                root.CFrame = CFrame.new(targetPosition, targetPosition + root.CFrame.LookVector)
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end)
            break
        end

        local direction = delta.Unit

        -- Desacelera perto do alvo para evitar passar do ponto.
        local currentSpeed = math.clamp(
            math.min(maxSpeed, math.max(55, remaining * 6)),
            55,
            maxSpeed
        )

        local dt = RunService.Heartbeat:Wait()
        if type(dt) ~= "number" or dt <= 0 then
            dt = 1 / 60
        end

        local step = math.min(remaining, currentSpeed * math.min(dt, 0.05))
        local newPos = currentPos + direction * step

        -- Floor guard: nunca permite que a etapa de voo passe abaixo da altura
        -- mínima calculada pelo Raycast. Isso evita a “queda reta para dentro
        -- da terra” mesmo enquanto o noclip está ativo.
        if State.FarmFloorGuard then
            local floorY = GetFarmFloorY(newPos, 160)
            if floorY then
                local clearance = math.max(3, tonumber(State.FarmFloorClearance) or 6)
                local minimumY = floorY + clearance
                if newPos.Y < minimumY then
                    newPos = Vector3.new(newPos.X, minimumY, newPos.Z)
                end
            end
        end

        pcall(function()
            root.CFrame = CFrame.lookAt(
                newPos,
                newPos + direction
            )
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)

        -- Anti-stall simples. Se a posição praticamente não mudar, cria uma
        -- pequena correção para manter o glide avançando; não usa teleport.
        local now = os.clock()
        if now - lastSampleTime >= 0.30 then
            local moved = (root.Position - lastSamplePosition).Magnitude
            if moved < 1.0 and remaining > arrivedRadius + 2 then
                stalledFor = stalledFor + (now - lastSampleTime)
            else
                stalledFor = 0
            end

            lastSampleTime = now
            lastSamplePosition = root.Position

            if stalledFor >= 0.45 then
                rescueCount = rescueCount + 1
                stalledFor = 0

                local rescueStep = math.min(remaining, math.max(120, currentSpeed) * 0.08)
                local rescuePos = root.Position + direction * rescueStep

                if State.FarmFloorGuard then
                    local floorY = GetFarmFloorY(rescuePos, 160)
                    if floorY then
                        local clearance = math.max(3, tonumber(State.FarmFloorClearance) or 6)
                        rescuePos = Vector3.new(
                            rescuePos.X,
                            math.max(rescuePos.Y, floorY + clearance),
                            rescuePos.Z
                        )
                    end
                end

                pcall(function()
                    root.CFrame = CFrame.lookAt(rescuePos, rescuePos + direction)
                end)

                if rescueCount >= 4 then
                    return false
                end
            else
                rescueCount = 0
            end
        end
    end

    local reached = false
    if root and root.Parent then
        reached = (root.Position - targetPosition).Magnitude <= arrivedRadius + 0.75
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    if humanoid and humanoid.Parent then
        pcall(function()
            humanoid.PlatformStand = oldPlatformStand
            humanoid.AutoRotate = oldAutoRotate
        end)
    end

    return reached
end

local function FarmFlyTo(targetPosition, speed, descend)
    local character, root = GetCharacter()

    if not character or not root then
        return false
    end

    if not FarmIsRunning() then
        return false
    end

    -- Toda a viagem é uma única sessão de voo. O noclip entra antes de sair,
    -- permanece ativo durante subida + cruzeiro + aproximação + descida e só
    -- é removido depois que o personagem parou no ponto seguro.
    StartFarmNoclip()
    SetFarmPhase("Voando / noclip ON")

    local flightHeight = math.clamp(
        tonumber(State.FarmFlightHeight) or 90,
        20,
        300
    )

    local descendHeight = math.clamp(
        tonumber(State.FarmFlightDescendHeight) or 6,
        3,
        12
    )

    local cruiseY = math.max(
        root.Position.Y,
        targetPosition.Y
    ) + flightHeight

    -- 1. Sobe suavemente até a altitude de cruzeiro.
    local upPoint = Vector3.new(
        root.Position.X,
        cruiseY,
        root.Position.Z
    )

    local effectiveSpeed = speed or State.FarmFlightSpeed
    if State.FarmEngineProfile == "Conservative" then
        effectiveSpeed = math.min(effectiveSpeed, 220)
    end

    local ok = FarmFlightSegment(
        upPoint,
        effectiveSpeed,
        2,
        true
    )

    -- 2. Cruza o mapa em linha reta, ainda com noclip.
    if ok and FarmIsRunning() then
        local cruisePoint = Vector3.new(
            targetPosition.X,
            cruiseY,
            targetPosition.Z
        )

        ok = FarmFlightSegment(
            cruisePoint,
            effectiveSpeed,
            2.5,
            true
        )
    end

    -- 3. Faz a descida somente dentro da coluna do alvo. O noclip continua
    -- ligado nesta etapa para não enroscar em teto/parede, mas o Raycast trava
    -- o ponto final acima do chão.
    if ok and FarmIsRunning() and descend ~= false then
        local dropPoint = GetSafeDescentPosition(
            targetPosition,
            math.max(
                descendHeight,
                tonumber(State.FarmPickupApproachHeight) or 6
            )
        )

        if not dropPoint then
            ok = false
        else
            SetFarmPhase("Aproximando / noclip ON")
            ok = FarmFlightSegment(
                dropPoint,
                math.min(
                    speed or State.FarmFlightSpeed,
                    160
                ),
                2.8,
                true
            )
        end
    end

    if ok and descend ~= false and FarmIsRunning() then
        task.wait(math.clamp(tonumber(State.FarmArrivalPause) or 0.35, 0.10, 0.80))
    end

    -- O voo termina aqui. Só depois de realmente parar restauramos a colisão.
    StopFarmNoclip()
    DestroyFarmFlightMovers()
    SetFarmPhase(ok and "Parado / colisão ativa" or "Voo interrompido / colisão ativa")

    -- Depois da descida, ainda deixamos o personagem um frame estabilizar com
    -- colisão normal antes de qualquer interação com ovo/base.
    if ok and FarmIsRunning() then
        RunService.Heartbeat:Wait()
    end

    return ok
end

--============================================================--
-- FARM ENGINE
--============================================================--

local FarmBusy = false
local PickupBusy = false

FarmIsRunning = function()
    return Running and State.AutoFarm
end

local function FarmStatus(message)
    LastFarmStatus = tostring(message)
end

local function SetFarmPhase(phase)
    State.FarmPhase = tostring(phase)
    LastFarmStatus = State.FarmPhase
end

local function ClearFarmTarget()
    State.FarmTargetUID = nil
    State.FarmTargetName = nil
    State.FarmTargetPosition = nil
    State.FarmTargetRetries = 0
end

local function GetBasketCount()
    local basket = LocalPlayer:FindFirstChild("Basket")
    if not basket then
        return 0
    end

    return #basket:GetChildren()
end

local function SafeTeleport(position, offset)
    local character, root = GetCharacter()

    if not character or not root or typeof(position) ~= "Vector3" then
        return false
    end

    local finalPosition = position + (offset or Vector3.zero)

    return pcall(function()
        root.CFrame = CFrame.new(finalPosition) * root.CFrame.Rotation
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function FindPromptOnEgg(candidate)
    local model = candidate and candidate.Rendered

    if not model or not model.Parent then
        return nil
    end

    local ok, prompt = pcall(function()
        return model:FindFirstChildWhichIsA("ProximityPrompt", true)
    end)

    if ok then
        return prompt
    end

    return nil
end

local function ConfirmPickup(candidate, beforeCount, timeout)
    local deadline = os.clock() + (timeout or 2)

    while FarmIsRunning() and os.clock() < deadline do
        if not candidate then
            return false
        end

        if GetBasketCount() > beforeCount then
            return true
        end

        if candidate.Rendered and not candidate.Rendered.Parent then
            return true
        end

        if candidate.Instance and not candidate.Instance.Parent then
            return true
        end

        task.wait(0.05)
    end

    return false
end

local function GetLiveActiveEgg(uid)
    local activeEggs = GetActiveEggFolder()
    if not activeEggs or not uid then
        return nil
    end

    return activeEggs:FindFirstChild(uid)
end

local function ConfirmFarmPickup(candidate, beforeBasket, timeout)
    local deadline = os.clock() + (timeout or 2)

    while FarmIsRunning() and os.clock() < deadline do
        if GetBasketCount() > beforeBasket then
            return true
        end

        if candidate and candidate.UID
            and not GetLiveActiveEgg(candidate.UID) then
            return true
        end

        task.wait(0.05)
    end

    return false
end

local function TryRemotePickup(candidate)
    local remote = GetEggPickupRemote()

    if not remote or not remote:IsA("RemoteEvent") then
        return false
    end

    local uid = candidate and (candidate.UID or candidate.ID)
    if not uid then
        return false
    end

    local beforeBasket = GetBasketCount()

    local ok = pcall(function()
        remote:FireServer(uid)
    end)

    if not ok then
        return false
    end

    return ConfirmFarmPickup(candidate, beforeBasket, 2)
end

local function FindPromptOnEgg(candidate)
    local model = candidate and candidate.Rendered
    if not model or not model.Parent then
        return nil
    end

    return model:FindFirstChildWhichIsA("ProximityPrompt", true)
end

local function TryPromptPickup(candidate)
    if type(fireproximityprompt) ~= "function" then
        return false
    end

    local prompt = FindPromptOnEgg(candidate)
    if not prompt then
        return false
    end

    local beforeBasket = GetBasketCount()

    local ok = pcall(function()
        fireproximityprompt(prompt)
    end)

    if not ok then
        return false
    end

    return ConfirmFarmPickup(candidate, beforeBasket, 2)
end

local function AttemptPickup(candidate)
    if not candidate then
        return false
    end

    local retries = math.clamp(
        math.floor(tonumber(State.FarmPickupRetries) or 5),
        1,
        10
    )

    local mode = State.FarmPickupMode
    local profile = State.FarmEngineProfile

    for _ = 1, retries do
        if not FarmIsRunning() then
            return false
        end

        -- Recupera o UID real perto do RenderedEgg quando a seleção veio do fallback.
        if candidate.Synthetic or not candidate.UID then
            local recovered = candidate.Position and FindActiveEggNear(candidate.Position, 24)
            if recovered then
                candidate.UID = recovered.Name
                candidate.ID = recovered.Name
                candidate.Instance = recovered
                candidate.Synthetic = false
            end
        end

        local remoteFirst = mode == "Remote"
            or (mode == "Auto" and profile ~= "Prompt Priority")

        local promptFirst = mode == "Prompt"
            or (mode == "Auto" and (profile == "Prompt Priority" or profile == "Max Confiável 2026" or profile == "Rendered Eggs"))

        if remoteFirst and State.FarmRemoteFallback then
            if TryRemotePickup(candidate) then
                return true
            end
        end

        if promptFirst or State.FarmPromptFallback then
            if TryPromptPickup(candidate) then
                return true
            end
        end

        -- Mesmo quando o modo está em Remote, o perfil Hybrid tenta Prompt como
        -- segundo mecanismo para não travar quando só o RenderedEgg possui prompt.
        if mode == "Remote" and State.FarmRemoteFallback and State.FarmPromptFallback then
            if TryPromptPickup(candidate) then
                return true
            end
        end

        local liveUID = candidate.UID or candidate.ID
        if liveUID and not GetLiveActiveEgg(liveUID) then
            return true
        end

        task.wait(math.max(0.05, tonumber(State.FarmPickupWait) or 0.20))
    end

    return false
end

local VOLCANO_FALLBACK = Vector3.new(
    -4924.9033203125,
    41287.4609375,
    -3700.96435546875
)

local function EnterVolcano()
    if not FarmIsRunning() then
        return false
    end

    if IsInVolcano() then
        return true
    end

    local volcano = workspace:FindFirstChild("Volcano")
    local entrance = volcano and volcano:FindFirstChild("VolcanoEntrance")
    local validate = volcano and volcano:FindFirstChild("VolcanoValidate")

    if entrance and entrance:IsA("BasePart") then
        if not FarmFlyTo(
            entrance.Position,
            math.min(State.FarmFlightSpeed, 700),
            false
        ) then
            return false
        end
    else
        if not FarmFlyTo(
            VOLCANO_FALLBACK,
            math.min(State.FarmFlightSpeed, 500),
            false
        ) then
            return false
        end
    end

    task.wait(0.25)

    if not FarmIsRunning() then
        return false
    end

    if not IsInVolcano() and validate and validate:IsA("BasePart") then
        if not FarmFlyTo(
            validate.Position,
            math.min(State.FarmFlightSpeed, 350),
            true
        ) then
            return false
        end
    elseif not IsInVolcano() then
        if not FarmFlyTo(
            VOLCANO_FALLBACK,
            math.min(State.FarmFlightSpeed, 350),
            true
        ) then
            return false
        end
    end

    local deadline = os.clock() + 3

    while FarmIsRunning() and os.clock() < deadline do
        if IsInVolcano() then
            return true
        end
        task.wait(0.1)
    end

    return IsInVolcano()
end

local function ReturnFromVolcanoToPlot()
    if not FarmIsRunning() then
        return false
    end

    local volcano = workspace:FindFirstChild("Volcano")
    local validate = volcano and volcano:FindFirstChild("VolcanoValidate")

    if IsInVolcano() then
        if validate and validate:IsA("BasePart") then
            FarmFlyTo(
                validate.Position,
                math.min(State.FarmFlightSpeed, 300),
                true
            )
            task.wait(0.25)
        else
            FarmFlyTo(
                VOLCANO_FALLBACK,
                math.min(State.FarmFlightSpeed, 300),
                true
            )
            task.wait(0.25)
        end
    end

    return true
end

local function FarmMoveTo(position)
    if typeof(position) ~= "Vector3" then
        return false
    end

    if not FarmIsRunning() then
        return false
    end

    -- Auto Farm não usa mais SafeTeleport/Instant.
    -- Sempre sobe, voa até a coluna do ovo e desce perto dele.
    return FarmFlyTo(
        position,
        State.FarmFlightSpeed,
        true
    )
end

local function ReturnToPlotForFarm()
    if not FarmIsRunning() then
        return false
    end

    local plot = GetMyPlot()
    if not plot then
        return false
    end

    local ok, pivot = pcall(function()
        return plot:GetPivot()
    end)

    if not ok or not pivot then
        return false
    end

    -- Depois de coletar, sobe novamente e volta voando.
    return FarmFlyTo(
        pivot.Position,
        State.FarmFlightSpeed,
        true
    )
end

local function GetPlotHoverPosition()
    local plot = GetMyPlot()
    if not plot then
        return nil
    end

    local ok, pivot = pcall(function()
        return plot:GetPivot()
    end)

    if not ok or not pivot then
        return nil
    end

    return pivot.Position + Vector3.new(
        0,
        math.clamp(
            tonumber(State.FarmHoverHeight) or 55,
            25,
            150
        ),
        0
    )
end

local function HoverAbovePlot()
    if not FarmIsRunning() then
        return false
    end

    local hoverPosition = GetPlotHoverPosition()
    if not hoverPosition then
        return false
    end

    local _, root = GetCharacter()
    if not root then
        return false
    end

    local hoverRadius = math.clamp(
        tonumber(State.FarmHoverRadius) or 18,
        8,
        40
    )

    if (root.Position - hoverPosition).Magnitude <= hoverRadius then
        SetFarmPhase("Hovering at base")
        return true
    end

    SetFarmPhase("Returning to base")
    return FarmFlyTo(
        hoverPosition,
        State.FarmFlightSpeed,
        false
    )
end

local function GetBaseRoutePoints()
    local plot = GetMyPlot()
    if not plot then
        return nil
    end

    local baseplate = plot:FindFirstChild("Baseplate")
    if not baseplate or not baseplate:IsA("BasePart") then
        return nil
    end

    local _, root = GetCharacter()
    if not root then
        return nil
    end

    local cf = baseplate.CFrame
    local size = baseplate.Size
    local halfX = math.max(4, size.X * 0.5)
    local halfZ = math.max(4, size.Z * 0.5)
    local topY = baseplate.Position.Y + (size.Y * 0.5)

    local localRoot = cf:PointToObjectSpace(root.Position)
    local useX = math.abs(localRoot.X) >= math.abs(localRoot.Z)
    local sideSign
    local sideAxisSize

    if useX then
        sideSign = localRoot.X >= 0 and 1 or -1
        sideAxisSize = halfX
        if math.abs(localRoot.X) < 2 then
            sideSign = -1
        end
    else
        sideSign = localRoot.Z >= 0 and 1 or -1
        sideAxisSize = halfZ
        if math.abs(localRoot.Z) < 2 then
            sideSign = -1
        end
    end

    local sideOffset = math.clamp(
        tonumber(State.FarmBaseSideOffset) or 26,
        8,
        60
    )

    local sideHeight = math.clamp(
        tonumber(State.FarmBaseSideHeight) or 6,
        3,
        15
    )

    local entryInset = math.clamp(
        tonumber(State.FarmBaseEntryInset) or 14,
        4,
        math.max(4, sideAxisSize - 3)
    )

    local entryHeight = math.clamp(
        tonumber(State.FarmBaseEntryHeight) or 7,
        3,
        15
    )

    local hoverHeight = math.clamp(
        tonumber(State.FarmHoverHeight) or 55,
        20,
        150
    )

    local sideLocal
    local entryLocal

    if useX then
        sideLocal = Vector3.new(sideSign * (halfX + sideOffset), 0, 0)
        entryLocal = Vector3.new(sideSign * math.max(0, halfX - entryInset), 0, 0)
    else
        sideLocal = Vector3.new(0, 0, sideSign * (halfZ + sideOffset))
        entryLocal = Vector3.new(0, 0, sideSign * math.max(0, halfZ - entryInset))
    end

    local sideGround = cf:PointToWorldSpace(sideLocal + Vector3.new(0, topY - cf.Position.Y + sideHeight, 0))
    local sideAir = Vector3.new(sideGround.X, topY + hoverHeight, sideGround.Z)
    local entryPoint = cf:PointToWorldSpace(entryLocal + Vector3.new(0, topY - cf.Position.Y + entryHeight, 0))

    return {
        Plot = plot,
        Baseplate = baseplate,
        SideAir = sideAir,
        SideGround = sideGround,
        EntryPoint = entryPoint,
        TopY = topY,
    }
end

local function IsInsideMyPlot(position)
    if typeof(position) ~= "Vector3" then
        return false
    end

    local route = GetBaseRoutePoints()
    if not route or not route.Baseplate then
        return false
    end

    local localPosition = route.Baseplate.CFrame:PointToObjectSpace(position)
    local margin = 2.5
    return math.abs(localPosition.X) <= (route.Baseplate.Size.X * 0.5) - margin
        and math.abs(localPosition.Z) <= (route.Baseplate.Size.Z * 0.5) - margin
end

local function ConfirmPlotEntry(timeout)
    local deadline = os.clock() + math.clamp(
        tonumber(timeout) or State.FarmBaseConfirmTimeout or 2.5,
        0.5,
        5.0
    )

    while FarmIsRunning() and os.clock() < deadline do
        local _, root = GetCharacter()
        if root and IsInsideMyPlot(root.Position) then
            return true
        end
        task.wait(0.08)
    end

    local _, root = GetCharacter()
    return root and IsInsideMyPlot(root.Position) or false
end

local function GetNestWorldPosition(nest)
    if not nest or not nest.Parent then
        return nil
    end

    local ok, pivot = pcall(function()
        return nest:GetPivot()
    end)

    if ok and pivot then
        return pivot.Position
    end

    if nest:IsA("BasePart") then
        return nest.Position
    end

    local part = nest:FindFirstChildWhichIsA("BasePart", true)
    if part then
        return part.Position
    end

    return nil
end

local function ResolveFarmTarget(uid, fallbackName)
    if not uid then
        return nil
    end

    local active = GetActiveEggFolder()
    local live = active and active:FindFirstChild(uid)

    if live then
        local eggName = live:GetAttribute("Egg")
        if type(eggName) ~= "string" or eggName == "" then
            eggName = fallbackName or live.Name
        end

        local position = live:GetAttribute("Position")
        if typeof(position) == "CFrame" then
            position = position.Position
        end
        if typeof(position) ~= "Vector3" then
            position = GetEggPosition(live)
        end
        if not position then
            return nil
        end

        return {
            Instance = live,
            UID = live.Name,
            ID = live.Name,
            Name = eggName,
            Position = position,
            Distance = 0,
            Weight = GetEggWeight(live) or 0,
            Luck = GetEggLuck(live) or 0,
            Mutation = GetEggMutation(live),
            Rarity = GetEggRarity(eggName, live),
            Synthetic = false,
        }
    end

    -- Fallback visual: se o UID servidor ainda não estiver disponível, usa
    -- RenderedEggs para manter o voo/coleta funcionando e tenta recuperar o
    -- Configuration real imediatamente antes do pickup.
    if State.FarmRenderedFallback then
        local rendered = GetRenderedEggFolder()
        if rendered then
            for _, model in ipairs(rendered:GetChildren()) do
                local position = GetEggPosition(model)
                local eggName = GetRealRenderedEggName(model)
                if position and (model.Name == uid or uid == tostring(model:GetDebugId()))
                    and type(eggName) == "string" and EggData[eggName] then
                    local activeNear = FindActiveEggNear(position, 22)
                    local realUID = activeNear and activeNear.Name or model.Name
                    local source = activeNear or model
                    return {
                        Instance = source,
                        Rendered = model,
                        UID = realUID,
                        ID = realUID,
                        Name = eggName,
                        Position = position,
                        Distance = 0,
                        Weight = GetEggWeight(source) or 0,
                        Luck = GetEggLuck(source) or 0,
                        Mutation = GetEggMutation(source),
                        Rarity = GetEggRarity(eggName, source),
                        Synthetic = activeNear == nil,
                    }
                end
            end
        end
    end

    return nil
end

local function ChooseAndCommitFarmTarget()
    local candidates = GetFarmCandidates()
    local target = SelectBestFarmCandidate(candidates)

    if not target then
        return nil
    end

    State.FarmTargetUID = target.UID
    State.FarmTargetName = target.Name
    State.FarmTargetPosition = target.Position
    State.FarmTargetRetries = 0

    return target
end

local function GetCurrentFarmTarget()
    if not State.FarmTargetUID then
        return nil
    end

    local target = ResolveFarmTarget(
        State.FarmTargetUID,
        State.FarmTargetName
    )

    if target then
        State.FarmTargetName = target.Name
        State.FarmTargetPosition = target.Position
    end

    return target
end

local function FailCurrentFarmTarget(message, cooldown)
    local uid = State.FarmTargetUID

    if uid then
        FailedFarmTargets[uid] = os.clock() + (cooldown or 5)
    end

    ClearFarmTarget()
    SetFarmPhase(message or "Changing target")
end

function FarmUtil.FireEggPlaced(nestName)
    local remote = GetEggPlacedRemote()
    if not remote or not remote:IsA("RemoteEvent") then
        return false
    end

    return pcall(function()
        remote:FireServer({NestId = tostring(nestName)})
    end)
end

function FarmUtil.EquipEggTool(tool)
    local character, humanoid = GetCharacter()
    if not character or not humanoid or not tool or not tool.Parent then
        return false
    end

    return pcall(function()
        humanoid:EquipTool(tool)
    end)
end

function FarmUtil.CopyCountMap(source)
    local copy = {}
    if type(source) ~= "table" then
        return copy
    end
    for name, count in pairs(source) do
        local n = tonumber(count) or 0
        if n > 0 then
            copy[name] = math.floor(n)
        end
    end
    return copy
end

function FarmUtil.CountPendingTools(expected, beforeTools)
    local found = {}
    for _, tool in ipairs(FarmUtil.GetEggTools()) do
        if (not beforeTools or not beforeTools[tool]) and expected[tool.Name] then
            found[tool.Name] = (found[tool.Name] or 0) + 1
        end
    end
    return found
end

function FarmUtil.PlaceEggToolsInNests(expected, beforeTools)
    local remaining = FarmUtil.CopyCountMap(expected)
    local deadline = os.clock() + math.clamp(
        tonumber(State.FarmNestWait) or 8.0,
        2.0,
        20.0
    )

    while FarmIsRunning() and os.clock() < deadline do
        local nests = FarmUtil.GetFreeNests()
        local available = FarmUtil.CountPendingTools(remaining, beforeTools)

        local hasRemaining = false
        for _, count in pairs(remaining) do
            if count > 0 then
                hasRemaining = true
                break
            end
        end

        if not hasRemaining then
            State.FarmPendingEggs = {}
            return true
        end

        if #nests > 0 then
            for _, nest in ipairs(nests) do
                if not FarmIsRunning() then
                    return false
                end

                local tool = nil
                for _, candidate in ipairs(FarmUtil.GetEggTools()) do
                    if (not beforeTools or not beforeTools[candidate]) and remaining[candidate.Name]
                        and remaining[candidate.Name] > 0 then
                        tool = candidate
                        break
                    end
                end

                if not tool then
                    break
                end

                local nestPosition = GetNestWorldPosition(nest)
                if not nestPosition then
                    continue
                end
                local safeNestPosition = GetSafeDescentPosition(
                    nestPosition,
                    math.max(3, tonumber(State.FarmNestApproachHeight) or 6)
                )
                if safeNestPosition then
                    nestPosition = safeNestPosition
                end

                SetFarmPhase("Indo até o ninho " .. tostring(nest.Name))
                local nestTarget = Vector3.new(
                    nestPosition.X,
                    nestPosition.Y,
                    nestPosition.Z
                )
                if not FarmFlyTo(
                    nestTarget,
                    math.clamp(tonumber(State.FarmNestApproachSpeed) or 100, 60, 180),
                    true
                ) then
                    return false
                end

                if not FarmIsRunning() then
                    return false
                end

                SetFarmPhase("Equipando " .. tostring(tool.Name) .. " no ninho " .. tostring(nest.Name))

                if not FarmUtil.EquipEggTool(tool) then
                    return false
                end

                task.wait(0.15)

                if not FarmIsRunning() then
                    return false
                end

                if not FarmUtil.FireEggPlaced(nest.Name) then
                    return false
                end

                local placed = false
                local confirmDeadline = os.clock() + 4

                while FarmIsRunning() and os.clock() < confirmDeadline do
                    local occupied = nest:GetAttribute("Occupied") == true
                    local stillInTools = false

                    for _, currentTool in ipairs(FarmUtil.GetEggTools()) do
                        if currentTool == tool then
                            stillInTools = true
                            break
                        end
                    end

                    if occupied or not stillInTools then
                        placed = true
                        break
                    end

                    task.wait(0.10)
                end

                if not placed then
                    State.FarmPendingEggs = FarmUtil.CopyCountMap(remaining)
                    SetFarmPhase("Depósito não confirmado")
                    return false
                end

                remaining[tool.Name] = math.max(0, (remaining[tool.Name] or 1) - 1)
                if remaining[tool.Name] <= 0 then
                    remaining[tool.Name] = nil
                end

                task.wait(math.clamp(
                    tonumber(State.FarmBasePause) or 2.50,
                    0.50,
                    5.0
                ))
            end
        end

        State.FarmPendingEggs = FarmUtil.CopyCountMap(remaining)
        task.wait(math.clamp(tonumber(State.FarmNestPoll) or 0.25, 0.10, 0.75))
    end

    State.FarmPendingEggs = FarmUtil.CopyCountMap(remaining)
    return next(remaining) == nil
end

local function FarmDeposit()
    if not FarmIsRunning() then
        return false
    end

    local route = GetBaseRoutePoints()
    if not route then
        SetFarmPhase("Base não encontrada")
        return false
    end

    local expected = FarmUtil.GetBasketEggNames()
    if next(expected) == nil then
        expected = FarmUtil.CopyCountMap(State.FarmPendingEggs)
    end

    if next(expected) == nil then
        return GetBasketCount() <= 0
    end

    local beforeTools = FarmUtil.SnapshotEggTools()

    -- ETAPA 1: chega acima do lado da base usando a velocidade de cruzeiro.
    SetFarmPhase("Voltando para a base • acima do lado")
    if not FarmFlyTo(
        route.SideAir,
        math.clamp(tonumber(State.FarmFlightSpeed) or 300, 50, 350),
        false
    ) then
        return false
    end

    if not FarmIsRunning() then
        return false
    end

    -- ETAPA 2: desce do lado da base, fora do plot, sem mergulhar no centro.
    SetFarmPhase("Descendo ao lado da base")
    if not FarmFlyTo(
        route.SideGround,
        math.clamp(tonumber(State.FarmBaseApproachSpeed) or 140, 60, 220),
        true
    ) then
        return false
    end

    if not FarmIsRunning() then
        return false
    end

    task.wait(math.clamp(
        tonumber(State.FarmBaseSidePause) or 0.60,
        0.20,
        2.0
    ))

    if not FarmIsRunning() then
        return false
    end

    -- ETAPA 3: entra fisicamente no plot a partir do lado escolhido.
    SetFarmPhase("Entrando no plot")
    if not FarmFlyTo(
        route.EntryPoint,
        math.clamp(tonumber(State.FarmBaseEntrySpeed) or 110, 60, 180),
        true
    ) then
        return false
    end

    if not FarmIsRunning() then
        return false
    end

    -- Confirma que realmente cruzamos o limite do Baseplate.
    if not ConfirmPlotEntry(State.FarmBaseConfirmTimeout) then
        SetFarmPhase("Entrada do plot não confirmada")

        -- Uma única reaproximação controlada para corrigir a entrada.
        if not FarmFlyTo(
            route.EntryPoint,
            math.clamp(tonumber(State.FarmBaseEntrySpeed) or 110, 60, 180),
            true
        ) then
            return false
        end

        if not ConfirmPlotEntry(1.5) then
            SetFarmPhase("Falha ao entrar no plot")
            return false
        end
    end

    SetFarmPhase("Dentro do plot • confirmando")
    task.wait(math.clamp(
        tonumber(State.FarmBaseEntryPause) or 0.80,
        0.20,
        2.0
    ))

    if not FarmIsRunning() then
        return false
    end

    -- ETAPA 4: espera a Basket ser convertida pelo jogo nos EggTools.
    SetFarmPhase("Confirmando ovo na base")
    local returned = FarmUtil.WaitForReturnedEggTools(
        expected,
        beforeTools,
        math.clamp(tonumber(State.FarmDepositWait) or 3.50, 2.0, 8.0)
    )

    if not returned and GetBasketCount() > 0 then
        -- Não cria uma nova rota: somente revalida a posição interna uma vez.
        SetFarmPhase("Reconfirmando ovo dentro da base")
        local _, root = GetCharacter()
        if not root or not IsInsideMyPlot(root.Position) then
            if not FarmFlyTo(route.EntryPoint, 100, true) then
                return false
            end
        end

        task.wait(math.clamp(
            tonumber(State.FarmBaseEntryPause) or 0.80,
            0.20,
            2.0
        ))

        returned = FarmUtil.WaitForReturnedEggTools(
            expected,
            beforeTools,
            math.clamp(tonumber(State.FarmDepositWait) or 3.50, 2.0, 8.0)
        )
    end

    if not returned and GetBasketCount() > 0 then
        SetFarmPhase("Ovo ainda não chegou à base")
        return false
    end

    State.FarmPendingEggs = FarmUtil.CopyCountMap(expected)

    -- ETAPA 5: procura um ninho livre e vai fisicamente até ele antes do Remote.
    SetFarmPhase("Procurando ninho livre")
    local placed = FarmUtil.PlaceEggToolsInNests(expected, beforeTools)

    if not placed then
        SetFarmPhase("Aguardando ninho livre")
        return false
    end

    -- ETAPA 6: só libera o próximo ciclo quando a entrega estiver limpa.
    if GetBasketCount() <= 0 and next(State.FarmPendingEggs) == nil then
        SetFarmPhase("Ovo entregue • próximo alvo")
        return true
    end

    SetFarmPhase("Entrega não confirmada")
    return false
end

local function FarmOnce()
    if not FarmIsRunning() or FarmBusy then
        return
    end

    FarmBusy = true

    local ok = pcall(function()
        if not FarmIsRunning() then
            return
        end

        -- HOLDING / PENDING DELIVERY
        if GetBasketCount() > 0 or next(State.FarmPendingEggs) ~= nil then
            SetFarmPhase(GetBasketCount() > 0 and "Carrying egg" or "Pending egg delivery")

            if State.ReturnToPlot then
                FarmDeposit()
            end

            return
        end

        -- MOUNT
        -- Tenta montar o pet quando habilitado, mas não trava o farm por isso.
        if State.AutoMountPet and not IsRidingPet() then
            SetFarmPhase("Mounting pet")

            local mounted = MountBestPet()

            if not mounted and not IsRidingPet() then
                if State.FarmRequireMountedPet then
                    FarmStatus("Waiting for a usable pet")
                    return
                else
                    FarmStatus("Pet não montado - continuando")
                end
            else
                task.wait(0.25)
            end
        end

        if not FarmIsRunning() then
            return
        end

        -- SELECT
        local target = GetCurrentFarmTarget()

        if not target then
            SetFarmPhase("Scanning eggs")
            target = ChooseAndCommitFarmTarget()

            if not target then
                SetFarmPhase("No target - hovering")
                HoverAbovePlot()
                task.wait(math.clamp(
                    tonumber(State.FarmNoTargetDelay) or 1.00,
                    0.25,
                    5.00
                ))
                return
            end
        end

        -- SPECIAL AREA
        local volcanic = string.lower(target.Name) == "volcanic egg"

        if volcanic and State.VolcanicSupport then
            if not IsInVolcano() then
                SetFarmPhase("Entering volcano")

                if not EnterVolcano() then
                    FailCurrentFarmTarget("Volcano entry failed", 4)
                    return
                end

                return
            end
        elseif IsInVolcano() then
            SetFarmPhase("Leaving volcano")
            ReturnFromVolcanoToPlot()
            return
        end

        if not FarmIsRunning() then
            return
        end

        -- REVALIDATE POSITION
        local refreshed = GetCurrentFarmTarget()

        if not refreshed then
            FailCurrentFarmTarget("Target disappeared", 2)
            return
        end

        target = refreshed

        local _, root = GetCharacter()

        if not root then
            return
        end

        local distance = (target.Position - root.Position).Magnitude
        local pickupRadius = math.clamp(
            tonumber(State.FarmPickupRadius) or 20,
            8,
            30
        )

        -- FLY
        if distance > pickupRadius then
            SetFarmPhase("Flying to " .. tostring(target.Name))

            if not FarmFlyTo(
                target.Position,
                State.FarmFlightSpeed,
                true
            ) then
                FailCurrentFarmTarget("Flight failed", 4)
                return
            end

            return
        end

        -- FINAL REVALIDATION + PICKUP
        target = GetCurrentFarmTarget()

        if not target then
            FailCurrentFarmTarget("Target expired", 2)
            return
        end

        _, root = GetCharacter()

        if not root then
            return
        end

        distance = (target.Position - root.Position).Magnitude

        if distance > pickupRadius then
            SetFarmPhase("Target moved")
            return
        end

        SetFarmPhase("Aproximação final: " .. tostring(target.Name))

        -- Nunca tenta coletar de dentro do chão. Faz uma microaproximação
        -- vertical segura e bem mais lenta antes de disparar o pickup.
        local pickupPoint = GetSafeDescentPosition(
            target.Position,
            math.max(
                tonumber(State.FarmPickupApproachHeight) or 6,
                6
            )
        )

        if pickupPoint and (root.Position - pickupPoint).Magnitude > 4 then
            if not FarmFlyTo(pickupPoint, 120, true) then
                FailCurrentFarmTarget("Falha na aproximação do ovo", 3)
                return
            end

            _, root = GetCharacter()
            if not root then
                return
            end
        end

        SetFarmPhase("Collecting " .. tostring(target.Name))
        task.wait(math.clamp(tonumber(State.FarmPickupPause) or 0.45, 0.20, 1.00))

        -- Revalida o alvo imediatamente antes do remote.
        local liveBeforePickup = GetCurrentFarmTarget()
        if not liveBeforePickup then
            FailCurrentFarmTarget("Target expired antes da coleta", 2)
            return
        end
        target = liveBeforePickup

        local picked = AttemptPickup({
            UID = target.UID,
            ID = target.UID,
            Name = target.Name,
            Instance = target.Instance,
            Rendered = target.Rendered,
        })

        -- Uma tentativa de microaproximação é melhor que ficar repetindo
        -- o remote sem estar na distância física correta.
        if not picked and State.FarmPickupRetryApproach then
            SetFarmPhase("Reaproximando para coletar")

            local retryPoint = GetSafeDescentPosition(target.Position, 5)
            if retryPoint and FarmFlyTo(retryPoint, 90, true) then
                task.wait(0.30)
                picked = AttemptPickup({
                    UID = target.UID,
                    ID = target.UID,
                    Name = target.Name,
                    Instance = target.Instance,
                    Rendered = target.Rendered,
                })
            end
        end

        if not picked then
            State.FarmTargetRetries =
                State.FarmTargetRetries + 1

            if State.FarmTargetRetries >= 3 then
                FailCurrentFarmTarget(
                    "Pickup failed - changing target",
                    6
                )
            else
                FarmStatus(
                    "Pickup retry " ..
                    tostring(State.FarmTargetRetries)
                )
            end

            return
        end

        FailedFarmTargets[target.UID] = nil

        -- CONFIRM CARRY
        local deadline = os.clock() + 2

        while FarmIsRunning()
            and os.clock() < deadline
            and GetBasketCount() <= 0 do

            task.wait(0.05)
        end

        if GetBasketCount() <= 0 then
            FailCurrentFarmTarget("Pickup not confirmed", 5)
            return
        end

        ClearFarmTarget()

        -- DEPOSIT
        if State.ReturnToPlot then
            task.wait(math.clamp(tonumber(State.FarmPickupPause) or 0.30, 0.10, 0.80))
            FarmDeposit()
        else
            SetFarmPhase("Collected")
        end
    end)

    FarmBusy = false

    if not ok and FarmIsRunning() then
        ClearFarmTarget()
        SetFarmPhase("Farm recovered from error")
        task.wait(
            math.max(
                0.15,
                tonumber(State.FarmRetryDelay) or 0.30
            )
        )
    end
end

local function AutoPickupOnce()
    if not Running or not State.AutoPickup or PickupBusy or State.AutoFarm then
        return
    end

    PickupBusy = true

    pcall(function()
        local candidates = GetCandidates()
        local target = SelectBestCandidate(candidates)

        if not target then
            return
        end

        if target.Distance > math.clamp(
            tonumber(State.FarmPickupRadius) or 12,
            5,
            30
        ) then
            return
        end

        AttemptPickup(target)
    end)

    PickupBusy = false
end

--============================================================--
-- SPEED
--============================================================--

local SpeedConnection = nil

local function StopSpeed()
    State.SpeedEnabled = false

    if SpeedConnection then
        pcall(function()
            SpeedConnection:Disconnect()
        end)
        SpeedConnection = nil
    end
end

local function StartSpeed()
    if SpeedConnection then
        State.SpeedEnabled = true
        return
    end

    State.SpeedEnabled = true

    SpeedConnection = Track(RunService.RenderStepped:Connect(function()
        if not Running or not State.SpeedEnabled then
            return
        end

        local character, root = GetCharacter()
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")

        if not character or not root or not humanoid then
            return
        end

        local direction = humanoid.MoveDirection
        if direction.Magnitude <= 0 then
            return
        end

        pcall(function()
            character:TranslateBy(
                direction * (State.WalkSpeed / 135)
            )
        end)
    end))
end

--============================================================--
-- NOCOLIP / INFINITE JUMP / ANTI AFK
--============================================================--

local NoclipConnection = nil
local InfiniteJumpConnection = nil
local AntiAFKConnection = nil

local function RestoreNoclip()
    for part, original in pairs(NoclipOriginal) do
        if part and part.Parent then
            pcall(function()
                part.CanCollide = original
            end)
        end
    end
    table.clear(NoclipOriginal)
end

local function StopNoclip()
    State.Noclip = false

    if NoclipConnection then
        pcall(function()
            NoclipConnection:Disconnect()
        end)
        NoclipConnection = nil
    end

    RestoreNoclip()
end

local function StartNoclip()
    if NoclipConnection then
        State.Noclip = true
        return
    end

    State.Noclip = true

    NoclipConnection = Track(RunService.Stepped:Connect(function()
        if not Running or not State.Noclip then
            return
        end

        local character = LocalPlayer.Character
        if not character then
            return
        end

        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                if NoclipOriginal[part] == nil then
                    NoclipOriginal[part] = part.CanCollide
                end
                part.CanCollide = false
            end
        end
    end))
end

local function StopInfiniteJump()
    State.InfiniteJump = false
    if InfiniteJumpConnection then
        pcall(function()
            InfiniteJumpConnection:Disconnect()
        end)
        InfiniteJumpConnection = nil
    end
end

local function StartInfiniteJump()
    if InfiniteJumpConnection then
        State.InfiniteJump = true
        return
    end

    State.InfiniteJump = true

    InfiniteJumpConnection = Track(UserInputService.JumpRequest:Connect(function()
        if not Running or not State.InfiniteJump then
            return
        end

        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end))
end

local function StopAntiAFK()
    State.AntiAFK = false
    if AntiAFKConnection then
        pcall(function()
            AntiAFKConnection:Disconnect()
        end)
        AntiAFKConnection = nil
    end
end

local function StartAntiAFK()
    if AntiAFKConnection then
        State.AntiAFK = true
        return
    end

    State.AntiAFK = true

    AntiAFKConnection = Track(LocalPlayer.Idled:Connect(function()
        if not Running or not State.AntiAFK then
            return
        end

        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end))
end

--============================================================--
-- FLY
--============================================================--

local FlyConnection = nil

local function DestroyFlyMovers()
    if CurrentFlyVelocity then
        pcall(function() CurrentFlyVelocity:Destroy() end)
        CurrentFlyVelocity = nil
    end

    if CurrentFlyGyro then
        pcall(function() CurrentFlyGyro:Destroy() end)
        CurrentFlyGyro = nil
    end
end

local function EnsureFlyMovers(root)
    if CurrentFlyVelocity and CurrentFlyVelocity.Parent == root
        and CurrentFlyGyro and CurrentFlyGyro.Parent == root then
        return true
    end

    DestroyFlyMovers()

    local ok, result = pcall(function()
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.Name = "MontarUmPetFlyVelocity"
        bodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        bodyVelocity.Velocity = Vector3.zero
        bodyVelocity.Parent = root

        local bodyGyro = Instance.new("BodyGyro")
        bodyGyro.Name = "MontarUmPetFlyGyro"
        bodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        bodyGyro.P = 50000
        bodyGyro.D = 1000
        bodyGyro.CFrame = root.CFrame
        bodyGyro.Parent = root

        CurrentFlyVelocity = bodyVelocity
        CurrentFlyGyro = bodyGyro
    end)

    return ok and CurrentFlyVelocity ~= nil and CurrentFlyGyro ~= nil
end

local function StopFly()
    State.Flying = false

    if FlyConnection then
        pcall(function()
            FlyConnection:Disconnect()
        end)
        FlyConnection = nil
    end

    DestroyFlyMovers()
end

local function StartFly()
    if FlyConnection then
        State.Flying = true
        return
    end

    local character, root = GetCharacter()
    if not character or not root then
        State.Flying = false
        return
    end

    if not EnsureFlyMovers(root) then
        State.Flying = false
        return
    end

    State.Flying = true

    FlyConnection = Track(RunService.RenderStepped:Connect(function()
        if not Running or not State.Flying then
            return
        end

        local currentCharacter, currentRoot = GetCharacter()
        if not currentCharacter or not currentRoot then
            return
        end

        if not EnsureFlyMovers(currentRoot) then
            return
        end

        local humanoid = currentCharacter:FindFirstChildOfClass("Humanoid")
        local camera = workspace.CurrentCamera
        if not humanoid or not camera then
            return
        end

        local direction = humanoid.MoveDirection
        local velocity = Vector3.zero

        if direction.Magnitude > 0 then
            velocity = direction.Unit * State.FlySpeed
        end

        CurrentFlyVelocity.Velocity = velocity

        pcall(function()
            local look = camera.CFrame.LookVector
            CurrentFlyGyro.CFrame = CFrame.lookAt(
                currentRoot.Position,
                currentRoot.Position + look
            )
        end)
    end))
end

--============================================================--
-- ESP DE OVOS
-- Criado apenas quando o recurso está ligado, para economizar memória.
-- Atualização visual em baixa frequência para Delta Mobile.
--============================================================--

local RarityColors = {
    Common = Color3.fromRGB(210, 210, 210),
    Rare = Color3.fromRGB(75, 150, 255),
    Epic = Color3.fromRGB(180, 90, 255),
    Legendary = Color3.fromRGB(255, 190, 50),
    Mythic = Color3.fromRGB(255, 90, 100),
    Ethereal = Color3.fromRGB(255, 120, 255),
    Divine = Color3.fromRGB(100, 255, 220),
    Unknown = Color3.fromRGB(255, 255, 255),
}

local EggNameCache = setmetatable({}, {__mode = "k"})
local RenderedEggsFolder = nil
local RenderedEggsConnectionA = nil
local RenderedEggsConnectionB = nil
local ESPRefreshPending = false

local function GetESPPart(model)
    if not model:IsA("Model") then
        return nil
    end

    if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
        return model.PrimaryPart
    end

    return model:FindFirstChildWhichIsA("BasePart", true)
end

local function GetRealEggName(model)
    local cached = EggNameCache[model]
    if cached then
        return cached
    end

    local result = model.Name
    local eggSpawns = workspace:FindFirstChild("EggSpawns", true)
    local part = GetESPPart(model)

    if eggSpawns and part then
        local bestDistance = 15
        for _, spawn in ipairs(eggSpawns:GetChildren()) do
            local spawnPart = spawn:FindFirstChildWhichIsA("BasePart", true)
            if spawnPart then
                local distance = (spawnPart.Position - part.Position).Magnitude
                if distance < bestDistance then
                    bestDistance = distance
                    result = spawn.Name
                end
            end
        end
    end

    EggNameCache[model] = result
    return result
end

local function ESPShouldShow(model, realName)
    if not State.ESPEnabled then
        return false
    end

    if State.ESPOnlySelected and CountSet(State.ESPSelectedEggs) > 0 then
        if not State.ESPSelectedEggs[realName] and not State.ESPSelectedEggs[model.Name] then
            return false
        end
    end

    if State.ESPOnlyMutated and not GetEggMutation(model) then
        return false
    end

    return true
end

local function CreateESP(model)
    if not Running or not State.ESPEnabled or not model:IsA("Model") or ESPObjects[model] then
        return
    end

    local part = GetESPPart(model)
    if not part then
        return
    end

    local realName = GetRealEggName(model)
    local rarity = GetEggRarity(realName, model)

    local highlight = Instance.new("Highlight")
    highlight.Name = "MontarUmPetESP"
    highlight.Adornee = model
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = 0.78
    highlight.OutlineTransparency = 0
    highlight.FillColor = RarityColors[rarity] or RarityColors.Unknown
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.Enabled = false
    highlight.Parent = model

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "MontarUmPetESP"
    billboard.Adornee = part
    billboard.Size = UDim2.fromOffset(250, 70)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = false
    billboard.Parent = part

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextColor3 = RarityColors[rarity] or Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Text = realName
    label.Parent = billboard

    ESPObjects[model] = {
        Part = part,
        Highlight = highlight,
        Billboard = billboard,
        Label = label,
        RealName = realName,
        Rarity = rarity,
        LastText = "",
    }
end

local function RemoveESP(model)
    local data = ESPObjects[model]
    if not data then
        return
    end

    if data.Billboard then
        pcall(function() data.Billboard:Destroy() end)
    end

    if data.Highlight then
        pcall(function() data.Highlight:Destroy() end)
    end

    ESPObjects[model] = nil
end

local function ClearAllESP()
    for model in pairs(ESPObjects) do
        RemoveESP(model)
    end
end

local function RefreshEggESP()
    if ESPRefreshPending then
        return
    end

    ESPRefreshPending = true

    task.defer(function()
        ESPRefreshPending = false

        if not Running or not State.ESPEnabled then
            ClearAllESP()
            return
        end

        if not RenderedEggsFolder or not RenderedEggsFolder.Parent then
            RenderedEggsFolder = workspace:FindFirstChild("RenderedEggs", true)
        end

        if not RenderedEggsFolder then
            return
        end

        for _, obj in ipairs(RenderedEggsFolder:GetDescendants()) do
            if obj:IsA("Model") then
                CreateESP(obj)
            end
        end
    end)
end

local function AttachRenderedEggs()
    local folder = workspace:FindFirstChild("RenderedEggs", true)

    if folder == RenderedEggsFolder then
        RefreshEggESP()
        return
    end

    if RenderedEggsConnectionA then
        RenderedEggsConnectionA:Disconnect()
        RenderedEggsConnectionA = nil
    end

    if RenderedEggsConnectionB then
        RenderedEggsConnectionB:Disconnect()
        RenderedEggsConnectionB = nil
    end

    ClearAllESP()
    RenderedEggsFolder = folder

    if not folder then
        return
    end

    RenderedEggsConnectionA = Track(folder.DescendantAdded:Connect(function(obj)
        if Running and State.ESPEnabled and obj:IsA("Model") then
            task.defer(function()
                if obj.Parent then
                    CreateESP(obj)
                end
            end)
        end
    end))

    RenderedEggsConnectionB = Track(folder.DescendantRemoving:Connect(function(obj)
        if ESPObjects[obj] then
            RemoveESP(obj)
        end
    end))

    RefreshEggESP()
end

local function SetEggESPEnabled(enabled)
    State.ESPEnabled = enabled

    if enabled then
        AttachRenderedEggs()
    else
        ClearAllESP()
    end
end

AttachRenderedEggs()

task.spawn(function()
    while Running do
        task.wait(2)

        if not Running then
            break
        end

        local currentFolder = workspace:FindFirstChild("RenderedEggs", true)

        if currentFolder ~= RenderedEggsFolder then
            AttachRenderedEggs()
        end
    end
end)

task.spawn(function()
    while Running do
        task.wait(0.50)

        if not Running then
            break
        end

        if not State.ESPEnabled then
            continue
        end

        local _, root = GetCharacter()
        if not root then
            continue
        end

        local rootPosition = root.Position

        for model, data in pairs(ESPObjects) do
            if not model.Parent or not data.Part or not data.Part.Parent then
                RemoveESP(model)
            else
                local distance = (rootPosition - data.Part.Position).Magnitude
                local show = ESPShouldShow(model, data.RealName)
                    and distance <= State.ESPMaxDistance

                data.Billboard.Enabled = show
                data.Highlight.Enabled = show

                if show then
                    local parts = {data.RealName}

                    if State.ESPShowRarity then
                        table.insert(parts, "[" .. tostring(data.Rarity) .. "]")
                    end

                    if State.ESPShowWeight then
                        local weight = GetEggWeight(model)
                        if weight then
                            table.insert(parts, string.format("KG %.1f", weight))
                        end
                    end

                    if State.ESPShowLuck then
                        local luck = GetEggLuck(model)
                        if luck then
                            table.insert(parts, string.format("Luck %.1f", luck))
                        end
                    end

                    if State.ESPShowMutation then
                        local mutation = GetEggMutation(model)
                        if mutation then
                            table.insert(parts, tostring(mutation))
                        end
                    end

                    if State.ESPShowDistance then
                        table.insert(parts, string.format("%d studs", math.floor(distance)))
                    end

                    local textValue = table.concat(parts, " • ")
                    if textValue ~= data.LastText then
                        data.Label.Text = textValue
                        data.LastText = textValue
                    end
                end
            end
        end
    end
end)

--============================================================--
-- PLAYER ESP + HIDE PLAYERS
--============================================================--

local function RemovePlayerESP(player)
    local data = PlayerESPObjects[player]
    if not data then
        return
    end

    if data.Highlight then
        pcall(function() data.Highlight:Destroy() end)
    end

    if data.Billboard then
        pcall(function() data.Billboard:Destroy() end)
    end

    PlayerESPObjects[player] = nil
end

local function CreatePlayerESP(player)
    if player == LocalPlayer or not State.PlayerESP or PlayerESPObjects[player] then
        return
    end

    local character = player.Character
    if not character then
        return
    end

    local head = character:FindFirstChild("Head")
    if not head then
        return
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "MontarUmPetPlayerESP"
    highlight.Adornee = character
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = 0.82
    highlight.OutlineTransparency = 0.05
    highlight.FillColor = Color3.fromRGB(255, 90, 90)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.Parent = character

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "MontarUmPetPlayerESP"
    billboard.Adornee = head
    billboard.Size = UDim2.fromOffset(180, 28)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = head

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 11
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.Text = player.DisplayName
    label.Parent = billboard

    PlayerESPObjects[player] = {
        Highlight = highlight,
        Billboard = billboard,
    }
end

local function RefreshPlayerESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if State.PlayerESP then
                RemovePlayerESP(player)
                CreatePlayerESP(player)
            else
                RemovePlayerESP(player)
            end
        end
    end
end

local function RestoreHiddenPlayers()
    for obj, record in pairs(HiddenPlayerObjects) do
        if obj and obj.Parent and type(record) == "table" then
            if record.Type == "Part" then
                pcall(function()
                    obj.LocalTransparencyModifier = record.Value
                end)
            elseif record.Type == "Decal" then
                pcall(function()
                    obj.Transparency = record.Value
                end)
            end
        end
    end

    table.clear(HiddenPlayerObjects)
end

local function HideCharacter(character)
    if not character then
        return
    end

    for _, obj in ipairs(character:GetDescendants()) do
        if obj:IsA("BasePart") then
            if HiddenPlayerObjects[obj] == nil then
                HiddenPlayerObjects[obj] = {
                    Type = "Part",
                    Value = obj.LocalTransparencyModifier,
                }
            end
            obj.LocalTransparencyModifier = 1
        elseif obj:IsA("Decal") then
            if HiddenPlayerObjects[obj] == nil then
                HiddenPlayerObjects[obj] = {
                    Type = "Decal",
                    Value = obj.Transparency,
                }
            end
            obj.Transparency = 1
        end
    end
end

local function SetHidePlayers(enabled)
    State.HidePlayers = enabled

    if not enabled then
        RestoreHiddenPlayers()
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            HideCharacter(player.Character)
        end
    end
end

local function ConnectPlayer(player)
    if player == LocalPlayer then
        return
    end

    Track(player.CharacterAdded:Connect(function()
        task.wait(0.35)
        if not Running then
            return
        end

        if State.PlayerESP then
            CreatePlayerESP(player)
        end

        if State.HidePlayers then
            HideCharacter(player.Character)
        end
    end))
end

for _, player in ipairs(Players:GetPlayers()) do
    ConnectPlayer(player)
end

Track(Players.PlayerAdded:Connect(function(player)
    ConnectPlayer(player)
end))

Track(Players.PlayerRemoving:Connect(function(player)
    RemovePlayerESP(player)
end))

--============================================================--
-- PERFORMANCE
--============================================================--

local function ApplyLightingState()
    pcall(function()
        if State.Fullbright then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
        else
            Lighting.Brightness = OriginalLighting.Brightness
            Lighting.ClockTime = OriginalLighting.ClockTime
        end

        if State.Fullbright or State.LowGraphics or State.LowShadows then
            Lighting.GlobalShadows = false
        else
            Lighting.GlobalShadows = OriginalLighting.GlobalShadows
        end

        if State.Fullbright or State.NoFog then
            Lighting.FogEnd = 1000000
        else
            Lighting.FogEnd = OriginalLighting.FogEnd
        end
    end)
end

local function SetFPSCap(value)
    value = math.clamp(math.floor(tonumber(value) or 60), 15, 240)
    State.FPSCap = value

    if typeof(setfpscap) == "function" then
        pcall(function()
            setfpscap(value)
        end)
    end
end

local function SetLowGraphics(enabled)
    State.LowGraphics = enabled

    if enabled and OriginalQuality == nil then
        pcall(function()
            OriginalQuality = settings().Rendering.QualityLevel
        end)
    end

    if enabled then
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        end)
    elseif OriginalQuality ~= nil then
        pcall(function()
            settings().Rendering.QualityLevel = OriginalQuality
        end)
    end

    ApplyLightingState()
end

local function SetLowShadows(enabled)
    State.LowShadows = enabled
    ApplyLightingState()
end

local function SetFullbright(enabled)
    State.Fullbright = enabled
    ApplyLightingState()
end

local function SetNoFog(enabled)
    State.NoFog = enabled
    ApplyLightingState()
end

local function Set3DDisabled(enabled)
    State.Disable3D = enabled
    pcall(function()
        RunService:Set3dRenderingEnabled(not enabled)
    end)
end

--============================================================--
-- GUI: RAYFIELD GEN2
--============================================================--

local okRayfield, Rayfield = pcall(function()
    local source = game:HttpGet("https://sirius.menu/gen2")
    local loader = loadstring(source)
    assert(type(loader) == "function", "Rayfield Gen2 loader inválido")
    return loader()
end)

-- Outra execução pode ter assumido o singleton enquanto o loader carregava.
if not Running or (tonumber(ControlFolder:GetAttribute("Generation")) or 0) ~= MY_GENERATION then
    pcall(function()
        if Rayfield and Rayfield.Destroy then
            Rayfield:Destroy()
        end
    end)
    pcall(function()
        if GuardConnection then
            GuardConnection:Disconnect()
        end
        if ReplaceConnection then
            ReplaceConnection:Disconnect()
        end
        if Guard then
            Guard:Destroy()
        end
    end)
    return
end

if not okRayfield or type(Rayfield) ~= "table" then
    Running = false
    if GuardConnection then
        GuardConnection:Disconnect()
    end
    Guard:Destroy()
    warn("Montar um Pet: não foi possível carregar Rayfield Gen2.")
    return
end

-- Se outra execução pediu shutdown enquanto a biblioteca carregava,
-- não continue criando uma segunda interface.
if not Running then
    pcall(function()
        if Rayfield.Destroy then
            Rayfield:Destroy()
        end
    end)
    pcall(function()
        Guard:Destroy()
    end)
    return
end

if not Running or (tonumber(ControlFolder:GetAttribute("Generation")) or 0) ~= MY_GENERATION then
    pcall(function()
        if Rayfield and Rayfield.Destroy then
            Rayfield:Destroy()
        end
    end)
    return
end

local okWindow, Window = pcall(function()
    return Rayfield:CreateWindow({
        name = "Montar um Pet",
        subtitle = "MASTER v15 • Delta Mobile",
        sidebarLayout = true,
        toggleUIKeybind = "K",
        configuration = {
            autoSave = true,
            autoLoad = true,
            fileName = "MontarUmPet_Master_v15",
        },
    })
end)

if not okWindow or not Window then
    Running = false
    pcall(function()
        if Rayfield.Destroy then
            Rayfield:Destroy()
        end
    end)
    if GuardConnection then
        GuardConnection:Disconnect()
    end
    Guard:Destroy()
    warn("Montar um Pet: não foi possível criar a janela.")
    return
end

if not Running or (tonumber(ControlFolder:GetAttribute("Generation")) or 0) ~= MY_GENERATION then
    pcall(function()
        if Rayfield and Rayfield.Destroy then
            Rayfield:Destroy()
        end
    end)
    pcall(function()
        if GuardConnection then
            GuardConnection:Disconnect()
        end
        if ReplaceConnection then
            ReplaceConnection:Disconnect()
        end
        if Guard then
            Guard:Destroy()
        end
    end)
    return
end

--============================================================--
-- TABS
--============================================================--

local TabFarm = Window:CreateTab({name = "Farm"})
local TabOvos = Window:CreateTab({name = "Ovos"})
local TabMove = Window:CreateTab({name = "Movimento"})
local TabVisual = Window:CreateTab({name = "Visual"})
local TabPerf = Window:CreateTab({name = "Performance"})
local TabConfig = Window:CreateTab({name = "Config"})

--============================================================--
-- FARM TAB
--============================================================--

TabFarm:CreateSection({name = "Automação principal"})

TabFarm:CreateToggle({
    name = "Auto Farm",
    flag = "AutoFarm",
    value = State.AutoFarm,
    callback = function(value)
        State.AutoFarm = value

        if value then
            StartFarmNoclip()
            ClearFarmTarget()
            State.FarmPhase = "Starting"
            LastFarmStatus = "Starting Auto Farm"
            -- O trabalhador centralizado inicia o ciclo.
            -- Não fazemos uma segunda chamada manual aqui para evitar corrida.
        else
            CancelGlide()
            DestroyFarmFlightMovers()
            StopFarmNoclip()
            ClearFarmTarget()
            State.FarmPhase = "Stopped"
            -- Não libera FarmBusy à força no meio de uma rota; o ciclo encerra
            -- naturalmente, evitando corrida entre desligar e religar.
        end
    end,
})

TabFarm:CreateDropdown({
    name = "Modo de seleção",
    flag = "FarmMode",
    options = {"Rarity", "Egg"},
    value = State.FarmMode,
    callback = function(value)
        if value == "Egg" or value == "Rarity" then
            State.FarmMode = value
        end
    end,
})

TabFarm:CreateDropdown({
    name = "Raridades alvo",
    flag = "TargetRarities",
    multiSelect = true,
    options = Rarities,
    value = (function()
        local t = {}
        for k, v in pairs(State.SelectedRarities) do if v then table.insert(t, k) end end
        table.sort(t)
        return t
    end)(),
    placeholder = "Nenhuma",
    callback = function(value)
        State.SelectedRarities = CopyArrayToSet(value)
    end,
})

TabFarm:CreateDropdown({
    name = "Ovos alvo",
    flag = "TargetEggs",
    multiSelect = true,
    options = EggNames,
    value = {},
    placeholder = "Nenhum",
    callback = function(value)
        State.SelectedEggs = CopyArrayToSet(value)
    end,
})

TabFarm:CreateDropdown({
    name = "Prioridade",
    flag = "TargetPriority",
    options = {"Highest Rarity", "Highest Luck", "Closest", "Highest Weight"},
    value = State.TargetPriority,
    callback = function(value)
        State.TargetPriority = value
    end,
})

TabFarm:CreateDropdown({
    name = "Método de coleta",
    flag = "FarmPickupMode",
    description = "Remote usa Game.EggPickup; Auto usa Remote e Prompt como fallback.",
    options = {"Remote", "Auto", "Prompt"},
    value = State.FarmPickupMode,
    callback = function(value)
        if value == "Remote" or value == "Auto" or value == "Prompt" then
            State.FarmPickupMode = value
        end
    end,
})

TabFarm:CreateDropdown({
    name = "Perfil do Auto Farm 2026",
    flag = "FarmEngineProfile",
    description = "Combina padrões públicos: scanner RenderedEggs/ActiveEggs, glide e coleta Remote/Prompt.",
    options = {"Hybrid 2026", "Max Confiável 2026", "Remote Priority", "Prompt Priority", "Rendered Eggs", "Conservative"},
    value = State.FarmEngineProfile,
    callback = function(value)
        if value == "Hybrid 2026"
            or value == "Max Confiável 2026"
            or value == "Remote Priority"
            or value == "Prompt Priority"
            or value == "Rendered Eggs"
            or value == "Conservative" then
            State.FarmEngineProfile = value

            if value == "Max Confiável 2026" then
                State.FarmPickupMode = "Auto"
                State.FarmRenderedFallback = true
                State.FarmRemoteFallback = true
                State.FarmPromptFallback = true
                State.FarmFloorGuard = true
                State.FarmAutoRecover = true
            elseif value == "Remote Priority" then
                State.FarmPickupMode = "Remote"
                State.FarmRemoteFallback = true
                State.FarmPromptFallback = true
            elseif value == "Prompt Priority" then
                State.FarmPickupMode = "Prompt"
                State.FarmPromptFallback = true
                State.FarmRemoteFallback = true
            elseif value == "Rendered Eggs" then
                State.FarmPickupMode = "Auto"
                State.FarmRenderedFallback = true
                State.FarmPromptFallback = true
            elseif value == "Conservative" then
                State.FarmPickupMode = "Auto"
                State.FarmRenderedFallback = true
                State.FarmPromptFallback = true
                State.FarmRemoteFallback = true
                State.FarmFloorGuard = true
                State.FarmCycleDelay = math.max(State.FarmCycleDelay or 1.5, 1.5)
            end
        end
    end,
})

TabFarm:CreateToggle({
    name = "Fallback RenderedEggs",
    flag = "FarmRenderedFallback",
    description = "Usa os ovos visuais quando ActiveEggs estiver atrasado ou indisponível.",
    value = State.FarmRenderedFallback,
    callback = function(value)
        State.FarmRenderedFallback = value
    end,
})

TabFarm:CreateToggle({
    name = "Fallback Prompt",
    flag = "FarmPromptFallback",
    description = "Tenta ProximityPrompt quando o Remote não confirmar a coleta.",
    value = State.FarmPromptFallback,
    callback = function(value)
        State.FarmPromptFallback = value
    end,
})

TabFarm:CreateToggle({
    name = "Auto Recovery",
    flag = "FarmAutoRecover",
    description = "Troca de alvo e recupera o ciclo após erro de movimento/coleta.",
    value = State.FarmAutoRecover,
    callback = function(value)
        State.FarmAutoRecover = value
    end,
})

TabFarm:CreateSlider({
    name = "Espera de recuperação",
    flag = "FarmRetryAfterError",
    range = {0.25, 4.00},
    increment = 0.25,
    value = State.FarmRetryAfterError,
    suffix = " s",
    callback = function(value)
        State.FarmRetryAfterError = math.clamp(tonumber(value) or 1.00, 0.25, 4.00)
    end,
})

TabFarm:CreateButton({
    name = "Diagnóstico do Auto Farm",
    description = "Mostra quais fontes e remotes estão disponíveis agora.",
    callback = function()
        pcall(function()
            local fs = GetGameFeatureStatus()
            local candidates = #GetFarmCandidates()
            Window:Notify({
                title = "Diagnóstico Auto Farm",
                content = string.format(
                    "ActiveEggs:%s • RenderedEggs:%s • EggPickup:%s • EggPlaced:%s • Ovos:%d • Fase:%s",
                    tostring(fs.ActiveEggs), tostring(fs.RenderedEggs), tostring(fs.EggPickup),
                    tostring(fs.EggPlaced), candidates, tostring(State.FarmPhase)
                ),
                duration = 6,
            })
        end)
    end,
})

TabFarm:CreateSlider({
    name = "Raio de coleta",
    flag = "FarmPickupRadius",
    range = {8, 30},
    increment = 1,
    value = State.FarmPickupRadius,
    suffix = " studs",
    callback = function(value)
        State.FarmPickupRadius = math.clamp(math.floor(tonumber(value) or 20), 8, 30)
    end,
})

TabFarm:CreateInput({
    name = "Peso mínimo do ovo",
    flag = "MinEggWeight",
    description = "0 desativa o filtro. Ex.: 50000",
    numeric = true,
    value = tostring(State.MinEggWeight),
    callback = function(value)
        State.MinEggWeight = math.max(0, tonumber(value) or 0)
    end,
})

TabFarm:CreateInput({
    name = "Luck mínima",
    flag = "MinEggLuck",
    description = "0 desativa o filtro.",
    numeric = true,
    value = tostring(State.MinEggLuck),
    callback = function(value)
        State.MinEggLuck = math.max(0, tonumber(value) or 0)
    end,
})

TabFarm:CreateToggle({
    name = "Somente ovos mutados",
    flag = "OnlyMutated",
    value = State.OnlyMutated,
    callback = function(value)
        State.OnlyMutated = value
    end,
})

TabFarm:CreateToggle({
    name = "Auto Pickup próximo",
    flag = "AutoPickup",
    description = "Recolhe um alvo dentro de ~20 studs.",
    value = State.AutoPickup,
    callback = function(value)
        State.AutoPickup = value
    end,
})

TabFarm:CreateToggle({
    name = "Auto Mount Pet",
    flag = "AutoMountPet",
    description = "Usa o pet com menor Weight encontrado na mochila, conforme a implementação pública pesquisada.",
    value = State.AutoMountPet,
    callback = function(value)
        State.AutoMountPet = value
    end,
})

TabFarm:CreateToggle({
    name = "Exigir pet montado",
    flag = "FarmRequireMountedPet",
    description = "Desligado por padrão para o Auto Farm não ficar preso na base se o pet não montar.",
    value = State.FarmRequireMountedPet,
    callback = function(value)
        State.FarmRequireMountedPet = value
    end,
})

TabFarm:CreateToggle({
    name = "Volcanic Support",
    flag = "VolcanicSupport",
    value = State.VolcanicSupport,
    callback = function(value)
        State.VolcanicSupport = value
    end,
})

TabFarm:CreateToggle({
    name = "Retornar para a base",
    flag = "ReturnToPlot",
    value = State.ReturnToPlot,
    callback = function(value)
        State.ReturnToPlot = value
    end,
})

TabFarm:CreateSlider({
    name = "Travel Speed",
    flag = "TravelSpeed",
    range = {50, 2000},
    increment = 10,
    value = State.TravelSpeed,
    suffix = " studs/s",
    callback = function(value)
        State.TravelSpeed = math.clamp(math.floor(tonumber(value) or 500), 50, 2000)
    end,
})

TabFarm:CreateSection({name = "Voo do Auto Farm"})

TabFarm:CreateSlider({
    name = "Velocidade do voo",
    flag = "FarmFlightSpeed",
    range = {50, 350},
    increment = 10,
    value = State.FarmFlightSpeed,
    suffix = " studs/s",
    callback = function(value)
        State.FarmFlightSpeed = math.clamp(
            math.floor(tonumber(value) or 300),
            50,
            350
        )
    end,
})

TabFarm:CreateSlider({
    name = "Altura de voo",
    flag = "FarmFlightHeight",
    range = {20, 200},
    increment = 5,
    value = State.FarmFlightHeight,
    suffix = " studs",
    callback = function(value)
        State.FarmFlightHeight = math.clamp(
            math.floor(tonumber(value) or 60),
            20,
            200
        )
    end,
})

TabFarm:CreateSlider({
    name = "Altura de espera na base",
    flag = "FarmHoverHeight",
    range = {25, 150},
    increment = 5,
    value = State.FarmHoverHeight,
    suffix = " studs",
    callback = function(value)
        State.FarmHoverHeight = math.clamp(
            math.floor(tonumber(value) or 55),
            25,
            150
        )
    end,
})

TabFarm:CreateSlider({
    name = "Altura ao pegar",
    flag = "FarmFlightDescendHeight",
    range = {4, 12},
    increment = 1,
    value = State.FarmFlightDescendHeight,
    suffix = " studs",
    callback = function(value)
        State.FarmFlightDescendHeight = math.clamp(
            math.floor(tonumber(value) or 6),
            4,
            12
        )
    end,
})

TabFarm:CreateSlider({
    name = "Pausa ao chegar",
    flag = "FarmArrivalPause",
    range = {0.10, 0.80},
    increment = 0.05,
    value = State.FarmArrivalPause,
    suffix = " s",
    callback = function(value)
        State.FarmArrivalPause = math.clamp(tonumber(value) or 0.35, 0.10, 0.80)
    end,
})

TabFarm:CreateSlider({
    name = "Pausa para confirmar coleta",
    flag = "FarmPickupPause",
    range = {0.20, 1.00},
    increment = 0.05,
    value = State.FarmPickupPause,
    suffix = " s",
    callback = function(value)
        State.FarmPickupPause = math.clamp(tonumber(value) or 0.45, 0.20, 1.00)
    end,
})

TabFarm:CreateSlider({
    name = "Altura segura para coletar",
    flag = "FarmPickupApproachHeight",
    range = {4, 12},
    increment = 1,
    value = State.FarmPickupApproachHeight,
    suffix = " studs",
    callback = function(value)
        State.FarmPickupApproachHeight = math.clamp(math.floor(tonumber(value) or 6), 4, 12)
    end,
})

TabFarm:CreateToggle({
    name = "Reaproximar se coleta falhar",
    flag = "FarmPickupRetryApproach",
    value = State.FarmPickupRetryApproach,
    callback = function(value)
        State.FarmPickupRetryApproach = value
    end,
})

TabFarm:CreateSection({name = "Motor avançado e segurança"})

TabFarm:CreateSlider({
    name = "Tentativas de coleta",
    flag = "FarmPickupRetries",
    range = {1, 10},
    increment = 1,
    value = State.FarmPickupRetries,
    suffix = " tentativas",
    callback = function(value)
        State.FarmPickupRetries = math.clamp(math.floor(tonumber(value) or 6), 1, 10)
    end,
})

TabFarm:CreateSlider({
    name = "Espera após tentativa",
    flag = "FarmPickupWait",
    range = {0.10, 0.80},
    increment = 0.05,
    value = State.FarmPickupWait,
    suffix = " s",
    callback = function(value)
        State.FarmPickupWait = math.clamp(tonumber(value) or 0.25, 0.10, 0.80)
    end,
})

TabFarm:CreateSlider({
    name = "Atraso entre retries",
    flag = "FarmRetryDelay",
    range = {0.10, 1.00},
    increment = 0.05,
    value = State.FarmRetryDelay,
    suffix = " s",
    callback = function(value)
        State.FarmRetryDelay = math.clamp(tonumber(value) or 0.30, 0.10, 1.00)
    end,
})

TabFarm:CreateSlider({
    name = "Raio de chegada",
    flag = "FarmFlightArriveRadius",
    range = {2, 10},
    increment = 1,
    value = State.FarmFlightArriveRadius,
    suffix = " studs",
    callback = function(value)
        State.FarmFlightArriveRadius = math.clamp(math.floor(tonumber(value) or 4), 2, 10)
    end,
})

TabFarm:CreateSlider({
    name = "Altura de entrada no plot",
    flag = "FarmBaseEntryHeight",
    range = {3, 15},
    increment = 1,
    value = State.FarmBaseEntryHeight,
    suffix = " studs",
    callback = function(value)
        State.FarmBaseEntryHeight = math.clamp(math.floor(tonumber(value) or 7), 3, 15)
    end,
})

TabFarm:CreateSlider({
    name = "Velocidade de aproximação da base",
    flag = "FarmBaseApproachSpeed",
    range = {60, 220},
    increment = 5,
    value = State.FarmBaseApproachSpeed,
    suffix = " studs/s",
    callback = function(value)
        State.FarmBaseApproachSpeed = math.clamp(math.floor(tonumber(value) or 140), 60, 220)
    end,
})

TabFarm:CreateSlider({
    name = "Altura de aproximação do ninho",
    flag = "FarmNestApproachHeight",
    range = {3, 12},
    increment = 1,
    value = State.FarmNestApproachHeight,
    suffix = " studs",
    callback = function(value)
        State.FarmNestApproachHeight = math.clamp(math.floor(tonumber(value) or 6), 3, 12)
    end,
})

TabFarm:CreateSlider({
    name = "Intervalo de procura do ninho",
    flag = "FarmNestPoll",
    range = {0.10, 0.75},
    increment = 0.05,
    value = State.FarmNestPoll,
    suffix = " s",
    callback = function(value)
        State.FarmNestPoll = math.clamp(tonumber(value) or 0.25, 0.10, 0.75)
    end,
})

TabFarm:CreateSlider({
    name = "Raio para considerar na base",
    flag = "FarmHoverRadius",
    range = {8, 40},
    increment = 1,
    value = State.FarmHoverRadius,
    suffix = " studs",
    callback = function(value)
        State.FarmHoverRadius = math.clamp(math.floor(tonumber(value) or 18), 8, 40)
    end,
})

TabFarm:CreateSlider({
    name = "Intervalo do motor",
    flag = "FarmLoopDelay",
    range = {0.05, 0.50},
    increment = 0.05,
    value = State.FarmLoopDelay,
    suffix = " s",
    callback = function(value)
        State.FarmLoopDelay = math.clamp(tonumber(value) or 0.10, 0.05, 0.50)
    end,
})

TabFarm:CreateSlider({
    name = "Pausa entre ciclos",
    flag = "FarmCycleDelay",
    range = {0.50, 5.00},
    increment = 0.25,
    value = State.FarmCycleDelay,
    suffix = " s",
    callback = function(value)
        State.FarmCycleDelay = math.clamp(tonumber(value) or 1.50, 0.50, 5.00)
    end,
})

TabFarm:CreateSlider({
    name = "Espera sem ovo alvo",
    flag = "FarmNoTargetDelay",
    range = {0.25, 5.00},
    increment = 0.25,
    value = State.FarmNoTargetDelay,
    suffix = " s",
    callback = function(value)
        State.FarmNoTargetDelay = math.clamp(tonumber(value) or 1.00, 0.25, 5.00)
    end,
})

TabFarm:CreateToggle({
    name = "Proteção contra atravessar o chão",
    flag = "FarmFloorGuard",
    description = "Mantém folga do piso, limita a descida e restaura colisão na aproximação final.",
    value = State.FarmFloorGuard,
    callback = function(value)
        State.FarmFloorGuard = value
        if not value and State.AutoFarm then
            StartFarmNoclip()
        end
    end,
})

TabFarm:CreateSlider({
    name = "Folga mínima do chão",
    flag = "FarmFloorClearance",
    range = {3, 12},
    increment = 1,
    value = State.FarmFloorClearance,
    suffix = " studs",
    callback = function(value)
        State.FarmFloorClearance = math.clamp(math.floor(tonumber(value) or 6), 3, 12)
    end,
})

TabFarm:CreateSlider({
    name = "Velocidade máxima de descida",
    flag = "FarmMaxDescendSpeed",
    range = {30, 120},
    increment = 5,
    value = State.FarmMaxDescendSpeed,
    suffix = " studs/s",
    callback = function(value)
        State.FarmMaxDescendSpeed = math.clamp(math.floor(tonumber(value) or 70), 30, 120)
    end,
})

TabFarm:CreateSlider({
    name = "Pausa na base",
    flag = "FarmBasePause",
    range = {1.0, 5.0},
    increment = 0.25,
    value = State.FarmBasePause,
    suffix = " s",
    callback = function(value)
        State.FarmBasePause = math.clamp(tonumber(value) or 2.50, 1.0, 5.0)
    end,
})

TabFarm:CreateSlider({
    name = "Tempo máximo para entrega",
    flag = "FarmDepositWait",
    range = {1.5, 6.0},
    increment = 0.25,
    value = State.FarmDepositWait,
    suffix = " s",
    callback = function(value)
        State.FarmDepositWait = math.clamp(tonumber(value) or 3.50, 1.5, 6.0)
    end,
})

TabFarm:CreateSlider({
    name = "Espera por ninho livre",
    flag = "FarmNestWait",
    range = {2.0, 20.0},
    increment = 0.5,
    value = State.FarmNestWait,
    suffix = " s",
    callback = function(value)
        State.FarmNestWait = math.clamp(tonumber(value) or 8.0, 2.0, 20.0)
    end,
})

TabFarm:CreateSection({name = "Rota segura 2026"})

TabFarm:CreateSlider({
    name = "Distância do lado da base",
    flag = "FarmBaseSideOffset",
    range = {8, 60},
    increment = 1,
    value = State.FarmBaseSideOffset,
    suffix = " studs",
    callback = function(value)
        State.FarmBaseSideOffset = math.clamp(math.floor(tonumber(value) or 26), 8, 60)
    end,
})

TabFarm:CreateSlider({
    name = "Altura ao cair ao lado",
    flag = "FarmBaseSideHeight",
    range = {3, 15},
    increment = 1,
    value = State.FarmBaseSideHeight,
    suffix = " studs",
    callback = function(value)
        State.FarmBaseSideHeight = math.clamp(math.floor(tonumber(value) or 6), 3, 15)
    end,
})

TabFarm:CreateSlider({
    name = "Entrada no plot",
    flag = "FarmBaseEntryInset",
    range = {4, 40},
    increment = 1,
    value = State.FarmBaseEntryInset,
    suffix = " studs",
    callback = function(value)
        State.FarmBaseEntryInset = math.clamp(math.floor(tonumber(value) or 14), 4, 40)
    end,
})

TabFarm:CreateSlider({
    name = "Velocidade para entrar",
    flag = "FarmBaseEntrySpeed",
    range = {60, 180},
    increment = 5,
    value = State.FarmBaseEntrySpeed,
    suffix = " studs/s",
    callback = function(value)
        State.FarmBaseEntrySpeed = math.clamp(math.floor(tonumber(value) or 110), 60, 180)
    end,
})

TabFarm:CreateSlider({
    name = "Pausa ao lado da base",
    flag = "FarmBaseSidePause",
    range = {0.20, 2.0},
    increment = 0.10,
    value = State.FarmBaseSidePause,
    suffix = " s",
    callback = function(value)
        State.FarmBaseSidePause = math.clamp(tonumber(value) or 0.60, 0.20, 2.0)
    end,
})

TabFarm:CreateSlider({
    name = "Pausa dentro do plot",
    flag = "FarmBaseEntryPause",
    range = {0.20, 2.0},
    increment = 0.10,
    value = State.FarmBaseEntryPause,
    suffix = " s",
    callback = function(value)
        State.FarmBaseEntryPause = math.clamp(tonumber(value) or 0.80, 0.20, 2.0)
    end,
})

TabFarm:CreateSlider({
    name = "Velocidade até o ninho",
    flag = "FarmNestApproachSpeed",
    range = {60, 180},
    increment = 5,
    value = State.FarmNestApproachSpeed,
    suffix = " studs/s",
    callback = function(value)
        State.FarmNestApproachSpeed = math.clamp(math.floor(tonumber(value) or 100), 60, 180)
    end,
})

TabFarm:CreateSlider({
    name = "Confirmação do plot",
    flag = "FarmBaseConfirmTimeout",
    range = {0.5, 5.0},
    increment = 0.25,
    value = State.FarmBaseConfirmTimeout,
    suffix = " s",
    callback = function(value)
        State.FarmBaseConfirmTimeout = math.clamp(tonumber(value) or 2.50, 0.5, 5.0)
    end,
})

TabFarm:CreateSection({name = "Controle"})

TabFarm:CreateButton({
    name = "Estado do Auto Farm",
    description = "Mostra a fase atual e o alvo.",
    callback = function()
        pcall(function()
            Window:Notify({
                title = "Auto Farm",
                content =
                    tostring(State.FarmPhase) ..
                    " • alvo: " ..
                    tostring(State.FarmTargetName or "nenhum"),
                duration = 4,
            })
        end)
    end,
})

TabFarm:CreateButton({
    name = "Status do Auto Farm",
    description = "Mostra o último estado interno do motor.",
    callback = function()
        pcall(function()
            Window:Notify({
                title = "Auto Farm",
                content = LastFarmStatus,
                duration = 4,
            })
        end)
    end,
})

TabFarm:CreateButton({
    name = "Stop Farm agora",
    callback = function()
        State.AutoFarm = false
        State.AutoPickup = false
        CancelGlide()
        DestroyFarmFlightMovers()
        StopFarmNoclip()
        ClearFarmTarget()
        State.FarmPhase = "Stopped"
        LastFarmStatus = "Auto Farm parado"
        -- FarmBusy fica sob controle do ciclo atual até ele sair naturalmente.
    end,
})

TabFarm:CreateButton({
    name = "Montar melhor pet agora",
    callback = function()
        MountBestPet()
    end,
})

TabFarm:CreateSection({name = "Automações 2026 verificadas"})

TabFarm:CreateToggle({
    name = "Auto Place Eggs",
    flag = "AutoPlaceEggs",
    description = "Coloca ovos em ninhos livres; no Auto Farm principal, a entrega já faz parte do ciclo.",
    value = State.AutoPlaceEggs,
    callback = function(value)
        State.AutoPlaceEggs = value
    end,
})

TabFarm:CreateToggle({
    name = "Auto Hatch Eggs",
    flag = "AutoHatchEggs",
    description = "Hatch eggs com timer concluído e confirma a remoção do ovo.",
    value = State.AutoHatchEggs,
    callback = function(value)
        State.AutoHatchEggs = value
    end,
})

TabFarm:CreateToggle({
    name = "Auto Best Pets",
    flag = "AutoBestPets",
    description = "Reorganiza os pets colocados usando Income ou Speed.",
    value = State.AutoBestPets,
    callback = function(value)
        State.AutoBestPets = value
    end,
})

TabFarm:CreateDropdown({
    name = "Melhor pet por",
    flag = "BestPetMetric",
    options = {"Income", "Speed"},
    value = State.BestPetMetric,
    callback = function(value)
        if value == "Income" or value == "Speed" then
            State.BestPetMetric = value
        end
    end,
})

TabFarm:CreateToggle({
    name = "Auto Claim Index",
    flag = "AutoClaimIndex",
    description = "Resgata automaticamente o próximo reward de Index quando o objetivo já foi alcançado.",
    value = State.AutoClaimIndex,
    callback = function(value)
        State.AutoClaimIndex = value
    end,
})

TabFarm:CreateToggle({
    name = "Auto Buy Food",
    flag = "AutoBuyFood",
    description = "Compra comida apenas quando o estoque e o dinheiro podem ser confirmados.",
    value = State.AutoBuyFood,
    callback = function(value)
        State.AutoBuyFood = value
    end,
})

TabFarm:CreateToggle({
    name = "Auto Feed Pets",
    flag = "AutoFeedPets",
    description = "Alimenta um pet elegível com comida disponível; não interfere enquanto o Auto Farm estiver voando.",
    value = State.AutoFeedPets,
    callback = function(value)
        State.AutoFeedPets = value
    end,
})

TabFarm:CreateToggle({
    name = "Auto Favorites",
    flag = "AutoFavorites",
    description = "Favorita pets de inventário usando o melhor pet disponível por sua métrica selecionada.",
    value = State.AutoFavorites,
    callback = function(value)
        State.AutoFavorites = value
    end,
})

TabFarm:CreateButton({
    name = "Status 2026",
    description = "Mostra quais módulos e APIs avançadas foram detectados.",
    callback = function()
        pcall(function()
            Window:Notify({
                title = "Automações 2026",
                content = tostring(State.AdvancedStatus),
                duration = 6,
            })
        end)
    end,
})

--============================================================--
-- OVOS TAB
--============================================================--

TabOvos:CreateSection({name = "Tracker / Teleporte"})

TabOvos:CreateToggle({
    name = "Egg ESP",
    flag = "EggESP",
    value = false,
    callback = function(value)
        SetEggESPEnabled(value)
    end,
})

TabOvos:CreateToggle({
    name = "ESP somente ovos selecionados",
    flag = "ESPOnlySelected",
    value = false,
    callback = function(value)
        State.ESPOnlySelected = value
    end,
})

TabOvos:CreateDropdown({
    name = "Ovos do ESP",
    flag = "ESPSelectedEggs",
    multiSelect = true,
    options = EggNames,
    value = {},
    placeholder = "Todos",
    callback = function(value)
        State.ESPSelectedEggs = CopyArrayToSet(value)
    end,
})

TabOvos:CreateToggle({
    name = "ESP somente mutados",
    flag = "ESPOnlyMutated",
    value = false,
    callback = function(value)
        State.ESPOnlyMutated = value
    end,
})

TabOvos:CreateSlider({
    name = "ESP distância máxima",
    flag = "ESPMaxDistance",
    range = {100, 3000},
    increment = 50,
    value = State.ESPMaxDistance,
    suffix = " studs",
    callback = function(value)
        State.ESPMaxDistance = math.floor(tonumber(value) or 1000)
    end,
})

TabOvos:CreateToggle({
    name = "Mostrar raridade",
    flag = "ESPShowRarity",
    value = true,
    callback = function(value)
        State.ESPShowRarity = value
    end,
})

TabOvos:CreateToggle({
    name = "Mostrar peso",
    flag = "ESPShowWeight",
    value = true,
    callback = function(value)
        State.ESPShowWeight = value
    end,
})

TabOvos:CreateToggle({
    name = "Mostrar luck",
    flag = "ESPShowLuck",
    value = true,
    callback = function(value)
        State.ESPShowLuck = value
    end,
})

TabOvos:CreateToggle({
    name = "Mostrar mutação",
    flag = "ESPShowMutation",
    value = true,
    callback = function(value)
        State.ESPShowMutation = value
    end,
})

TabOvos:CreateToggle({
    name = "Mostrar distância",
    flag = "ESPShowDistance",
    value = true,
    callback = function(value)
        State.ESPShowDistance = value
    end,
})

TabOvos:CreateSection({name = "Posições"})

TabOvos:CreateButton({
    name = "Ir para o melhor ovo selecionado",
    callback = function()
        local candidates = GetCandidates()
        local target = SelectBestCandidate(candidates)

        if target then
            GlideTo(target.Position, State.TravelSpeed)
        end
    end,
})

TabOvos:CreateButton({
    name = "Salvar posição atual",
    callback = function()
        local _, root = GetCharacter()
        if root then
            State.SavedCFrame = root.CFrame
        end
    end,
})

TabOvos:CreateButton({
    name = "Voltar para posição salva",
    callback = function()
        ReturnToSaved()
    end,
})

TabOvos:CreateButton({
    name = "Voltar para a base",
    callback = function()
        ReturnToPlot()
    end,
})

--============================================================--
-- MOVIMENTO TAB
--============================================================--

TabMove:CreateSection({name = "Walk / Speed"})

TabMove:CreateToggle({
    name = "Ativar Speed",
    flag = "SpeedEnabled",
    value = false,
    callback = function(value)
        if value then
            StartSpeed()
        else
            StopSpeed()
            CancelGlide()
        end
    end,
})

TabMove:CreateSlider({
    name = "Speed",
    flag = "WalkSpeed",
    range = {1, 1000},
    increment = 1,
    value = State.WalkSpeed,
    callback = function(value)
        State.WalkSpeed = math.clamp(math.floor(tonumber(value) or 150), 1, 1000)
    end,
})

TabMove:CreateInput({
    name = "Speed exato",
    flag = "WalkSpeedExact",
    numeric = true,
    value = tostring(State.WalkSpeed),
    callback = function(value)
        local n = tonumber(value)
        if n then
            State.WalkSpeed = math.clamp(math.floor(n), 1, 1000)
        end
    end,
})

TabMove:CreateSection({name = "Player utilities"})

TabMove:CreateToggle({
    name = "Noclip",
    flag = "Noclip",
    value = false,
    callback = function(value)
        if value then
            StartNoclip()
        else
            StopNoclip()
        end
    end,
})

TabMove:CreateToggle({
    name = "Infinite Jump",
    flag = "InfiniteJump",
    value = false,
    callback = function(value)
        if value then
            StartInfiniteJump()
        else
            StopInfiniteJump()
        end
    end,
})

TabMove:CreateToggle({
    name = "Fly",
    flag = "Flying",
    value = false,
    callback = function(value)
        if value then
            StartFly()
        else
            StopFly()
        end
    end,
})

TabMove:CreateSlider({
    name = "Fly Speed",
    flag = "FlySpeed",
    range = {10, 250},
    increment = 5,
    value = State.FlySpeed,
    suffix = " studs/s",
    callback = function(value)
        State.FlySpeed = math.clamp(math.floor(tonumber(value) or 60), 10, 250)
    end,
})

TabMove:CreateToggle({
    name = "Anti AFK",
    flag = "AntiAFK",
    value = false,
    callback = function(value)
        if value then
            StartAntiAFK()
        else
            StopAntiAFK()
        end
    end,
})

--============================================================--
-- VISUAL TAB
--============================================================--

TabVisual:CreateSection({name = "Players"})

TabVisual:CreateToggle({
    name = "Player ESP",
    flag = "PlayerESP",
    value = false,
    callback = function(value)
        RefreshPlayerESP(value)
    end,
})

TabVisual:CreateToggle({
    name = "Ocultar jogadores",
    flag = "HidePlayers",
    description = "Oculta visualmente os outros personagens no seu cliente.",
    value = false,
    callback = function(value)
        SetHidePlayers(value)
    end,
})

--============================================================--
-- PERFORMANCE TAB
--============================================================--

TabPerf:CreateSection({name = "Desempenho local"})

TabPerf:CreateLabel("Estas opções mexem só na renderização local. Não alteram o Auto Farm nem a lógica do script.")

TabPerf:CreateSlider({
    name = "FPS Cap",
    flag = "FPSCap",
    range = {15, 240},
    increment = 5,
    value = State.FPSCap,
    suffix = " FPS",
    callback = function(value)
        SetFPSCap(value)
    end,
})

TabPerf:CreateToggle({
    name = "Low Graphics",
    flag = "LowGraphics",
    description = "Reduz a qualidade gráfica local para aliviar o celular.",
    value = State.LowGraphics,
    callback = function(value)
        SetLowGraphics(value)
    end,
})

TabPerf:CreateToggle({
    name = "Desligar sombras",
    flag = "LowShadows",
    description = "Remove apenas as sombras locais para reduzir o custo de renderização.",
    value = State.LowShadows,
    callback = function(value)
        SetLowShadows(value)
    end,
})

TabPerf:CreateButton({
    name = "Aplicar FPS Cap atual",
    callback = function()
        SetFPSCap(State.FPSCap)
        pcall(function()
            Window:Notify({
                title = "Desempenho",
                content = "FPS Cap aplicado. Nenhuma função do Auto Farm foi alterada.",
                duration = 3,
            })
        end)
    end,
})

--============================================================--
-- CONFIG TAB
--============================================================--

TabConfig:CreateSection({name = "Configuração"})

local CONFIG_FOLDER = "MontarUmPet"
local CONFIG_FILE = "MontarUmPet_MASTER_v15_config.json"

local function CanUseConfigFiles()
    return type(writefile) == "function"
        and type(readfile) == "function"
        and type(isfile) == "function"
end

local function EnsureConfigFolder()
    if type(isfolder) == "function" and type(makefolder) == "function" then
        pcall(function()
            if not isfolder(CONFIG_FOLDER) then
                makefolder(CONFIG_FOLDER)
            end
        end)
    end
end

local function SaveConfigNow()
    local saved = false

    pcall(function()
        if type(Rayfield.SaveConfiguration) == "function" then
            Rayfield:SaveConfiguration()
            saved = true
        elseif type(Rayfield.SaveConfig) == "function" then
            Rayfield:SaveConfig()
            saved = true
        end
    end)

    if CanUseConfigFiles() then
        EnsureConfigFolder()

        local data = { __version = 15 }
        pcall(function()
            for flagName, flag in pairs(Rayfield.Flags or {}) do
                if type(flag) == "table" then
                    local value = flag.CurrentValue
                    if value == nil then value = flag.CurrentOption end
                    if value == nil then value = flag.CurrentKeybind end
                    if value ~= nil then
                        data[flagName] = value
                    end
                end
            end
        end)

        local ok = pcall(function()
            writefile(CONFIG_FILE, HttpService:JSONEncode(data))
        end)

        if ok then
            saved = true
        end
    end

    return saved
end

local function LoadConfigNow()
    if CanUseConfigFiles() and isfile(CONFIG_FILE) then
        local ok, decoded = pcall(function()
            return HttpService:JSONDecode(readfile(CONFIG_FILE))
        end)

        if ok and type(decoded) == "table" then
            local changed = false

            for flagName, value in pairs(decoded) do
                local flag = Rayfield.Flags and Rayfield.Flags[flagName]
                if flag and type(flag.Set) == "function" then
                    pcall(function()
                        flag:Set(value)
                        changed = true
                    end)
                end
            end

            return changed
        end
    end

    local loaded = false

    pcall(function()
        if type(Rayfield.LoadConfiguration) == "function" then
            Rayfield:LoadConfiguration()
            loaded = true
        end
    end)

    return loaded
end

TabConfig:CreateButton({
    name = "Salvar config",
    description = "Salva os toggles, sliders, filtros e seleções atuais no arquivo do hub.",
    callback = function()
        local ok = SaveConfigNow()

        pcall(function()
            Window:Notify({
                title = "Configuração",
                content = ok
                    and "Configuração salva com sucesso."
                    or "O executor não permitiu salvar a configuração.",
                duration = 4,
            })
        end)
    end,
})

TabConfig:CreateButton({
    name = "Carregar config",
    description = "Restaura a configuração salva e atualiza os controles.",
    callback = function()
        local ok = LoadConfigNow()

        pcall(function()
            Window:Notify({
                title = "Configuração",
                content = ok
                    and "Configuração carregada."
                    or "Nenhuma configuração válida foi encontrada.",
                duration = 4,
            })
        end)
    end,
})

TabConfig:CreateSection({name = "Compatibilidade"})

TabConfig:CreateButton({
    name = "Verificar recursos detectados",
    callback = function()
        local status = GetGameFeatureStatus()
        local encontrados = {}

        for nome, ok in pairs(status) do
            if ok then
                table.insert(encontrados, nome)
            end
        end

        table.sort(encontrados)

        local mensagem
        if #encontrados == 0 then
            mensagem = "Nenhum recurso conhecido foi detectado."
        else
            mensagem = "Detectados: " .. table.concat(encontrados, ", ")
        end

        pcall(function()
            Window:Notify({
                title = "Compatibilidade",
                content = mensagem,
                duration = 6,
            })
        end)
    end,
})

TabConfig:CreateButton({
    name = "Recarregar dados de ovos",
    callback = function()
        LoadEggData()

        if #EggNames == 0 then
            pcall(function()
                Window:Notify({
                    title = "Ovos",
                    content = "GameData.Eggs indisponível; usando a lista local de referência.",
                    duration = 4,
                })
            end)
            return
        end

        pcall(function()
            local fonte = next(EggData) and "GameData.Eggs" or "lista local de referência"
            Window:Notify({
                title = "Ovos",
                content = tostring(#EggNames) .. " tipos de ovo disponíveis (" .. fonte .. ").",
                duration = 4,
            })
        end)
    end,
})

TabConfig:CreateSection({name = "Sessão"})


TabConfig:CreateButton({
    name = "Stop All",
    callback = function()
        State.AutoFarm = false
        State.AutoPickup = false
        State.SpeedEnabled = false
        State.Noclip = false
        State.InfiniteJump = false
        State.AntiAFK = false
        State.Flying = false
        State.AutoPlaceEggs = false
        State.AutoHatchEggs = false
        State.AutoBestPets = false
        State.AutoClaimIndex = false
        State.AutoBuyFood = false
        State.AutoFeedPets = false
        State.AutoFavorites = false

        StopSpeed()
        CancelGlide()
        StopNoclip()
        StopInfiniteJump()
        StopAntiAFK()
        StopFly()
        StopFarmNoclip()
    end,
})

TabConfig:CreateButton({
    name = "Salvar posição",
    callback = function()
        local _, root = GetCharacter()
        if root then
            State.SavedCFrame = root.CFrame
        end
    end,
})

TabConfig:CreateButton({
    name = "Descarregar Hub",
    callback = function()
        if StopHandler then
            StopHandler()
        end
    end,
})

--============================================================--
-- CAMADA 2026 VERIFICADA (CARREGADA SOMENTE APOS A UI)
-- Baseada em APIs concretas vistas no codigo publico atual do jogo.
-- Todas as automacoes abaixo sao opt-in; qualquer falha fica confinada
-- a esta camada e nao pode impedir a interface v15 de aparecer.
--============================================================--

local Advanced2026 = {
    Ready = false,
    Failed = false,
    Busy = false,
    Data = {},
    Services = {},
    Cooldowns = {},
    FavoriteRequests = {},
}

function Advanced2026:SetStatus(message)
    State.AdvancedStatus = tostring(message)
end

function Advanced2026:Ready(key, interval)
    local now = os.clock()
    if now < (self.Cooldowns[key] or 0) then
        return false
    end
    self.Cooldowns[key] = now + interval
    return true
end

function Advanced2026:Value(name, default)
    local saved = LocalPlayer:FindFirstChild("SavedData")
    local value = saved and saved:FindFirstChild(name)
    return value and value.Value or default
end

function Advanced2026:Fire(name, ...)
    local remotes = GetGameRemotes()
    local remote = remotes and remotes:FindFirstChild(name)
    if not remote or not remote:IsA("RemoteEvent") then
        return false
    end
    local ok = pcall(function(...)
        remote:FireServer(...)
    end, ...)
    return ok
end

function Advanced2026:WaitFor(predicate, timeout)
    local deadline = os.clock() + (timeout or 3)
    while Running and os.clock() < deadline do
        local ok, result = pcall(predicate)
        if ok and result then
            return true
        end
        task.wait(0.10)
    end
    return false
end

function Advanced2026:Tools()
    local result = {}
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    local character = LocalPlayer.Character
    for _, container in ipairs({backpack, character}) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if item:IsA("Tool") then
                    table.insert(result, item)
                end
            end
        end
    end
    return result
end

function Advanced2026:ToolByPetKey(key)
    for _, tool in ipairs(self:Tools()) do
        if tool:GetAttribute("PetKey") == key then
            return tool
        end
    end
    return nil
end

function Advanced2026:Equip(tool)
    local character, humanoid = GetCharacter()
    if not character or not humanoid or not tool or not tool.Parent then
        return false
    end
    return pcall(function()
        humanoid:EquipTool(tool)
    end)
end

function Advanced2026:EggTools()
    local result = {}
    for _, tool in ipairs(self:Tools()) do
        if self.Data.Eggs and self.Data.Eggs[tool.Name] and not tool:GetAttribute("PetKey") then
            table.insert(result, tool)
        end
    end
    table.sort(result, function(a, b)
        local la = (self.Data.Eggs[a.Name] and self.Data.Eggs[a.Name].Luck) or 0
        local lb = (self.Data.Eggs[b.Name] and self.Data.Eggs[b.Name].Luck) or 0
        if la == lb then
            return a.Name < b.Name
        end
        return la > lb
    end)
    return result
end

function Advanced2026:FreeNests()
    local plot = GetMyPlot()
    local nests = plot and plot:FindFirstChild("Nests")
    local result = {}
    if not nests then
        return result
    end
    for _, nest in ipairs(nests:GetChildren()) do
        if nest:GetAttribute("Unlocked") and not nest:GetAttribute("Occupied") then
            table.insert(result, nest)
        end
    end
    table.sort(result, function(a, b)
        return (tonumber(a.Name) or math.huge) < (tonumber(b.Name) or math.huge)
    end)
    return result
end

function Advanced2026:PetList()
    local result, seen = {}, {}
    local function add(object)
        if not object then return end
        local key = object:GetAttribute("PetKey")
        local name = object:GetAttribute("PetName") or object.Name
        local data = self.Data.Pets and self.Data.Pets[name]
        if not key or not data or seen[key] then return end
        seen[key] = true
        local weight = tonumber(object:GetAttribute("Weight")) or 10
        local age = tonumber(object:GetAttribute("Age")) or 1
        local mutation = object:GetAttribute("Mutation")
        local spawnMutation = object:GetAttribute("SpawnMutation")
        local factor = 1
        if self.Data.Mutations and type(self.Data.Mutations.CombinedFactor) == "function" then
            local ok, value = pcall(self.Data.Mutations.CombinedFactor, mutation, spawnMutation)
            if ok and type(value) == "number" then factor = value end
        end
        local income = (tonumber(data.Income) or 0) * weight / 10 * factor
        local speed = tonumber(data.Speed) or 0
        if self.Services.PetAging and type(self.Services.PetAging.DisplaySpeedFor) == "function" then
            local ok, value = pcall(self.Services.PetAging.DisplaySpeedFor, data.Speed or 0, weight)
            if ok and type(value) == "number" then speed = value * factor end
        end
        result[#result + 1] = {
            Key = key,
            Name = name,
            Object = object,
            Age = age,
            Weight = weight,
            Income = income,
            Speed = speed,
            Rarity = data.Rarity,
            Favorite = object:GetAttribute("Favorited") == true,
            Placed = not object:IsA("Tool"),
        }
    end

    local plot = GetMyPlot()
    local petsFolder = plot and plot:FindFirstChild("Pets")
    if petsFolder then
        for _, pet in ipairs(petsFolder:GetChildren()) do
            add(pet)
        end
    end
    for _, tool in ipairs(self:Tools()) do
        if tool:GetAttribute("PetKey") then
            add(tool)
        end
    end

    table.sort(result, function(a, b)
        local metric = State.BestPetMetric == "Speed" and "Speed" or "Income"
        if a[metric] == b[metric] then
            return a.Key < b.Key
        end
        return (a[metric] or 0) > (b[metric] or 0)
    end)
    return result
end

function Advanced2026:Dismount()
    if not IsRidingPet() then
        return true
    end
    if not self:Fire("PetDismount") then
        return false
    end
    return self:WaitFor(function()
        return not IsRidingPet()
    end, 3)
end

function Advanced2026:PlaceEggs()
    if not self.Ready or State.AutoFarm or GetBasketCount() <= 0 then
        return false
    end
    local plot = GetMyPlot()
    if not plot then
        self:SetStatus("Aguardando seu plot")
        return false
    end

    ReturnToPlot()
    local toolReady = self:WaitFor(function()
        return #self:EggTools() > 0
    end, 4)
    if not toolReady then
        self:SetStatus("Auto Place: ovo ainda nao virou Tool na mochila")
        return false
    end

    local nests = self:FreeNests()
    local tools = self:EggTools()
    if #nests == 0 then
        self:SetStatus("Auto Place: aguardando ninho livre")
        return false
    end
    if #tools == 0 then
        self:SetStatus("Auto Place: aguardando ovo na mochila")
        return false
    end

    for _, nest in ipairs(nests) do
        if not Running or not State.AutoPlaceEggs or State.AutoFarm then break end
        local tool = self:EggTools()[1]
        if not tool then break end
        if not self:Equip(tool) then
            self:SetStatus("Auto Place: falha ao equipar ovo")
            return false
        end
        task.wait(0.15)
        if not self:Fire("EggPlaced", {NestId = nest.Name}) then
            self:SetStatus("Auto Place: EggPlaced indisponivel")
            return false
        end
        if not self:WaitFor(function()
            return nest:GetAttribute("Occupied") == true
        end, 3) then
            self:SetStatus("Auto Place: colocacao nao confirmada")
            return false
        end
    end

    self:SetStatus("Auto Place: ovos colocados e confirmados")
    return true
end

function Advanced2026:EggTimers()
    local result = {}
    local plot = GetMyPlot()
    local eggs = plot and plot:FindFirstChild("Eggs")
    if not eggs then return result end
    for _, egg in ipairs(eggs:GetChildren()) do
        local info = egg:FindFirstChild("EggData", true)
        local data = self.Data.Eggs and self.Data.Eggs[egg.Name]
        local start = info and info:FindFirstChild("PlaceTime")
        local weight = info and info:FindFirstChild("Weight")
        if data and start and start:IsA("NumberValue") and self.Services.DayNight and type(self.Services.DayNight.GrowthRealRemaining) == "function" then
            local total = tonumber(data.GrowthTime) or 0
            if self.Data.General and type(self.Data.General.GrowthTimeFor) == "function" then
                local ok, value = pcall(self.Data.General.GrowthTimeFor, data.GrowthTime or 0, weight and weight.Value or 1)
                if ok and type(value) == "number" then total = value end
            end
            local ok, remaining = pcall(self.Services.DayNight.GrowthRealRemaining, start.Value, total)
            if ok and type(remaining) == "number" then
                result[#result + 1] = {Object = egg, Key = egg:GetAttribute("EggKey"), Name = egg.Name, Remaining = remaining}
            end
        end
    end
    table.sort(result, function(a, b)
        return (a.Remaining or math.huge) < (b.Remaining or math.huge)
    end)
    return result
end

function Advanced2026:AutoHatch()
    if not self.Ready or State.AutoFarm or not State.AutoHatchEggs then
        return false
    end
    local timers = self:EggTimers()
    for _, egg in ipairs(timers) do
        if egg.Remaining <= 0 and egg.Key then
            local _, root = GetCharacter()
            if not root then return false end
            if (root.Position - egg.Object:GetPivot().Position).Magnitude > 12 then
                if not GlideTo(egg.Object:GetPivot().Position, State.TravelSpeed) then
                    self:SetStatus("Auto Hatch: falha no deslocamento")
                    return false
                end
            end
            if not self:Dismount() then
                self:SetStatus("Auto Hatch: nao foi possivel desmontar")
                return false
            end
            if not self:Fire("Hatch", {EggKey = egg.Key}) then
                self:SetStatus("Auto Hatch: remote indisponivel")
                return false
            end
            if self:WaitFor(function()
                return not egg.Object.Parent
            end, 8) then
                self:SetStatus("Auto Hatch: ovo chocou " .. tostring(egg.Name))
                return true
            end
        end
    end
    return false
end

function Advanced2026:AutoClaimIndex()
    if not self.Ready or State.AutoFarm or not State.AutoClaimIndex or not self.Data.IndexRewards then
        return false
    end
    local stage = tonumber(self:Value("IndexRewardStage", 0)) or 0
    local reward
    if type(self.Data.IndexRewards.StageAt) == "function" then
        local ok, value = pcall(self.Data.IndexRewards.StageAt, stage)
        if ok then reward = value end
    end
    if not reward then return false end
    local count = 0
    if type(self.Data.IndexRewards.DiscoveredCount) == "function" then
        local ok, value = pcall(self.Data.IndexRewards.DiscoveredCount, self:Value("OwnedPets", ""))
        if ok then count = tonumber(value) or 0 end
    end
    if count < (tonumber(reward.Goal) or math.huge) then return false end
    if not self:Fire("ClaimIndexReward") then
        self:SetStatus("Auto Index: remote indisponivel")
        return false
    end
    if self:WaitFor(function()
        return (tonumber(self:Value("IndexRewardStage", 0)) or 0) ~= stage
    end, 2) then
        self:SetStatus("Auto Index: reward resgatado")
        return true
    end
    return false
end

function Advanced2026:AutoBestPets()
    if not self.Ready or State.AutoFarm or not State.AutoBestPets then
        return false
    end
    if not self:Dismount() then return false end
    if not ReturnToPlot() then return false end
    task.wait(0.35)
    local plot = GetMyPlot()
    if not plot then return false end
    local pets = self:PetList()
    if #pets == 0 then return false end
    local capacity = tonumber(LocalPlayer:GetAttribute("MaxPets")) or tonumber(self:Value("MaxPets", 5)) or 5
    capacity = math.max(1, math.floor(capacity))
    table.sort(pets, function(a, b)
        local metric = State.BestPetMetric == "Speed" and "Speed" or "Income"
        if a[metric] == b[metric] then return a.Key < b.Key end
        return (a[metric] or 0) > (b[metric] or 0)
    end)
    local desired = {}
    for i = 1, math.min(capacity, #pets) do desired[pets[i].Key] = true end

    for _, pet in ipairs(pets) do
        if pet.Placed and not desired[pet.Key] then
            if self:Fire("PickupPet", pet.Key) then
                self:WaitFor(function() return self:ToolByPetKey(pet.Key) ~= nil end, 3)
            end
        end
    end

    local base = plot:FindFirstChild("Baseplate")
    if not base then return false end
    local cols = math.max(1, math.ceil(math.sqrt(capacity)))
    local spacing = math.min(9, (math.min(base.Size.X, base.Size.Z) - 12) / cols)

    for i = 1, math.min(capacity, #pets) do
        local pet = pets[i]
        local tool = self:ToolByPetKey(pet.Key)
        if tool then
            if not self:Equip(tool) then return false end
            task.wait(0.15)
            local pos = (base.CFrame * CFrame.new(
                ((i - 1) % cols - (cols - 1) / 2) * spacing,
                4,
                math.floor((i - 1) / cols) * spacing
            )).Position
            if not self:Fire("PlacePet", pet.Key, pos) then
                return false
            end
            if not self:WaitFor(function()
                for _, current in ipairs(self:PetList()) do
                    if current.Key == pet.Key and current.Placed then return true end
                end
                return false
            end, 3) then
                self:SetStatus("Auto Best Pets: colocacao nao confirmada")
                return false
            end
        end
    end

    self:SetStatus("Auto Best Pets: " .. tostring(State.BestPetMetric))
    return true
end

function Advanced2026:FoodTools(name)
    local result = {}
    for _, tool in ipairs(self:Tools()) do
        if tool.Name == name then table.insert(result, tool) end
    end
    return result
end

function Advanced2026:FoodAmount(tool)
    local data = tool and tool:FindFirstChild("Data")
    local amount = data and data:FindFirstChild("Amount")
    if amount and amount:IsA("ValueBase") then
        return math.max(0, math.floor(tonumber(amount.Value) or 0))
    end
    return tool and tool.Parent and 1 or 0
end

function Advanced2026:FoodCount(name)
    local total = 0
    for _, tool in ipairs(self:FoodTools(name)) do
        total = total + self:FoodAmount(tool)
    end
    return total
end

function Advanced2026:AutoBuyFoodOnce()
    if not self.Ready or State.AutoFarm or not State.AutoBuyFood or not self.Data.Shop or not self.Data.Shop.Food then
        return false
    end
    local main = LocalPlayer.PlayerGui:FindFirstChild("Main")
    local shop = main and main:FindFirstChild("Shop")
    local holders = shop and shop:FindFirstChild("Holders")
    local foodHolder = holders and holders:FindFirstChild("Food")
    for name, definition in pairs(self.Data.Shop.Food) do
        if type(definition) == "table" and self.Data.Foods and self.Data.Foods[name] then
            local card = foodHolder and foodHolder:FindFirstChild(name)
            local stockLabel = card and card:FindFirstChild("Stock", true)
            local stock = stockLabel and tonumber(stockLabel.Text:match("(%d+)"))
            local cash = tonumber(self:Value("Cash", 0)) or 0
            if stock and stock > 0 and cash >= (tonumber(definition.Price) or math.huge) then
                local before = self:FoodCount(name)
                if self:Fire("BuyWithCash", "Food", name) and self:WaitFor(function()
                    return self:FoodCount(name) > before
                end, 3) then
                    self:SetStatus("Auto Buy Food: " .. tostring(name))
                    return true
                end
            end
        end
    end
    return false
end

function Advanced2026:AutoFeedOnce()
    if not self.Ready or State.AutoFarm or not State.AutoFeedPets then return false end
    local foodName = nil
    if self:FoodCount("Grass") > 0 then foodName = "Grass" end
    if not foodName then return false end
    local pets = self:PetList()
    for _, pet in ipairs(pets) do
        local maxAge = self.Services.PetAging and tonumber(self.Services.PetAging.MaxAge) or 100
        if pet.Age < maxAge then
            if pet.Placed and pet.Object:IsA("Model") then
                local pos = pet.Object:GetPivot().Position
                local _, root = GetCharacter()
                if root and (root.Position - pos).Magnitude > 18 then
                    if not GlideTo(pos, State.TravelSpeed) then return false end
                end
            end
            local food = self:FoodTools(foodName)[1]
            if not food or not self:Equip(food) then return false end
            task.wait(0.15)
            local before = self:FoodCount(foodName)
            if not self:Fire("FeedPet", pet.Key, foodName) then return false end
            if self:WaitFor(function() return self:FoodCount(foodName) < before end, 3) then
                self:SetStatus("Auto Feed: " .. tostring(pet.Name))
                return true
            end
        end
    end
    return false
end

function Advanced2026:AutoFavoriteOnce()
    if not self.Ready or State.AutoFarm or not State.AutoFavorites or not self.Data.Pets then return false end
    local pets = self:PetList()
    table.sort(pets, function(a, b)
        if a.Favorite ~= b.Favorite then return not a.Favorite end
        local metric = State.BestPetMetric == "Speed" and "Speed" or "Income"
        if a[metric] == b[metric] then return a.Key < b.Key end
        return (a[metric] or 0) > (b[metric] or 0)
    end)
    for _, pet in ipairs(pets) do
        if pet.Object:IsA("Tool") and not pet.Favorite and not self.FavoriteRequests[pet.Key] then
            self.FavoriteRequests[pet.Key] = true
            if not self:Fire("FavoritePet", pet.Key) then
                self.FavoriteRequests[pet.Key] = nil
                return false
            end
            if self:WaitFor(function()
                local tool = self:ToolByPetKey(pet.Key)
                return tool and tool:GetAttribute("Favorited") == true
            end, 3) then
                self.FavoriteRequests[pet.Key] = nil
                self:SetStatus("Auto Favorites: " .. tostring(pet.Name))
                return true
            end
            self.FavoriteRequests[pet.Key] = nil
        end
    end
    return false
end

function Advanced2026:LoadModules()
    local essentialOk, essentialErr = pcall(function()
        local gameData = ReplicatedStorage:WaitForChild("GameData", 10)
        local gameServices = ReplicatedStorage:WaitForChild("GameServices", 10)
        self.Data.Eggs = require(gameData:WaitForChild("Eggs", 10))
        self.Data.Pets = require(gameData:WaitForChild("Pets", 10))
        self.Data.General = require(gameData:WaitForChild("General", 10))
        self.Data.Mutations = require(gameData:WaitForChild("Mutations", 10))
        self.Data.EggBaskets = require(gameData:WaitForChild("EggBaskets", 10))
        self.Data.IndexRewards = require(gameData:WaitForChild("IndexRewards", 10))
        self.Services.PetAging = require(gameServices:WaitForChild("PetAging", 10))
        self.Services.DayNight = require(gameServices:WaitForChild("DayNight", 10))
    end)
    if not essentialOk then
        self.Failed = true
        self:SetStatus("Falha nos módulos essenciais 2026: " .. tostring(essentialErr))
        return false
    end

    -- Food/Shop é opcional: se o jogo mudar esses módulos, as outras automações
    -- continuam disponíveis.
    pcall(function()
        local gameData = ReplicatedStorage:FindFirstChild("GameData")
        if gameData then
            local foods = gameData:FindFirstChild("Foods")
            local shop = gameData:FindFirstChild("Shop")
            if foods and foods:IsA("ModuleScript") then self.Data.Foods = require(foods) end
            if shop and shop:IsA("ModuleScript") then self.Data.Shop = require(shop) end
        end
    end)

    self.Ready = true
    self:SetStatus("Módulos 2026 essenciais carregados")
    return true
end

task.defer(function()
    if not Running then return end
    local loaded = Advanced2026:LoadModules()
    if not loaded then return end
    while Running do
        task.wait(math.clamp(tonumber(State.AdvancedInterval) or 1.0, 0.5, 5.0))
        if Running and not Advanced2026.Failed and not Advanced2026.Busy and not State.AutoFarm then
            Advanced2026.Busy = true
            pcall(function()
                if State.AutoPlaceEggs and GetBasketCount() > 0 then
                    Advanced2026:PlaceEggs()
                elseif State.AutoHatchEggs then
                    Advanced2026:AutoHatch()
                elseif State.AutoClaimIndex then
                    Advanced2026:AutoClaimIndex()
                elseif State.AutoBestPets and Advanced2026:Ready("Best", 25) then
                    Advanced2026:AutoBestPets()
                elseif State.AutoBuyFood and Advanced2026:Ready("BuyFood", 2) and Advanced2026.Data.Foods and Advanced2026.Data.Shop then
                    Advanced2026:AutoBuyFoodOnce()
                elseif State.AutoFeedPets and Advanced2026:Ready("Feed", 3) then
                    Advanced2026:AutoFeedOnce()
                elseif State.AutoFavorites and Advanced2026:Ready("Fav", 1) then
                    Advanced2026:AutoFavoriteOnce()
                end
            end)
            Advanced2026.Busy = false
        end
    end
end)

--============================================================--
-- LOOPS CENTRALIZADOS
--============================================================--

local FarmLoop = task.spawn(function()
    while Running do
        if not State.AutoFarm then
            task.wait(0.15)
        elseif FarmBusy then
            -- Um único ciclo por vez. Isso evita duas rotas brigando pelo personagem.
            task.wait(0.05)
        else
            local ok, err = pcall(FarmOnce)

            if not ok and FarmIsRunning() then
                SetFarmPhase("Recuperando do erro")
                LastFarmStatus = "Auto Farm error: " .. tostring(err)
                warn("[MontarUmPet] Auto Farm:", err)
                if State.FarmAutoRecover then
                    ClearFarmTarget()
                    task.wait(math.clamp(tonumber(State.FarmRetryAfterError) or 1.0, 0.25, 4.0))
                end
            elseif State.FarmAutoRecover and FarmIsRunning() and State.FarmPhase == "No target - hovering" then
                task.wait(math.clamp(tonumber(State.FarmNoTargetDelay) or 1.0, 0.25, 5.0))
            elseif FarmIsRunning() then
                task.wait(math.clamp(tonumber(State.FarmCycleDelay) or 1.50, 0.25, 5.0))
            end
        end
    end
end)

-- Dá um primeiro ciclo ao worker assim que o toggle for ligado sem criar um
-- segundo worker ou uma segunda UI.
Track(RunService.Heartbeat:Connect(function()
    if Running and State.AutoFarm and not FarmBusy and State.FarmPhase == "Starting" then
        task.defer(function()
            if Running and State.AutoFarm and not FarmBusy then
                pcall(FarmOnce)
            end
        end)
    end
end))

local PickupLoop = task.spawn(function()
    while Running do
        task.wait(0.25)

        if Running and State.AutoPickup and not State.AutoFarm and not PickupBusy then
            AutoPickupOnce()
        end
    end
end)

--============================================================--
-- STOP HANDLER
--============================================================--

StopHandler = function()
    if not Running then
        return
    end

    CancelGlide()
    DestroyFarmFlightMovers()
    ClearFarmTarget()
    Running = false

    State.AutoFarm = false
    State.AutoPickup = false
    State.SpeedEnabled = false
    State.Noclip = false
    State.InfiniteJump = false
    State.AntiAFK = false
    State.Flying = false
    State.AutoPlaceEggs = false
    State.AutoHatchEggs = false
    State.AutoBestPets = false
    State.AutoClaimIndex = false
    State.AutoBuyFood = false
    State.AutoFeedPets = false
    State.AutoFavorites = false
    State.ESPEnabled = false
    State.PlayerESP = false
    State.HidePlayers = false
    State.Fullbright = false
    State.LowGraphics = false
    State.LowShadows = false
    State.NoFog = false
    State.Disable3D = false

    pcall(StopSpeed)
    pcall(StopNoclip)
    pcall(StopFarmNoclip)
    pcall(StopInfiniteJump)
    pcall(StopAntiAFK)
    pcall(StopFly)

    pcall(ClearAllESP)

    for player in pairs(PlayerESPObjects) do
        RemovePlayerESP(player)
    end

    pcall(RestoreHiddenPlayers)

    pcall(function()
        Set3DDisabled(false)
    end)

    pcall(function()
        if OriginalQuality ~= nil then
            settings().Rendering.QualityLevel = OriginalQuality
        end
    end)

    pcall(function()
        ApplyLightingState()
    end)

    DisconnectAll()

    pcall(function()
        if Rayfield and Rayfield.Destroy then
            Rayfield:Destroy()
        end
    end)

    pcall(function()
        if GuardConnection then
            GuardConnection:Disconnect()
            GuardConnection = nil
        end
    end)

    pcall(function()
        if ReplaceConnection then
            ReplaceConnection:Disconnect()
            ReplaceConnection = nil
        end
    end)

    pcall(function()
        if Guard then
            Guard:Destroy()
        end
    end)
end

ENV[TOKEN_NAMES[1]] = {
    Stop = StopHandler,
}



--============================================================--
-- v27 SAFE AUTOFARM LAYER
-- Base: v22 UI ORIGINAL v15 (INTACT)
-- Regra: nenhuma lógica opcional é executada antes da interface.
-- Qualquer extensão futura deve ser carregada depois que a UI existir.
--============================================================--

task.defer(function()
    if not Running then
        return
    end

    -- Contexto mínimo para extensões futuras, sem alterar a UI ou o Auto Farm atual.
    -- Fica disponível somente depois que Window/Tabs já foram criadas.
    pcall(function()
        ENV.__MUP_V23_CONTEXT = {
            Version = "25-2026-verified",
            Window = Window,
            TabFarm = TabFarm,
            TabOvos = TabOvos,
            TabMove = TabMove,
            TabVisual = TabVisual,
            TabPerf = TabPerf,
            TabConfig = TabConfig,
            State = State,
            GetCharacter = GetCharacter,
            GetMyPlot = GetMyPlot,
            GetBasketCount = GetBasketCount,
            GetGameRemotes = GetGameRemotes,
            GetGameRemote = function(name)
                local remotes = GetGameRemotes()
                local remote = remotes and remotes:FindFirstChild(name)
                return remote
            end,
            IsRidingPet = IsRidingPet,
            Running = function()
                return Running
            end,
        }
    end)
end)
