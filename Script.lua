--============================================================--
-- MONTAR UM PET - MASTER v15.2026 AUTOFARM + PROGRESSION + DYNAMIC GAME API
-- PlaceId: 124216119978534
-- UI: Native Delta Mobile 2026 (no external UI dependency)
-- Config: salvamento manual + persistência do Rayfield + flags 2026
-- Foco: Delta Mobile + Auto Farm por estados + camada 2026 dinâmica + cleanup robusto
--
-- Pesquisa usada para esta versão:
--   * VintHub / Ride a Pet.lua
--   * Iamdungx / roblox-lua / ride-a-pet.lua
--   * SixZensED / sixly-script / games/ride-a-pet.lua
--   * Bac0nHck / Scripts / rideapet.lua (interface dinâmica 2026)
--
-- Mecânicas implementadas com base em caminhos/remotes encontrados
-- publicamente: Game.EggPickup, Game.Mounting, GameData.Eggs,
-- ServerData.ActiveEggs, Plots.NestsOwnerLoaded, InVolcano, IsRiding.
--
-- Recursos 2026 com schema/remotes atuais foram adicionados dinamicamente.
-- Rebirth/Radar/Luck/Unlock que não possuem contrato confirmado permanecem
-- em modo de diagnóstico, sem chamadas inventadas.
--============================================================--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")

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
    "__MONTAR_UM_PET_MASTER_V15_2026",
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
    "MontarUmPet_2026_DeltaUI",
}

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

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
                or t:find("MASTER v15", 1, true)
                or t:find("MASTER v15.2026", 1, true) then
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
-- V15.2026 CORE - camada dinâmica baseada nos GameData/remotes atuais
-- Recursos: mount mais rápido, auto place, auto hatch, best pets,
-- favorite, feed, buy food, sell, server-hop/rejoin e automação orquestrada.
-- Recursos sem schema confirmado continuam como "probe only".
--============================================================--

local TeleportService = game:GetService("TeleportService")

State.Automation2026 = false
State.AutoCollect2026 = true
State.AutoPlace2026 = true
State.AutoHatch2026 = true
State.AutoBest2026 = true
State.AutoFeed2026 = false
State.AutoBuyFood2026 = false
State.AutoFavorite2026 = false
State.AutoSell2026 = false
State.BestMetric2026 = "Speed"
State.MaxPets2026 = 5
State.FeedFood2026 = "Any"
State.FavoriteRarities2026 = {
    Common = false,
    Rare = false,
    Epic = false,
    Legendary = true,
    Mythic = true,
    Ethereal = true,
    Divine = true,
}
State.AdvancedLoopDelay = 0.45
State.AdvancedCollectDelay = 0.30
State.AdvancedPlaceDelay = 0.70
State.AdvancedReturnToPlot = true
State.ServerHopOnFail = false
State.ServerHopDelay = 45

local Advanced = {
    Data = {},
    Services = {},
    Names = {Pets = {}, Food = {}, Mutations = {}},
    LastAction = "Ready",
    LastError = nil,
    SellAPI = nil,
    SellDialogue = nil,
    SellDialogueRevision = 0,
    SellConnected = false,
    Running = true,
}

local function AdvancedRequire(parent, childName)
    local module = parent and parent:FindFirstChild(childName)
    if not module or not module:IsA("ModuleScript") then
        return nil
    end
    local ok, value = pcall(require, module)
    if ok and type(value) == "table" then
        return value
    end
    return nil
end

local function AdvancedLoadData()
    local gameData = ReplicatedStorage:FindFirstChild("GameData")
    Advanced.Data.Eggs = EggData
    Advanced.Data.Pets = AdvancedRequire(gameData, "Pets") or {}
    Advanced.Data.General = AdvancedRequire(gameData, "General") or {}
    Advanced.Data.Mutations = AdvancedRequire(gameData, "Mutations") or {}
    Advanced.Data.EggBaskets = AdvancedRequire(gameData, "EggBaskets") or {}
    Advanced.Data.IndexRewards = AdvancedRequire(gameData, "IndexRewards") or {}
    Advanced.Data.Foods = AdvancedRequire(gameData, "Foods") or {}
    Advanced.Data.Shop = AdvancedRequire(gameData, "Shop") or {}

    local gameServices = ReplicatedStorage:FindFirstChild("GameServices")
    Advanced.Services.PetAging = AdvancedRequire(gameServices, "PetAging") or AdvancedRequire(gameData, "PetAging") or {}
    Advanced.Services.DayNight = AdvancedRequire(gameServices, "DayNight") or AdvancedRequire(gameData, "DayNight") or {}

    table.clear(Advanced.Names.Pets)
    for name, data in pairs(Advanced.Data.Pets) do
        if type(name) == "string" and type(data) == "table" and data.Rarity then
            table.insert(Advanced.Names.Pets, name)
        end
    end
    table.sort(Advanced.Names.Pets)

    table.clear(Advanced.Names.Mutations)
    for name in pairs(Advanced.Data.Mutations) do
        if type(name) == "string" then
            table.insert(Advanced.Names.Mutations, name)
        end
    end
    table.sort(Advanced.Names.Mutations)

    table.clear(Advanced.Names.Food)
    local shopFood = type(Advanced.Data.Shop.Food) == "table" and Advanced.Data.Shop.Food or {}
    for name in pairs(shopFood) do
        if type(name) == "string" then
            table.insert(Advanced.Names.Food, name)
        end
    end
    table.sort(Advanced.Names.Food)

    return true
end

AdvancedLoadData()

function Advanced:GetRemotes()
    return GetGameRemotes()
end

function Advanced:GetRemote(name)
    local remotes = self:GetRemotes()
    local remote = remotes and remotes:FindFirstChild(name)
    if remote and remote:IsA("RemoteEvent") then
        return remote
    end
    return nil
end

function Advanced:Fire(name, ...)
    local remote = self:GetRemote(name)
    if not remote then
        return false, "Remote não encontrado: " .. tostring(name)
    end
    local ok, err = pcall(function()
        remote:FireServer(...)
    end)
    if not ok then
        return false, tostring(err)
    end
    return true
end

function Advanced:Value(name, default)
    local value = LocalPlayer:GetAttribute(name)
    if value ~= nil then
        return value
    end

    local saved = ReplicatedStorage:FindFirstChild("SavedData")
    if saved then
        local localData = saved:FindFirstChild(LocalPlayer.Name)
        if localData then
            local child = localData:FindFirstChild(name, true)
            if child then
                if child:IsA("ValueBase") then
                    return child.Value
                end
                local attr = child:GetAttribute("Value")
                if attr ~= nil then
                    return attr
                end
            end
        end
        local child = saved:FindFirstChild(name, true)
        if child and child:IsA("ValueBase") then
            return child.Value
        end
    end

    return default
end

function Advanced:Tools()
    local result = {}
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    local character = LocalPlayer.Character
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then result[#result + 1] = item end
        end
    end
    if character then
        for _, item in ipairs(character:GetChildren()) do
            if item:IsA("Tool") then result[#result + 1] = item end
        end
    end
    return result
end

function Advanced:Equip(tool)
    if not tool then return false end
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    local ok = pcall(function() humanoid:EquipTool(tool) end)
    return ok
end

function Advanced:IsPlaced(petKey)
    local plot = GetMyPlot()
    if not plot or not petKey then return false end
    for _, obj in ipairs(plot:GetDescendants()) do
        if obj:GetAttribute("PetKey") == petKey then
            return true
        end
    end
    return false
end

function Advanced:PetList()
    local result = {}
    local pets = Advanced.Data.Pets or {}

    for _, tool in ipairs(self:Tools()) do
        local key = tool:GetAttribute("PetKey")
        local name = tool:GetAttribute("PetName") or tool.Name
        local data = pets[name]
        if key and type(data) == "table" then
            local weight = tonumber(tool:GetAttribute("Weight")) or 0
            local age = tonumber(tool:GetAttribute("Age")) or 0
            local mutation = tool:GetAttribute("Mutation")
            local spawnMutation = tool:GetAttribute("SpawnMutation")
            local factor = 1

            local mutations = Advanced.Data.Mutations
            if type(mutations.CombinedFactor) == "function" then
                pcall(function()
                    factor = tonumber(mutations.CombinedFactor(mutation, spawnMutation)) or 1
                end)
            end

            local speed = tonumber(data.Speed) or 0
            if type(Advanced.Services.PetAging.DisplaySpeedFor) == "function" then
                pcall(function()
                    speed = tonumber(Advanced.Services.PetAging.DisplaySpeedFor(data.Speed, weight)) or speed
                end)
            end

            local income = 0
            if type(data.Income) == "number" then
                income = data.Income * factor
            elseif type(Advanced.Data.General.PetIncomeFor) == "function" then
                pcall(function()
                    income = tonumber(Advanced.Data.General.PetIncomeFor(data, weight, age, mutation, spawnMutation)) or 0
                end)
            end

            result[#result + 1] = {
                Key = tostring(key),
                Name = tostring(name),
                Rarity = tostring(data.Rarity or "Unknown"),
                Weight = weight,
                Age = age,
                Mutation = mutation,
                SpawnMutation = spawnMutation,
                Speed = speed,
                Income = income,
                Tool = tool,
                Placed = self:IsPlaced(key),
                Favorite = tool:GetAttribute("Favorited") == true,
            }
        end
    end

    return result
end

function Advanced:Basket()
    local basket = LocalPlayer:FindFirstChild("Basket")
    local result = {}
    if not basket then return result end
    for _, item in ipairs(basket:GetChildren()) do
        result[#result + 1] = item
    end
    return result
end

function Advanced:Capacity()
    local basketName = LocalPlayer:GetAttribute("EquippedEggBasket")
    local baskets = Advanced.Data.EggBaskets or {}
    local data = basketName and baskets[basketName]
    if type(data) == "table" and tonumber(data.Capacity) then
        return tonumber(data.Capacity)
    end
    return tonumber(self:Value("EggBasketCapacity", 5)) or 5
end

function Advanced:EggTools()
    local result = {}
    local eggData = Advanced.Data.Eggs or {}
    for _, tool in ipairs(self:Tools()) do
        if eggData[tool.Name] and tool:GetAttribute("PetName") == nil then
            result[#result + 1] = tool
        end
    end
    return result
end

function Advanced:FreeNests()
    local plot = GetMyPlot()
    local result = {}
    local nests = plot and plot:FindFirstChild("Nests")
    if not nests then return result end
    for _, nest in ipairs(nests:GetChildren()) do
        if nest:GetAttribute("Unlocked") == true and nest:GetAttribute("Occupied") ~= true then
            result[#result + 1] = nest
        end
    end
    table.sort(result, function(a,b) return a.Name < b.Name end)
    return result
end

function Advanced:EggTimers()
    local plot = GetMyPlot()
    local eggsFolder = plot and plot:FindFirstChild("Eggs")
    local result = {}
    if not eggsFolder then return result end

    local general = Advanced.Data.General or {}
    for _, egg in ipairs(eggsFolder:GetChildren()) do
        local data = egg:FindFirstChild("EggData")
        local eggName = egg:GetAttribute("Egg") or egg.Name
        local placeTime = data and (data:GetAttribute("PlaceTime") or data:GetAttribute("PlacedAt"))
        local weight = data and (data:GetAttribute("Weight") or egg:GetAttribute("Weight")) or egg:GetAttribute("Weight")
        local growth = 0

        if type(general.GrowthTimeFor) == "function" then
            pcall(function()
                growth = tonumber(general.GrowthTimeFor(eggName, weight)) or 0
            end)
        end
        if growth <= 0 then
            local eggDefinition = Advanced.Data.Eggs and Advanced.Data.Eggs[eggName]
            if type(eggDefinition) == "table" then
                growth = tonumber(eggDefinition.GrowthTime or eggDefinition.HatchTime or eggDefinition.Growth) or 0
            end
        end

        local remaining = math.huge
        if tonumber(placeTime) and growth > 0 then
            local now
            pcall(function() now = workspace:GetServerTimeNow() end)
            now = tonumber(now) or os.time()
            remaining = math.max(0, growth - (now - tonumber(placeTime)))
        elseif egg:GetAttribute("Ready") == true or egg:GetAttribute("ReadyToHatch") == true then
            remaining = 0
        end

        result[#result + 1] = {
            Object = egg,
            Key = tostring(egg:GetAttribute("EggKey") or egg.Name),
            Name = tostring(eggName),
            Remaining = remaining,
        }
    end

    table.sort(result, function(a,b) return a.Remaining < b.Remaining end)
    return result
end

function Advanced:PlaceEggs(limit)
    local tools = self:EggTools()
    local nests = self:FreeNests()
    local count = math.min(#tools, #nests, tonumber(limit) or math.huge)
    if count <= 0 then return false end

    local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end

    local placed = 0
    for i = 1, count do
        if not Running or not State.Automation2026 then break end
        local tool, nest = tools[i], nests[i]
        if tool and nest then
            if self:Equip(tool) then
                task.wait(0.15)
                local ok = self:Fire("EggPlaced", {NestId = nest.Name})
                if ok then
                    local deadline = os.clock() + 2.5
                    while Running and os.clock() < deadline do
                        if nest:GetAttribute("Occupied") == true then
                            placed += 1
                            break
                        end
                        task.wait(0.05)
                    end
                end
                task.wait(State.AdvancedPlaceDelay)
            end
        end
    end
    self.LastAction = "Placed " .. tostring(placed) .. " egg(s)"
    return placed > 0
end

function Advanced:HatchReady()
    local timers = self:EggTimers()
    local hatched = 0
    for _, egg in ipairs(timers) do
        if not Running or not State.Automation2026 then break end
        if egg.Remaining <= 0 then
            local ok = self:Fire("Hatch", {EggKey = egg.Key})
            if ok then
                local deadline = os.clock() + 3
                while Running and os.clock() < deadline do
                    if not egg.Object.Parent then
                        hatched += 1
                        break
                    end
                    task.wait(0.05)
                end
            end
        end
    end
    self.LastAction = "Hatched " .. tostring(hatched) .. " ready egg(s)"
    return hatched > 0
end

function Advanced:PlaceBestPets()
    local pets = self:PetList()
    local metric = State.BestMetric2026 == "Income" and "Income" or "Speed"
    table.sort(pets, function(a,b)
        local av, bv = tonumber(a[metric]) or 0, tonumber(b[metric]) or 0
        if av == bv then return a.Key < b.Key end
        return av > bv
    end)

    local capacity = math.clamp(math.floor(tonumber(State.MaxPets2026) or 5), 1, 100)
    local desired = {}
    local selected = 0
    for _, pet in ipairs(pets) do
        if selected >= capacity then break end
        desired[pet.Key] = true
        selected += 1
    end

    for _, pet in ipairs(pets) do
        if pet.Placed and not desired[pet.Key] then
            self:Fire("PickupPet", pet.Key)
            task.wait(0.15)
        end
    end

    local plot = GetMyPlot()
    local base = plot and plot:FindFirstChild("Baseplate")
    if not base then return false end

    local placed = 0
    local cols = math.max(1, math.ceil(math.sqrt(selected)))
    local spacing = math.min(9, (math.min(base.Size.X, base.Size.Z) - 12) / cols)
    for i, pet in ipairs(pets) do
        if i > capacity then break end
        local tool = pet.Tool
        if tool and tool.Parent then
            self:Equip(tool)
            task.wait(0.12)
            local pos = (base.CFrame * CFrame.new(
                ((i - 1) % cols - (cols - 1) / 2) * spacing,
                4,
                math.floor((i - 1) / cols) * spacing
            )).Position
            local ok = self:Fire("PlacePet", pet.Key, pos)
            if ok then placed += 1 end
            task.wait(0.12)
        end
    end

    self.LastAction = "Best pets: " .. metric .. " | placed=" .. tostring(placed)
    return placed > 0
end

function Advanced:FoodStock(name)
    local inventory = LocalPlayer:FindFirstChild("Food") or LocalPlayer:FindFirstChild("Foods")
    if inventory then
        local item = inventory:FindFirstChild(name)
        if item then
            if item:IsA("ValueBase") then return tonumber(item.Value) or 0 end
            return tonumber(item:GetAttribute("Amount")) or 0
        end
    end
    return nil
end

function Advanced:NextFood()
    if State.FeedFood2026 ~= "Any" then
        return State.FeedFood2026
    end
    for _, name in ipairs(Advanced.Names.Food) do
        local stock = self:FoodStock(name)
        if stock == nil or stock > 0 then
            return name
        end
    end
    return nil
end

function Advanced:BuyFoodOne()
    local name = self:NextFood()
    if not name then return false end
    local ok = self:Fire("BuyWithCash", "Food", name)
    if ok then
        self.LastAction = "Buying food: " .. name
    end
    return ok
end

function Advanced:FeedOne()
    local food = self:NextFood()
    if not food then return false end
    local maxAge = tonumber(Advanced.Services.PetAging.MaxAge) or 100
    for _, pet in ipairs(self:PetList()) do
        if pet.Age < maxAge then
            local ok = self:Fire("FeedPet", pet.Key, food)
            if ok then
                self.LastAction = "Fed " .. pet.Name .. " with " .. food
                return true
            end
        end
    end
    return false
end

function Advanced:FavoriteOne()
    for _, pet in ipairs(self:PetList()) do
        if not pet.Favorite and State.FavoriteRarities2026[pet.Rarity] then
            local ok = self:Fire("FavoritePet", pet.Key)
            if ok then
                self.LastAction = "Favorited " .. pet.Name
                return true
            end
        end
    end
    return false
end

function Advanced:InitSell()
    if self.SellAPI and self.SellConnected then return true end
    local dialogue = ReplicatedStorage:FindFirstChild("Dialogue")
    local modules = dialogue and dialogue:FindFirstChild("Modules")
    local module = modules and modules:FindFirstChild("DialogueModule")
    local remotes = dialogue and dialogue:FindFirstChild("Remotes")
    if not module or not remotes then return false end
    local ok, api = pcall(require, module)
    if not ok or type(api) ~= "table" or type(api.SelectOption) ~= "function" then return false end
    self.SellAPI = api

    if not self.SellConnected then
        for _, remoteName in ipairs({"DialogueSend", "DialogueUpdate"}) do
            local remote = remotes:FindFirstChild(remoteName)
            if not remote or not remote:IsA("RemoteEvent") then return false end
            Track(remote.OnClientEvent:Connect(function(data)
                self.SellDialogue = type(data) == "table" and data or nil
                self.SellDialogueRevision += 1
            end))
        end
        self.SellConnected = true
    end
    return true
end

function Advanced:SellOne()
    if not self:InitSell() or type(fireproximityprompt) ~= "function" then return false end
    local stall = workspace:FindFirstChild("Stalls")
    local sell = stall and stall:FindFirstChild("Sell")
    local npc = sell and sell:FindFirstChild("Richie")
    local root = npc and npc:FindFirstChild("HumanoidRootPart")
    local prompt = root and root:FindFirstChildOfClass("ProximityPrompt")
    if not npc or not root or not prompt then return false end

    for _, pet in ipairs(self:PetList()) do
        if not pet.Favorite and not State.FavoriteRarities2026[pet.Rarity] then
            Advanced:Equip(pet.Tool)
            task.wait(0.15)
            local dialogReady = false
            local data = self.SellDialogue
            if data and data.Model == npc then
                for _, option in ipairs(data.Options or {}) do
                    if option.Text == "I would like to sell this" then dialogReady = true break end
                end
            end
            if not dialogReady then
                local revision = self.SellDialogueRevision
                pcall(function() fireproximityprompt(prompt) end)
                local deadline = os.clock() + 3
                while Running and os.clock() < deadline do
                    data = self.SellDialogue
                    if self.SellDialogueRevision > revision and data and data.Model == npc then
                        dialogReady = true
                        break
                    end
                    task.wait(0.05)
                end
            end
            if dialogReady then
                local ok = pcall(self.SellAPI.SelectOption, "I would like to sell this")
                if ok then
                    self.LastAction = "Sold " .. pet.Name
                    return true
                end
            end
        end
    end
    return false
end

function Advanced:CollectOne()
    local candidates = GetFarmCandidates()
    local target = SelectBestFarmCandidate(candidates)
    if not target then
        self.LastAction = "No matching egg"
        return false
    end

    local start = GetBasketCount()
    if not FarmMoveTo(target.Position) then return false end
    if not AttemptPickup(target) then
        FailedFarmTargets[target.UID or target.ID] = os.clock() + 10
        self.LastAction = "Pickup failed: " .. tostring(target.Name)
        return false
    end
    self.LastAction = "Collected: " .. tostring(target.Name)

    if State.AdvancedReturnToPlot then
        local plot = GetMyPlot()
        if plot and not State.ReturnToPlot then
            return true
        end
        if not ReturnToPlotForFarm() then return false end
    end
    return GetBasketCount() > start or true
end

function Advanced:RunCycle()
    if not Running or not State.Automation2026 then return false end

    if State.AutoMountPet then
        MountBestPet()
    end

    if State.AutoHatch2026 and #self:EggTimers() > 0 then
        self:HatchReady()
    end

    if State.AutoBest2026 then
        self:PlaceBestPets()
    end

    if State.AutoPlace2026 and #self:EggTools() > 0 and #self:FreeNests() > 0 then
        self:PlaceEggs()
    end

    if State.AutoFavorite2026 then
        self:FavoriteOne()
    end

    if State.AutoFeed2026 then
        self:FeedOne()
    end

    if State.AutoBuyFood2026 then
        self:BuyFoodOne()
    end

    if State.AutoSell2026 then
        self:SellOne()
    end

    if State.AutoCollect2026 and #self:Basket() < self:Capacity() then
        self:CollectOne()
    end

    return true
end

function Advanced:ServerHop()
    local url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100"
    local raw
    local ok = pcall(function()
        raw = game:HttpGet(url)
    end)
    if not ok or type(raw) ~= "string" then return false end

    local success, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not success or type(data) ~= "table" or type(data.data) ~= "table" then return false end

    local candidates = {}
    for _, server in ipairs(data.data) do
        if server.id and server.playing and server.maxPlayers
            and server.id ~= game.JobId and server.playing < server.maxPlayers then
            candidates[#candidates + 1] = server
        end
    end
    if #candidates == 0 then return false end
    table.sort(candidates, function(a,b) return (a.playing or 0) < (b.playing or 0) end)
    local target = candidates[1]
    return pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, target.id, LocalPlayer)
    end)
end

function Advanced:Rejoin()
    return pcall(function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
end

-- A versão dinâmica deve vencer a lógica antiga de "menor peso".
MountBestPet = function()
    local pets = Advanced:PetList()
    table.sort(pets, function(a,b)
        if a.Speed == b.Speed then
            if a.Income == b.Income then return a.Key < b.Key end
            return a.Income > b.Income
        end
        return a.Speed > b.Speed
    end)

    local pet = pets[1]
    local remote = GetMountRemote()
    if not pet or not remote then return false end
    if not Advanced:Equip(pet.Tool) then return false end
    task.wait(0.12)
    local ok = pcall(function() remote:FireServer() end)
    return ok
end

local AdvancedLoop = task.spawn(function()
    while Running do
        task.wait(math.clamp(tonumber(State.AdvancedLoopDelay) or 0.45, 0.20, 3))
        if Running and State.Automation2026 and not FarmBusy and not PickupBusy then
            FarmBusy = true
            StartFarmNoclip()
            pcall(function()
                Advanced:RunCycle()
            end)
            FarmBusy = false
        end
    end
end)


--============================================================--
-- GUI: MONTAR UM PET 2026 / DELTA NATIVE MOBILE UI
-- Sem dependência externa de biblioteca de interface.
-- A API abaixo mantém o mesmo formato usado pelo restante do hub:
-- Window:CreateTab, Tab:CreateToggle/Slider/Dropdown/Input/Button...
--============================================================--

local UI_PARENT = PlayerGui

pcall(function()
    if typeof(gethui) == "function" then
        local h = gethui()
        if h then
            UI_PARENT = h
            return
        end
    end
end)

local GUI_NAME = "MontarUmPet_2026_DeltaUI"

pcall(function()
    local old = UI_PARENT:FindFirstChild(GUI_NAME)
    if old then old:Destroy() end
end)

pcall(function()
    local old = PlayerGui:FindFirstChild(GUI_NAME)
    if old then old:Destroy() end
end)

local UI_COLORS = {
    Background = Color3.fromRGB(10, 12, 18),
    Panel = Color3.fromRGB(17, 20, 29),
    Panel2 = Color3.fromRGB(22, 26, 37),
    Panel3 = Color3.fromRGB(28, 33, 46),
    Stroke = Color3.fromRGB(53, 61, 82),
    Text = Color3.fromRGB(245, 247, 252),
    Muted = Color3.fromRGB(157, 166, 185),
    Accent = Color3.fromRGB(103, 146, 255),
    Accent2 = Color3.fromRGB(76, 112, 226),
    Success = Color3.fromRGB(71, 205, 132),
    Danger = Color3.fromRGB(241, 91, 91),
}

local function UICorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 10)
    c.Parent = parent
    return c
end

local function UIStroke(parent, color, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or UI_COLORS.Stroke
    s.Transparency = transparency or 0
    s.Thickness = 1
    s.Parent = parent
    return s
end

local function makeText(parent, text, size, color, bold)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Text = tostring(text or "")
    label.TextColor3 = color or UI_COLORS.Text
    label.TextSize = size or 14
    label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Parent = parent
    return label
end

local function makeButton(parent, text, height)
    local b = Instance.new("TextButton")
    b.AutoButtonColor = false
    b.BackgroundColor3 = UI_COLORS.Panel3
    b.TextColor3 = UI_COLORS.Text
    b.Text = tostring(text or "")
    b.TextSize = 13
    b.Font = Enum.Font.GothamMedium
    b.Size = UDim2.new(1, 0, 0, height or 40)
    b.Parent = parent
    UICorner(b, 9)
    UIStroke(b, UI_COLORS.Stroke, 0.15)
    b.MouseEnter:Connect(function()
        pcall(function() b.BackgroundColor3 = UI_COLORS.Panel2 end)
    end)
    b.MouseLeave:Connect(function()
        pcall(function() b.BackgroundColor3 = UI_COLORS.Panel3 end)
    end)
    b.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            b.BackgroundColor3 = UI_COLORS.Panel2
        end
    end)
    return b
end

local function uiViewport()
    local camera = workspace.CurrentCamera
    return camera and camera.ViewportSize or Vector2.new(800, 600)
end

local function clampUiSize()
    local v = uiViewport()
    if v.X < 600 then
        return UDim2.new(0.94, 0, 0.82, 0)
    end
    return UDim2.new(0, 520, 0, 640)
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = GUI_NAME
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ScreenGui.DisplayOrder = 100000
ScreenGui.Parent = UI_PARENT

local Root = Instance.new("Frame")
Root.Name = "Root"
Root.AnchorPoint = Vector2.new(0.5, 0.5)
Root.Position = UDim2.fromScale(0.5, 0.5)
Root.Size = clampUiSize()
Root.BackgroundColor3 = UI_COLORS.Background
Root.BorderSizePixel = 0
Root.Parent = ScreenGui
UICorner(Root, 16)
UIStroke(Root, UI_COLORS.Stroke, 0)

local Scale = Instance.new("UIScale")
Scale.Scale = 1
Scale.Parent = Root

local Header = Instance.new("Frame")
Header.BackgroundColor3 = UI_COLORS.Panel
Header.BorderSizePixel = 0
Header.Size = UDim2.new(1, 0, 0, 58)
Header.Parent = Root
UICorner(Header, 16)

local HeaderCover = Instance.new("Frame")
HeaderCover.BackgroundColor3 = UI_COLORS.Panel
HeaderCover.BorderSizePixel = 0
HeaderCover.Position = UDim2.new(0, 0, 1, -16)
HeaderCover.Size = UDim2.new(1, 0, 0, 16)
HeaderCover.Parent = Header

local Title = makeText(Header, "MONTAR UM PET", 16, UI_COLORS.Text, true)
Title.Position = UDim2.new(0, 18, 0, 6)
Title.Size = UDim2.new(1, -150, 0, 22)

local Subtitle = makeText(Header, "V15.2026 • DELTA • MOBILE", 10, UI_COLORS.Muted, false)
Subtitle.Position = UDim2.new(0, 19, 0, 30)
Subtitle.Size = UDim2.new(1, -150, 0, 17)

local MinBtn = makeButton(Header, "—", 34)
MinBtn.Position = UDim2.new(1, -86, 0, 12)
MinBtn.Size = UDim2.fromOffset(32, 34)
local CloseBtn = makeButton(Header, "×", 34)
CloseBtn.Position = UDim2.new(1, -48, 0, 12)
CloseBtn.Size = UDim2.fromOffset(32, 34)

local Body = Instance.new("Frame")
Body.BackgroundTransparency = 1
Body.Position = UDim2.new(0, 10, 0, 68)
Body.Size = UDim2.new(1, -20, 1, -78)
Body.Parent = Root

local TabBar = Instance.new("ScrollingFrame")
TabBar.BackgroundTransparency = 1
TabBar.BorderSizePixel = 0
TabBar.Size = UDim2.new(1, 0, 0, 42)
TabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
TabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
TabBar.ScrollingDirection = Enum.ScrollingDirection.X
TabBar.ScrollBarThickness = 0
TabBar.Parent = Body

local TabList = Instance.new("UIListLayout")
TabList.FillDirection = Enum.FillDirection.Horizontal
TabList.Padding = UDim.new(0, 6)
TabList.SortOrder = Enum.SortOrder.LayoutOrder
TabList.Parent = TabBar

local PageHolder = Instance.new("Frame")
PageHolder.BackgroundTransparency = 1
PageHolder.Position = UDim2.new(0, 0, 0, 48)
PageHolder.Size = UDim2.new(1, 0, 1, -48)
PageHolder.Parent = Body

local ToastHolder = Instance.new("Frame")
ToastHolder.BackgroundTransparency = 1
ToastHolder.AnchorPoint = Vector2.new(1, 0)
ToastHolder.Position = UDim2.new(1, -12, 0, 74)
ToastHolder.Size = UDim2.fromOffset(280, 300)
ToastHolder.Parent = ScreenGui
local ToastLayout = Instance.new("UIListLayout")
ToastLayout.Padding = UDim.new(0, 6)
ToastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
ToastLayout.VerticalAlignment = Enum.VerticalAlignment.Top
ToastLayout.Parent = ToastHolder

local Floating = makeButton(ScreenGui, "PET", 44)
Floating.Size = UDim2.fromOffset(64, 44)
Floating.AnchorPoint = Vector2.new(1, 1)
Floating.Position = UDim2.new(1, -14, 1, -14)
Floating.BackgroundColor3 = UI_COLORS.Accent2
Floating.Visible = false
Floating.ZIndex = 1000

local function showToast(title, content, duration)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 62)
    card.BackgroundColor3 = UI_COLORS.Panel
    card.BorderSizePixel = 0
    card.Parent = ToastHolder
    UICorner(card, 10)
    UIStroke(card, UI_COLORS.Stroke, 0.1)

    local t = makeText(card, title, 12, UI_COLORS.Text, true)
    t.Position = UDim2.new(0, 12, 0, 7)
    t.Size = UDim2.new(1, -20, 0, 18)

    local c = makeText(card, content, 10, UI_COLORS.Muted, false)
    c.Position = UDim2.new(0, 12, 0, 27)
    c.Size = UDim2.new(1, -20, 0, 28)
    c.TextWrapped = true

    task.delay(duration or 4, function()
        pcall(function() card:Destroy() end)
    end)
end

local function beginDrag(frame, handle)
    local dragging = false
    local dragStart
    local startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            local conn
            conn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if conn then conn:Disconnect() end
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end)
end

beginDrag(Root, Header)

local Window = {}
local Rayfield = { Flags = {} }
local Tabs = {}
local CurrentTab
local WindowDestroyed = false

local function createPage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = "Page_" .. tostring(name)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.Size = UDim2.fromScale(1, 1)
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = UI_COLORS.Stroke
    page.Visible = false
    page.Parent = PageHolder

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 2)
    pad.PaddingRight = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 16)
    pad.Parent = page

    return page
end

local function controlCard(tabPage, height)
    local card = Instance.new("Frame")
    card.BackgroundColor3 = UI_COLORS.Panel
    card.BorderSizePixel = 0
    card.Size = UDim2.new(1, -6, 0, height or 54)
    card.Parent = tabPage
    UICorner(card, 11)
    UIStroke(card, UI_COLORS.Stroke, 0.25)
    return card
end

local function addFlag(RayfieldStub, flagName, api)
    if flagName and flagName ~= "" then
        RayfieldStub.Flags[flagName] = api
    end
end

local function numericValue(v, fallback)
    local n = tonumber(v)
    if n == nil then return fallback end
    return n
end

function Window:CreateTab(settings)
    local name = type(settings) == "table" and settings.name or tostring(settings)
    name = name or "Tab"

    local page = createPage(name)
    local tabButton = makeButton(TabBar, name, 38)
    tabButton.Size = UDim2.fromOffset(math.max(84, #tostring(name) * 8 + 26), 38)

    local tab = {}
    tab.Name = name
    tab.Page = page
    tab.Button = tabButton
    tab.Window = Window

    tabButton.MouseButton1Click:Connect(function()
        for _, data in pairs(Tabs) do
            data.Page.Visible = false
            data.Button.BackgroundColor3 = UI_COLORS.Panel3
        end
        page.Visible = true
        tabButton.BackgroundColor3 = UI_COLORS.Accent2
        CurrentTab = tab
    end)

    function tab:CreateSection(cfg)
        local section = Instance.new("Frame")
        section.BackgroundTransparency = 1
        section.Size = UDim2.new(1, -6, 0, 26)
        section.Parent = page
        local label = makeText(section, "  " .. tostring(cfg and cfg.name or ""), 11, UI_COLORS.Accent, true)
        label.Size = UDim2.fromScale(1, 1)
        return {Set = function(_, text) label.Text = "  " .. tostring(text or "") end}
    end

    function tab:CreateLabel(text)
        local card = controlCard(page, 44)
        card.BackgroundTransparency = 0.15
        local label = makeText(card, text, 11, UI_COLORS.Muted, false)
        label.Position = UDim2.new(0, 12, 0, 5)
        label.Size = UDim2.new(1, -24, 1, -10)
        label.TextWrapped = true
        return { Set = function(_, value) label.Text = tostring(value or "") end }
    end

    function tab:CreateButton(cfg)
        local card = controlCard(page, cfg and cfg.description and 70 or 54)
        local title = makeText(card, cfg.name, 13, UI_COLORS.Text, true)
        title.Position = UDim2.new(0, 12, 0, cfg.description and 7 or 0)
        title.Size = UDim2.new(1, -108, 0, 24)
        local click = makeButton(card, "ABRIR", 34)
        click.AnchorPoint = Vector2.new(1, 0.5)
        click.Position = UDim2.new(1, -10, 0.5, 0)
        click.Size = UDim2.fromOffset(76, 34)
        if cfg.description then
            local desc = makeText(card, cfg.description, 10, UI_COLORS.Muted, false)
            desc.Position = UDim2.new(0, 12, 0, 34)
            desc.Size = UDim2.new(1, -100, 0, 28)
            desc.TextWrapped = true
        end
        click.MouseButton1Click:Connect(function()
            local ok, err = pcall(cfg.callback or function() end)
            if not ok then showToast("Erro", tostring(err), 5) end
        end)
        return click
    end

    function tab:CreateToggle(cfg)
        local value = cfg.value == true
        local card = controlCard(page, cfg.description and 70 or 54)
        local title = makeText(card, cfg.name, 13, UI_COLORS.Text, true)
        title.Position = UDim2.new(0, 12, 0, cfg.description and 7 or 0)
        title.Size = UDim2.new(1, -96, 0, 24)

        local switch = makeButton(card, value and "ON" or "OFF", 32)
        switch.AnchorPoint = Vector2.new(1, 0.5)
        switch.Position = UDim2.new(1, -10, 0.5, 0)
        switch.Size = UDim2.fromOffset(58, 32)

        local desc
        if cfg.description then
            desc = makeText(card, cfg.description, 10, UI_COLORS.Muted, false)
            desc.Position = UDim2.new(0, 12, 0, 34)
            desc.Size = UDim2.new(1, -90, 0, 28)
            desc.TextWrapped = true
        end

        local api = { CurrentValue = value }
        function api:Set(newValue, silent)
            value = newValue == true
            api.CurrentValue = value
            switch.Text = value and "ON" or "OFF"
            switch.BackgroundColor3 = value and UI_COLORS.Success or UI_COLORS.Panel3
            if not silent then
                local ok, err = pcall(cfg.callback or function() end, value)
                if not ok then showToast("Erro em " .. tostring(cfg.name), tostring(err), 5) end
            end
        end
        switch.MouseButton1Click:Connect(function() api:Set(not value) end)
        api:Set(value, true)
        addFlag(Rayfield, cfg.flag, api)
        return api
    end

    function tab:CreateInput(cfg)
        local value = tostring(cfg.value or "")
        local card = controlCard(page, cfg.description and 78 or 58)
        local title = makeText(card, cfg.name, 13, UI_COLORS.Text, true)
        title.Position = UDim2.new(0, 12, 0, 7)
        title.Size = UDim2.new(0.42, 0, 0, 22)

        local box = Instance.new("TextBox")
        box.BackgroundColor3 = UI_COLORS.Panel3
        box.TextColor3 = UI_COLORS.Text
        box.PlaceholderColor3 = UI_COLORS.Muted
        box.Text = value
        box.PlaceholderText = cfg.placeholder or "digite..."
        box.TextSize = 12
        box.Font = Enum.Font.Gotham
        box.ClearTextOnFocus = false
        box.Size = UDim2.new(0.52, 0, 0, 34)
        box.Position = UDim2.new(0.46, 0, 0, 6)
        box.Parent = card
        UICorner(box, 9)
        UIStroke(box, UI_COLORS.Stroke, 0.2)

        if cfg.description then
            local desc = makeText(card, cfg.description, 10, UI_COLORS.Muted, false)
            desc.Position = UDim2.new(0, 12, 0, 42)
            desc.Size = UDim2.new(1, -24, 0, 26)
            desc.TextWrapped = true
        end

        local api = { CurrentValue = value }
        local function commit()
            value = box.Text
            api.CurrentValue = value
            local out = value
            if cfg.numeric then out = tonumber(value) or 0 end
            local ok, err = pcall(cfg.callback or function() end, out)
            if not ok then showToast("Erro em " .. tostring(cfg.name), tostring(err), 5) end
        end
        function api:Set(newValue, silent)
            value = tostring(newValue or "")
            api.CurrentValue = value
            box.Text = value
            if not silent then commit() end
        end
        box.FocusLost:Connect(function() commit() end)
        addFlag(Rayfield, cfg.flag, api)
        return api
    end

    function tab:CreateDropdown(cfg)
        local current = cfg.value
        local multi = cfg.multiSelect == true
        local options = type(cfg.options) == "table" and cfg.options or {}
        local cardHeight = cfg.description and 76 or 58
        local card = controlCard(page, cardHeight)
        local title = makeText(card, cfg.name, 13, UI_COLORS.Text, true)
        title.Position = UDim2.new(0, 12, 0, 7)
        title.Size = UDim2.new(0.40, 0, 0, 22)

        local display = Instance.new("TextLabel")
        display.BackgroundColor3 = UI_COLORS.Panel3
        display.TextColor3 = UI_COLORS.Text
        display.TextSize = 11
        display.Font = Enum.Font.Gotham
        display.TextXAlignment = Enum.TextXAlignment.Left
        display.TextTruncate = Enum.TextTruncate.AtEnd
        display.Size = UDim2.new(0.54, 0, 0, 34)
        display.Position = UDim2.new(0.44, 0, 0, 6)
        display.Parent = card
        UICorner(display, 9)
        UIStroke(display, UI_COLORS.Stroke, 0.2)

        local open = makeButton(card, "⌄", 30)
        open.AnchorPoint = Vector2.new(1, 0.5)
        open.Position = UDim2.new(1, -8, 0.5, 0)
        open.Size = UDim2.fromOffset(28, 30)

        local list = Instance.new("Frame")
        list.BackgroundColor3 = UI_COLORS.Panel2
        list.BorderSizePixel = 0
        list.Visible = false
        list.Position = UDim2.new(0, 8, 1, 5)
        list.Size = UDim2.new(1, -16, 0, math.min(180, math.max(40, #options * 32 + 10)))
        list.ZIndex = 20
        list.Parent = card
        UICorner(list, 9)
        UIStroke(list, UI_COLORS.Stroke, 0.1)

        local optScroll = Instance.new("ScrollingFrame")
        optScroll.BackgroundTransparency = 1
        optScroll.BorderSizePixel = 0
        optScroll.Size = UDim2.fromScale(1, 1)
        optScroll.ScrollBarThickness = 3
        optScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        optScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        optScroll.ZIndex = 21
        optScroll.Parent = list
        local optLayout = Instance.new("UIListLayout")
        optLayout.Padding = UDim.new(0, 4)
        optLayout.Parent = optScroll
        local optPad = Instance.new("UIPadding")
        optPad.PaddingTop = UDim.new(0, 5)
        optPad.PaddingLeft = UDim.new(0, 5)
        optPad.PaddingRight = UDim.new(0, 5)
        optPad.PaddingBottom = UDim.new(0, 5)
        optPad.Parent = optScroll

        local selected = {}
        if multi then
            if type(current) == "table" then
                for _, item in ipairs(current) do selected[item] = true end
            end
        else
            if type(current) == "table" then current = current[1] end
            if current ~= nil then selected[tostring(current)] = true end
        end

        local api = { CurrentOption = current }
        local function selectedText()
            if multi then
                local out = {}
                for _, option in ipairs(options) do
                    if selected[option] then table.insert(out, tostring(option)) end
                end
                if #out == 0 then return cfg.placeholder or "Nenhum" end
                if #out == 1 then return out[1] end
                if #out <= 3 then return table.concat(out, ", ") end
                return tostring(#out) .. " selecionados"
            end
            for _, option in ipairs(options) do
                if selected[option] then return tostring(option) end
            end
            return cfg.placeholder or "Nenhum"
        end

        local function syncDisplay()
            display.Text = "  " .. selectedText()
            for _, child in ipairs(optScroll:GetChildren()) do
                if child:IsA("TextButton") then
                    local on = selected[child.Name] == true
                    child.BackgroundColor3 = on and UI_COLORS.Accent2 or UI_COLORS.Panel3
                end
            end
            if multi then
                local out = {}
                for _, option in ipairs(options) do if selected[option] then table.insert(out, option) end end
                api.CurrentOption = out
            else
                api.CurrentOption = selectedText()
            end
        end

        for _, option in ipairs(options) do
            local b = makeButton(optScroll, tostring(option), 28)
            b.Name = tostring(option)
            b.LayoutOrder = #optScroll:GetChildren()
            b.ZIndex = 22
            b.MouseButton1Click:Connect(function()
                if multi then
                    selected[option] = not selected[option]
                else
                    for key in pairs(selected) do selected[key] = nil end
                    selected[option] = true
                    list.Visible = false
                end
                syncDisplay()
                local ok, err = pcall(cfg.callback or function() end, api.CurrentOption)
                if not ok then showToast("Erro em " .. tostring(cfg.name), tostring(err), 5) end
            end)
        end

        open.MouseButton1Click:Connect(function()
            list.Visible = not list.Visible
        end)

        function api:Set(newValue, silent)
            for key in pairs(selected) do selected[key] = nil end
            if multi then
                local values = type(newValue) == "table" and newValue or {newValue}
                for _, item in ipairs(values) do selected[item] = true end
            else
                local item = type(newValue) == "table" and newValue[1] or newValue
                if item ~= nil then selected[item] = true end
            end
            syncDisplay()
            if not silent then
                local ok, err = pcall(cfg.callback or function() end, api.CurrentOption)
                if not ok then showToast("Erro em " .. tostring(cfg.name), tostring(err), 5) end
            end
        end
        syncDisplay()
        addFlag(Rayfield, cfg.flag, api)
        return api
    end

    function tab:CreateSlider(cfg)
        local min = tonumber(cfg.range and cfg.range[1]) or 0
        local max = tonumber(cfg.range and cfg.range[2]) or 100
        local step = tonumber(cfg.increment) or 1
        local value = numericValue(cfg.value, min)
        value = math.clamp(value, min, max)
        local card = controlCard(page, 72)

        local title = makeText(card, cfg.name, 13, UI_COLORS.Text, true)
        title.Position = UDim2.new(0, 12, 0, 7)
        title.Size = UDim2.new(1, -112, 0, 20)

        local valBox = Instance.new("TextBox")
        valBox.BackgroundColor3 = UI_COLORS.Panel3
        valBox.TextColor3 = UI_COLORS.Text
        valBox.Text = string.format("%s", tostring(value))
        valBox.TextSize = 11
        valBox.Font = Enum.Font.GothamMedium
        valBox.Size = UDim2.fromOffset(82, 28)
        valBox.Position = UDim2.new(1, -94, 0, 5)
        valBox.Parent = card
        UICorner(valBox, 8)
        UIStroke(valBox, UI_COLORS.Stroke, 0.2)

        local minus = makeButton(card, "−", 28)
        minus.Position = UDim2.new(0, 10, 0, 37)
        minus.Size = UDim2.fromOffset(30, 28)
        local plus = makeButton(card, "+", 28)
        plus.AnchorPoint = Vector2.new(1, 0)
        plus.Position = UDim2.new(1, -10, 0, 37)
        plus.Size = UDim2.fromOffset(30, 28)

        local bar = Instance.new("Frame")
        bar.BackgroundColor3 = UI_COLORS.Panel3
        bar.BorderSizePixel = 0
        bar.Position = UDim2.new(0, 48, 0, 49)
        bar.Size = UDim2.new(1, -96, 0, 5)
        bar.Parent = card
        UICorner(bar, 5)

        local fill = Instance.new("Frame")
        fill.BackgroundColor3 = UI_COLORS.Accent
        fill.BorderSizePixel = 0
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.Parent = bar
        UICorner(fill, 5)

        local api = { CurrentValue = value }
        local function commit(newValue, silent)
            newValue = math.clamp(newValue, min, max)
            local steps = math.floor(((newValue - min) / step) + 0.5)
            newValue = min + steps * step
            newValue = math.clamp(newValue, min, max)
            value = newValue
            api.CurrentValue = value
            valBox.Text = tostring(value)
            local alpha = (max == min) and 0 or ((value - min) / (max - min))
            fill.Size = UDim2.new(alpha, 0, 1, 0)
            if not silent then
                local ok, err = pcall(cfg.callback or function() end, value)
                if not ok then showToast("Erro em " .. tostring(cfg.name), tostring(err), 5) end
            end
        end
        function api:Set(newValue, silent)
            commit(numericValue(newValue, min), silent)
        end
        minus.MouseButton1Click:Connect(function() commit(value - step, false) end)
        plus.MouseButton1Click:Connect(function() commit(value + step, false) end)
        valBox.FocusLost:Connect(function() commit(numericValue(valBox.Text, value), false) end)

        local dragging = false
        local function setFromInput(input)
            local x = input.Position.X
            local left = bar.AbsolutePosition.X
            local width = bar.AbsoluteSize.X
            if width <= 0 then return end
            local alpha = math.clamp((x - left) / width, 0, 1)
            commit(min + (max - min) * alpha, false)
        end
        bar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                setFromInput(input)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                setFromInput(input)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        commit(value, true)
        addFlag(Rayfield, cfg.flag, api)
        return api
    end

    table.insert(Tabs, tab)
    if not CurrentTab then
        tabButton.BackgroundColor3 = UI_COLORS.Accent2
        page.Visible = true
        CurrentTab = tab
    end
    return tab
end

function Window:Notify(cfg)
    showToast(cfg and cfg.title or "Montar um Pet", cfg and cfg.content or "", cfg and cfg.duration or 4)
end

function Window:Destroy()
    WindowDestroyed = true
    pcall(function() ScreenGui:Destroy() end)
end

function Window:SetVisibility(value)
    if WindowDestroyed then return end
    Root.Visible = value == true
    Floating.Visible = value ~= true
end

function Window:IsVisible()
    return Root.Visible
end

Rayfield.Destroy = function(self)
    Window:Destroy()
end

MinBtn.MouseButton1Click:Connect(function()
    Window:SetVisibility(false)
end)
CloseBtn.MouseButton1Click:Connect(function()
    if StopHandler then
        pcall(StopHandler)
    end
end)
Floating.MouseButton1Click:Connect(function()
    Window:SetVisibility(true)
end)

-- Cria as abas imediatamente; a UI fica disponível mesmo se uma automação
-- posterior falhar. O restante do script usa a mesma API de elementos.
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
    description = "Prioriza o pet com maior Speed; usa Income como desempate.",
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
local CONFIG_FILE = "MontarUmPet_MASTER_v15_2026_config.json"

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

        local data = { __version = "15.2026" }
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
-- V15.2026 / ABA DE PROGRESSÃO
--============================================================--

local Tab2026 = Window:CreateTab({name = "2026"})
local TabServer = Window:CreateTab({name = "Servidor"})

Tab2026:CreateSection({name = "Automação 2026 — orquestrador"})

Tab2026:CreateToggle({
    name = "Automação 2026",
    flag = "Automation2026",
    description = "Executa a fila: Hatch → Best Pets → Place Eggs → Favorite/Feed/Sell → Collect.",
    value = State.Automation2026,
    callback = function(value)
        State.Automation2026 = value
        if value then
            State.AutoFarm = false
            CancelGlide()
            ClearFarmTarget()
            StartFarmNoclip()
            FarmStatus("V15.2026 automation enabled")
        else
            State.AutoFarm = false
            CancelGlide()
            StopFarmNoclip()
            FarmStatus("V15.2026 automation stopped")
        end
    end,
})

Tab2026:CreateToggle({
    name = "Auto Coletar ovos",
    flag = "AutoCollect2026",
    value = State.AutoCollect2026,
    callback = function(value) State.AutoCollect2026 = value end,
})

Tab2026:CreateToggle({
    name = "Auto Place ovos",
    flag = "AutoPlace2026",
    value = State.AutoPlace2026,
    callback = function(value) State.AutoPlace2026 = value end,
})

Tab2026:CreateToggle({
    name = "Auto Hatch prontos",
    flag = "AutoHatch2026",
    value = State.AutoHatch2026,
    callback = function(value) State.AutoHatch2026 = value end,
})

Tab2026:CreateToggle({
    name = "Auto Best Pets",
    flag = "AutoBest2026",
    value = State.AutoBest2026,
    callback = function(value) State.AutoBest2026 = value end,
})

Tab2026:CreateDropdown({
    name = "Métrica dos melhores pets",
    flag = "BestMetric2026",
    options = {"Speed", "Income"},
    value = State.BestMetric2026,
    callback = function(value) State.BestMetric2026 = value end,
})

Tab2026:CreateSlider({
    name = "Máximo de pets colocados",
    flag = "MaxPets2026",
    range = {1, 30},
    increment = 1,
    value = State.MaxPets2026,
    suffix = " pets",
    callback = function(value) State.MaxPets2026 = math.clamp(math.floor(tonumber(value) or 5), 1, 30) end,
})

Tab2026:CreateSection({name = "Progressão segura"})

Tab2026:CreateToggle({
    name = "Auto Favoritar",
    flag = "AutoFavorite2026",
    description = "Favorita pets por raridade antes da venda.",
    value = State.AutoFavorite2026,
    callback = function(value) State.AutoFavorite2026 = value end,
})

Tab2026:CreateDropdown({
    name = "Raridades protegidas",
    flag = "FavoriteRarities2026",
    multiSelect = true,
    options = Rarities,
    value = (function()
        local t = {}
        for k,v in pairs(State.FavoriteRarities2026) do if v then table.insert(t,k) end end
        table.sort(t)
        return t
    end)(),
    placeholder = "Nenhuma",
    callback = function(value) State.FavoriteRarities2026 = CopyArrayToSet(value) end,
})

Tab2026:CreateToggle({
    name = "Auto Feed",
    flag = "AutoFeed2026",
    description = "Usa FeedPet somente quando o módulo de dados de pets/alimentos está disponível.",
    value = State.AutoFeed2026,
    callback = function(value) State.AutoFeed2026 = value end,
})

Tab2026:CreateDropdown({
    name = "Comida preferida",
    flag = "FeedFood2026",
    options = (function()
        local list = {"Any"}
        for _,n in ipairs(Advanced.Names.Food) do table.insert(list,n) end
        return list
    end)(),
    value = State.FeedFood2026,
    callback = function(value) State.FeedFood2026 = value end,
})

Tab2026:CreateToggle({
    name = "Auto Buy Food",
    flag = "AutoBuyFood2026",
    value = State.AutoBuyFood2026,
    callback = function(value) State.AutoBuyFood2026 = value end,
})

Tab2026:CreateToggle({
    name = "Auto Sell seguro",
    flag = "AutoSell2026",
    description = "Somente inventário não-favoritado e fora das raridades protegidas.",
    value = State.AutoSell2026,
    callback = function(value) State.AutoSell2026 = value end,
})

Tab2026:CreateSection({name = "Ações manuais"})

Tab2026:CreateButton({name = "Place ovos agora", callback = function() Advanced:PlaceEggs() end})
Tab2026:CreateButton({name = "Hatch ovos prontos", callback = function() Advanced:HatchReady() end})
Tab2026:CreateButton({name = "Colocar melhores pets", callback = function() Advanced:PlaceBestPets() end})
Tab2026:CreateButton({name = "Favoritar próximo pet", callback = function() Advanced:FavoriteOne() end})
Tab2026:CreateButton({name = "Alimentar próximo pet", callback = function() Advanced:FeedOne() end})
Tab2026:CreateButton({name = "Vender próximo pet seguro", callback = function() Advanced:SellOne() end})
Tab2026:CreateButton({name = "Recarregar GameData 2026", callback = function() AdvancedLoadData() end})
Tab2026:CreateButton({
    name = "Diagnóstico de remotes",
    callback = function()
        local names = {"EggPickup","Mounting","EggPlaced","Hatch","PlacePet","PickupPet","FeedPet","BuyWithCash","FavoritePet","ClaimIndexReward","Rebirth","BuyRadar","UseRadar","UnlockNest","UpgradeHatchLuck"}
        local found = {}
        for _,name in ipairs(names) do if Advanced:GetRemote(name) then table.insert(found,name) end end
        local text = #found > 0 and table.concat(found, ", ") or "nenhum dos remotes opcionais detectado"
        pcall(function() Window:Notify({title="API 2026",content=text,duration=6}) end)
    end,
})

TabServer:CreateSection({name = "Servidor"})
TabServer:CreateToggle({
    name = "Server Hop automático em falha",
    flag = "ServerHopOnFail",
    value = State.ServerHopOnFail,
    callback = function(value) State.ServerHopOnFail = value end,
})
TabServer:CreateSlider({
    name = "Intervalo mínimo do hop",
    flag = "ServerHopDelay",
    range = {15, 300},
    increment = 5,
    value = State.ServerHopDelay,
    suffix = " s",
    callback = function(value) State.ServerHopDelay = math.clamp(math.floor(tonumber(value) or 45), 15, 300) end,
})
TabServer:CreateButton({name = "Rejoin servidor", callback = function() Advanced:Rejoin() end})
TabServer:CreateButton({name = "Server Hop", callback = function() Advanced:ServerHop() end})
TabServer:CreateButton({
    name = "Status 2026",
    callback = function()
        local modules = {}
        for _,key in ipairs({"Pets","General","Mutations","EggBaskets","IndexRewards","Foods","Shop"}) do
            if type(Advanced.Data[key]) == "table" and next(Advanced.Data[key]) then table.insert(modules,key) end
        end
        local remotes = {}
        for _,key in ipairs({"EggPlaced","Hatch","PlacePet","PickupPet","FeedPet","BuyWithCash","FavoritePet"}) do
            if Advanced:GetRemote(key) then table.insert(remotes,key) end
        end
        local text = "Modules: "..(#modules>0 and table.concat(modules,", ") or "nenhum").." | Remotes: "..(#remotes>0 and table.concat(remotes,", ") or "nenhum")
        pcall(function() Window:Notify({title="V15.2026",content=text,duration=6}) end)
    end,
})

-- Atualiza a aba de farm para deixar explícito que o mount atual é por velocidade.
TabFarm:CreateSection({name = "Compatibilidade 2026"})
TabFarm:CreateButton({
    name = "Montar pet mais rápido",
    callback = function()
        local ok = MountBestPet()
        pcall(function() Window:Notify({title="Mount",content=ok and "Pet de maior velocidade solicitado." or "Não foi possível identificar/montar um pet.",duration=4}) end)
    end,
})
TabFarm:CreateButton({
    name = "Abrir Automação 2026",
    callback = function()
        State.Automation2026 = true
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
    State.Automation2026 = false
    State.AutoCollect2026 = false
    State.AutoPlace2026 = false
    State.AutoHatch2026 = false
    State.AutoBest2026 = false
    State.AutoFeed2026 = false
    State.AutoBuyFood2026 = false
    State.AutoFavorite2026 = false
    State.AutoSell2026 = false
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

