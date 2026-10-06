--============================================================--
-- MONTAR UM PET - MASTER v21 UI NATIVA + AUTOFARM FLIGHT + NOCLIP + CONFIG
-- PlaceId: 124216119978534
-- UI: Nativa, sem dependência externa; layout mobile/PC
-- Config: salvamento manual em arquivo + flags compatíveis
-- Foco: Delta Mobile + Auto Farm por estados + voo sem colisão + retorno/entrega robustos + cleanup robusto
--
-- Pesquisa usada para esta versão:
--   * VintHub / Ride a Pet.lua
--   * Iamdungx / roblox-lua / ride-a-pet.lua
--   * SixZensED / sixly-script / games/ride-a-pet.lua
--
-- Mecânicas implementadas com base em caminhos/remotes encontrados
-- publicamente: Game.EggPickup, Game.Mounting, GameData.Eggs,
-- ServerData.ActiveEggs, Plots.NestsOwnerLoaded, InVolcano, IsRiding.
--
-- Recursos anunciados por hubs públicos, mas sem remote/path confiável
-- confirmado nas fontes abertas consultadas (Auto Place/Hatch/Feed/Shop/
-- Rebirth etc.), NÃO recebem botões falsos nesta versão.
--============================================================--

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
    "MontarUmPet_NativeUI",
}

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Limpeza direta da UI nativa desta versão, inclusive quando a janela
-- antiga foi parentada no gethui/CoreGui e o handler anterior não chegou
-- a ser registrado.
local function RemoveOldNativeUI(container)
    if not container then
        return
    end
    pcall(function()
        for _, child in ipairs(container:GetChildren()) do
            if child.Name == "MontarUmPet_NativeUI" then
                child:Destroy()
            end
        end
    end)
end

pcall(function()
    RemoveOldNativeUI(PlayerGui)
    RemoveOldNativeUI(game:GetService("CoreGui"))
    if typeof(gethui) == "function" then
        RemoveOldNativeUI(gethui())
    end
end)

-- Para versões anteriores que já tenham um Stop exposto.
for _, tokenName in ipairs(TOKEN_NAMES) do
    pcall(function()
        local oldToken = ENV[tokenName]
        if oldToken and oldToken.Stop then
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

task.wait(0.10)

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
                or t:find("MASTER v15", 1, true) then
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
    FarmPickupMode = "Remote",     -- Auto, Prompt, Remote
    FarmPickupRetries = 6,
    FarmPickupWait = 0.25,
    FarmPickupRadius = 12,
    FarmRetryDelay = 0.30,
    FarmReturnInstant = true,

    -- Auto Farm Flight
    FarmFlightSpeed = 300,
    FarmFlightHeight = 90,
    -- Mantém o HumanoidRootPart alguns studs acima do ovo/solo.
    -- Isso evita que os pés atravessem o chão quando o noclip está ativo.
    FarmFlightDescendHeight = 6,
    FarmFlightArriveRadius = 4,
    FarmArrivalPause = 0.45,
    FarmPickupPause = 0.45,
    FarmPickupApproachHeight = 6,
    FarmPickupRetryApproach = true,
    FarmBasePause = 2.50,
    FarmDepositWait = 3.50,

    -- Auto Farm state machine
    FarmPhase = "Idle",
    FarmTargetUID = nil,
    FarmTargetName = nil,
    FarmTargetPosition = nil,
    FarmTargetRetries = 0,
    FarmHoverRadius = 18,
    FarmHoverHeight = 55,
    FarmLoopDelay = 0.10,
    FarmRequireMountedPet = false,

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
    local activeEggs = GetActiveEggFolder()

    if not root or not activeEggs then
        return {}
    end

    local result = {}

    for _, egg in ipairs(activeEggs:GetChildren()) do
        if egg:IsA("Configuration") then
            local eggName = egg:GetAttribute("Egg")

            if type(eggName) == "string" and MeetsFilters(egg, eggName) then
                local position = egg:GetAttribute("Position")

                if typeof(position) == "CFrame" then
                    position = position.Position
                end

                if typeof(position) ~= "Vector3" then
                    position = GetEggPosition(egg)
                end

                if position then
                    local weight = GetEggWeight(egg) or 0
                    local luck = GetEggLuck(egg) or 0
                    local rarity = GetEggRarity(eggName, egg)
                    local uid = egg.Name

                    if not FailedFarmTargets[uid]
                        or os.clock() >= FailedFarmTargets[uid] then

                        result[#result + 1] = {
                            Instance = egg,
                            UID = uid,
                            ID = uid,
                            Name = eggName,
                            Position = position,
                            Distance = (position - root.Position).Magnitude,
                            Weight = weight,
                            Luck = luck,
                            Rarity = rarity,
                            RarityScore = RarityPriority[rarity] or 0,
                            Mutation = GetEggMutation(egg),
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

    for _, plot in ipairs(plots:GetChildren()) do
        if plot:GetAttribute("NestsOwnerLoaded") == LocalPlayer.UserId then
            return plot
        end
    end

    return nil
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
-- Vai voando em altitude, desce apenas no alvo, coleta e
-- volta voando para a base. Não usa teleport para o ciclo do farm.
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
    local bodyClearance = 6
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

local function FarmFlightSegment(targetPosition, speed, timeoutMultiplier)
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

    StartFarmNoclip()

    if not FarmFlightVelocity or FarmFlightVelocity.Parent ~= root
        or not FarmFlightGyro or FarmFlightGyro.Parent ~= root then

        if not CreateFarmFlightMovers(root) then
            return false
        end
    end

    local maxSpeed = math.clamp(
        tonumber(speed) or State.FarmFlightSpeed,
        50,
        1200
    )

    local arrivedRadius = math.clamp(
        tonumber(State.FarmFlightArriveRadius) or 4,
        2,
        10
    )

    local distance = (targetPosition - root.Position).Magnitude
    local timeout = math.clamp(
        (distance / maxSpeed) * (timeoutMultiplier or 2.5) + 2,
        3,
        35
    )

    local started = os.clock()
    local lastSampleTime = started
    local lastSamplePosition = root.Position
    local stalledFor = 0
    local rescueCount = 0

    while FarmIsRunning()
        and character.Parent
        and root.Parent
        and os.clock() - started < timeout do

        EnforceFarmNoclip()

        local delta = targetPosition - root.Position
        local remaining = delta.Magnitude

        if remaining <= arrivedRadius then
            pcall(function()
                FarmFlightVelocity.Velocity = Vector3.zero
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end)
            return true
        end

        local direction = delta.Unit

        -- Diminui a velocidade perto do ponto final para não passar direto.
        local currentSpeed = math.clamp(
            remaining * 5,
            40,
            maxSpeed
        )

        -- Anti-engasgo: se a física não avançar, sobe e atravessa sem
        -- depender de colisão local. Não usa teleport.
        local now = os.clock()
        if now - lastSampleTime >= 0.30 then
            local moved = (root.Position - lastSamplePosition).Magnitude
            if moved < 1.5 and remaining > arrivedRadius + 3 then
                stalledFor = stalledFor + (now - lastSampleTime)
            else
                stalledFor = 0
            end

            lastSampleTime = now
            lastSamplePosition = root.Position

            if stalledFor >= 0.30 then
                rescueCount = rescueCount + 1
                stalledFor = 0

                pcall(function()
                    FarmFlightVelocity.Velocity =
                        direction * math.max(currentSpeed, 120)
                        + Vector3.new(0, 90, 0)

                    root.AssemblyLinearVelocity =
                        direction * math.max(currentSpeed, 120)
                        + Vector3.new(0, 90, 0)
                end)

                if rescueCount >= 3 then
                    DestroyFarmFlightMovers()
                    task.wait(0.05)
                    if not FarmIsRunning() then
                        return false
                    end
                    if not CreateFarmFlightMovers(root) then
                        return false
                    end
                    rescueCount = 0
                end
            end
        end

        pcall(function()
            FarmFlightVelocity.Velocity = direction * currentSpeed
            FarmFlightGyro.CFrame = CFrame.lookAt(
                root.Position,
                root.Position + direction
            )
            root.AssemblyLinearVelocity = direction * currentSpeed
        end)

        RunService.Heartbeat:Wait()
    end

    pcall(function()
        if FarmFlightVelocity then
            FarmFlightVelocity.Velocity = Vector3.zero
        end
        if root and root.Parent then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end)

    return false
end

local function FarmFlyTo(targetPosition, speed, descend)
    local character, root = GetCharacter()

    if not character or not root then
        return false
    end

    if not FarmIsRunning() then
        return false
    end

    StartFarmNoclip()

    if not CreateFarmFlightMovers(root) then
        return false
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local oldPlatformStand = nil
    local oldAutoRotate = nil

    if humanoid then
        oldPlatformStand = humanoid.PlatformStand
        oldAutoRotate = humanoid.AutoRotate
        humanoid.PlatformStand = true
        humanoid.AutoRotate = false
    end

    -- Noclip persistente durante todo o ciclo do Auto Farm.
    EnforceFarmNoclip()

    local flightHeight = math.clamp(
        tonumber(State.FarmFlightHeight) or 90,
        20,
        300
    )

    local descendHeight = math.clamp(
        tonumber(State.FarmFlightDescendHeight) or 3,
        1,
        8
    )

    -- Mantém o voo acima do ponto mais alto entre origem e destino.
    local cruiseY = math.max(
        root.Position.Y,
        targetPosition.Y
    ) + flightHeight

    -- 1. Sobe verticalmente.
    local upPoint = Vector3.new(
        root.Position.X,
        cruiseY,
        root.Position.Z
    )

    local ok = FarmFlightSegment(
        upPoint,
        speed or State.FarmFlightSpeed,
        2
    )

    -- 2. Voa rápido acima do ovo/base.
    if ok and FarmIsRunning() then
        local cruisePoint = Vector3.new(
            targetPosition.X,
            cruiseY,
            targetPosition.Z
        )

        ok = FarmFlightSegment(
            cruisePoint,
            speed or State.FarmFlightSpeed,
            2.5
        )
    end

    -- 3. Só desce quando está exatamente na coluna do destino.
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
            -- Aproximação final deliberadamente mais lenta.
            ok = FarmFlightSegment(
                dropPoint,
                math.min(
                    speed or State.FarmFlightSpeed,
                    180
                ),
                2.5
            )
        end
    end

    DestroyFarmFlightMovers()

    -- Pequena estabilização após pousar na coluna do alvo/base para dar
    -- tempo ao jogo de registrar a posição e processar a interação.
    if ok and descend ~= false and FarmIsRunning() then
        task.wait(math.clamp(tonumber(State.FarmArrivalPause) or 0.35, 0.10, 0.80))
    end

    if humanoid and humanoid.Parent then
        pcall(function()
            humanoid.PlatformStand = oldPlatformStand
            humanoid.AutoRotate = oldAutoRotate
        end)
    end

    -- Não restaura colisão aqui. O noclip continua ativo até o Auto Farm parar,
    -- evitando que árvore/estrutura faça o personagem travar no próximo trecho.
    EnforceFarmNoclip()

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

    for _ = 1, retries do
        if not FarmIsRunning() then
            return false
        end

        -- Remote é o caminho principal confirmado pelo script open-source
        -- do SixZensED: Game.EggPickup:FireServer(uid).
        if mode == "Remote" then
            if TryRemotePickup(candidate) then
                return true
            end

        elseif mode == "Prompt" then
            if TryPromptPickup(candidate) then
                return true
            end

        else
            -- AUTO: Remote primeiro; Prompt só como fallback.
            if TryRemotePickup(candidate) then
                return true
            end

            if TryPromptPickup(candidate) then
                return true
            end
        end

        if not GetLiveActiveEgg(candidate.UID or candidate.ID) then
            return true
        end

        task.wait(math.max(
            0.05,
            tonumber(State.FarmPickupWait) or 0.20
        ))
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

local function ResolveFarmTarget(uid, fallbackName)
    if not uid then
        return nil
    end

    local active = GetActiveEggFolder()
    local live = active and active:FindFirstChild(uid)

    if not live then
        return nil
    end

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
    }
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

local function FarmDeposit()
    if not FarmIsRunning() then
        return false
    end

    local plot = GetMyPlot()
    if not plot then
        SetFarmPhase("Base não encontrada")
        return false
    end

    local okPivot, pivot = pcall(function()
        return plot:GetPivot()
    end)

    if not okPivot or not pivot then
        SetFarmPhase("Posição da base indisponível")
        return false
    end

    local basePosition = pivot.Position
    local hoverHeight = math.clamp(
        tonumber(State.FarmHoverHeight) or 55,
        25,
        150
    )

    local hoverPosition = basePosition + Vector3.new(0, hoverHeight, 0)
    local _, root = GetCharacter()
    if not root then
        return false
    end

    -- CHECKPOINT 1: sobe antes do retorno para nunca cortar o terreno.
    SetFarmPhase("Subindo para voltar")
    if not FarmFlyTo(
        hoverPosition,
        State.FarmFlightSpeed,
        false
    ) then
        return false
    end

    if not FarmIsRunning() then
        return false
    end

    -- CHECKPOINT 2: chega sobre a base em altitude.
    local _, latestRoot = GetCharacter()
    if not latestRoot then
        return false
    end

    if (latestRoot.Position - hoverPosition).Magnitude > 20 then
        SetFarmPhase("Posicionando sobre a base")
        if not FarmFlyTo(
            hoverPosition,
            State.FarmFlightSpeed,
            false
        ) then
            return false
        end
    end

    if not FarmIsRunning() then
        return false
    end

    -- CHECKPOINT 3: desce apenas até uma altura segura do piso.
    SetFarmPhase("Descendo na base")
    local depositPoint = GetSafeDescentPosition(
        basePosition,
        math.max(
            tonumber(State.FarmFlightDescendHeight) or 6,
            6
        )
    )

    if not depositPoint then
        return false
    end

    if not FarmFlyTo(
        depositPoint,
        math.min(State.FarmFlightSpeed, 180),
        true
    ) then
        return false
    end

    -- CHECKPOINT 4: parada intencional. Dá tempo para o servidor registrar
    -- a entrega antes de iniciar o próximo alvo.
    SetFarmPhase("Estabilizando na base")

    local settleDeadline = os.clock() + math.clamp(
        tonumber(State.FarmDepositWait) or 3.5,
        1.5,
        6
    )

    while FarmIsRunning()
        and os.clock() < settleDeadline
        and GetBasketCount() > 0 do
        EnforceFarmNoclip()
        task.wait(0.08)
    end

    if not FarmIsRunning() then
        return false
    end

    -- Mesmo que a cesta já esteja vazia, mantém a parada configurada.
    task.wait(math.clamp(
        tonumber(State.FarmBasePause) or 2.50,
        1.0,
        5.0
    ))

    if not FarmIsRunning() then
        return false
    end

    -- Última confirmação. Se ainda estiver carregando, faz uma única
    -- reaproximação curta em baixa velocidade e espera novamente.
    if GetBasketCount() > 0 then
        SetFarmPhase("Confirmando entrega")

        local retryPoint = GetSafeDescentPosition(
            basePosition,
            6
        )

        if retryPoint and not FarmFlyTo(
            retryPoint,
            120,
            true
        ) then
            return false
        end

        task.wait(math.clamp(
            tonumber(State.FarmBasePause) or 2.50,
            1.0,
            5.0
        ))
    end

    if GetBasketCount() <= 0 then
        SetFarmPhase("Entregue - procurando próximo ovo")
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

        -- HOLDING
        if GetBasketCount() > 0 then
            SetFarmPhase("Carrying egg")

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
-- GUI: UI NATIVA ESTÁVEL / ZERO DEPENDÊNCIA
-- A interface não depende de HttpGet/loadstring de biblioteca externa.
-- Mantém a mesma API usada pelo restante do script (Window/Tab/Rayfield.Flags).
--============================================================--

local NativeUI = {}
NativeUI.Flags = {}
NativeUI._windows = {}

local function uiParent()
    local ok, hui = pcall(function()
        if typeof(gethui) == "function" then
            return gethui()
        end
    end)
    if ok and hui then
        return hui
    end

    local okCore, core = pcall(function()
        return game:GetService("CoreGui")
    end)
    if okCore and core then
        return core
    end

    return PlayerGui
end

local function make(className, props, parent)
    local obj = Instance.new(className)
    if props then
        for key, value in pairs(props) do
            pcall(function()
                obj[key] = value
            end)
        end
    end
    obj.Parent = parent
    return obj
end

local function corner(parent, radius)
    return make("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
    }, parent)
end

local function stroke(parent, color, thickness, transparency)
    return make("UIStroke", {
        Color = color or Color3.fromRGB(45, 48, 58),
        Thickness = thickness or 1,
        Transparency = transparency or 0,
    }, parent)
end

local COLORS = {
    bg = Color3.fromRGB(12, 14, 18),
    panel = Color3.fromRGB(18, 21, 27),
    panel2 = Color3.fromRGB(23, 27, 34),
    hover = Color3.fromRGB(31, 36, 46),
    accent = Color3.fromRGB(92, 124, 255),
    accent2 = Color3.fromRGB(73, 102, 230),
    text = Color3.fromRGB(238, 241, 247),
    sub = Color3.fromRGB(153, 160, 175),
    line = Color3.fromRGB(40, 45, 55),
    good = Color3.fromRGB(79, 208, 126),
    bad = Color3.fromRGB(231, 90, 98),
    white = Color3.fromRGB(255, 255, 255),
}

local function tween(obj, props, duration)
    pcall(function()
        TweenService:Create(
            obj,
            TweenInfo.new(duration or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            props
        ):Play()
    end)
end

local function clampNumber(v, a, b)
    local n = tonumber(v) or a
    return math.clamp(n, a, b)
end

local function arrayHas(tbl, value)
    if type(tbl) ~= "table" then
        return false
    end
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

local function clearChildrenOfClass(parent, className)
    for _, c in ipairs(parent:GetChildren()) do
        if c:IsA(className) then
            c:Destroy()
        end
    end
end

local function createFlag(flagName, initialValue, setter)
    if not flagName or flagName == "" then
        return nil
    end

    local flag = NativeUI.Flags[flagName]
    if not flag then
        flag = {}
        NativeUI.Flags[flagName] = flag
    end

    flag.CurrentValue = initialValue
    flag.CurrentOption = initialValue
    flag.CurrentKeybind = initialValue
    flag.Set = function(_, value)
        setter(value, true)
    end

    return flag
end

function NativeUI:CreateWindow(options)
    -- Derruba qualquer janela nativa anterior do próprio hub.
    for _, w in pairs(self._windows) do
        pcall(function()
            if w.Destroy then
                w:Destroy()
            end
        end)
    end
    self._windows = {}

    local gui = make("ScreenGui", {
        Name = "MontarUmPet_NativeUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 1000000,
    }, uiParent())

    local root = make("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.52),
        Size = UDim2.new(0.92, 0, 0.80, 0),
        BackgroundColor3 = COLORS.bg,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, gui)
    corner(root, 12)
    stroke(root, Color3.fromRGB(50, 56, 68), 1)

    local top = make("Frame", {
        Name = "TopBar",
        Size = UDim2.new(1, 0, 0, 58),
        BackgroundColor3 = COLORS.panel,
        BorderSizePixel = 0,
    }, root)

    local title = make("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 16, 0, 7),
        Size = UDim2.new(0.48, 0, 0, 24),
        Font = Enum.Font.GothamBold,
        Text = tostring(options and options.name or "Montar um Pet"),
        TextColor3 = COLORS.text,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, top)

    local subtitle = make("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 16, 0, 31),
        Size = UDim2.new(0.55, 0, 0, 18),
        Font = Enum.Font.Gotham,
        Text = tostring(options and options.subtitle or "MASTER • UI Nativa"),
        TextColor3 = COLORS.sub,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, top)

    local status = make("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -54, 0.5, 0),
        Size = UDim2.new(0, 78, 0, 26),
        BackgroundColor3 = Color3.fromRGB(26, 50, 37),
        Text = "ONLINE",
        Font = Enum.Font.GothamBold,
        TextColor3 = COLORS.good,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Center,
    }, top)
    corner(status, 8)

    local close = make("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.new(0, 30, 0, 30),
        BackgroundColor3 = COLORS.panel2,
        AutoButtonColor = false,
        Text = "×",
        Font = Enum.Font.GothamBold,
        TextColor3 = COLORS.text,
        TextSize = 20,
    }, top)
    corner(close, 8)

    local body = make("Frame", {
        Position = UDim2.new(0, 0, 0, 58),
        Size = UDim2.new(1, 0, 1, -58),
        BackgroundTransparency = 1,
    }, root)

    local sidebarWidth = 148

    local sidebar = make("Frame", {
        Size = UDim2.new(0, sidebarWidth, 1, 0),
        BackgroundColor3 = COLORS.panel,
        BorderSizePixel = 0,
    }, body)

    local sidebarLine = make("Frame", {
        Position = UDim2.new(1, -1, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = COLORS.line,
        BorderSizePixel = 0,
    }, sidebar)

    local tabList = make("ScrollingFrame", {
        Position = UDim2.new(0, 8, 0, 10),
        Size = UDim2.new(1, -16, 1, -20),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = COLORS.accent,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, sidebar)

    local tabLayout = make("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, tabList)

    local content = make("Frame", {
        Position = UDim2.new(0, sidebarWidth, 0, 0),
        Size = UDim2.new(1, -sidebarWidth, 1, 0),
        BackgroundColor3 = COLORS.bg,
        BorderSizePixel = 0,
    }, body)

    local pages = {}
    local pageButtons = {}
    local currentTab

    local function updateCanvas(scroll)
        if not scroll then return end
        local layout = scroll:FindFirstChildOfClass("UIListLayout")
        if layout then
            scroll.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 18)
        end
    end

    local dragging = false
    local dragStart
    local startPos
    local dragConn

    top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = root.Position

            if dragConn then
                dragConn:Disconnect()
            end

            dragConn = UserInputService.InputChanged:Connect(function(changed)
                if not dragging then
                    return
                end
                if changed.UserInputType ~= Enum.UserInputType.MouseMovement
                    and changed.UserInputType ~= Enum.UserInputType.Touch then
                    return
                end

                local delta = changed.Position - dragStart
                root.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            end)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            if dragConn then
                dragConn:Disconnect()
                dragConn = nil
            end
        end
    end)

    local uiVisible = true

    local function setUIVisible(v)
        uiVisible = not not v
        root.Visible = uiVisible
    end

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then
            return
        end
        if input.KeyCode == Enum.KeyCode.K then
            setUIVisible(not uiVisible)
        end
    end)

    local minimized = false
    local normalSize = root.Size

    local minimize = make("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -90, 0.5, 0),
        Size = UDim2.new(0, 30, 0, 30),
        BackgroundColor3 = COLORS.panel2,
        AutoButtonColor = false,
        Text = "–",
        Font = Enum.Font.GothamBold,
        TextColor3 = COLORS.text,
        TextSize = 18,
    }, top)
    corner(minimize, 8)

    local function setMinimized()
        minimized = not minimized
        if minimized then
            normalSize = root.Size
            tween(root, {Size = UDim2.new(0, math.min(380, 520), 0, 58)}, 0.16)
            body.Visible = false
            minimize.Text = "+"
        else
            body.Visible = true
            tween(root, {Size = normalSize}, 0.16)
            minimize.Text = "–"
        end
    end
    minimize.MouseButton1Click:Connect(setMinimized)

    local window = {}
    self._windows[#self._windows + 1] = window

    function window:Notify(data)
        data = data or {}
        local note = make("Frame", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -14, 0, 72),
            Size = UDim2.new(0, 270, 0, 72),
            BackgroundColor3 = COLORS.panel2,
            BorderSizePixel = 0,
            ZIndex = 2000,
        }, gui)
        corner(note, 10)
        stroke(note, COLORS.line, 1)

        make("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 12, 0, 8),
            Size = UDim2.new(1, -24, 0, 20),
            Font = Enum.Font.GothamBold,
            Text = tostring(data.title or "Montar um Pet"),
            TextColor3 = COLORS.text,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 2001,
        }, note)

        make("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 12, 0, 29),
            Size = UDim2.new(1, -24, 0, 36),
            Font = Enum.Font.Gotham,
            Text = tostring(data.content or ""),
            TextWrapped = true,
            TextColor3 = COLORS.sub,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            ZIndex = 2001,
        }, note)

        task.delay(tonumber(data.duration) or 3, function()
            pcall(function()
                tween(note, {BackgroundTransparency = 1}, 0.15)
                task.wait(0.16)
                note:Destroy()
            end)
        end)
    end

    function window:Destroy()
        pcall(function()
            if dragConn then
                dragConn:Disconnect()
                dragConn = nil
            end
        end)
        pcall(function()
            if gui then
                gui:Destroy()
            end
        end)
    end

    close.MouseButton1Click:Connect(function()
        Running = false
        if StopHandler then
            task.spawn(function()
                pcall(StopHandler)
            end)
        end
        window:Destroy()
    end)

    function window:CreateTab(tabOptions)
        local tabName = tostring((tabOptions and tabOptions.name) or "Tab")

        local page = make("ScrollingFrame", {
            Name = "Page_" .. tabName:gsub("%W", ""),
            Size = UDim2.new(1, -22, 1, -18),
            Position = UDim2.new(0, 11, 0, 9),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = COLORS.accent,
            CanvasSize = UDim2.new(),
            Visible = false,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
        }, content)

        local layout = make("UIListLayout", {
            Padding = UDim.new(0, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, page)

        local pad = make("UIPadding", {
            PaddingTop = UDim.new(0, 2),
            PaddingBottom = UDim.new(0, 10),
        }, page)

        local button = make("TextButton", {
            Size = UDim2.new(1, 0, 0, 38),
            BackgroundColor3 = COLORS.panel,
            AutoButtonColor = false,
            Text = tabName,
            Font = Enum.Font.GothamMedium,
            TextColor3 = COLORS.sub,
            TextSize = 12,
        }, tabList)
        corner(button, 8)

        local tab = {
            _page = page,
            _button = button,
            _layout = layout,
        }

        local function select()
            for _, record in pairs(pages) do
                record.page.Visible = false
            end
            for _, b in pairs(pageButtons) do
                b.BackgroundColor3 = COLORS.panel
                b.TextColor3 = COLORS.sub
            end

            page.Visible = true
            button.BackgroundColor3 = COLORS.hover
            button.TextColor3 = COLORS.text
            currentTab = tabName
        end

        button.MouseButton1Click:Connect(select)

        pages[tabName] = {page = page, tab = tab}
        pageButtons[tabName] = button

        local function addBox(height)
            local box = make("Frame", {
                Size = UDim2.new(1, 0, 0, height or 54),
                BackgroundColor3 = COLORS.panel,
                BorderSizePixel = 0,
            }, page)
            corner(box, 9)
            stroke(box, COLORS.line, 1)
            return box
        end

        function tab:CreateSection(o)
            local text = tostring((o and o.name) or "Seção")
            local box = make("TextLabel", {
                Size = UDim2.new(1, 0, 0, 28),
                BackgroundTransparency = 1,
                Font = Enum.Font.GothamBold,
                Text = text,
                TextColor3 = COLORS.accent,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, page)
            return box
        end

        function tab:CreateLabel(text)
            local box = make("TextLabel", {
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundTransparency = 1,
                Font = Enum.Font.Gotham,
                Text = tostring(text or ""),
                TextColor3 = COLORS.sub,
                TextSize = 11,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, page)
            return box
        end

        function tab:CreateButton(o)
            o = o or {}
            local box = addBox(54)
            local b = make("TextButton", {
                Position = UDim2.new(0, 10, 0, 7),
                Size = UDim2.new(1, -20, 0, 40),
                BackgroundColor3 = COLORS.panel2,
                AutoButtonColor = false,
                Text = tostring(o.name or "Button"),
                Font = Enum.Font.GothamMedium,
                TextColor3 = COLORS.text,
                TextSize = 12,
            }, box)
            corner(b, 8)
            b.MouseEnter:Connect(function() tween(b, {BackgroundColor3 = COLORS.hover}, 0.08) end)
            b.MouseLeave:Connect(function() tween(b, {BackgroundColor3 = COLORS.panel2}, 0.08) end)
            b.MouseButton1Click:Connect(function()
                pcall(o.callback)
            end)
            return b
        end

        function tab:CreateToggle(o)
            o = o or {}
            local value = not not o.value
            local box = addBox(58)
            local label = make("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 7),
                Size = UDim2.new(1, -92, 0, 20),
                Font = Enum.Font.GothamMedium,
                Text = tostring(o.name or "Toggle"),
                TextColor3 = COLORS.text,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, box)

            local desc = make("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 28),
                Size = UDim2.new(1, -104, 0, 18),
                Font = Enum.Font.Gotham,
                Text = tostring(o.description or ""),
                TextColor3 = COLORS.sub,
                TextSize = 9,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }, box)

            local btn = make("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -12, 0.5, 0),
                Size = UDim2.new(0, 48, 0, 26),
                BackgroundColor3 = COLORS.line,
                AutoButtonColor = false,
                Text = "",
            }, box)
            corner(btn, 13)

            local dot = make("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 3, 0.5, 0),
                Size = UDim2.new(0, 20, 0, 20),
                BackgroundColor3 = COLORS.sub,
                BorderSizePixel = 0,
            }, btn)
            corner(dot, 10)

            local function render()
                btn.BackgroundColor3 = value and COLORS.accent2 or COLORS.line
                dot.Position = value and UDim2.new(1, -23, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
                dot.BackgroundColor3 = value and COLORS.white or COLORS.sub
            end

            local function setValue(v, fire)
                value = not not v
                render()
                local flag = o.flag and NativeUI.Flags[o.flag]
                if flag then
                    flag.CurrentValue = value
                    flag.CurrentOption = value
                end
                if fire and o.callback then
                    pcall(o.callback, value)
                end
            end

            createFlag(o.flag, value, setValue)

            btn.MouseButton1Click:Connect(function()
                setValue(not value, true)
            end)
            render()

            return btn
        end

        function tab:CreateSlider(o)
            o = o or {}
            local range = o.range or {0, 100}
            local minV = tonumber(range[1]) or 0
            local maxV = tonumber(range[2]) or 100
            local increment = tonumber(o.increment) or 1
            local value = clampNumber(o.value, minV, maxV)

            local box = addBox(68)
            make("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 8),
                Size = UDim2.new(0.62, 0, 0, 20),
                Font = Enum.Font.GothamMedium,
                Text = tostring(o.name or "Slider"),
                TextColor3 = COLORS.text,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, box)

            local valueLabel = make("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -12, 0, 8),
                Size = UDim2.new(0.30, 0, 0, 20),
                Font = Enum.Font.GothamBold,
                TextColor3 = COLORS.accent,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Right,
            }, box)

            local bar = make("TextButton", {
                Position = UDim2.new(0, 12, 0, 37),
                Size = UDim2.new(1, -24, 0, 12),
                BackgroundColor3 = COLORS.line,
                AutoButtonColor = false,
                Text = "",
            }, box)
            corner(bar, 6)

            local fill = make("Frame", {
                Size = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = COLORS.accent,
                BorderSizePixel = 0,
            }, bar)
            corner(fill, 6)

            local knob = make("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0, 0, 0.5, 0),
                Size = UDim2.new(0, 16, 0, 16),
                BackgroundColor3 = COLORS.white,
                BorderSizePixel = 0,
            }, bar)
            corner(knob, 8)

            local draggingSlider = false

            local function quantize(v)
                local steps = math.floor(((v - minV) / increment) + 0.5)
                return math.clamp(minV + steps * increment, minV, maxV)
            end

            local function render()
                local alpha = maxV == minV and 0 or (value - minV) / (maxV - minV)
                fill.Size = UDim2.new(alpha, 0, 1, 0)
                knob.Position = UDim2.new(alpha, 0, 0.5, 0)
                valueLabel.Text = tostring(math.floor(value * 100) / 100) .. tostring(o.suffix or "")
            end

            local function setValue(v, fire)
                value = quantize(clampNumber(v, minV, maxV))
                render()
                local flag = o.flag and NativeUI.Flags[o.flag]
                if flag then
                    flag.CurrentValue = value
                    flag.CurrentOption = value
                end
                if fire and o.callback then
                    pcall(o.callback, value)
                end
            end

            createFlag(o.flag, value, setValue)

            local function setFromInput(x)
                local alpha = math.clamp(
                    (x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1),
                    0, 1
                )
                setValue(minV + (maxV - minV) * alpha, true)
            end

            bar.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    draggingSlider = true
                    setFromInput(input.Position.X)
                end
            end)

            UserInputService.InputChanged:Connect(function(input)
                if not draggingSlider then return end
                if input.UserInputType == Enum.UserInputType.MouseMovement
                    or input.UserInputType == Enum.UserInputType.Touch then
                    setFromInput(input.Position.X)
                end
            end)

            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    draggingSlider = false
                end
            end)

            render()
            return bar
        end

        function tab:CreateInput(o)
            o = o or {}
            local value = tostring(o.value or "")
            local box = addBox(64)

            make("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 7),
                Size = UDim2.new(0.45, 0, 0, 20),
                Font = Enum.Font.GothamMedium,
                Text = tostring(o.name or "Input"),
                TextColor3 = COLORS.text,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, box)

            local input = make("TextBox", {
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -10, 0, 7),
                Size = UDim2.new(0.50, 0, 0, 34),
                BackgroundColor3 = COLORS.panel2,
                Text = value,
                PlaceholderText = tostring(o.placeholder or ""),
                ClearTextOnFocus = false,
                Font = Enum.Font.Gotham,
                TextColor3 = COLORS.text,
                PlaceholderColor3 = COLORS.sub,
                TextSize = 11,
            }, box)
            corner(input, 8)

            make("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 34),
                Size = UDim2.new(0.42, 0, 0, 22),
                Font = Enum.Font.Gotham,
                Text = tostring(o.description or ""),
                TextColor3 = COLORS.sub,
                TextSize = 8,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, box)

            local function setValue(v, fire)
                value = tostring(v or "")
                input.Text = value
                local flag = o.flag and NativeUI.Flags[o.flag]
                if flag then
                    flag.CurrentValue = value
                    flag.CurrentOption = value
                end
                if fire and o.callback then
                    pcall(o.callback, value)
                end
            end

            createFlag(o.flag, value, setValue)

            input.FocusLost:Connect(function()
                setValue(input.Text, true)
            end)

            return input
        end

        function tab:CreateDropdown(o)
            o = o or {}
            local optionsList = {}
            for _, option in ipairs(o.options or {}) do
                optionsList[#optionsList + 1] = tostring(option)
            end

            local multi = o.multiSelect == true
            local selected = {}

            if multi then
                for _, v in ipairs(o.value or {}) do
                    selected[tostring(v)] = true
                end
            else
                local initial = o.value
                if initial ~= nil then
                    selected[tostring(initial)] = true
                elseif optionsList[1] then
                    selected[optionsList[1]] = true
                end
            end

            local expanded = false
            local box = addBox(58)

            make("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 7),
                Size = UDim2.new(1, -24, 0, 20),
                Font = Enum.Font.GothamMedium,
                Text = tostring(o.name or "Dropdown"),
                TextColor3 = COLORS.text,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, box)

            local selectButton = make("TextButton", {
                Position = UDim2.new(0, 10, 0, 29),
                Size = UDim2.new(1, -20, 0, 26),
                BackgroundColor3 = COLORS.panel2,
                AutoButtonColor = false,
                Text = "",
                Font = Enum.Font.Gotham,
                TextColor3 = COLORS.text,
                TextSize = 10,
            }, box)
            corner(selectButton, 7)

            local summary = make("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 9, 0, 0),
                Size = UDim2.new(1, -18, 1, 0),
                Font = Enum.Font.Gotham,
                TextColor3 = COLORS.sub,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }, selectButton)

            local listFrame

            local function currentValue()
                if multi then
                    local t = {}
                    for _, opt in ipairs(optionsList) do
                        if selected[opt] then
                            t[#t + 1] = opt
                        end
                    end
                    return t
                end

                for _, opt in ipairs(optionsList) do
                    if selected[opt] then
                        return opt
                    end
                end
                return nil
            end

            local function renderSummary()
                if multi then
                    local vals = currentValue()
                    if #vals == 0 then
                        summary.Text = tostring(o.placeholder or "Nenhuma")
                    elseif #vals <= 2 then
                        summary.Text = table.concat(vals, ", ")
                    else
                        summary.Text = tostring(#vals) .. " selecionados"
                    end
                else
                    summary.Text = tostring(currentValue() or o.placeholder or "Selecionar")
                end
            end

            local function fire()
                local v = currentValue()
                local flag = o.flag and NativeUI.Flags[o.flag]
                if flag then
                    flag.CurrentValue = v
                    flag.CurrentOption = v
                end
                if o.callback then
                    pcall(o.callback, v)
                end
            end

            local function rebuildList()
                if listFrame then
                    listFrame:Destroy()
                    listFrame = nil
                end

                if not expanded then
                    box.Size = UDim2.new(1, 0, 0, 58)
                    return
                end

                local rows = math.max(#optionsList, 1)
                local listHeight = math.min(rows * 30 + 4, 190)

                box.Size = UDim2.new(1, 0, 0, 58 + listHeight)

                listFrame = make("Frame", {
                    Position = UDim2.new(0, 10, 0, 58),
                    Size = UDim2.new(1, -20, 0, listHeight),
                    BackgroundColor3 = COLORS.panel2,
                    BorderSizePixel = 0,
                }, box)
                corner(listFrame, 8)
                stroke(listFrame, COLORS.line, 1)

                local sc = make("ScrollingFrame", {
                    Size = UDim2.new(1, -8, 1, -8),
                    Position = UDim2.new(0, 4, 0, 4),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    ScrollBarThickness = 2,
                    CanvasSize = UDim2.new(0, 0, 0, rows * 30),
                }, listFrame)

                local ll = make("UIListLayout", {
                    Padding = UDim.new(0, 2),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }, sc)

                for _, option in ipairs(optionsList) do
                    local item = make("TextButton", {
                        Size = UDim2.new(1, -2, 0, 28),
                        BackgroundColor3 = selected[option] and COLORS.hover or COLORS.panel2,
                        AutoButtonColor = false,
                        Text = (selected[option] and "✓  " or "    ") .. option,
                        Font = Enum.Font.Gotham,
                        TextColor3 = selected[option] and COLORS.text or COLORS.sub,
                        TextSize = 10,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    }, sc)
                    corner(item, 6)

                    item.MouseButton1Click:Connect(function()
                        if multi then
                            selected[option] = not selected[option]
                            renderSummary()
                            fire()
                            rebuildList()
                        else
                            for k in pairs(selected) do
                                selected[k] = nil
                            end
                            selected[option] = true
                            expanded = false
                            renderSummary()
                            fire()
                            rebuildList()
                        end
                    end)
                end
            end

            local function setValue(v, fireCallback)
                for k in pairs(selected) do
                    selected[k] = nil
                end

                if multi then
                    for _, item in ipairs(v or {}) do
                        selected[tostring(item)] = true
                    end
                else
                    if v ~= nil then
                        selected[tostring(v)] = true
                    end
                end

                renderSummary()
                if fireCallback then
                    fire()
                end
                rebuildList()
            end

            createFlag(o.flag, currentValue(), setValue)

            selectButton.MouseButton1Click:Connect(function()
                expanded = not expanded
                rebuildList()
            end)

            renderSummary()
            rebuildList()
            return selectButton
        end

        -- Recalcula o canvas após alterações de altura (especialmente dropdowns).
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            updateCanvas(page)
        end)

        task.defer(function()
            updateCanvas(page)
        end)

        if not currentTab then
            select()
        end

        return tab
    end

    -- API de configuração.
    function self:SaveConfiguration()
        return true
    end

    function self:LoadConfiguration()
        return true
    end

    function self:Destroy()
        window:Destroy()
    end

    return window
end

-- A partir daqui o restante do v15 usa a mesma API, mas com UI nativa.
local Rayfield = NativeUI

local okWindow, Window = pcall(function()
    return NativeUI:CreateWindow({
        name = "Montar um Pet",
        subtitle = "MASTER v21 • UI Nativa • Mobile/PC",
    })
end)

if not okWindow or not Window then
    Running = false
    pcall(function()
        if GuardConnection then
            GuardConnection:Disconnect()
        end
        if Guard then
            Guard:Destroy()
        end
    end)
    warn("Montar um Pet: não foi possível criar a UI nativa.")
    return
end

if not Running or (tonumber(ControlFolder:GetAttribute("Generation")) or 0) ~= MY_GENERATION then
    pcall(function()
        Window:Destroy()
    end)
    return
end

--============================================================--
-- TABS
--============================================================--

local TabInicio = Window:CreateTab({name = "Início"})
local TabFarm = Window:CreateTab({name = "Farm"})
local TabOvos = Window:CreateTab({name = "Ovos"})
local TabMove = Window:CreateTab({name = "Movimento"})
local TabVisual = Window:CreateTab({name = "Visual"})
local TabPerf = Window:CreateTab({name = "Performance"})
local TabConfig = Window:CreateTab({name = "Config"})

TabInicio:CreateSection({name = "Montar um Pet • MASTER v21"})
TabInicio:CreateLabel("UI nativa sem dependência de Rayfield/WindUI. Feita para Delta Mobile e PC, com rolagem, toque, arrastar, minimizar e singleton de uma única janela.")
TabInicio:CreateLabel("Status: interface carregada. Use a aba Farm para automação e Movimento para voo/velocidade.")
TabInicio:CreateButton({
    name = "Ativar Auto Farm",
    description = "Liga o Auto Farm imediatamente.",
    callback = function()
        State.AutoFarm = true
        pcall(StartFarmNoclip)
        pcall(ClearFarmTarget)
        State.FarmPhase = "Starting"
        LastFarmStatus = "Starting Auto Farm"
        task.spawn(function()
            task.wait(0.05)
            if Running and State.AutoFarm and not FarmBusy then
                pcall(FarmOnce)
            end
        end)
    end,
})

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
            task.spawn(function()
                task.wait(0.05)
                if Running and State.AutoFarm and not FarmBusy then
                    FarmOnce()
                end
            end)
        else
            CancelGlide()
            DestroyFarmFlightMovers()
            StopFarmNoclip()
            ClearFarmTarget()
            State.FarmPhase = "Stopped"
            FarmBusy = false
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
    range = {50, 1200},
    increment = 25,
    value = State.FarmFlightSpeed,
    suffix = " studs/s",
    callback = function(value)
        State.FarmFlightSpeed = math.clamp(
            math.floor(tonumber(value) or 300),
            50,
            1200
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
        FarmBusy = false
        PickupBusy = false
        CancelGlide()
    end,
})

TabFarm:CreateButton({
    name = "Montar melhor pet agora",
    callback = function()
        MountBestPet()
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
-- LOOPS CENTRALIZADOS
--============================================================--

local FarmLoop = task.spawn(function()
    while Running do
        task.wait(
            math.clamp(
                tonumber(State.FarmLoopDelay) or 0.10,
                0.05,
                0.50
            )
        )

        if Running and State.AutoFarm and not FarmBusy then
            FarmOnce()
        end
    end
end)

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

