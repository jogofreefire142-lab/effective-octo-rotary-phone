--============================================================--
-- MONTAR UM PET - MASTER v5 CORRIGIDO
-- PlaceId: 124216119978534
-- UI: Rayfield Gen2 (stable)
-- Foco: Delta Mobile + baixo custo de polling + cleanup robusto
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
-- DUPLICAÇÃO: guard persistente no PlayerGui
-- O guard não renderiza nada e funciona mesmo quando getgenv() é isolado.
--============================================================--

local GUARD_NAME = "MontarUmPet_Master_Guard"
local TOKEN_NAMES = {
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

for _, tokenName in ipairs(TOKEN_NAMES) do
    pcall(function()
        local oldToken = ENV[tokenName]
        if oldToken and oldToken.Stop then
            oldToken:Stop()
        end
    end)
end

pcall(function()
    local oldGuard = PlayerGui:FindFirstChild(GUARD_NAME)
    if oldGuard then
        local event = oldGuard:FindFirstChild("Shutdown")
        if event and event:IsA("BindableEvent") then
            event:Fire()
        end
        oldGuard:Destroy()
    end
end)

-- Remove only known hub GUIs, never arbitrary game UI.
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

local Guard = Instance.new("Folder")
Guard.Name = GUARD_NAME
Guard.Parent = PlayerGui

local GuardEvent = Instance.new("BindableEvent")
GuardEvent.Name = "Shutdown"
GuardEvent.Parent = Guard

local Running = true
local StopHandler = nil

local GuardConnection = GuardEvent.Event:Connect(function()
    if StopHandler then
        pcall(StopHandler)
    else
        Running = false
    end
end)

--============================================================--
-- ESTADO
--============================================================--

local State = {
    SpeedEnabled = false,
    WalkSpeed = 150,

    AutoFarm = false,
    FarmMode = "Rarity",
    SelectedEggs = {},
    SelectedRarities = {
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

    local root = instance:FindFirstChildWhichIsA("BasePart", true)
    if root then
        return root.Position
    end

    return nil
end

local function GetEggMutation(instance)
    local names = {
        "Mutation",
        "MutationType",
        "Mutated",
    }

    for _, attributeName in ipairs(names) do
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
    local value = instance:GetAttribute("Weight")
    return type(value) == "number" and value or nil
end

local function GetEggLuck(instance)
    local value = instance:GetAttribute("Luck")
    return type(value) == "number" and value or nil
end

local function IsMutationMatch(instance)
    if not State.OnlyMutated then
        return true
    end
    return GetEggMutation(instance) ~= nil
end

local function IsSelectedForFarm(eggName, instance)
    if State.FarmMode == "Egg" then
        return State.SelectedEggs[eggName] == true
    end

    local rarity = GetEggRarity(eggName, instance)
    return State.SelectedRarities[rarity] == true
end

local function MeetsFilters(instance, eggName)
    if not IsSelectedForFarm(eggName, instance) then
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
    local activeEggs = GetActiveEggFolder()
    if not activeEggs then
        return {}
    end

    local _, root = GetCharacter()
    if not root then
        return {}
    end

    local result = {}

    for _, egg in ipairs(activeEggs:GetChildren()) do
        local eggName = egg:GetAttribute("Egg")

        if type(eggName) == "string"
            and egg:IsA("Configuration")
            and MeetsFilters(egg, eggName) then

            local position = GetEggPosition(egg)

            if position then
                local distance = (position - root.Position).Magnitude
                local weight = GetEggWeight(egg) or 0
                local luck = GetEggLuck(egg) or 0

                table.insert(result, {
                    Instance = egg,
                    Name = eggName,
                    Position = position,
                    Distance = distance,
                    Weight = weight,
                    Luck = luck,
                    Rarity = GetEggRarity(eggName, egg),
                    RarityScore = RarityPriority[GetEggRarity(eggName, egg)] or 0,
                    Mutation = GetEggMutation(egg),
                })
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
            elseif candidate.RarityScore == best.RarityScore and candidate.Distance < best.Distance then
                best = candidate
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
    if not backpack then
        return false
    end

    local selectedPet = nil
    local lowestWeight = math.huge

    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") and item:GetAttribute("PetName") ~= nil then
            local weight = item:GetAttribute("Weight")

            if type(weight) == "number" and weight < lowestWeight then
                lowestWeight = weight
                selectedPet = item
            end
        end
    end

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
-- FARM
--============================================================--

local FarmBusy = false
local PickupBusy = false

local function FarmOnce()
    if not Running or not State.AutoFarm or FarmBusy then
        return
    end

    FarmBusy = true

    local success = pcall(function()
        if not Running or not State.AutoFarm then
            return
        end

        if IsCarryingEggs() then
            if State.ReturnToPlot then
                if State.VolcanicSupport and IsInVolcano() then
                    local volcano = workspace:FindFirstChild("Volcano")
                    local validate = volcano and volcano:FindFirstChild("VolcanoValidate")
                    if validate and validate:IsA("BasePart") then
                        GlideTo(validate.Position, math.min(State.TravelSpeed, 150), function()
                            return Running and State.AutoFarm
                        end)
                    end
                end

                if Running and State.AutoFarm then
                    ReturnToPlot()
                end
            end
            return
        end

        if State.AutoMountPet and not IsRidingPet() then
            if not MountBestPet() then
                return
            end
            task.wait(0.15)
        end

        if not Running or not State.AutoFarm then
            return
        end

        local candidates = GetCandidates()
        local target = SelectBestCandidate(candidates)

        if not target then
            return
        end

        local isVolcanic = target.Name == "Volcanic Egg"

        if isVolcanic and State.VolcanicSupport then
            if not IsInVolcano() and IsCarryingEggs() then
                ReturnToPlot()
                return
            end

            if IsInVolcano() and IsCarryingEggs() then
                local volcano = workspace:FindFirstChild("Volcano")
                local validate = volcano and volcano:FindFirstChild("VolcanoValidate")

                if validate and validate:IsA("BasePart") then
                    GlideTo(validate.Position, math.min(State.TravelSpeed, 150), function()
                        return Running and State.AutoFarm
                    end)
                end
                return
            end

            if not IsInVolcano() then
                if not IsRidingPet() then
                    if not MountBestPet() then
                        return
                    end
                    task.wait(0.6)
                end

                local volcano = workspace:FindFirstChild("Volcano")
                local entrance = volcano and volcano:FindFirstChild("VolcanoEntrance")
                local validate = volcano and volcano:FindFirstChild("VolcanoValidate")

                if entrance and entrance:IsA("BasePart") then
                    GlideTo(entrance.Position, State.TravelSpeed, function()
                        return Running and State.AutoFarm
                    end)
                end

                if Running and State.AutoFarm and validate and validate:IsA("BasePart") and not IsInVolcano() then
                    GlideTo(validate.Position, math.min(State.TravelSpeed, 150), function()
                        return Running and State.AutoFarm
                    end)
                end

                task.wait(0.25)
            end
        else
            if IsInVolcano() then
                local volcano = workspace:FindFirstChild("Volcano")
                local validate = volcano and volcano:FindFirstChild("VolcanoValidate")
                if validate and validate:IsA("BasePart") then
                    GlideTo(validate.Position, math.min(State.TravelSpeed, 150), function()
                        return Running and State.AutoFarm
                    end)
                end
                return
            end
        end

        if not Running or not State.AutoFarm then
            return
        end

        local _, currentRoot = GetCharacter()
        if not currentRoot then
            return
        end

        local distance = (target.Position - currentRoot.Position).Magnitude

        if distance > 8 then
            local reached = GlideTo(target.Position, State.TravelSpeed, function()
                return Running and State.AutoFarm
            end)

            if not reached then
                return
            end
        end

        if not Running or not State.AutoFarm then
            return
        end

        local EggPickupRemote = GetEggPickupRemote()
        if not EggPickupRemote or not EggPickupRemote:IsA("RemoteEvent") then
            return
        end

        -- The public implementation uses the Configuration name as UID.
        EggPickupRemote:FireServer(target.Instance.Name)
        task.wait(0.2)

        if Running and State.AutoFarm and IsCarryingEggs() and State.ReturnToPlot then
            ReturnToPlot()
        end
    end)

    FarmBusy = false

    if not success then
        task.wait(0.10)
    end
end

local function AutoPickupOnce()
    if not Running or not State.AutoPickup or PickupBusy then
        return
    end

    PickupBusy = true

    pcall(function()
        if IsCarryingEggs() then
            return
        end

        local candidates = GetCandidates()
        local target = SelectBestCandidate(candidates)

        if not target or target.Distance > 20 then
            return
        end

        local EggPickupRemote = GetEggPickupRemote()
        if EggPickupRemote and EggPickupRemote:IsA("RemoteEvent") then
            EggPickupRemote:FireServer(target.Instance.Name)
        end
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

        if State.Fullbright or State.LowGraphics then
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

local okWindow, Window = pcall(function()
    return Rayfield:CreateWindow({
        name = "Montar um Pet",
        subtitle = "MASTER v5 • Delta Mobile",
        sidebarLayout = true,
        toggleUIKeybind = "K",
        configuration = {
            autoSave = true,
            autoLoad = true,
            fileName = "MontarUmPet_Master_v5",
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
    value = false,
    callback = function(value)
        State.AutoFarm = value
        if not value then
            CancelGlide()
        end
    end,
})

TabFarm:CreateDropdown({
    name = "Modo de seleção",
    flag = "FarmMode",
    options = {"Rarity", "Egg"},
    value = "Rarity",
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
    value = {"Ethereal", "Divine"},
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
    options = {"Highest Rarity", "Closest", "Highest Weight"},
    value = "Highest Rarity",
    callback = function(value)
        State.TargetPriority = value
    end,
})

TabFarm:CreateInput({
    name = "Peso mínimo do ovo",
    description = "0 desativa o filtro. Ex.: 50000",
    numeric = true,
    value = "0",
    callback = function(value)
        State.MinEggWeight = math.max(0, tonumber(value) or 0)
    end,
})

TabFarm:CreateInput({
    name = "Luck mínima",
    description = "0 desativa o filtro.",
    numeric = true,
    value = "0",
    callback = function(value)
        State.MinEggLuck = math.max(0, tonumber(value) or 0)
    end,
})

TabFarm:CreateToggle({
    name = "Somente ovos mutados",
    flag = "OnlyMutated",
    value = false,
    callback = function(value)
        State.OnlyMutated = value
    end,
})

TabFarm:CreateToggle({
    name = "Auto Pickup próximo",
    flag = "AutoPickup",
    description = "Recolhe um alvo dentro de ~20 studs.",
    value = false,
    callback = function(value)
        State.AutoPickup = value
    end,
})

TabFarm:CreateToggle({
    name = "Auto Mount Pet",
    flag = "AutoMountPet",
    description = "Usa o pet com menor Weight encontrado na mochila, conforme a implementação pública pesquisada.",
    value = true,
    callback = function(value)
        State.AutoMountPet = value
    end,
})

TabFarm:CreateToggle({
    name = "Volcanic Support",
    flag = "VolcanicSupport",
    value = true,
    callback = function(value)
        State.VolcanicSupport = value
    end,
})

TabFarm:CreateToggle({
    name = "Retornar para a base",
    flag = "ReturnToPlot",
    value = true,
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

TabFarm:CreateSection({name = "Controle"})

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

TabPerf:CreateSection({name = "Desempenho"})

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
    value = false,
    callback = function(value)
        SetLowGraphics(value)
    end,
})

TabPerf:CreateToggle({
    name = "Fullbright",
    flag = "Fullbright",
    value = false,
    callback = function(value)
        SetFullbright(value)
    end,
})

TabPerf:CreateToggle({
    name = "Remover Fog",
    flag = "NoFog",
    value = false,
    callback = function(value)
        SetNoFog(value)
    end,
})

TabPerf:CreateToggle({
    name = "Desativar 3D rendering",
    flag = "Disable3D",
    value = false,
    callback = function(value)
        Set3DDisabled(value)
    end,
})

TabPerf:CreateButton({
    name = "Aplicar FPS Cap atual",
    callback = function()
        SetFPSCap(State.FPSCap)
    end,
})

--============================================================--
-- CONFIG TAB
--============================================================--

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

task.spawn(function()
    while Running do
        task.wait(0.25)
        if Running and State.AutoFarm then
            FarmOnce()
        end
    end
end)

task.spawn(function()
    while Running do
        task.wait(0.20)
        if Running and State.AutoPickup then
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
    State.NoFog = false
    State.Disable3D = false

    pcall(StopSpeed)
    pcall(StopNoclip)
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
        Guard:Destroy()
    end)
end

ENV[TOKEN_NAMES[1]] = {
    Stop = StopHandler,
}
ENV[TOKEN_NAME] = ENV[TOKEN_NAMES[1]]

