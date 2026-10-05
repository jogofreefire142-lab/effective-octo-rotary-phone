--[[
    Ride A Pet - LAB v22
    Alvo exclusivo: [⚡] Ride A Pet / Montar um Pet
    Base técnica: estrutura pública observada em scripts open-source do jogo.

    Confirmado em fonte aberta:
      Remotes/Game:
        EggPickup(eggId)
        EggPlaced({NestId = nestName})
        Hatch({EggKey = eggKey})
        PickupPet(petKey)
        PlacePet(petKey, worldPosition)
        ClaimIndexReward()
        FeedPet(petKey, foodName)
        FavoritePet(petKey)
        BuyWithCash("Food", foodName)
        PetDismount()
      Estrutura:
        ServerData/ActiveEggs
        SavedData
        GameData/{Eggs,Pets,General,Mutations,EggBaskets,IndexRewards,Foods,Shop}
        GameServices/{PetAging,DayNight}
        Plots/<plot>/Nests, Eggs, Pets
        Stalls/Sell/Richie

    O script não inventa assinaturas para Rebirth/Hatch Luck/Nest Unlock.
    Essas funções podem aparecer em hubs, mas não foram confirmadas pela fonte
    aberta usada como base desta versão.
]]

-- Compatibilidade simples para executores: usa apenas APIs opcionais quando existirem.
local function _safeGlobal(name)
    local ok, value = pcall(function() return _G[name] end)
    if ok then return value end
end

local _getgenv = _safeGlobal("getgenv")
local _identifyExecutor = _safeGlobal("identifyexecutor") or _safeGlobal("getexecutorname")
local ExecutorName = "Roblox/Unknown"
if type(_identifyExecutor) == "function" then
    local ok, name = pcall(_identifyExecutor)
    if ok and name then ExecutorName = tostring(name) end
end

local _traceback = function(err)
    local dbg = _safeGlobal("debug")
    local tb = type(dbg) == "table" and dbg.traceback
    if type(tb) == "function" then
        local ok, result = pcall(tb, tostring(err))
        if ok and result then return result end
    end
    return tostring(err)
end

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local function Main()
    -- Compatibilidade e limpeza de instancias antigas. Isto melhora estabilidade;
    -- nao tenta esconder o script nem contornar sistemas anti-cheat.
    local Env = _G
do
    if type(_getgenv) == "function" then
        local okEnv, envValue = pcall(_getgenv)
        if okEnv and type(envValue) == "table" then Env = envValue end
    end
end
    for _, oldKey in ipairs({"__RideAPet_COMPLETO_v13", "__RideAPet_COMPLETO_v14", "__RideAPet_COMPLETO_v15", "__RideAPet_COMPLETO_v16", "__RideAPet_COMPLETO_v17", "__RideAPet_COMPLETO_v18", "__RideAPet_COMPLETO_v19", "__RideAPet_COMPLETO_v20", "__RideAPet_COMPLETO_v21"}) do
        local oldDestroy = Env[oldKey]
        if type(oldDestroy) == "function" then
            pcall(oldDestroy)
        end
    end

    local INSTANCE_KEY = "__RideAPet_COMPLETO_v22"
    if type(Env[INSTANCE_KEY]) == "function" then
        pcall(Env[INSTANCE_KEY])
    end

    local function GetService(name)
        local ok, service = pcall(function() return game:GetService(name) end)
        return ok and service or nil
    end

    local Players = GetService("Players")
    local RunService = GetService("RunService")
    local TweenService = GetService("TweenService")
    local ReplicatedStorage = GetService("ReplicatedStorage")
    local Workspace = GetService("Workspace")
    local UserInputService = GetService("UserInputService")
    local VirtualUser = GetService("VirtualUser")
    if not Players or not RunService or not TweenService or not ReplicatedStorage or not Workspace then
        warn("[RideAPet v22] Servicos essenciais indisponiveis neste cliente.")
        return
    end
    local LocalPlayer = Players.LocalPlayer
    if not LocalPlayer then
        warn("[RideAPet v22] LocalPlayer indisponível.")
        return
    end

    local function GetGuiParent()
        local ok, pg = pcall(function() return LocalPlayer:FindFirstChild("PlayerGui") end)
        if ok and pg then return pg end
        local gethuiFn = rawget(_G, "gethui")
        if type(gethuiFn) == "function" then
            local okH, hui = pcall(gethuiFn)
            if okH and hui then return hui end
        end
        local CoreGui = GetService("CoreGui")
        if CoreGui then
            local okC, _ = pcall(function() return CoreGui.Name end)
            if okC then return CoreGui end
        end
        return nil
    end

    local function CreateBootstrapUI()
        local pg = GetGuiParent()
        if not pg then return nil end
        pcall(function()
            local old = pg:FindFirstChild("RideAPet_BOOT_v22")
            if old then old:Destroy() end
        end)
        local ok, gui = pcall(function()
            local g = Instance.new("ScreenGui")
            g.Name = "RideAPet_BOOT_v22"
            g.ResetOnSpawn = false
            g.IgnoreGuiInset = false
            g.DisplayOrder = 2147483647
            g.Parent = pg
            local f = Instance.new("Frame")
            f.Size = UDim2.fromOffset(360, 110)
            f.Position = UDim2.new(0.5, -180, 0.5, -55)
            f.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
            f.BorderSizePixel = 0
            f.Parent = g
            Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)
            local t = Instance.new("TextLabel")
            t.Name = "Status"
            t.Size = UDim2.new(1, -24, 1, -24)
            t.Position = UDim2.fromOffset(12, 12)
            t.BackgroundTransparency = 1
            t.TextColor3 = Color3.new(1,1,1)
            t.Font = Enum.Font.GothamBold
            t.TextSize = 14
            t.TextWrapped = true
            t.Text = "Ride A Pet LAB v22\nInicializando..."
            t.Parent = f
            return g
        end)
        return ok and gui or nil
    end

    -- Interface de bootstrap criada ANTES de require/loaders/diagnósticos.
    -- Se qualquer etapa posterior falhar, o usuário ainda verá o erro.
    local BootGui = CreateBootstrapUI()
    local function BootStatus(text)
        if BootGui then
            pcall(function()
                local f = BootGui:FindFirstChildOfClass("Frame")
                local label = f and f:FindFirstChild("Status")
                if label then label.Text = tostring(text) end
            end)
        end
    end
    BootStatus("Ride A Pet LAB v22\nExecutor: " .. ExecutorName .. "\nValidando ambiente...")
    local ALLOWED_PLACE_ID = 124216119978534
    if tonumber(game.PlaceId) ~= ALLOWED_PLACE_ID then
        BootStatus("Ride A Pet LAB v22\nJogo incorreto.\nPlaceId atual: " .. tostring(game.PlaceId) .. "\nEsperado: " .. tostring(ALLOWED_PLACE_ID))
        warn("[RideAPet v22] Bloqueado fora do Monter um Pet. PlaceId=" .. tostring(game.PlaceId))
        return
    end

    local Destroyed = false
    local Connections = {}
    local Rayfield, Window
    local SpeedConnection
    local EggESP = {}
    local Busy = false
    local JobToken = 0

    local function Connect(signal, callback)
        local ok, conn = pcall(function()
            return signal:Connect(callback)
        end)
        if ok and conn then
            table.insert(Connections, conn)
        end
        return conn
    end

    local function DisconnectAll()
        for _, conn in ipairs(Connections) do
            pcall(function() conn:Disconnect() end)
        end
        Connections = {}
        if SpeedConnection then
            pcall(function() SpeedConnection:Disconnect() end)
            SpeedConnection = nil
        end
    end

    local State = {
        status = "Inicializando...",
        errors = 0,
        collected = 0,
        placed = 0,
        hatched = 0,
        claimed = 0,
        fed = 0,
        boughtFood = 0,
        sold = 0,
        favorited = 0,
        manualTests = 0,
        autoCollect = false,
        autoPlace = false,
        autoHatch = false,
        autoBest = false,
        autoIndex = false,
        autoFeed = false,
        autoBuyFood = false,
        autoSell = false,
        autoFavorites = false,
        autoFarm = false,
        autoRideBest = false,
        rideBestMetric = "Speed",
        serverHopInterval = 300,
        antiAFK = true,
        eggESP = false,
        espDistance = 5000,
        maxCollectDistance = 15000,
        minLuck = 0,
        minWeight = 0,
        eggPriority = "Highest luck",
        eggSearch = "",
        selectedEgg = "",
        selectedPetKey = "",
        selectedFood = "",
        walkSpeed = 16,
        fov = 70,
        jumpPower = 50,
        tweenSpeed = 180,
        selectedRarities = {},
        selectedTypes = {},
        selectedMutations = {},
        mutatedOnly = false,
        feedPets = {},
        buyFoods = {},
        favoriteRarities = {},
        favoriteTypes = {},
        sellFavoritesProtected = true,
        foodAmount = 1,
        sellOneByOne = true,
        autoServerHop = false,
        serverHopInterval = 300,
        startedAt = os.clock(),
        failureStreak = {},
        failurePaused = {},
        lastRemoteFire = {},
        failedEggs = {},
        compatibility = {},
    }

    local OriginalPlayer = {
        walkSpeed = nil,
        jumpPower = nil,
        useJumpPower = nil,
        fov = nil,
    }

    for _, r in ipairs({"Common","Rare","Epic","Legendary","Mythic","Divine","Ethereal"}) do
        State.selectedRarities[r] = true
        State.favoriteRarities[r] = true
    end

    local function Status(text)
        State.status = tostring(text)
        print("[RideAPet] " .. State.status)
    end

    local function Error(context, err)
        State.errors += 1
        Status(context .. ": " .. tostring(err))
        warn("[RideAPet v22] " .. context .. ": " .. tostring(err))
    end

    local function Notify(title, content, duration)
        if Rayfield then
            pcall(function()
                Rayfield:Notify({
                    Title = title or "Ride A Pet",
                    Content = content or "",
                    Duration = duration or 3,
                })
            end)
        end
    end

    local function SafeRequire(moduleScript)
        if not moduleScript or not moduleScript:IsA("ModuleScript") then
            return nil
        end
        local ok, result = pcall(require, moduleScript)
        return ok and result or nil
    end

    local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local GameRemotes = Remotes and Remotes:FindFirstChild("Game")
    local ServerData = ReplicatedStorage:FindFirstChild("ServerData")
    local ActiveEggs = ServerData and ServerData:FindFirstChild("ActiveEggs")
    local SavedData = LocalPlayer:FindFirstChild("SavedData")

    local GameDataFolder = ReplicatedStorage:FindFirstChild("GameData")
    local GameServicesFolder = ReplicatedStorage:FindFirstChild("GameServices")
    local Data = {
        Eggs = SafeRequire(GameDataFolder and GameDataFolder:FindFirstChild("Eggs")),
        Pets = SafeRequire(GameDataFolder and GameDataFolder:FindFirstChild("Pets")),
        General = SafeRequire(GameDataFolder and GameDataFolder:FindFirstChild("General")),
        Mutations = SafeRequire(GameDataFolder and GameDataFolder:FindFirstChild("Mutations")),
        EggBaskets = SafeRequire(GameDataFolder and GameDataFolder:FindFirstChild("EggBaskets")),
        IndexRewards = SafeRequire(GameDataFolder and GameDataFolder:FindFirstChild("IndexRewards")),
        Foods = SafeRequire(GameDataFolder and GameDataFolder:FindFirstChild("Foods")),
        Shop = SafeRequire(GameDataFolder and GameDataFolder:FindFirstChild("Shop")),
    }
    local Services = {
        PetAging = SafeRequire(GameServicesFolder and GameServicesFolder:FindFirstChild("PetAging")),
        DayNight = SafeRequire(GameServicesFolder and GameServicesFolder:FindFirstChild("DayNight")),
    }
    local Renderer = SafeRequire(
        LocalPlayer:FindFirstChild("PlayerScripts")
        and LocalPlayer.PlayerScripts:FindFirstChild("Game")
        and LocalPlayer.PlayerScripts.Game:FindFirstChild("Pets")
        and LocalPlayer.PlayerScripts.Game.Pets:FindFirstChild("PetRenderer")
    )

    local function RefreshGameReferences()
        Remotes = ReplicatedStorage:FindFirstChild("Remotes")
        GameRemotes = Remotes and Remotes:FindFirstChild("Game")
        ServerData = ReplicatedStorage:FindFirstChild("ServerData")
        ActiveEggs = ServerData and ServerData:FindFirstChild("ActiveEggs")
        SavedData = LocalPlayer:FindFirstChild("SavedData")
        GameDataFolder = ReplicatedStorage:FindFirstChild("GameData")
        GameServicesFolder = ReplicatedStorage:FindFirstChild("GameServices")
        Data.Eggs = SafeRequire(GameDataFolder and GameDataFolder:FindFirstChild("Eggs"))
        Data.Pets = SafeRequire(GameDataFolder and GameDataFolder:FindFirstChild("Pets"))
        Data.General = SafeRequire(GameDataFolder and GameDataFolder:FindFirstChild("General"))
        Data.Mutations = SafeRequire(GameDataFolder and GameDataFolder:FindFirstChild("Mutations"))
        Data.EggBaskets = SafeRequire(GameDataFolder and GameDataFolder:FindFirstChild("EggBaskets"))
        Data.IndexRewards = SafeRequire(GameDataFolder and GameDataFolder:FindFirstChild("IndexRewards"))
        Data.Foods = SafeRequire(GameDataFolder and GameDataFolder:FindFirstChild("Foods"))
        Data.Shop = SafeRequire(GameDataFolder and GameDataFolder:FindFirstChild("Shop"))
        Services.PetAging = SafeRequire(GameServicesFolder and GameServicesFolder:FindFirstChild("PetAging"))
        Services.DayNight = SafeRequire(GameServicesFolder and GameServicesFolder:FindFirstChild("DayNight"))
        Renderer = SafeRequire(
            LocalPlayer:FindFirstChild("PlayerScripts")
            and LocalPlayer.PlayerScripts:FindFirstChild("Game")
            and LocalPlayer.PlayerScripts.Game:FindFirstChild("Pets")
            and LocalPlayer.PlayerScripts.Game.Pets:FindFirstChild("PetRenderer")
        )
    end

    local function InitializeFilterDefaults()
        if Data.Eggs then
            for name, data in pairs(Data.Eggs) do
                if type(data) == "table" and not data.Premium then
                    State.selectedTypes[name] = true
                end
            end
        end
        if Data.Mutations then
            State.selectedMutations.None = true
            for name, data in pairs(Data.Mutations) do
                if type(data) == "table" then State.selectedMutations[name] = true end
            end
        else
            State.selectedMutations.None = true
        end
        if Data.Pets then
            for name, data in pairs(Data.Pets) do
                if type(data) == "table" then State.favoriteTypes[name] = true end
            end
        end
    end

    local function WaitForGameStructure(seconds)
        local deadline = os.clock() + (seconds or 12)
        repeat
            RefreshGameReferences()
            if GameRemotes and ActiveEggs and SavedData and Data.Eggs and Data.Pets then
                return true
            end
            task.wait(0.25)
        until os.clock() >= deadline or Destroyed
        return GameRemotes ~= nil and ActiveEggs ~= nil
    end

    local function Value(name, default)
        local obj = SavedData and SavedData:FindFirstChild(name)
        if obj then
            local ok, value = pcall(function() return obj.Value end)
            if ok then return value end
        end
        return default
    end

    local function Character()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if humanoid and root and humanoid.Health > 0 then
            return character, humanoid, root
        end
    end

    local function Tools()
        local result = {}
        for _, root in ipairs({
            LocalPlayer:FindFirstChild("Backpack"),
            LocalPlayer.Character,
        }) do
            if root then
                for _, item in ipairs(root:GetChildren()) do
                    if item:IsA("Tool") then
                        table.insert(result, item)
                    end
                end
            end
        end
        return result
    end

    local function Tool(name, key)
        for _, tool in ipairs(Tools()) do
            local matchesName = (not name or tool.Name == name)
            local matchesKey = (not key or tool:GetAttribute("PetKey") == key)
            if matchesName and matchesKey then
                return tool
            end
        end
    end

    local function Equip(tool)
        local _, humanoid = Character()
        if humanoid and tool and tool.Parent then
            local ok = pcall(function() humanoid:EquipTool(tool) end)
            return ok
        end
        return false
    end

    local function GameRemote(name)
        if not GameRemotes then return nil end
        local remote = GameRemotes:FindFirstChild(name)
        if remote and remote:IsA("RemoteEvent") then
            return remote
        end
        return nil
    end

    local function Fire(name, ...)
        if IsPaused(name) then return false end
        if not RemoteCooldown(name, 0.12) then return false end
        local remote = GameRemote(name)
        if not remote then
            RecordFailure("Remote " .. name, "ausente")
            return false
        end
        local ok, err = pcall(function(...)
            remote:FireServer(...)
        end, ...)
        if not ok then
            RecordFailure(name, err)
            return false
        end
        State.failureStreak[name] = {count = 0, at = os.clock()}
        return true
    end

    local function WaitFor(predicate, seconds, token)
        local deadline = os.clock() + seconds
        repeat
            if Destroyed then return false end
            if token and token ~= JobToken then return false end
            local ok, result = pcall(predicate)
            if ok and result then return result end
            task.wait(0.1)
        until os.clock() >= deadline
        return false
    end

    local function StartJob(label)
        if Busy then return nil end
        Busy = true
        JobToken += 1
        Status(label)
        return JobToken
    end

    local function EndJob(token)
        if token == JobToken then
            Busy = false
        end
    end

    local function StopMovement()
        if SpeedConnection then
            pcall(function() SpeedConnection:Disconnect() end)
            SpeedConnection = nil
        end
        local _, humanoid, root = Character()
        if humanoid then
            humanoid.PlatformStand = false
            humanoid.AutoRotate = true
        end
        if root then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end

    local function EnsureDismounted(token)
        if Destroyed or (token and token ~= JobToken) then return false end
        if LocalPlayer:GetAttribute("IsRiding") then
            if not Fire("PetDismount") then return false end
            if not WaitFor(function() return not LocalPlayer:GetAttribute("IsRiding") end, 3, token) then
                return false
            end
        end
        return true
    end

    local function MoveTo(position, token, radius)
        if token ~= JobToken or Destroyed then return false end
        if not EnsureDismounted(token) then return false end
        local character, humanoid, root = Character()
        if not character or not humanoid or not root then return false end

        local target = position + Vector3.new(0, math.max(3, humanoid.HipHeight + root.Size.Y / 2), 0)
        local duration = math.max(0.1, (root.Position - target).Magnitude / math.clamp(State.tweenSpeed, 40, 350))

        local originalPlatformStand = humanoid.PlatformStand
        local originalAutoRotate = humanoid.AutoRotate
        local collisionBackup = {}
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                collisionBackup[part] = part.CanCollide
            end
        end

        humanoid.PlatformStand = true
        humanoid.AutoRotate = false

        local tween
        local okCreate, tweenResult = pcall(function()
            return TweenService:Create(
                root,
                TweenInfo.new(duration, Enum.EasingStyle.Linear),
                {CFrame = CFrame.new(target) * root.CFrame.Rotation}
            )
        end)
        if not okCreate or not tweenResult then
            humanoid.PlatformStand = originalPlatformStand
            humanoid.AutoRotate = originalAutoRotate
            return false
        end
        tween = tweenResult
        local collisionConnection
        collisionConnection = Connect(RunService.Stepped, function()
            if root.Parent and humanoid.Health > 0 then
                for part in pairs(collisionBackup) do
                    if part.Parent then part.CanCollide = false end
                end
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end
        end)

        tween:Play()
        local deadline = os.clock() + duration + 3
        while token == JobToken and root.Parent and humanoid.Health > 0
            and os.clock() < deadline
            and tween.PlaybackState == Enum.PlaybackState.Playing do
            task.wait(0.05)
        end
        local completed = tween.PlaybackState == Enum.PlaybackState.Completed
        pcall(function() tween:Cancel() end)
        pcall(function() tween:Destroy() end)
        if collisionConnection then
            pcall(function() collisionConnection:Disconnect() end)
            for i, conn in ipairs(Connections) do
                if conn == collisionConnection then table.remove(Connections, i) break end
            end
        end
        for part, value in pairs(collisionBackup) do
            if part.Parent then part.CanCollide = value end
        end
        if humanoid.Parent then
            humanoid.PlatformStand = originalPlatformStand
            humanoid.AutoRotate = originalAutoRotate
        end
        if root.Parent then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
        if not completed or token ~= JobToken then return false end
        task.wait(0.2)
        local _, _, currentRoot = Character()
        return currentRoot == root and (root.Position - target).Magnitude <= math.max(radius or 10, 12)
    end

    local function Plot()
        local plots = Workspace:FindFirstChild("Plots")
        if not plots then return nil end
        for _, plot in ipairs(plots:GetChildren()) do
            local data = plot:FindFirstChild("Data")
            local owner = data and data:FindFirstChild("Owner")
            if owner and owner.Value == LocalPlayer then
                return plot
            end
        end
    end

    local Basket
    local EggTools

    local function Home(token)
        if token ~= JobToken or Destroyed then return false end
        local plot = Plot()
        local base = plot and plot:FindFirstChild("Baseplate")
        local _, _, root = Character()
        if not plot or not base or not root then return false end

        local point = base.CFrame:PointToObjectSpace(root.Position)
        local onPlot = math.abs(point.X) < base.Size.X / 2
            and math.abs(point.Z) < base.Size.Z / 2
            and math.abs(point.Y) < 35

        if #Basket() > 0 then
            local expected = {}
            for _, egg in ipairs(Basket()) do
                local name = egg:GetAttribute("Egg")
                if name then expected[name] = (expected[name] or 0) + 1 end
            end
            local beforeTools = {}
            for _, tool in ipairs(EggTools()) do beforeTools[tool] = true end

            if not onPlot and not MoveTo(base.Position + Vector3.new(0, 3, 0), token, 12) then
                return false
            end

            local function delivered()
                if #Basket() > 0 then return false end
                local received = {}
                for _, tool in ipairs(EggTools()) do
                    if not beforeTools[tool] then
                        received[tool.Name] = (received[tool.Name] or 0) + 1
                    end
                end
                for name, count in pairs(expected) do
                    if (received[name] or 0) < count then return false end
                end
                return true
            end

            if not WaitFor(delivered, 4, token) then
                Status("Entrega do ovo não confirmada.")
                return false
            end
            return true
        end

        if onPlot then return true end
        return MoveTo(base.Position + Vector3.new(0, 3, 0), token, 12)
    end

    Basket = function()
        local basket = LocalPlayer:FindFirstChild("Basket")
        return basket and basket:GetChildren() or {}
    end

    local function EggCapacity()
        if not Data.EggBaskets then return 1 end
        local config = Data.EggBaskets[Value("EquippedEggBasket", "Wooden")]
        return config and config.Capacity or 1
    end

    EggTools = function()
        local result = {}
        for _, tool in ipairs(Tools()) do
            if Data.Eggs and Data.Eggs[tool.Name] and not tool:GetAttribute("PetKey") then
                table.insert(result, tool)
            end
        end
        table.sort(result, function(a, b)
            local al = Data.Eggs[a.Name].Luck or 0
            local bl = Data.Eggs[b.Name].Luck or 0
            return al > bl
        end)
        return result
    end

    local function FormatNumber(value)
        value = tonumber(value)
        if not value then return "?" end
        local units = {{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}}
        for _, item in ipairs(units) do
            if math.abs(value) >= item[1] then
                return string.format("%.2f%s", value / item[1], item[2])
            end
        end
        return string.format("%.2f", value):gsub("%.?0+$","")
    end

    local RarityOrder = {
        Common = 1, Rare = 2, Epic = 3, Legendary = 4,
        Mythic = 5, Divine = 6, Ethereal = 7,
    }

    local function EggRowFromObject(obj)
        if not obj or not Data.Eggs then return nil end
        local name = obj:GetAttribute("Egg")
        local data = name and Data.Eggs[name]
        local position = obj:GetAttribute("Position")
        if not data or typeof(position) ~= "Vector3" then return nil end
        local privateTo = obj:GetAttribute("PrivateTo")
        if privateTo and privateTo ~= LocalPlayer.UserId then return nil end
        local collectedText = "," .. tostring(LocalPlayer:GetAttribute("CollectedEggs") or "") .. ","
        if string.find(collectedText, "," .. tostring(obj.Name) .. ",", 1, true) then return nil end

        local mutation = obj:GetAttribute("Mutation")
        local spawnMutation = obj:GetAttribute("SpawnMutation")
        local rawWeight = tonumber(obj:GetAttribute("Weight") or 1) or 1
        local kg = rawWeight
        if Data.General and type(Data.General.ShownEggKG) == "function" then
            local okKG, shown = pcall(Data.General.ShownEggKG, rawWeight)
            if okKG and tonumber(shown) then kg = tonumber(shown) end
        end
        local luck = tonumber(data.Luck or 0) or 0
        local rarity = data.Rarity or "Common"
        local row = {
            ID = obj.Name,
            Object = obj,
            Name = name,
            Position = position,
            Rarity = rarity,
            Luck = luck,
            Weight = kg,
            Mutation = mutation,
            SpawnMutation = spawnMutation,
            Distance = math.huge,
        }
        local _, _, root = Character()
        if root then
            row.Distance = (root.Position - position).Magnitude
        end
        local label = {}
        if mutation and mutation ~= "" then table.insert(label, mutation) end
        if spawnMutation and spawnMutation ~= "" and spawnMutation ~= mutation then table.insert(label, spawnMutation) end
        row.MutationLabel = #label > 0 and table.concat(label, " + ") or "None"
        return row
    end

    local function MatchesEgg(row)
        if not row then return false end
        if next(State.selectedRarities) and not State.selectedRarities[row.Rarity] then return false end
        if next(State.selectedTypes) and not State.selectedTypes[row.Name] then return false end

        local mutationCount = 0
        local mutationOK = false
        for _, mutation in ipairs({row.Mutation, row.SpawnMutation}) do
            if mutation and mutation ~= "" then
                mutationCount += 1
                if next(State.selectedMutations) == nil or State.selectedMutations[mutation] then
                    mutationOK = true
                end
            end
        end
        if mutationCount == 0 then
            mutationOK = next(State.selectedMutations) == nil or State.selectedMutations.None == true
        end
        if next(State.selectedMutations) == nil then mutationOK = true end
        if not mutationOK then return false end
        if State.mutatedOnly and mutationCount == 0 then return false end
        if row.Luck < State.minLuck then return false end
        if row.Weight < State.minWeight then return false end
        if row.Distance > State.maxCollectDistance then return false end
        if State.eggSearch ~= "" and not string.find(string.lower(row.Name), string.lower(State.eggSearch), 1, true) then return false end
        return true
    end

    local function EggList()
        local result = {}
        if not ActiveEggs then return result end
        for _, obj in ipairs(ActiveEggs:GetChildren()) do
            local row = EggRowFromObject(obj)
            if row and os.clock() >= (State.failedEggs[row.ID] or 0) and MatchesEgg(row) then
                table.insert(result, row)
            end
        end
        table.sort(result, function(a, b)
            if State.eggPriority == "Highest luck" and a.Luck ~= b.Luck then
                return a.Luck > b.Luck
            elseif State.eggPriority == "Rarest" and a.Rarity ~= b.Rarity then
                return (RarityOrder[a.Rarity] or 0) > (RarityOrder[b.Rarity] or 0)
            elseif State.eggPriority == "Heaviest" and a.Weight ~= b.Weight then
                return a.Weight > b.Weight
            end
            return a.Distance < b.Distance
        end)
        return result
    end

    local function EggNameList()
        local names = {}
        if not Data.Eggs then return names end
        for name, data in pairs(Data.Eggs) do
            if type(data) == "table" and not data.Premium then
                table.insert(names, name)
            end
        end
        table.sort(names, function(a, b)
            return (Data.Eggs[a].Luck or 0) < (Data.Eggs[b].Luck or 0)
        end)
        return names
    end

    local function FreeNests()
        local result = {}
        local plot = Plot()
        local nests = plot and plot:FindFirstChild("Nests")
        if nests then
            for _, nest in ipairs(nests:GetChildren()) do
                if nest:GetAttribute("Unlocked") and not nest:GetAttribute("Occupied") then
                    table.insert(result, nest)
                end
            end
        end
        table.sort(result, function(a, b)
            return (tonumber(a.Name) or 0) < (tonumber(b.Name) or 0)
        end)
        return result
    end

    local function PetList()
        local result, seen = {}, {}
        local renderer = Renderer

        local function AddPet(obj, stateData, placed)
            if not obj then return end
            local key = obj:GetAttribute("PetKey")
            local name = obj:GetAttribute("PetName") or obj.Name
            local data = Data.Pets and Data.Pets[name]
            if not key or not data or seen[key] then return end
            seen[key] = true
            local age = tonumber(obj:GetAttribute("Age") or (stateData and stateData.CurrentAge) or 1) or 1
            local weight = tonumber(obj:GetAttribute("Weight") or 10) or 10
            local mutation = obj:GetAttribute("Mutation")
            local spawnMutation = obj:GetAttribute("SpawnMutation")
            local factor = 1
            if Data.Mutations and type(Data.Mutations.CombinedFactor) == "function" then
                local ok, value = pcall(Data.Mutations.CombinedFactor, mutation, spawnMutation)
                if ok and tonumber(value) then factor = value end
            end
            local income = stateData and (stateData.DisplayIncome or stateData.Income)
            if not income then
                income = (data.Income or 0) * weight / 10 * factor
            end
            local speed = (data.Speed or 0) * factor
            if Services.PetAging and type(Services.PetAging.DisplaySpeedFor) == "function" then
                local ok, value = pcall(Services.PetAging.DisplaySpeedFor, data.Speed or 0, weight)
                if ok and tonumber(value) then speed = value * factor end
            end
            table.insert(result, {
                Key = key,
                Name = name,
                Object = obj,
                State = stateData,
                Placed = placed,
                Age = age,
                Weight = weight,
                Income = tonumber(income) or 0,
                Speed = tonumber(speed) or 0,
                Rarity = data.Rarity or "Common",
                Mutation = mutation,
                SpawnMutation = spawnMutation,
                Favorite = obj:GetAttribute("Favorited") == true,
            })
        end

        if renderer and type(renderer.GetAll) == "function" then
            local ok, all = pcall(renderer.GetAll)
            if ok and type(all) == "table" then
                for _, stateData in pairs(all) do
                    if stateData.OwnerUserId == LocalPlayer.UserId and stateData.Model and stateData.Model.Parent then
                        AddPet(stateData.Model, stateData, true)
                    end
                end
            end
        end

        local plot = Plot()
        local placedPets = plot and plot:FindFirstChild("Pets")
        if placedPets then
            for _, pet in ipairs(placedPets:GetChildren()) do
                AddPet(pet, nil, true)
            end
        end

        local _, _, root = Character()
        local mountJoint = root and root:FindFirstChild("PetMountJoint")
        if mountJoint and mountJoint.Part1 and mountJoint.Part1.Parent then
            AddPet(mountJoint.Part1.Parent, nil, false)
        end

        for _, tool in ipairs(Tools()) do
            AddPet(tool, nil, false)
        end

        table.sort(result, function(a, b)
            return a.Income > b.Income
        end)
        return result
    end

    local function InventoryPets()
        local placed = {}
        local result, seen = {}, {}
        for _, pet in ipairs(PetList()) do
            if pet.Placed then placed[pet.Key] = true end
        end
        local _, _, root = Character()
        local joint = root and root:FindFirstChild("PetMountJoint")
        local mounted = joint and joint.Part1 and joint.Part1.Parent
        local mountedKey = mounted and mounted:GetAttribute("PetKey")
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        local character = LocalPlayer.Character

        for _, tool in ipairs(Tools()) do
            local key = tool:GetAttribute("PetKey")
            local name = tool:GetAttribute("PetName") or tool.Name
            local data = Data.Pets and Data.Pets[name]
            if key and data and not seen[key] and not placed[key] and key ~= mountedKey
                and (tool.Parent == backpack or tool.Parent == character) then
                seen[key] = true
                table.insert(result, {
                    Key = key,
                    Name = name,
                    Rarity = data.Rarity or "Common",
                    Tool = tool,
                    Favorite = tool:GetAttribute("Favorited") == true,
                })
            end
        end
        table.sort(result, function(a, b) return a.Name < b.Name end)
        return result
    end

    local function EggTimers()
        local rows = {}
        local plot = Plot()
        local eggs = plot and plot:FindFirstChild("Eggs")
        if not eggs or not Data.Eggs or not Data.General or not Services.DayNight then return rows end

        for _, egg in ipairs(eggs:GetChildren()) do
            local info = egg:FindFirstChild("EggData", true)
            local data = Data.Eggs[egg.Name]
            local start = info and info:FindFirstChild("PlaceTime")
            local weight = info and info:FindFirstChild("Weight")
            if data and start and type(Data.General.GrowthTimeFor) == "function"
                and type(Services.DayNight.GrowthRealRemaining) == "function" then
                local ok1, total = pcall(Data.General.GrowthTimeFor, data.GrowthTime or 0, weight and weight.Value or 1)
                local ok2, remaining = pcall(Services.DayNight.GrowthRealRemaining, start.Value, total)
                if ok1 and ok2 then
                    table.insert(rows, {
                        Object = egg,
                        Key = egg:GetAttribute("EggKey"),
                        Name = egg.Name,
                        Remaining = tonumber(remaining) or 0,
                    })
                end
            end
        end
        table.sort(rows, function(a, b) return a.Remaining < b.Remaining end)
        return rows
    end

    local function CollectEgg(egg)
        local token = StartJob("Coletando " .. egg.Name)
        if not token then return false end

        local ok = false
        if not egg.Object or not egg.Object.Parent then
            EndJob(token)
            return false
        end

        if #Basket() >= EggCapacity() then
            if not Home(token) then
                EndJob(token)
                return false
            end
        end

        local _, _, root = Character()
        if not root then
            EndJob(token)
            return false
        end
        if (root.Position - egg.Position).Magnitude > 10 then
            if not MoveTo(egg.Position, token, 10) then
                EndJob(token)
                return false
            end
        end
        if token ~= JobToken or not egg.Object.Parent then
            EndJob(token)
            return false
        end

        local before = #Basket()
        if not Fire("EggPickup", egg.ID) then
            EndJob(token)
            return false
        end

        if not WaitFor(function()
            return #Basket() > before
        end, 3, token) then
            State.failedEggs[egg.ID] = os.clock() + 30
            Status("Coleta não confirmada: " .. egg.Name .. " | ignorando por 30s")
            EndJob(token)
            return false
        end

        State.collected += 1
        Status("Coletado: " .. egg.Name)
        if Home(token) then
            Status("Ovo entregue ao plot.")
        end
        EndJob(token)
        return true
    end

    local function PlaceEggs()
        local token = StartJob("Colocando ovos")
        if not token then return false end
        local plot = Plot()
        if not plot or not Home(token) then
            EndJob(token)
            return false
        end
        local nests = FreeNests()
        if #nests == 0 then
            Status("Sem ninhos livres.")
            EndJob(token)
            return false
        end

        for _, nest in ipairs(nests) do
            local tools = EggTools()
            local tool = tools[1]
            if not tool or token ~= JobToken then break end
            if Equip(tool) then
                task.wait(0.12)
                if Fire("EggPlaced", {NestId = nest.Name}) then
                    if WaitFor(function()
                        return nest:GetAttribute("Occupied") == true
                    end, 3, token) then
                        State.placed += 1
                    end
                end
            end
        end

        EndJob(token)
        return true
    end

    local function HatchReady()
        local token = StartJob("Abrindo ovos prontos")
        if not token then return false end
        for _, egg in ipairs(EggTimers()) do
            if token ~= JobToken then break end
            if egg.Remaining <= 0 and egg.Key then
                local _, _, root = Character()
                if root and (root.Position - egg.Object:GetPivot().Position).Magnitude > 12 then
                    if not MoveTo(egg.Object:GetPivot().Position, token, 12) then break end
                end
                if Fire("Hatch", {EggKey = egg.Key}) then
                    if WaitFor(function() return not egg.Object.Parent end, 8, token) then
                        State.hatched += 1
                        Status("Hatch: " .. egg.Name)
                    end
                end
            end
        end
        EndJob(token)
        return true
    end

    local function RideBestPet()
        local pets = PetList()
        if #pets == 0 then
            Status("Nenhum pet encontrado para montar.")
            return false
        end
        local metric = State.rideBestMetric == "Income" and "Income" or "Speed"
        table.sort(pets, function(a, b)
            local av, bv = tonumber(a[metric]) or 0, tonumber(b[metric]) or 0
            if av == bv then return tostring(a.Key) < tostring(b.Key) end
            return av > bv
        end)
        local best = pets[1]
        local tool = Tool(nil, best.Key)
        if not tool then
            for _, candidate in ipairs(Tools()) do
                if candidate:GetAttribute("PetKey") == best.Key then tool = candidate break end
            end
        end
        if not tool or not Equip(tool) then
            Status("Não foi possível equipar o melhor pet.")
            return false
        end
        task.wait(0.25)
        local deadline = os.clock() + 3
        while os.clock() < deadline do
            if LocalPlayer:GetAttribute("IsRiding") then
                Status("Montado: " .. tostring(best.Name))
                return true
            end
            task.wait(0.1)
        end
        Status("Pet equipado, mas a montagem não foi confirmada.")
        return false
    end

    local function PlaceBestPets()
        local token = StartJob("Organizando melhores pets")
        if not token then return false end
        if not Home(token) then
            EndJob(token)
            return false
        end

        local pets = PetList()
        local capacity = tonumber(LocalPlayer:GetAttribute("MaxPets")) or tonumber(Value("MaxPets", 5)) or 5
        table.sort(pets, function(a, b) return a.Income > b.Income end)

        local desired = {}
        for i = 1, math.min(capacity, #pets) do
            desired[pets[i].Key] = true
        end

        for _, pet in ipairs(pets) do
            if token ~= JobToken then break end
            if pet.Placed and not desired[pet.Key] then
                Fire("PickupPet", pet.Key)
                WaitFor(function()
                    return Tool(nil, pet.Key) ~= nil
                end, 3, token)
            end
        end

        local plot = Plot()
        local base = plot and plot:FindFirstChild("Baseplate")
        if not base then
            EndJob(token)
            return false
        end

        local count = math.min(capacity, #pets)
        local cols = math.max(1, math.ceil(math.sqrt(math.max(count, 1))))
        local spacing = math.min(9, (math.min(base.Size.X, base.Size.Z) - 12) / cols)

        for i = 1, count do
            local pet = pets[i]
            local tool = Tool(nil, pet.Key)
            if tool and Equip(tool) then
                task.wait(0.12)
                local pos = (
                    base.CFrame
                    * CFrame.new(
                        ((i - 1) % cols - (cols - 1) / 2) * spacing,
                        4,
                        math.floor((i - 1) / cols) * spacing
                    )
                ).Position
                if Fire("PlacePet", pet.Key, pos) then
                    WaitFor(function()
                        for _, p in ipairs(PetList()) do
                            if p.Key == pet.Key and p.Placed then
                                return true
                            end
                        end
                        return false
                    end, 3, token)
                end
            end
        end

        Status("Melhores pets organizados.")
        EndJob(token)
        return true
    end

    local function ClaimIndex()
        if not Data.IndexRewards then return false end
        if type(Data.IndexRewards.StageAt) ~= "function"
            or type(Data.IndexRewards.DiscoveredCount) ~= "function" then
            return false
        end

        local stage = tonumber(Value("IndexRewardStage", 0)) or 0
        local reward = Data.IndexRewards.StageAt(stage)
        local owned = Value("OwnedPets", "")
        local discovered = Data.IndexRewards.DiscoveredCount(owned)

        if reward and discovered >= reward.Goal then
            local token = StartJob("Resgatando recompensa do Index")
            if not token then return false end
            if Fire("ClaimIndexReward") then
                if WaitFor(function()
                    return tonumber(Value("IndexRewardStage", 0)) ~= stage
                end, 2, token) then
                    State.claimed += 1
                    Status("Recompensa do Index resgatada.")
                end
            end
            EndJob(token)
            return true
        end
        return false
    end

    local function FoodCount(name)
        local count = 0
        for _, tool in ipairs(Tools()) do
            if tool.Name == name then
                local data = tool:FindFirstChild("Data")
                local amount = data and data:FindFirstChild("Amount")
                if amount and amount:IsA("ValueBase") then
                    count += math.max(0, math.floor(tonumber(amount.Value) or 0))
                else
                    count += 1
                end
            end
        end
        return count
    end

    local function BuyFood(name, amount)
        amount = math.clamp(math.floor(tonumber(amount) or 1), 1, 100)
        for _ = 1, amount do
            if not Data.Shop or not Data.Shop.Food then break end
            local def = Data.Shop.Food[name]
            if not def or type(def.Price) ~= "number" then break end
            local cash = tonumber(Value("Cash", 0)) or 0
            if cash < def.Price then break end
            local before = FoodCount(name)
            if not Fire("BuyWithCash", "Food", name) then break end
            if WaitFor(function()
                return FoodCount(name) > before
            end, 3) then
                State.boughtFood += 1
            else
                break
            end
        end
    end

    local function FeedPet(petKey, foodName)
        local pet
        for _, item in ipairs(PetList()) do
            if item.Key == petKey then pet = item break end
        end
        if not pet then return false end
        if FoodCount(foodName) <= 0 then return false end

        local token = StartJob("Alimentando " .. pet.Name)
        if not token then return false end

        local _, _, root = Character()
        if pet.Placed and pet.Object and pet.Object:IsA("Model") and root then
            local pos = pet.Object:GetPivot().Position
            if (root.Position - pos).Magnitude > 18 then
                if not MoveTo(pos, token, 12) then
                    EndJob(token)
                    return false
                end
            end
        end

        local foodTool = Tool(foodName)
        if not Equip(foodTool) then
            EndJob(token)
            return false
        end

        task.wait(0.15)
        local before = FoodCount(foodName)
        if Fire("FeedPet", petKey, foodName)
            and WaitFor(function()
                return FoodCount(foodName) < before
            end, 3, token) then
            State.fed += 1
            Status("Alimentado: " .. pet.Name)
            EndJob(token)
            return true
        end

        EndJob(token)
        return false
    end

    local SellAPI
    local SellDialogue
    local SellDialogueRevision = 0

    local function InitSell()
        local dialogue = ReplicatedStorage:FindFirstChild("Dialogue")
        local modules = dialogue and dialogue:FindFirstChild("Modules")
        local remotes = dialogue and dialogue:FindFirstChild("Remotes")
        local module = modules and modules:FindFirstChild("DialogueModule")
        local api = SafeRequire(module)
        if type(api) ~= "table" or type(api.SelectOption) ~= "function" or not remotes then
            return false
        end

        SellAPI = api
        for _, name in ipairs({"DialogueSend","DialogueUpdate"}) do
            local remote = remotes:FindFirstChild(name)
            if remote and remote:IsA("RemoteEvent") then
                Connect(remote.OnClientEvent, function(data)
                    if type(data) == "table" then
                        SellDialogue = data
                        SellDialogueRevision += 1
                    end
                end)
            end
        end
        return true
    end

    local function SellVendor()
        local stalls = Workspace:FindFirstChild("Stalls")
        local stall = stalls and stalls:FindFirstChild("Sell")
        local npc = stall and stall:FindFirstChild("Richie")
        local root = npc and npc:FindFirstChild("HumanoidRootPart")
        local prompt = root and root:FindFirstChildOfClass("ProximityPrompt")
        return npc, root, prompt
    end

    local function SellOptionReady(npc)
        if not SellDialogue or SellDialogue.Model ~= npc then return false end
        local offered = false
        for _, option in ipairs(SellDialogue.Options or {}) do
            if option.Text == "I would like to sell this" then
                offered = true
                break
            end
        end
        if not offered then return false end

        local options = LocalPlayer.PlayerGui:FindFirstChild("Options")
        local button = options and options:FindFirstChild("I would like to sell this")
        return button and button:IsA("GuiButton") and button.Visible and button.Active and options.Enabled
    end

    local function OpenSellDialogue(npc, prompt, token)
        if SellOptionReady(npc) then return true end
        if type(fireproximityprompt) ~= "function" then
            Status("Delta/executor não expõe fireproximityprompt.")
            return false
        end
        local revision = SellDialogueRevision
        if not pcall(fireproximityprompt, prompt) then return false end
        return WaitFor(function()
            return SellDialogueRevision > revision and SellOptionReady(npc)
        end, 5, token)
    end

    local function SellOne(petKey)
        local pet
        for _, item in ipairs(InventoryPets()) do
            if item.Key == petKey then pet = item break end
        end
        if not pet or (State.sellFavoritesProtected and pet.Favorite) then
            return false
        end
        local npc, vendorRoot, prompt = SellVendor()
        if not npc or not vendorRoot or not prompt or not SellAPI then
            Status("Venda indisponível neste cliente.")
            return false
        end

        local token = StartJob("Vendendo " .. pet.Name)
        if not token then return false end

        local _, _, root = Character()
        if not root then
            EndJob(token)
            return false
        end

        local range = math.max(5, math.min(18, prompt.MaxActivationDistance - 3))
        if (root.Position - vendorRoot.Position).Magnitude > range then
            if not MoveTo(vendorRoot.Position + vendorRoot.CFrame.LookVector * 8, token, 12) then
                EndJob(token)
                return false
            end
        end

        pet = nil
        for _, item in ipairs(InventoryPets()) do
            if item.Key == petKey then pet = item break end
        end
        if not pet or not Equip(pet.Tool) then
            EndJob(token)
            return false
        end

        task.wait(0.2)
        if not OpenSellDialogue(npc, prompt, token) then
            EndJob(token)
            return false
        end

        if not pcall(SellAPI.SelectOption, "I would like to sell this") then
            EndJob(token)
            return false
        end

        local confirmed = WaitFor(function()
            return Tool(nil, petKey) == nil
        end, 5, token)

        if confirmed then
            State.sold += 1
            Status("Vendido: " .. pet.Name)
        end

        EndJob(token)
        return confirmed
    end

    local function FavoritePet(petKey)
        if not petKey then return false end
        if Fire("FavoritePet", petKey) then
            State.favorited += 1
            return true
        end
        return false
    end

    local function ShouldFavorite(pet)
        if not pet then return false end
        if next(State.favoriteRarities) and not State.favoriteRarities[pet.Rarity] then return false end
        if next(State.favoriteTypes) and not State.favoriteTypes[pet.Name] then return false end
        return true
    end

    local function NextFavoritePet()
        for _, pet in ipairs(InventoryPets()) do
            if not pet.Favorite and ShouldFavorite(pet) then return pet end
        end
    end

    local function AutoFavoriteOne()
        local pet = NextFavoritePet()
        if not pet then return false end
        return FavoritePet(pet.Key)
    end

    local function Dismount()
        if LocalPlayer:GetAttribute("IsRiding") then
            return Fire("PetDismount")
        end
        return true
    end

    local function ApplyPlayerSettings()
        local _, humanoid = Character()
        if humanoid then
            if OriginalPlayer.walkSpeed == nil then OriginalPlayer.walkSpeed = humanoid.WalkSpeed end
            if OriginalPlayer.useJumpPower == nil then OriginalPlayer.useJumpPower = humanoid.UseJumpPower end
            local jp = humanoid.JumpPower
            if OriginalPlayer.jumpPower == nil then OriginalPlayer.jumpPower = jp end
            humanoid.WalkSpeed = State.walkSpeed
            pcall(function()
                humanoid.UseJumpPower = true
                humanoid.JumpPower = State.jumpPower
            end)
        end
        local camera = Workspace.CurrentCamera
        if camera then
            if OriginalPlayer.fov == nil then OriginalPlayer.fov = camera.FieldOfView end
            camera.FieldOfView = State.fov
        end
    end

    local function RestorePlayerSettings()
        local _, humanoid = Character()
        if humanoid then
            if OriginalPlayer.walkSpeed ~= nil then humanoid.WalkSpeed = OriginalPlayer.walkSpeed end
            if OriginalPlayer.useJumpPower ~= nil then
                pcall(function() humanoid.UseJumpPower = OriginalPlayer.useJumpPower end)
            end
            if OriginalPlayer.jumpPower ~= nil then
                pcall(function() humanoid.JumpPower = OriginalPlayer.jumpPower end)
            end
        end
        local camera = Workspace.CurrentCamera
        if camera and OriginalPlayer.fov ~= nil then camera.FieldOfView = OriginalPlayer.fov end
    end

    local function ToggleSpeedBoost(enabled)
        if SpeedConnection then
            pcall(function() SpeedConnection:Disconnect() end)
            SpeedConnection = nil
        end
        if not enabled then return end
        SpeedConnection = Connect(RunService.Heartbeat, function()
            local _, humanoid = Character()
            if humanoid then
                humanoid.WalkSpeed = State.walkSpeed
            end
        end)
    end

    local function SetAntiAFK(enabled)
        State.antiAFK = enabled
        if State.afkConnection then
            pcall(function() State.afkConnection:Disconnect() end)
            State.afkConnection = nil
        end
        if not enabled then return end
        if not VirtualUser then
            Status("Anti-AFK indisponivel neste cliente.")
            return
        end
        if State.afkConnection then
            pcall(function() State.afkConnection:Disconnect() end)
            State.afkConnection = nil
        end
        State.afkConnection = Connect(LocalPlayer.Idled, function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:Button2Down(Vector2.zero, Workspace.CurrentCamera.CFrame)
                task.wait(0.15)
                VirtualUser:Button2Up(Vector2.zero, Workspace.CurrentCamera.CFrame)
            end)
        end)
    end

    local function CreateEggESP(row)
        if not row or EggESP[row.ID] then return end
        local model = Workspace:FindFirstChild("RenderedEggs")
        local target
        if model then
            for _, obj in ipairs(model:GetChildren()) do
                if obj:IsA("Model") and obj.Name == row.Name then
                    local ok, pos = pcall(function() return obj:GetPivot().Position end)
                    if ok and (pos - row.Position).Magnitude < 30 then
                        target = obj
                        break
                    end
                end
            end
        end
        if not target then return end
        local part = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
        if not part then return end

        local billboard = Instance.new("BillboardGui")
        billboard.Name = "RideAPet_v16_EggESP"
        billboard.AlwaysOnTop = true
        billboard.Size = UDim2.fromOffset(240, 70)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.Parent = part

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromScale(1, 1)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 12
        label.TextColor3 = Color3.new(1,1,1)
        label.TextStrokeTransparency = 0
        label.Parent = billboard

        local highlight = Instance.new("Highlight")
        highlight.Name = "RideAPet_v16_EggHighlight"
        highlight.Adornee = target
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillTransparency = 0.82
        highlight.Parent = target

        EggESP[row.ID] = {model = target, billboard = billboard, label = label, highlight = highlight}
    end

    local function ClearEggESP()
        for id, item in pairs(EggESP) do
            pcall(function() item.billboard:Destroy() end)
            pcall(function() item.highlight:Destroy() end)
            EggESP[id] = nil
        end
    end

    local function RefreshEggESP()
        if not State.eggESP then
            ClearEggESP()
            return
        end
        ClearEggESP()
        local rows = EggList()
        for i = 1, math.min(#rows, 60) do
            CreateEggESP(rows[i])
        end
    end

    local function UpdateEggESPText()
        if not State.eggESP then return end
        local _, _, root = Character()
        if not root then return end
        for id, item in pairs(EggESP) do
            if not item.model or not item.model.Parent then
                pcall(function() item.billboard:Destroy() end)
                pcall(function() item.highlight:Destroy() end)
                EggESP[id] = nil
            else
                local pos = item.model:GetPivot().Position
                local dist = (root.Position - pos).Magnitude
                local row
                if ActiveEggs then
                    local object = ActiveEggs:FindFirstChild(id)
                    if object then row = EggRowFromObject(object) end
                end
                if row and dist <= State.espDistance then
                    local extra = string.format(
                        "%s\n%s | %.0fx | %.2f KG\nMutation: %s\n%d studs",
                        row.Name,
                        row.Rarity,
                        row.Luck,
                        row.Weight,
                        row.MutationLabel,
                        math.floor(dist)
                    )
                    item.label.Text = extra
                    item.billboard.Enabled = true
                    item.highlight.Enabled = true
                else
                    item.billboard.Enabled = false
                    item.highlight.Enabled = false
                end
            end
        end
    end

    local function ResetVisuals()
        ClearEggESP()
        ApplyPlayerSettings()
    end

    local function ScanDiagnostics()
        local rows = {}
        local function add(name, ok, extra)
            table.insert(rows, string.format("%s %s%s", ok and "✓" or "✗", name, extra and (" • " .. extra) or ""))
        end

        add("Remotes/Game", GameRemotes ~= nil)
        add("ServerData/ActiveEggs", ActiveEggs ~= nil)
        add("SavedData", SavedData ~= nil)
        add("GameData/Eggs", Data.Eggs ~= nil)
        add("GameData/Pets", Data.Pets ~= nil)
        add("GameData/General", Data.General ~= nil)
        add("GameData/Mutations", Data.Mutations ~= nil)
        add("GameData/EggBaskets", Data.EggBaskets ~= nil)
        add("GameData/IndexRewards", Data.IndexRewards ~= nil)
        add("GameServices/PetAging", Services.PetAging ~= nil)
        add("GameServices/DayNight", Services.DayNight ~= nil)
        add("Dialogue/Sell", SellAPI ~= nil)
        add("Executor/cliente HttpGet", State.compatibility.HttpGet == "OK")
        add("Executor/cliente loader", State.compatibility.Loadstring == "OK" or State.compatibility.Load == "OK")
        add("Executor/cliente fireproximityprompt", State.compatibility.FireProximityPrompt == "OK")
        add("Executor/cliente VirtualUser", State.compatibility.VirtualUser == "OK")
        add("Executor/cliente Drawing", State.compatibility.Drawing == "OK")
        add("Executor/cliente Request", State.compatibility.Request == "OK")

        local known = {
            "EggPickup","EggPlaced","Hatch","PickupPet","PlacePet",
            "ClaimIndexReward","FeedPet","FavoritePet","BuyWithCash","PetDismount"
        }
        for _, name in ipairs(known) do
            add("Remote " .. name, GameRemote(name) ~= nil)
        end

        return table.concat(rows, "\n")
    end

    local function StopAll()
        JobToken += 1
        Busy = false
        State.autoCollect = false
        State.autoPlace = false
        State.autoHatch = false
        State.autoBest = false
        State.autoRideBest = false
        State.autoIndex = false
        State.autoFeed = false
        State.autoBuyFood = false
        State.autoSell = false
        State.autoFavorites = false
        State.autoFarm = false
        ToggleSpeedBoost(false)
        StopMovement()
        Status("Todas as automações paradas.")
    end

    local function Destroy()
        if Destroyed then return end
        Destroyed = true
        StopAll()
        if State.afkConnection then
            pcall(function() State.afkConnection:Disconnect() end)
        end
        DisconnectAll()
        ClearEggESP()
        RestorePlayerSettings()
        if Window then
            pcall(function() Window:Destroy() end)
        end
        Env[INSTANCE_KEY] = nil
    end

    Env[INSTANCE_KEY] = Destroy

    local function ProbeCompatibility()
        local function yes(v) return v and "OK" or "N/A" end
        State.compatibility = {
            HttpGet = yes(type(game.HttpGet) == "function"),
            Loadstring = yes(type(loadstring) == "function"),
            Load = yes(type(load) == "function"),
            GetGenv = yes(type(getgenv) == "function"),
            FireProximityPrompt = yes(type(fireproximityprompt) == "function"),
            VirtualUser = yes(VirtualUser ~= nil),
            Drawing = yes(type(Drawing) == "table" and type(Drawing.new) == "function"),
            Request = yes((type(request) == "function") or (type(http_request) == "function")),
        }
    end

    local function RecordFailure(label, err)
        local data = State.failureStreak[label] or {count = 0, at = 0}
        if os.clock() - data.at > 20 then data.count = 0 end
        data.count += 1
        data.at = os.clock()
        State.failureStreak[label] = data
        if data.count >= 5 then
            State.failurePaused[label] = true
            Status(label .. " pausado apos falhas repetidas")
            Notify("Protecao", label .. " foi pausado automaticamente apos 5 falhas.", 5)
        end
        Error(label, err)
    end

    local function IsPaused(label)
        return State.failurePaused[label] == true
    end

    local function RemoteCooldown(name, seconds)
        local now = os.clock()
        local last = State.lastRemoteFire[name] or 0
        if now - last < seconds then return false end
        State.lastRemoteFire[name] = now
        return true
    end


    local TeleportService = GetService("TeleportService")
    local HttpService = GetService("HttpService")

    local function RejoinServer()
        if not TeleportService then
            Notify("Servidor", "TeleportService indisponível.")
            return false
        end
        local ok, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end)
        if not ok then Error("Rejoin", err) end
        return ok
    end

    local function ServerHop()
        if type(game.HttpGet) ~= "function" or not HttpService or not TeleportService then
            Notify("Servidor", "API HTTP/Teleport não disponível neste executor.", 4)
            return false
        end
        local cursor = ""
        local url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100"
        if cursor ~= "" then url = url .. "&cursor=" .. cursor end
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if not ok or type(body) ~= "string" then
            Error("ServerHop", body)
            return false
        end
        local decodeOk, data = pcall(function() return HttpService:JSONDecode(body) end)
        if not decodeOk or type(data) ~= "table" then
            Error("ServerHop", "resposta JSON inválida")
            return false
        end
        local candidates = {}
        for _, server in ipairs(data.data or {}) do
            if server.id ~= game.JobId and tonumber(server.playing) and tonumber(server.maxPlayers) and server.playing < server.maxPlayers then
                candidates[#candidates + 1] = server.id
            end
        end
        if #candidates == 0 then
            Notify("Servidor", "Nenhum servidor disponível encontrado.", 4)
            return false
        end
        local jobId = candidates[math.random(1, #candidates)]
        local teleOk, teleErr = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer)
        end)
        if not teleOk then Error("ServerHop", teleErr) end
        return teleOk
    end

    ------------------------------------------------------------------------
    -- UI BOOTSTRAP v22
    -- Primaria: BobloUI; fallback: UUI; fallback: Rayfield; ultimo recurso:
    -- UI nativa. O objetivo aqui e evitar o "executou e nao apareceu nada".
    ------------------------------------------------------------------------

    local UIBackend = ""
    local UIReady = false

    -- UI principal: somente Roblox/PlayerGui. Bibliotecas externas nao sao necessarias.
    -- Isso reduz pontos de falha e o tamanho do bootstrap para executores moveis.

    local function BuildNativeAdapter()
        local backend = {Kind = "Native"}
        local playerGui = GetGuiParent()
        if not playerGui then
            local deadline = os.clock() + 5
            repeat
                task.wait(0.2)
                playerGui = GetGuiParent()
            until playerGui or os.clock() >= deadline
        end
        if not playerGui then return nil end
        local okBuild, result = pcall(function()
            local old = playerGui:FindFirstChild("RideAPet_NATIVE_v22")
            if old then pcall(function() old:Destroy() end) end

            local gui = Instance.new("ScreenGui")
            gui.Name = "RideAPet_NATIVE_v22"
            gui.ResetOnSpawn = false
            gui.IgnoreGuiInset = true
            gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
            gui.DisplayOrder = 2147483647
            gui.Parent = playerGui

        local root = Instance.new("Frame")
        root.Size = UDim2.fromOffset(620, 440)
        root.Position = UDim2.new(0.5, -310, 0.5, -220)
        root.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
        root.BorderSizePixel = 0
        root.Parent = gui
        Instance.new("UICorner", root).CornerRadius = UDim.new(0, 10)

        local top = Instance.new("TextLabel")
        top.Size = UDim2.new(1, 0, 0, 42)
        top.BackgroundTransparency = 1
        top.Text = "Ride A Pet • LAB v22  [NATIVE FALLBACK]"
        top.TextColor3 = Color3.new(1,1,1)
        top.Font = Enum.Font.GothamBold
        top.TextSize = 16
        top.Parent = root

        local nav = Instance.new("ScrollingFrame")
        nav.Size = UDim2.new(0, 145, 1, -42)
        nav.Position = UDim2.fromOffset(0, 42)
        nav.BackgroundColor3 = Color3.fromRGB(14, 16, 21)
        nav.BorderSizePixel = 0
        nav.ScrollBarThickness = 4
        nav.Parent = root
        local navLayout = Instance.new("UIListLayout", nav)
        navLayout.Padding = UDim.new(0, 4)
        local navPad = Instance.new("UIPadding", nav)
        navPad.PaddingTop = UDim.new(0, 8)
        navPad.PaddingLeft = UDim.new(0, 8)
        navPad.PaddingRight = UDim.new(0, 8)

        local body = Instance.new("ScrollingFrame")
        body.Size = UDim2.new(1, -145, 1, -42)
        body.Position = UDim2.new(0, 145, 0, 42)
        body.BackgroundColor3 = Color3.fromRGB(21, 24, 30)
        body.BorderSizePixel = 0
        body.ScrollBarThickness = 5
        body.Parent = root

        local pages = {}
        local order = 0

        local function makeText(parent, text, h, size, bold)
            local l = Instance.new("TextLabel")
            l.Size = UDim2.new(1, -16, 0, h)
            l.BackgroundTransparency = 1
            l.TextXAlignment = Enum.TextXAlignment.Left
            l.TextYAlignment = Enum.TextYAlignment.Center
            l.TextWrapped = true
            l.Text = tostring(text or "")
            l.TextColor3 = Color3.fromRGB(235, 235, 240)
            l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
            l.TextSize = size or 13
            l.Parent = parent
            return l
        end

        function backend:Notify(title, content, duration)
            SafeNotifyFallback(title, content, duration)
        end
        function backend:SaveConfiguration() end
        function backend:LoadConfiguration() end
        function backend:Destroy() pcall(function() gui:Destroy() end) end
        function backend:CreateWindow()
            local window = {}
            function window:Destroy() backend:Destroy() end
            function window:CreateTab(name)
                order += 1
                local page = Instance.new("Frame")
                page.Name = "Page_" .. tostring(order)
                page.Size = UDim2.new(1, -16, 1, -16)
                page.Position = UDim2.fromOffset(8, 8)
                page.BackgroundTransparency = 1
                page.Visible = (order == 1)
                page.Parent = body
                local list = Instance.new("UIListLayout", page)
                list.Padding = UDim.new(0, 7)
                local pad = Instance.new("UIPadding", page)
                pad.PaddingLeft = UDim.new(0, 4)
                pad.PaddingRight = UDim.new(0, 4)
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, 0, 0, 34)
                btn.BackgroundColor3 = Color3.fromRGB(30, 34, 42)
                btn.Text = tostring(name)
                btn.TextColor3 = Color3.new(1,1,1)
                btn.Font = Enum.Font.GothamBold
                btn.TextSize = 12
                btn.Parent = nav
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
                btn.Activated:Connect(function()
                    for _, p in pairs(pages) do p.Visible = false end
                    page.Visible = true
                end)
                pages[name] = page
                local tab = {Root = page}
                function tab:CreateSection(title) makeText(page, tostring(title), 28, 14, true) end
                function tab:CreateLabel(text) return makeText(page, text, 28, 12, false) end
                function tab:CreateParagraph(cfg)
                    local l = makeText(page, (cfg.Title and (tostring(cfg.Title) .. "\n") or "") .. tostring(cfg.Content or ""), 60, 12, cfg.Title ~= nil)
                    local h = {}
                    function h:Set(data)
                        l.Text = (data.Title and (tostring(data.Title) .. "\n") or "") .. tostring(data.Content or "")
                    end
                    return h
                end
                function tab:CreateButton(cfg)
                    local b = Instance.new("TextButton")
                    b.Size = UDim2.new(1, 0, 0, 36)
                    b.BackgroundColor3 = Color3.fromRGB(42, 47, 58)
                    b.Text = tostring(cfg.Name or "Button")
                    b.TextColor3 = Color3.new(1,1,1)
                    b.Font = Enum.Font.GothamBold
                    b.TextSize = 12
                    b.Parent = page
                    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
                    b.Activated:Connect(function() pcall(cfg.Callback) end)
                    return b
                end
                function tab:CreateToggle(cfg)
                    local on = cfg.CurrentValue == true
                    local b = Instance.new("TextButton")
                    b.Size = UDim2.new(1, 0, 0, 36)
                    b.BackgroundColor3 = on and Color3.fromRGB(34, 105, 74) or Color3.fromRGB(42, 47, 58)
                    b.Text = tostring(cfg.Name or "Toggle") .. " : " .. (on and "ON" or "OFF")
                    b.TextColor3 = Color3.new(1,1,1)
                    b.Font = Enum.Font.Gotham
                    b.TextSize = 12
                    b.Parent = page
                    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
                    b.Activated:Connect(function()
                        on = not on
                        b.Text = tostring(cfg.Name or "Toggle") .. " : " .. (on and "ON" or "OFF")
                        b.BackgroundColor3 = on and Color3.fromRGB(34, 105, 74) or Color3.fromRGB(42, 47, 58)
                        pcall(cfg.Callback, on)
                    end)
                    return b
                end
                function tab:CreateSlider(cfg)
                    local f = Instance.new("Frame")
                    f.Size = UDim2.new(1, 0, 0, 44)
                    f.BackgroundTransparency = 1
                    f.Parent = page
                    makeText(f, tostring(cfg.Name or "Slider"), 20, 12, false).Size = UDim2.new(0.55,0,0,20)
                    local box = Instance.new("TextBox")
                    box.Size = UDim2.new(0.42, 0, 0, 28)
                    box.Position = UDim2.new(0.58,0,0,0)
                    box.BackgroundColor3 = Color3.fromRGB(34, 38, 46)
                    box.TextColor3 = Color3.new(1,1,1)
                    box.Text = tostring(cfg.CurrentValue or 0)
                    box.ClearTextOnFocus = false
                    box.Parent = f
                    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)
                    box.FocusLost:Connect(function()
                        local n = tonumber(box.Text)
                        if n then
                            local range = cfg.Range or {0,100}
                            n = math.clamp(n, range[1], range[2])
                            if cfg.Increment then n = math.floor(n / cfg.Increment + 0.5) * cfg.Increment end
                            box.Text = tostring(n)
                            pcall(cfg.Callback, n)
                        end
                    end)
                    return {SetValue = function(_,v) box.Text=tostring(v); pcall(cfg.Callback,v) end}
                end
                function tab:CreateDropdown(cfg)
                    local options = cfg.Options or {}
                    local multiple = cfg.MultipleOptions == true
                    local selected = {}
                    local initial = cfg.CurrentOption or options
                    if multiple then
                        for _, value in ipairs(type(initial) == "table" and initial or {initial}) do
                            if value ~= nil then selected[tostring(value)] = true end
                        end
                    end
                    local idx = 1
                    local b = Instance.new("TextButton")
                    b.Size = UDim2.new(1,0,0,36)
                    b.BackgroundColor3 = Color3.fromRGB(42,47,58)
                    b.TextColor3 = Color3.new(1,1,1)
                    b.Font = Enum.Font.Gotham
                    b.TextSize = 12
                    b.TextWrapped = true
                    b.Parent = page
                    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)

                    local function multiValues()
                        local result = {}
                        for _, value in ipairs(options) do
                            if selected[tostring(value)] then result[#result+1] = value end
                        end
                        return result
                    end
                    local function refreshText()
                        if #options == 0 then
                            b.Text = tostring(cfg.Name or "Dropdown") .. " : -"
                            return
                        end
                        if not multiple then
                            b.Text = tostring(cfg.Name or "Dropdown") .. " : " .. tostring(options[idx] or options[1])
                            return
                        end
                        local values = multiValues()
                        local preview = #values == 0 and "None" or (#values <= 2 and table.concat(values, ", ") or (#values .. " selected"))
                        b.Text = tostring(cfg.Name or "Dropdown") .. " : " .. preview
                    end
                    refreshText()
                    b.Activated:Connect(function()
                        if #options == 0 then return end
                        if multiple then
                            local value = tostring(options[idx] or options[1])
                            selected[value] = not selected[value]
                            refreshText()
                            pcall(cfg.Callback, multiValues())
                        else
                            idx = idx % #options + 1
                            refreshText()
                            pcall(cfg.Callback, options[idx])
                        end
                    end)
                    return {
                        Refresh = function(_, newOptions)
                            options = newOptions or {}
                            idx = 1
                            if multiple then
                                local keep = {}
                                for _, value in ipairs(options) do
                                    if selected[tostring(value)] then keep[tostring(value)] = true end
                                end
                                selected = keep
                            end
                            refreshText()
                        end,
                        SetValue = function(_, value)
                            if multiple then
                                selected = {}
                                for _, item in ipairs(type(value) == "table" and value or {value}) do selected[tostring(item)] = true end
                                refreshText()
                                pcall(cfg.Callback, multiValues())
                            else
                                for i, item in ipairs(options) do
                                    if tostring(item) == tostring(value) then idx = i break end
                                end
                                refreshText()
                                pcall(cfg.Callback, options[idx])
                            end
                        end,
                    }
                end
                return tab
            end
            return window
        end
        return backend
        end)
        if not okBuild then
            warn("[RideAPet v22] BuildNativeAdapter erro: " .. tostring(result))
            return nil
        end
        return result
    end

    local function BuildUI()
        -- UI nativa é o backend principal. Bibliotecas externas foram removidas
        -- para reduzir incompatibilidades entre Delta e outros executores.
        local ok, adapter = pcall(BuildNativeAdapter)
        if ok and adapter then
            UIBackend = "NativeStable"
            UIReady = true
            State.compatibility.UI = UIBackend
            return adapter
        end
        UIBackend = "NativeFailed"
        UIReady = false
        State.compatibility.UI = UIBackend
        warn("[RideAPet v22] UI nativa falhou: " .. tostring(adapter))
        return nil
    end

    -- A UI nao depende da estrutura do jogo. Ela abre primeiro; a estrutura e carregada em background.
    BootStatus("Ride A Pet LAB v22\nCriando interface imediatamente...")
    ProbeCompatibility()
    Rayfield = BuildUI()
    if not Rayfield then
        BootStatus("Ride A Pet LAB v22\nERRO: não foi possível criar a interface.\nPlayerGui/API de UI indisponível.")
        return
    end

    local okWindow, createdWindow = pcall(function()
        return Rayfield:CreateWindow({
            Name = "Ride A Pet • LAB v22",
            Icon = 0,
            LoadingTitle = "Ride A Pet",
            LoadingSubtitle = "LAB v22 • bootstrap resiliente",
            Theme = "Default",
            DisableRayfieldPrompts = true,
            DisableBuildWarnings = true,
            ConfigurationSaving = {Enabled = true, FolderName = "RideAPetLab", FileName = "RideAPet_v22"},
            Discord = {Enabled = false},
            KeySystem = false,
        })
    end)
    if not okWindow or not createdWindow then
        BootStatus("Ride A Pet LAB v22\nFalha criando a janela UI via " .. tostring(UIBackend))
        return
    end
    Window = createdWindow

    local Dashboard = Window:CreateTab("Dashboard", 4483362458)
    local Farm = Window:CreateTab("Farm", 4483362458)
    local Eggs = Window:CreateTab("Ovos", 4483362458)
    local Pets = Window:CreateTab("Pets", 4483362458)
    local Food = Window:CreateTab("Food", 4483362458)
    local Sell = Window:CreateTab("Sell", 4483362458)
    local ESP = Window:CreateTab("ESP", 4483362458)
    local Diagnostics = Window:CreateTab("Diagnóstico", 4483362458)
    local Player = Window:CreateTab("Jogador", 4483362458)
    local Config = Window:CreateTab("Config", 4483362458)
    local Server = Window:CreateTab("Servidor", 4483362458)

    local DashboardInfo = Dashboard:CreateParagraph({
        Title = "Status",
        Content = "Carregando...",
    })

    Dashboard:CreateParagraph({
        Title = "Compatibilidade do cliente",
        Content = string.format("UI: %s • HttpGet: %s • Loader: %s • fireproximityprompt: %s • VirtualUser: %s",
            State.compatibility.UI or UIBackend or "?",
            State.compatibility.HttpGet or "?",
            (State.compatibility.Loadstring == "OK" or State.compatibility.Load == "OK") and "OK" or "N/A",
            State.compatibility.FireProximityPrompt or "?",
            State.compatibility.VirtualUser or "?"),
    })

    Dashboard:CreateButton({
        Name = "PARAR TUDO",
        Callback = StopAll,
    })

    Dashboard:CreateButton({
        Name = "ESCANEAR ESTRUTURA",
        Callback = function()
            Notify("Diagnóstico", ScanDiagnostics(), 6)
        end,
    })

    Dashboard:CreateButton({
        Name = "REFRESH EGG CACHE",
        Callback = function()
            RefreshEggESP()
            Status("Egg cache atualizado.")
        end,
    })

    Dashboard:CreateParagraph({
        Title = "Funções com assinatura confirmada",
        Content = "Confirmado: EggPickup • EggPlaced • Hatch • PickupPet • PlacePet • ClaimIndexReward • FeedPet • FavoritePet • BuyWithCash • PetDismount.\nRecursos de servidor são opcionais e dependem das APIs do executor.",
    })

    Farm:CreateSection("Loop principal")
    Farm:CreateToggle({
        Name = "Auto Farm",
        CurrentValue = false,
        Flag = "AutoFarm",
        Callback = function(v)
            State.autoFarm = v
            State.autoCollect = v
            State.autoPlace = v
            State.autoHatch = v
            State.autoBest = v
            State.autoIndex = v
        end,
    })

    Farm:CreateToggle({
        Name = "Auto Coletar Ovos",
        CurrentValue = false,
        Flag = "AutoCollect",
        Callback = function(v) State.autoCollect = v end,
    })
    Farm:CreateToggle({
        Name = "Auto Colocar Ovos",
        CurrentValue = false,
        Flag = "AutoPlace",
        Callback = function(v) State.autoPlace = v end,
    })
    Farm:CreateToggle({
        Name = "Auto Hatch",
        CurrentValue = false,
        Flag = "AutoHatch",
        Callback = function(v) State.autoHatch = v end,
    })
    Farm:CreateToggle({
        Name = "Auto Equip/Place Best",
        CurrentValue = false,
        Flag = "AutoBest",
        Callback = function(v) State.autoBest = v end,
    })
    Farm:CreateToggle({
        Name = "Auto Montar Melhor Pet",
        CurrentValue = false,
        Flag = "AutoRideBest",
        Callback = function(v) State.autoRideBest = v end,
    })

    Farm:CreateToggle({
        Name = "Auto Claim Index",
        CurrentValue = false,
        Flag = "AutoIndex",
        Callback = function(v) State.autoIndex = v end,
    })

    Farm:CreateDropdown({
        Name = "Prioridade do ovo",
        Options = {"Highest luck","Rarest","Heaviest","Nearest"},
        CurrentOption = {"Highest luck"},
        Flag = "EggPriority",
        Callback = function(v) State.eggPriority = type(v) == "table" and v[1] or v end,
    })

    Farm:CreateDropdown({
        Name = "Métrica do melhor pet",
        Options = {"Speed", "Income"},
        CurrentOption = {State.rideBestMetric},
        Callback = function(v) State.rideBestMetric = tostring(type(v) == "table" and v[1] or v) end,
    })

    Farm:CreateSlider({
        Name = "Velocidade do voo",
        Range = {40, 350},
        Increment = 5,
        CurrentValue = State.tweenSpeed,
        Flag = "TweenSpeed",
        Callback = function(v) State.tweenSpeed = v end,
    })

    Farm:CreateButton({
        Name = "COLETAR MELHOR OVO AGORA",
        Callback = function()
            local list = EggList()
            if list[1] then
                CollectEgg(list[1])
            else
                Notify("Farm", "Nenhum ovo corresponde aos filtros.")
            end
        end,
    })

    Farm:CreateButton({
        Name = "VOLTAR PARA O PLOT",
        Callback = function()
            local token = StartJob("Voltando para o plot")
            if token then
                Home(token)
                EndJob(token)
            end
        end,
    })

    local EggStatus = Eggs:CreateParagraph({
        Title = "Egg Tracker",
        Content = "Lendo...",
    })

    local EggDropdown
    local eggNames = EggNameList()
    if #eggNames == 0 then eggNames = {"Nenhum"} end

    EggDropdown = Eggs:CreateDropdown({
        Name = "Ovo selecionado",
        Options = eggNames,
        CurrentOption = {eggNames[1]},
        MultipleOptions = false,
        Flag = "SelectedEgg",
        Callback = function(v)
            State.selectedEgg = tostring(type(v) == "table" and v[1] or v or "")
        end,
    })

    Eggs:CreateButton({
        Name = "TP PARA OVO SELECIONADO",
        Callback = function()
            local row
            for _, item in ipairs(EggList()) do
                if item.Name == State.selectedEgg then
                    row = item
                    break
                end
            end
            if row then
                local token = StartJob("Indo para " .. row.Name)
                if token then
                    MoveTo(row.Position, token, 12)
                    EndJob(token)
                end
            else
                Notify("Ovos", "Ovo selecionado não está ativo agora.")
            end
        end,
    })

    Eggs:CreateSlider({
        Name = "Luck mínima",
        Range = {0, 1000000},
        Increment = 1,
        CurrentValue = 0,
        Flag = "MinLuck",
        Callback = function(v) State.minLuck = v end,
    })

    Eggs:CreateSlider({
        Name = "Peso mínimo",
        Range = {0, 1000},
        Increment = 0.1,
        CurrentValue = 0,
        Flag = "MinWeight",
        Callback = function(v) State.minWeight = v end,
    })

    Eggs:CreateSlider({
        Name = "Distância máxima",
        Range = {50, 15000},
        Increment = 50,
        CurrentValue = State.maxCollectDistance,
        Flag = "MaxCollectDistance",
        Callback = function(v) State.maxCollectDistance = v end,
    })

    Eggs:CreateButton({
        Name = "ATUALIZAR LISTA DE OVOS",
        Callback = function()
            local options = EggNameList()
            if #options == 0 then options = {"Nenhum"} end
            pcall(function() EggDropdown:Refresh(options) end)
            Notify("Ovos", tostring(#EggList()) .. " ovos compatíveis encontrados.")
        end,
    })

    local typeOptions = EggNameList()
    if #typeOptions == 0 then typeOptions = {"Nenhum"} end
    Eggs:CreateDropdown({
        Name = "Tipos de ovo",
        Options = typeOptions,
        CurrentOption = typeOptions,
        MultipleOptions = true,
        Callback = function(values)
            State.selectedTypes = {}
            for _, value in ipairs(values or {}) do if value ~= "Nenhum" then State.selectedTypes[value] = true end end
        end,
    })

    local mutationOptions = {"None"}
    if Data.Mutations then
        for name, data in pairs(Data.Mutations) do
            if type(data) == "table" then table.insert(mutationOptions, name) end
        end
        table.sort(mutationOptions)
    end
    Eggs:CreateDropdown({
        Name = "Mutações",
        Options = mutationOptions,
        CurrentOption = mutationOptions,
        MultipleOptions = true,
        Callback = function(values)
            State.selectedMutations = {}
            for _, value in ipairs(values or {}) do State.selectedMutations[value] = true end
        end,
    })

    Eggs:CreateToggle({
        Name = "Somente ovos com mutação",
        CurrentValue = false,
        Flag = "MutatedOnly",
        Callback = function(v) State.mutatedOnly = v end,
    })

    Eggs:CreateSection("Filtros de raridade")
    Eggs:CreateDropdown({
        Name = "Raridades",
        Options = {"Common","Rare","Epic","Legendary","Mythic","Divine","Ethereal"},
        CurrentOption = {"Common","Rare","Epic","Legendary","Mythic","Divine","Ethereal"},
        MultipleOptions = true,
        Flag = "RarityFilter",
        Callback = function(values)
            State.selectedRarities = {}
            for _, value in ipairs(values or {}) do State.selectedRarities[value] = true end
        end,
    })

    Pets:CreateParagraph({
        Title = "Pets detectados",
        Content = "Atualizando...",
    })

    local PetDropdown = Pets:CreateDropdown({
        Name = "Pet para ação",
        Options = {"Nenhum"},
        CurrentOption = {"Nenhum"},
        MultipleOptions = false,
        Callback = function(v)
            State.selectedPetKey = tostring(type(v) == "table" and v[1] or v or "")
        end,
    })

    Pets:CreateButton({
        Name = "REFRESH PETS",
        Callback = function()
            local options = {"Nenhum"}
            for _, pet in ipairs(PetList()) do
                table.insert(options, pet.Name .. " | " .. tostring(pet.Key))
            end
            pcall(function() PetDropdown:Refresh(options) end)
            Notify("Pets", tostring(#PetList()) .. " pets encontrados.")
        end,
    })

    Pets:CreateToggle({
        Name = "Auto Organizar Best",
        CurrentValue = false,
        Flag = "AutoBest",
        Callback = function(v) State.autoBest = v end,
    })

    Pets:CreateButton({
        Name = "ORGANIZAR BEST 1X",
        Callback = PlaceBestPets,
    })

    Pets:CreateButton({
        Name = "DESEQUIPAR / DISMOUNT",
        Callback = function()
            if Dismount() then Notify("Pets", "Dismount enviado.") else Notify("Pets", "Dismount não enviado.") end
        end,
    })

    Pets:CreateToggle({
        Name = "Auto Favoritar pets compatíveis",
        CurrentValue = false,
        Flag = "AutoFavorites",
        Callback = function(v) State.autoFavorites = v end,
    })

    Food:CreateParagraph({
        Title = "Food",
        Content = "Funções baseadas em GameData/Foods + Shop e remotes confirmados.",
    })

    local foodNames = {}
    if Data.Shop and Data.Shop.Food then
        for name, def in pairs(Data.Shop.Food) do
            if type(def) == "table" and (not Data.Foods or Data.Foods[name]) then
                table.insert(foodNames, name)
            end
        end
        table.sort(foodNames)
    end
    if #foodNames == 0 then foodNames = {"Nenhum"} end

    Food:CreateDropdown({
        Name = "Comida",
        Options = foodNames,
        CurrentOption = {foodNames[1]},
        MultipleOptions = false,
        Callback = function(v) State.selectedFood = tostring(type(v) == "table" and v[1] or v or "") end,
    })

    Food:CreateSlider({
        Name = "Quantidade por compra/ação",
        Range = {1, 20},
        Increment = 1,
        CurrentValue = State.foodAmount,
        Flag = "FoodAmount",
        Callback = function(v) State.foodAmount = math.floor(v) end,
    })

    Food:CreateToggle({
        Name = "Auto Comprar Food",
        CurrentValue = false,
        Flag = "AutoBuyFood",
        Callback = function(v) State.autoBuyFood = v end,
    })

    Food:CreateToggle({
        Name = "Auto Alimentar",
        CurrentValue = false,
        Flag = "AutoFeed",
        Callback = function(v) State.autoFeed = v end,
    })

    Food:CreateButton({
        Name = "COMPRAR FOOD 1X",
        Callback = function()
            if State.selectedFood ~= "" and State.selectedFood ~= "Nenhum" then
                BuyFood(State.selectedFood, State.foodAmount)
            end
        end,
    })

    Food:CreateButton({
        Name = "ALIMENTAR PET SELECIONADO",
        Callback = function()
            if State.selectedPetKey ~= "" and State.selectedFood ~= "" then
                FeedPet(State.selectedPetKey, State.selectedFood)
            else
                Notify("Food", "Selecione pet e comida.")
            end
        end,
    })

    Sell:CreateParagraph({
        Title = "Venda",
        Content = "A venda usa o diálogo do Richie. Se a estrutura não estiver disponível, a função fica desativada e informa o motivo.",
    })

    local sellReady = InitSell()
    Sell:CreateLabel("Sistema de venda: " .. (sellReady and "disponível" or "não detectado"))

    Sell:CreateToggle({
        Name = "Auto Sell (não-favoritos)",
        CurrentValue = false,
        Flag = "AutoSell",
        Callback = function(v) State.autoSell = v end,
    })

    Sell:CreateButton({
        Name = "VENDER 1 PET SELECIONADO",
        Callback = function()
            if State.selectedPetKey ~= "" then
                SellOne(State.selectedPetKey)
            else
                Notify("Sell", "Selecione um pet primeiro.")
            end
        end,
    })

    Sell:CreateButton({
        Name = "TELEPORTAR PARA RICHIE",
        Callback = function()
            local _, root = SellVendor()
            local _, _, playerRoot = Character()
            if root and playerRoot then
                local token = StartJob("Indo para Richie")
                if token then
                    MoveTo(root.Position + root.CFrame.LookVector * 8, token, 12)
                    EndJob(token)
                end
            else
                Notify("Sell", "Richie não encontrado.")
            end
        end,
    })

    ESP:CreateToggle({
        Name = "Egg ESP",
        CurrentValue = false,
        Flag = "EggESP",
        Callback = function(v)
            State.eggESP = v
            RefreshEggESP()
        end,
    })

    ESP:CreateSlider({
        Name = "Distância ESP",
        Range = {100, 10000},
        Increment = 100,
        CurrentValue = State.espDistance,
        Flag = "ESPDistance",
        Callback = function(v) State.espDistance = v end,
    })

    ESP:CreateButton({
        Name = "ATUALIZAR ESP",
        Callback = RefreshEggESP,
    })

    ESP:CreateParagraph({
        Title = "Legenda",
        Content = "Nome • Raridade • Luck • KG • Mutation • distância",
    })

    local DiagnosticParagraph = Diagnostics:CreateParagraph({
        Title = "Estrutura",
        Content = ScanDiagnostics(),
    })

    Diagnostics:CreateButton({
        Name = "ATUALIZAR DIAGNÓSTICO",
        Callback = function()
            DiagnosticParagraph:Set({
                Title = "Estrutura",
                Content = ScanDiagnostics(),
            })
        end,
    })

    Diagnostics:CreateButton({
        Name = "MOSTRAR REMOTES CONHECIDOS",
        Callback = function()
            local known = {"EggPickup","EggPlaced","Hatch","PickupPet","PlacePet","ClaimIndexReward","FeedPet","FavoritePet","BuyWithCash","PetDismount"}
            local lines = {}
            for _, name in ipairs(known) do
                table.insert(lines, string.format("%s = %s", name, GameRemote(name) and "FOUND" or "MISSING"))
            end
            Notify("Remotes", table.concat(lines, "\n"), 8)
        end,
    })

    Player:CreateSlider({
        Name = "WalkSpeed",
        Range = {1, 300},
        Increment = 1,
        CurrentValue = State.walkSpeed,
        Flag = "WalkSpeed",
        Callback = function(v)
            State.walkSpeed = v
            ApplyPlayerSettings()
        end,
    })

    Player:CreateSlider({
        Name = "JumpPower",
        Range = {1, 250},
        Increment = 1,
        CurrentValue = State.jumpPower,
        Flag = "JumpPower",
        Callback = function(v)
            State.jumpPower = v
            ApplyPlayerSettings()
        end,
    })

    Player:CreateSlider({
        Name = "FOV",
        Range = {30, 120},
        Increment = 1,
        CurrentValue = State.fov,
        Flag = "FOV",
        Callback = function(v)
            State.fov = v
            ApplyPlayerSettings()
        end,
    })

    Server:CreateSection("Servidor")
    Server:CreateParagraph({
        Title = "Controles de sessão",
        Content = "Recursos genéricos de TeleportService/HTTP. Se o executor bloquear HTTP, a função apenas informa a limitação."
    })
    Server:CreateButton({
        Name = "REENTRAR NO SERVIDOR ATUAL",
        Callback = RejoinServer,
    })
    Server:CreateButton({
        Name = "TROCAR DE SERVIDOR",
        Callback = ServerHop,
    })

    Config:CreateToggle({
        Name = "Anti-AFK",
        CurrentValue = true,
        Flag = "AntiAFK",
        Callback = SetAntiAFK,
    })

    Config:CreateToggle({
        Name = "Proteger favoritos ao vender",
        CurrentValue = true,
        Flag = "ProtectFavorites",
        Callback = function(v) State.sellFavoritesProtected = v end,
    })

    Config:CreateButton({
        Name = "PARAR TUDO",
        Callback = StopAll,
    })

    Config:CreateButton({
        Name = "RESTAURAR JOGADOR",
        Callback = function()
            State.walkSpeed = 16
            State.jumpPower = 50
            State.fov = 70
            ToggleSpeedBoost(false)
            ApplyPlayerSettings()
        end,
    })

    Config:CreateButton({
        Name = "SALVAR CONFIG",
        Callback = function()
            pcall(function() Rayfield:SaveConfiguration() end)
            Notify("Config", "Salvo.")
        end,
    })

    Config:CreateButton({
        Name = "RESETAR PROTECOES / FALHAS",
        Callback = function()
            State.failureStreak = {}
            State.failurePaused = {}
            State.lastRemoteFire = {}
            Status("Protecoes de falha resetadas.")
            Notify("Protecao", "Contadores e pausas de falha resetados.", 3)
        end,
    })

    Config:CreateButton({
        Name = "CARREGAR CONFIG",
        Callback = function()
            pcall(function() Rayfield:LoadConfiguration() end)
            Notify("Config", "Carregado.")
        end,
    })

    Config:CreateButton({
        Name = "REPARAR REFERÊNCIAS AGORA",
        Callback = function()
            local ok, err = pcall(function()
                RefreshGameReferences()
                InitializeFilterDefaults()
                if not SellAPI then InitSell() end
                Status("Referências reparadas.")
            end)
            if not ok then Error("Repair", err) end
        end,
    })

    Config:CreateButton({
        Name = "FECHAR",
        Callback = Destroy,
    })

    -- Carrega/refaz referencias sem bloquear o aparecimento da interface.
    task.spawn(function()
        local ok, err = pcall(function()
            WaitForGameStructure(12)
            InitializeFilterDefaults()
            RefreshGameReferences()
            if EggDropdown then
                local options = EggNameList()
                if #options == 0 then options = {"Nenhum"} end
                pcall(function() EggDropdown:Refresh(options) end)
            end
            if not SellAPI then InitSell() end
            Status("Estrutura do jogo atualizada.")
            Notify("Ride A Pet", "Estrutura carregada. Diagnostico disponivel na aba correspondente.", 3)
        end)
        if not ok then RecordFailure("Bootstrap", err) end
    end)

    -- Respawn
    Connect(LocalPlayer.CharacterAdded, function()
        task.wait(0.8)
        pcall(RefreshGameReferences)
        pcall(ApplyPlayerSettings)
    end)

    -- Loop principal único. Falha em uma função nao derruba as outras.
    task.spawn(function()
        while not Destroyed do
            if not Busy then
                local ok, err = pcall(function()
                    if State.autoIndex and not IsPaused("AutoIndex") then
                        ClaimIndex()
                    elseif State.autoHatch and not IsPaused("AutoHatch") and #EggTimers() > 0 and EggTimers()[1].Remaining <= 0 then
                        HatchReady()
                    elseif State.autoPlace and not IsPaused("AutoPlace") and #Basket() > 0 then
                        PlaceEggs()
                    elseif State.autoBest and not IsPaused("AutoBest") then
                        PlaceBestPets()
                    elseif State.autoRideBest and not IsPaused("AutoRideBest") then
                        if not LocalPlayer:GetAttribute("IsRiding") then RideBestPet() end
                    elseif State.autoFeed and not IsPaused("AutoFeed") and State.selectedPetKey ~= "" and State.selectedFood ~= "" then
                        FeedPet(State.selectedPetKey, State.selectedFood)
                    elseif State.autoBuyFood and not IsPaused("AutoBuyFood") and State.selectedFood ~= "" and State.selectedFood ~= "Nenhum" then
                        BuyFood(State.selectedFood, State.foodAmount)
                    elseif State.autoSell and not IsPaused("AutoSell") then
                        local candidates = InventoryPets()
                        for _, pet in ipairs(candidates) do
                            if not State.sellFavoritesProtected or not pet.Favorite then
                                if SellOne(pet.Key) then break end
                            end
                        end
                    elseif State.autoCollect and not IsPaused("AutoCollect") then
                        local list = EggList()
                        if list[1] then
                            CollectEgg(list[1])
                        end
                    elseif State.autoFavorites and not IsPaused("AutoFavorites") then
                        AutoFavoriteOne()
                    end
                end)
                if not ok then RecordFailure("MainLoop", err) end
            end
            task.wait(0.35)
        end
    end)

    -- Manutencao das referencias do jogo.
    task.spawn(function()
        while not Destroyed do
            local ok, err = pcall(RefreshGameReferences)
            if not ok then RecordFailure("ReferenceRefresh", err) end
            task.wait(5)
        end
    end)

    -- ESP refresh
    task.spawn(function()
        while not Destroyed do
            if State.eggESP then
                local ok, err = pcall(function()
                    RefreshEggESP()
                    UpdateEggESPText()
                end)
                if not ok then RecordFailure("EggESP", err) end
            end
            task.wait(0.8)
        end
    end)

    -- Dashboard leve; quando a lib suporta Set(), atualiza. Caso contrario o
    -- restante do script continua normalmente.
    task.spawn(function()
        while not Destroyed do
            local ok, err = pcall(function()
                RefreshGameReferences()
                if not SellAPI then InitSell() end
                if DashboardInfo and DashboardInfo.Set then
                    local rows = EggList()
                    local pets = PetList()
                    local timers = EggTimers()
                    local cash = Value("Cash", 0)
                    DashboardInfo:Set({
                        Title = "Ride A Pet • LAB v22",
                        Content = string.format(
                            "UI: %s\nStatus: %s\nCash: %s\nOvos compatíveis: %d\nPets detectados: %d\nBasket: %d • Livres: %d • Plot: %d\n\nColetados: %d • Colocados: %d • Hatch: %d\nIndex: %d • Food: %d • Feed: %d • Sold: %d • Fav: %d\nErros: %d\nEstrutura: %s",
                            tostring(UIBackend),
                            tostring(State.status),
                            FormatNumber(cash),
                            #rows,
                            #pets,
                            #Basket(),
                            #FreeNests(),
                            #timers,
                            State.collected,
                            State.placed,
                            State.hatched,
                            State.claimed,
                            State.boughtFood,
                            State.fed,
                            State.sold,
                            State.favorited,
                            State.errors,
                            (GameRemotes and ActiveEggs and SavedData) and "OK" or "INCOMPLETA"
                        )
                    })
                end
            end)
            if not ok then RecordFailure("Dashboard", err) end
            task.wait(1.5)
        end
    end)

    ProbeCompatibility()
    if BootGui then pcall(function() BootGui:Destroy() end) BootGui = nil end
    Status("LAB v22 carregado via " .. tostring(UIBackend) .. " • núcleo baseado em funções publicamente verificadas.")
    SetAntiAFK(State.antiAFK)
    ApplyPlayerSettings()
    Notify("Ride A Pet", "Interface: " .. tostring(UIBackend) .. " • pronto.", 4)

end

local ok, err = xpcall(Main, _traceback)
if not ok then
    warn("[RideAPet v22] Erro fatal:\n" .. tostring(err))
    -- Mostra o erro no PlayerGui mesmo que a janela principal tenha falhado.
    pcall(function()
        local Players = game:GetService("Players")
        local lp = Players.LocalPlayer
        local pg = lp and lp:FindFirstChild("PlayerGui")
        if not pg then return end
        local gui = pg:FindFirstChild("RideAPet_BOOT_v22")
        if not gui then
            gui = Instance.new("ScreenGui")
            gui.Name = "RideAPet_BOOT_v22"
            gui.ResetOnSpawn = false
            gui.DisplayOrder = 2147483647
            gui.Parent = pg
            local f = Instance.new("Frame")
            f.Size = UDim2.fromOffset(420, 150)
            f.Position = UDim2.new(0.5, -210, 0.5, -75)
            f.BackgroundColor3 = Color3.fromRGB(44, 22, 26)
            f.BorderSizePixel = 0
            f.Parent = gui
            Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)
            local t = Instance.new("TextLabel")
            t.Size = UDim2.new(1, -20, 1, -20)
            t.Position = UDim2.fromOffset(10, 10)
            t.BackgroundTransparency = 1
            t.TextColor3 = Color3.new(1,1,1)
            t.Font = Enum.Font.Code
            t.TextSize = 12
            t.TextWrapped = true
            t.TextXAlignment = Enum.TextXAlignment.Left
            t.TextYAlignment = Enum.TextYAlignment.Top
            t.Text = "Ride A Pet LAB v22\n\nFalha na inicialização:\nExecutor: " .. tostring(ExecutorName) .. "\n" .. tostring(err)
            t.Parent = f
        else
            local f = gui:FindFirstChildOfClass("Frame")
            local t = f and f:FindFirstChildOfClass("TextLabel")
            if t then t.Text = "Ride A Pet LAB v22\n\nFalha na inicialização:\nExecutor: " .. tostring(ExecutorName) .. "\n" .. tostring(err) end
        end
    end)
end
