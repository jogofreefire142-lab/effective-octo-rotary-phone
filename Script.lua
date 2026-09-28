if not game:IsLoaded() then 
    game.Loaded:Wait() 
end

-- [[ VARIÁVEIS GLOBAIS DE CONTROLE E CONFIGURAÇÃO ]]
_G.MAX_DETECTION_TIME = 15 
_G.StartTime = os.time()
_G.File_Name = "Elite_Pro_ServerTracker.json"
_G.IsProcessingFruit = false

-- [[ MÓDULO DE DECLARAÇÃO DE SERVIÇOS NATIVOS ]]
local Players = game:GetService("Players")
_G.LocalPlayer = Players.LocalPlayer
_G.ReplicatedStorage = game:GetService("ReplicatedStorage")
_G.HttpService = game:GetService("HttpService")
_G.TeleportService = game:GetService("TeleportService")
_G.GuiService = game:GetService("GuiService")
_G.TweenService = game:GetService("TweenService")
_G.Workspace = game:GetService("Workspace")
_G.RunService = game:GetService("RunService")

-- [[ BANCO DE DADOS DETALHADO DE FRUTAS (FRUITS DICTIONARY) ]]
_G.FruitsDatabase = {
    ["Rocket Fruit"] = {Id = 1, Name = "Rocket Fruit", Rarity = "Common"},
    ["Spin Fruit"] = {Id = 2, Name = "Spin Fruit", Rarity = "Common"},
    ["Chop Fruit"] = {Id = 3, Name = "Chop Fruit", Rarity = "Common"},
    ["Spring Fruit"] = {Id = 4, Name = "Spring Fruit", Rarity = "Common"},
    ["Bomb Fruit"] = {Id = 5, Name = "Bomb Fruit", Rarity = "Common"},
    ["Smoke Fruit"] = {Id = 6, Name = "Smoke Fruit", Rarity = "Common"},
    ["Spike Fruit"] = {Id = 7, Name = "Spike Fruit", Rarity = "Common"},
    ["Flame Fruit"] = {Id = 8, Name = "Flame Fruit", Rarity = "Uncommon"},
    ["Falcon Fruit"] = {Id = 9, Name = "Falcon Fruit", Rarity = "Uncommon"},
    ["Ice Fruit"] = {Id = 10, Name = "Ice Fruit", Rarity = "Uncommon"},
    ["Sand Fruit"] = {Id = 11, Name = "Sand Fruit", Rarity = "Uncommon"},
    ["Dark Fruit"] = {Id = 12, Name = "Dark Fruit", Rarity = "Uncommon"},
    ["Diamond Fruit"] = {Id = 13, Name = "Diamond Fruit", Rarity = "Rare"},
    ["Light Fruit"] = {Id = 14, Name = "Light Fruit", Rarity = "Rare"},
    ["Rubber Fruit"] = {Id = 15, Name = "Rubber Fruit", Rarity = "Rare"},
    ["Barrier Fruit"] = {Id = 16, Name = "Barrier Fruit", Rarity = "Rare"},
    ["Ghost Fruit"] = {Id = 17, Name = "Ghost Fruit", Rarity = "Rare"},
    ["Magma Fruit"] = {Id = 18, Name = "Magma Fruit", Rarity = "Rare"},
    ["Quake Fruit"] = {Id = 19, Name = "Quake Fruit", Rarity = "Legendary"},
    ["Buddha Fruit"] = {Id = 20, Name = "Buddha Fruit", Rarity = "Legendary"},
    ["Love Fruit"] = {Id = 21, Name = "Love Fruit", Rarity = "Legendary"},
    ["Spider Fruit"] = {Id = 22, Name = "Spider Fruit", Rarity = "Legendary"},
    ["Sound Fruit"] = {Id = 23, Name = "Sound Fruit", Rarity = "Legendary"},
    ["Phoenix Fruit"] = {Id = 24, Name = "Phoenix Fruit", Rarity = "Legendary"},
    ["Portal Fruit"] = {Id = 25, Name = "Portal Fruit", Rarity = "Legendary"},
    ["Rumble Fruit"] = {Id = 26, Name = "Rumble Fruit", Rarity = "Legendary"},
    ["Pain Fruit"] = {Id = 27, Name = "Pain Fruit", Rarity = "Legendary"},
    ["Blizzard Fruit"] = {Id = 28, Name = "Blizzard Fruit", Rarity = "Legendary"},
    ["Gravity Fruit"] = {Id = 29, Name = "Gravity Fruit", Rarity = "Mythical"},
    ["Mammoth Fruit"] = {Id = 30, Name = "Mammoth Fruit", Rarity = "Mythical"},
    ["T-Rex Fruit"] = {Id = 31, Name = "T-Rex Fruit", Rarity = "Mythical"},
    ["Dough Fruit"] = {Id = 32, Name = "Dough Fruit", Rarity = "Mythical"},
    ["Shadow Fruit"] = {Id = 33, Name = "Shadow Fruit", Rarity = "Mythical"},
    ["Venom Fruit"] = {Id = 34, Name = "Venom Fruit", Rarity = "Mythical"},
    ["Control Fruit"] = {Id = 35, Name = "Control Fruit", Rarity = "Mythical"},
    ["Spirit Fruit"] = {Id = 36, Name = "Spirit Fruit", Rarity = "Mythical"},
    ["Leopard Fruit"] = {Id = 37, Name = "Leopard Fruit", Rarity = "Mythical"},
    ["Kitsune Fruit"] = {Id = 38, Name = "Kitsune Fruit", Rarity = "Mythical"},
    ["Dragon Fruit"] = {Id = 39, Name = "Dragon Fruit", Rarity = "Mythical"}
}
-- [[ MÓDULO 3: OTIMIZAÇÃO GRÁFICA EXTREMA (CPU/GPU SAVER) ]]
-- Remove dinamicamente texturas e renderizações 3D pesadas para rodar 24/7 sem lag
task.spawn(function()
    settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    _G.RunService:Set3dRenderTime(0)
    while task.wait(5) do
        local allObjects = game:GetDescendants()
        for i = 1, #allObjects do
            local item = allObjects[i]
            if item and item:Parent() then
                if item:IsA("Part") or item:IsA("MeshPart") or item:IsA("CornerWedgePart") or item:IsA("WedgePart") then
                    item.Material = Enum.Material.SmoothPlastic
                    item.Reflectance = 0
                    item.CastShadow = false
                elseif item:IsA("Decal") or item:IsA("Texture") then
                    item:Destroy()
                elseif item:IsA("ParticleEmitter") or item:IsA("Trail") or item:IsA("Sparkles") or item:IsA("Smoke") or item:IsA("Fire") then
                    item.Enabled = false
                elseif item:IsA("PostEffect") or item:IsA("BloomEffect") or item:IsA("BlurEffect") or item:IsA("ColorCorrectionEffect") or item:IsA("SunRaysEffect") then
                    item.Enabled = false
                end
            end
        end
    end
end)

-- [[ MÓDULO 4: ANTI-CRASH E BYPASSER DE MEMÓRIA (GARBAGE COLLECTOR) ]]
-- Previne o vazamento de memória nativo do Roblox antes de cada teleporte de servidor
_G.ClearMemoryCache = function()
    setfpscap(15)
    task.wait(0.2)
    for i = 1, 15 do
        collectgarbage("collect")
    end
    task.wait(0.1)
    setfpscap(60)
end

-- [[ MÓDULO 5: MONITORAMENTO DE ERRO NATIVO (AUTO-REJOIN) ]]
-- Intercepta telas de desconexão (Erros 260, 277, etc.) e reconecta com tratamento de falhas
_G.GuiService.ErrorMessageChanged:Connect(function()
    task.wait(5)
    local reconnected = false
    while not reconnected do
        local success, err = pcall(function()
            _G.TeleportService:Teleport(game.PlaceId, _G.LocalPlayer)
        end)
        if success then
            reconnected = true
        else
            task.wait(2)
        end
    end
end)

-- [[ MÓDULO 6: LOGÍSTICA DE CONEXÃO E ROTAÇÃO DE SERVIDORES (SERVER HOP) ]]
-- Faz a varredura direta via requisições HTTP brutas em até 5 páginas da API do Roblox
_G.AdvancedServerHop = function()
    if _G.IsProcessingFruit then return end
    _G.ClearMemoryCache()
    local visitedServers = {}
    if isfile and readfile and isfile(_G.File_Name) then
        local success, result = pcall(function() 
            return _G.HttpService:JSONDecode(readfile(_G.File_Name)) 
        end)
        if success and type(result) == "table" then 
            visitedServers = result 
        end
    end
    local serverCount = 0
    for _ in pairs(visitedServers) do serverCount = serverCount + 1 end
    if serverCount > 200 then visitedServers = {} end 
    visitedServers[game.JobId] = true
    if writefile then 
        writefile(_G.File_Name, _G.HttpService:JSONEncode(visitedServers)) 
    end
    local requestMethod = syn and syn.request or http_request or request
    if requestMethod then
        local nextPageCursor = ""
        local serverFound = false
        for page = 1, 5 do
            if serverFound then break end
            local serverApiUrl = "https://roblox.com" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100&cursor=" .. nextPageCursor
            local response = requestMethod({Url = serverApiUrl, Method = "GET"})
            if response and response.Body then
                local success, decodedData = pcall(function() return _G.HttpService:JSONDecode(response.Body) end)
                if success and decodedData and decodedData.data then
                    nextPageCursor = decodedData.nextPageCursor or ""
                    for i = 1, #decodedData.data do
                        local server = decodedData.data[i]
                        if server and server.id and server.playing and server.maxPlayers then
                            if server.playing < server.maxPlayers and not visitedServers[server.id] and server.id ~= game.JobId then
                                serverFound = true
                                _G.TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, _G.LocalPlayer)
                                task.wait(10)
                                break
                            end
                        end
                    end
                end
            end
            if nextPageCursor == "" or nextPageCursor == nil then break end
        end
    end
    _G.TeleportService:Teleport(game.PlaceId, _G.LocalPlayer)
end
-- [[ MÓDULO 7: SISTEMA DUAL-MODE DE MOVIMENTAÇÃO (BYPASS ANTICHEAT) ]]
-- Executa cálculos matemáticos vetoriais explícitos para suavizar a velocidade do boneco
_G.DualModeMove = function(hrp, targetCFrame)
    if not hrp or not targetCFrame then return end
    local currentPosition = hrp.Position
    local targetPosition = targetCFrame.Position
    local deltaX = targetPosition.X - currentPosition.X
    local deltaY = targetPosition.Y - currentPosition.Y
    local deltaZ = targetPosition.Z - currentPosition.Z
    local distance = math.sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ)
    
    if distance < 150 then
        hrp.Velocity = Vector3.new(0, 0, 0)
        hrp.RotVelocity = Vector3.new(0, 0, 0)
        hrp.CFrame = targetCFrame
    else
        local speed = 350
        local duration = distance / speed
        hrp.Velocity = Vector3.new(0, 0, 0)
        hrp.RotVelocity = Vector3.new(0, 0, 0)
        local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
        local targetProperties = {CFrame = targetCFrame + Vector3.new(0, 2, 0)}
        local tween = _G.TweenService:Create(hrp, tweenInfo, targetProperties)
        tween:Play()
        tween.Completed:Wait()
    end
end

-- [[ MÓDULO 8: LOGÍSTICA DE ARMAZENAMENTO E VERIFICAÇÃO DE INVENTÁRIO ]]
-- Interage via rede de forma segura e gerencia falhas de inventário lotado
_G.ProcessFruitLogistics = function(fruit)
    if not fruit or not fruit:Parent() then return end
    _G.IsProcessingFruit = true
    local character = _G.LocalPlayer.Character
    if not character then _G.IsProcessingFruit = false return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local handle = fruit:FindFirstChild("Handle") or fruit:FindFirstChildWhichIsA("Part") or fruit:FindFirstChildWhichIsA("MeshPart")
    
    if hrp and handle and humanoid then
        _G.DualModeMove(hrp, handle.CFrame)
        task.wait(0.5)
        
        -- Mecanismo Inteligente de Toque por Rede (Magnet Interest)
        if firetouchinterest then
            local touchCheck = true
            local attempts = 0
            while touchCheck and fruit:Parent() == _G.Workspace and attempts < 15 do
                firetouchinterest(hrp, handle, 0)
                task.wait(0.05)
                firetouchinterest(hrp, handle, 1)
                task.wait(0.1)
                if _G.LocalPlayer.Backpack:FindFirstChild(fruit.Name) or character:FindFirstChild(fruit.Name) then
                    touchCheck = false
                end
                attempts = attempts + 1
            end
        end
        task.wait(0.5) 
        
        -- Validação de Item na Mochila e Armazenamento Permanente no Baú
        local backpack = _G.LocalPlayer.Backpack
        if backpack then
            local fruitInBackpack = backpack:FindFirstChild(fruit.Name)
            if fruitInBackpack then
                humanoid:EquipTool(fruitInBackpack)
                task.wait(0.5)
                local remotesFolder = _G.ReplicatedStorage:FindFirstChild("Remotes")
                if remotesFolder then
                    local commF = remotesFolder:FindFirstChild("CommF_")
                    if commF then
                        local attemptsStore = 0
                        local stored = false
                        while attemptsStore < 3 and not stored do
                            local success = commF:InvokeServer("StoreFruit", fruit.Name, fruitInBackpack)
                            if success then
                                stored = true
                            else
                                attemptsStore = attemptsStore + 1
                                task.wait(0.5)
                            end
                        end
                        -- Drop de Emergência caso o baú da fruta já esteja cheio
                        if not stored then
                            commF:InvokeServer("DropFruit", fruit.Name)
                            task.wait(0.5)
                        end
                    end
                end
            end
        end
    end
    _G.IsProcessingFruit = false
    _G.AdvancedServerHop()
end

-- [[ MÓDULO 9: MOTOR PRINCIPAL E GATILHO DO LOOP DE VARREDURA ]]
-- Gerencia o spawn do boneco, força a equipe e rastreia o mapa
task.spawn(function()
    local remotesFolder = _G.ReplicatedStorage:WaitForChild("Remotes", 5)
    if remotesFolder then
        local commF = remotesFolder:WaitForChild("CommF_", 5)
        if commF then
            while true do
                if _G.LocalPlayer.Team ~= nil then break end
                commF:InvokeServer("SetTeam", "Pirates")
                task.wait(0.5)
            end
        end
    end
    task.wait(2.0) 
    
    -- Varredura Explícita de Objetos e Itens no Mapa
    while os.time() - _G.StartTime < _G.MAX_DETECTION_TIME do
        if _G.IsProcessingFruit then break end
        local targetFruit = nil
        local workspaceItems = _G.Workspace:GetChildren()
        
        for i = 1, #workspaceItems do
            local item = workspaceItems[i]
            if item and item:IsA("Tool") then
                local isFruit = false
                if _G.FruitsDatabase[item.Name] then
                    isFruit = true
                elseif string.find(string.lower(item.Name), "fruit") then
                    isFruit = true
                elseif item:FindFirstChild("FruitCone") then
                    isFruit = true
                end
                if isFruit then
                    targetFruit = item
                    break
                end
            end
        end
        
        if targetFruit then
            task.spawn(function()
                _G.ProcessFruitLogistics(targetFruit)
            end)
            break
        end
        task.wait(0.5)
    end
    
    task.wait(0.5)
    if not _G.IsProcessingFruit then
        _G.AdvancedServerHop()
    end
end)
