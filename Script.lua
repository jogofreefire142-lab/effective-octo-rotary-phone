repeat task.wait() until game:IsLoaded()

-- =================================================================
-- ⭐ AKAIL HUB VIP PREMIUM — BLOX FRUITS UPDATE 30 (CORRIGIDO)
-- =================================================================
if getgenv().AkailHubUltimateLoaded then return end
getgenv().AkailHubUltimateLoaded = true

-- =================================================================
-- SERVIÇOS & CONFIGURAÇÕES
-- =================================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

if not LocalPlayer then
    warn("⚠️ LocalPlayer não encontrado!")
    return
end

getgenv().Config = {
    AutoFarm = false,
    Weapon = "Melee",
    FastAttack = true,
    FastAttackSpeed = 0.0004,
    BringMob = true,
    AutoHaki = true,
    AutoRejoin = true,
    AntiLag = true,
    AutoEliteHunter = false,
    AutoBossFarm = false,
    AutoSeaBeast = false,
    AutoTerrorShark = false,
    AutoRaid = false,
    AutoBone = false,
    AutoRandomFruit = false,
    AutoStoreFruit = false,
    AutoCollectFruits = false,
    ESPPlayer = false,
    ESPBoss = false,
    ESPFruit = false,
    ESPChest = false,
    AutoStatsMelee = false,
    AutoStatsDefense = false,
    AutoStatsFruit = false,
    AutoStatsGun = false,
    StatsPoints = 3,
    AutoMagnetFruit = false,
    AutoIslandSecrets = false,
    AutoMagnetEvent = false,
    AutoMagnetTokens = false,
    AutoSeaOneRework = false,
    AutoAwakenedBoss = false,
    AutoTeleportFastTravel = false,
    AutoLevelTo3000 = false,
    AutoCelestialFruit = false,
    AutoOniFruit = false,
    AutoDarkRework = false,
    AutoCrewFarm = false,
    AutoFourthSea = false,
    InfiniteStamina = false,
    SpeedBoost = false,
    SpeedMultiplier = 1.5,
    AutoDodge = false,
    ShowNotifications = true,
    ShowStats = true,
    AutoLevel2026 = false
}

local PlaceId = game.PlaceId
local World1, World2, World3, World4 = false, false, false, false

if PlaceId == 2753915549 or PlaceId == 85211729168715 then World1 = true
elseif PlaceId == 4442272183 or PlaceId == 79091703265657 then World2 = true
elseif PlaceId == 7449423635 or PlaceId == 100117331123089 then World3 = true
elseif PlaceId == 12345678901 or PlaceId == 999999999999 then World4 = true
end

-- ==================== LOGGER ====================
local function Log(msg, level)
    level = level or "INFO"
    local timestamp = os.date("%H:%M:%S")
    print("[" .. timestamp .. "][" .. level .. "] " .. msg)
end

Log("🔥 Iniciando AKAIL HUB UPDATE 30...", "LOAD")

-- ==================== NOTIFICAÇÕES ====================
local notificationStack = {}

local function ShowNotification(title, message, duration, color)
    if not getgenv().Config.ShowNotifications then return end
    
    duration = duration or 3
    color = color or Color3.fromRGB(0, 255, 128)
    
    local notif = Instance.new("Frame")
    notif.Name = "Notification"
    notif.Size = UDim2.new(0, 320, 0, 90)
    notif.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    notif.BorderSizePixel = 0
    notif.Position = UDim2.new(0.82, 0, 0.05 + (#notificationStack * 0.11), 0)
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = notif
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = 2
    stroke.Parent = notif
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Text = "✓ " .. title
    titleLabel.Size = UDim2.new(1, -10, 0, 30)
    titleLabel.Position = UDim2.new(0, 5, 0, 5)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = color
    titleLabel.TextSize = 12
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextScaled = false
    titleLabel.Parent = notif
    
    local msgLabel = Instance.new("TextLabel")
    msgLabel.Text = message
    msgLabel.Size = UDim2.new(1, -10, 0, 50)
    msgLabel.Position = UDim2.new(0, 5, 0, 35)
    msgLabel.BackgroundTransparency = 1
    msgLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    msgLabel.TextSize = 10
    msgLabel.Font = Enum.Font.Gotham
    msgLabel.TextWrapped = true
    msgLabel.Parent = notif
    
    if notif.Parent then notif.Parent:FindFirstChild(notif.Name) and notif.Parent:FindFirstChild(notif.Name):Destroy() end
    
    notif.Parent = CoreGui
    table.insert(notificationStack, notif)
    
    task.delay(duration, function()
        if notif and notif.Parent then
            notif:Destroy()
        end
        local idx = table.find(notificationStack, notif)
        if idx then table.remove(notificationStack, idx) end
    end)
end

-- ==================== VERIFICAÇÃO DE FARM ATIVO ====================
local function IsAutoFarmActive()
    return getgenv().Config.AutoFarm 
        or getgenv().Config.AutoEliteHunter 
        or getgenv().Config.AutoBossFarm 
        or getgenv().Config.AutoSeaBeast 
        or getgenv().Config.AutoTerrorShark 
        or getgenv().Config.AutoBone 
        or getgenv().Config.AutoRaid 
        or getgenv().Config.AutoCollectFruits
        or getgenv().Config.AutoMagnetFruit 
        or getgenv().Config.AutoIslandSecrets
        or getgenv().Config.AutoAwakenedBoss
end

-- ==================== ANTI-AFK ====================
pcall(function()
    LocalPlayer.Idled:Connect(function()
        VirtualUser:Button2Down(Vector2.zero, workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.zero, workspace.CurrentCamera.CFrame)
    end)
end)

-- ==================== AUTO RECONNECT ====================
pcall(function()
    if CoreGui:FindFirstChild("RobloxPromptGui") then
        CoreGui.RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
            if getgenv().Config.AutoRejoin and child.Name == "ErrorPrompt" then
                TeleportService:Teleport(PlaceId, LocalPlayer)
            end
        end)
    end
end)

-- ==================== ANTI-LAG ====================
if getgenv().Config.AntiLag then
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        settings().Rendering.QualityLevel = 1
        
        local descendants = workspace:GetDescendants()
        for _, v in pairs(descendants) do
            if v:IsA("BasePart") and not v:IsDescendantOf(LocalPlayer.Character or {}) then
                v.Material = Enum.Material.SmoothPlastic
                v.Reflectance = 0
            elseif v:IsA("Decal") or v:IsA("Texture") then
                pcall(function() v:Destroy() end)
            end
        end
        Log("✅ Anti-Lag ativado!", "OK")
    end)
end

-- ==================== NOCLIP ====================
RunService.RenderStepped:Connect(function()
    if IsAutoFarmActive() and LocalPlayer.Character then
        pcall(function()
            for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then 
                    part.CanCollide = false 
                end
            end
        end)
    end
end)

-- ==================== INFINITE STAMINA ====================
task.spawn(function()
    while task.wait(0.1) do
        if getgenv().Config.InfiniteStamina and LocalPlayer.Character then
            pcall(function()
                local char = LocalPlayer.Character
                if char:FindFirstChild("Stamina") then
                    char.Stamina.Value = 100
                end
            end)
        end
    end
end)

-- ==================== SPEED BOOST ====================
task.spawn(function()
    while task.wait(0.05) do
        if getgenv().Config.SpeedBoost and LocalPlayer.Character then
            pcall(function()
                local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
                if humanoid then
                    humanoid.WalkSpeed = 16 * getgenv().Config.SpeedMultiplier
                end
            end)
        end
    end
end)

-- =================================================================
-- UI PREMIUM
-- =================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AkailHubUltimate_UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then 
    pcall(function() ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui", 5) end)
end

if not ScreenGui.Parent then
    warn("⚠️ Não consegui adicionar a UI!")
    Log("Erro ao carregar UI", "ERROR")
end

-- STATS DISPLAY
local StatsDisplay = Instance.new("Frame")
StatsDisplay.Name = "StatsDisplay"
StatsDisplay.Size = UDim2.new(0, 260, 0, 200)
StatsDisplay.Position = UDim2.new(0.015, 0, 0.5, 0)
StatsDisplay.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
StatsDisplay.BorderSizePixel = 0
StatsDisplay.Parent = ScreenGui

local statsCorner = Instance.new("UICorner")
statsCorner.CornerRadius = UDim.new(0, 8)
statsCorner.Parent = StatsDisplay

local statsBorder = Instance.new("UIStroke")
statsBorder.Color = Color3.fromRGB(255, 100, 200)
statsBorder.Thickness = 2
statsBorder.Parent = StatsDisplay

local statsLabel = Instance.new("TextLabel")
statsLabel.Size = UDim2.new(1, 0, 1, 0)
statsLabel.BackgroundTransparency = 1
statsLabel.Text = "🎮 UPDATE 30\nLevel: ?\nExp: ?\nHp: ?\nMagnet: OFF"
statsLabel.TextColor3 = Color3.fromRGB(255, 100, 200)
statsLabel.TextSize = 10
statsLabel.Font = Enum.Font.GothamBold
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.TextYAlignment = Enum.TextYAlignment.Top
statsLabel.Parent = StatsDisplay

-- TOGGLE BUTTON
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 52, 0, 52)
ToggleBtn.Position = UDim2.new(0.015, 0, 0.15, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
ToggleBtn.Text = "☰"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 100, 200)
ToggleBtn.TextSize = 24
ToggleBtn.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)
ToggleBtn.Parent = ScreenGui

local UICornerBtn = Instance.new("UICorner")
UICornerBtn.CornerRadius = UDim.new(0, 14)
UICornerBtn.Parent = ToggleBtn

local UIBorderBtn = Instance.new("UIStroke")
UIBorderBtn.Color = Color3.fromRGB(255, 100, 200)
UIBorderBtn.Thickness = 2
UIBorderBtn.Parent = ToggleBtn

-- MAIN FRAME
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 550, 0, 600)
MainFrame.Position = UDim2.new(0.5, -275, 0.5, -300)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
MainFrame.Visible = false

local UICornerMain = Instance.new("UICorner")
UICornerMain.CornerRadius = UDim.new(0, 12)
UICornerMain.Parent = MainFrame

local UIBorderMain = Instance.new("UIStroke")
UIBorderMain.Color = Color3.fromRGB(255, 100, 200)
UIBorderMain.Thickness = 2
UIBorderMain.Parent = MainFrame

-- TITLE
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Title.Text = "   🔥 AKAIL HUB UPDATE 30"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
Title.Parent = MainFrame

local UICornerTitle = Instance.new("UICorner")
UICornerTitle.CornerRadius = UDim.new(0, 12)
UICornerTitle.Parent = Title

-- TAB BAR
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(0, 120, 1, -48)
TabBar.Position = UDim2.new(0, 8, 0, 42)
TabBar.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
TabBar.Parent = MainFrame

local UICornerTabBar = Instance.new("UICorner")
UICornerTabBar.CornerRadius = UDim.new(0, 8)
UICornerTabBar.Parent = TabBar

local TabList = Instance.new("UIListLayout")
TabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabList.SortOrder = Enum.SortOrder.LayoutOrder
TabList.Padding = UDim.new(0, 4)
TabList.Parent = TabBar

-- CONTENT FRAME
local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, -138, 1, -48)
ContentFrame.Position = UDim2.new(0, 132, 0, 42)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = MainFrame

local Pages = {}

local function CreatePage(pageName)
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.BackgroundTransparency = 1
    scroll.CanvasSize = UDim2.new(0, 0, 0, 700)
    scroll.ScrollBarThickness = 2
    scroll.Visible = false
    scroll.Parent = ContentFrame
    
    local layout = Instance.new("UIListLayout")
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)
    layout.Parent = scroll
    
    Pages[pageName] = scroll
    return scroll
end

local function CreateTabButton(tabName, pageTarget)
    local tabBtn = Instance.new("TextButton")
    tabBtn.Size = UDim2.new(0.92, 0, 0, 28)
    tabBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    tabBtn.Text = tabName
    tabBtn.TextColor3 = Color3.fromRGB(160, 160, 180)
    tabBtn.TextSize = 7
    tabBtn.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
    tabBtn.Parent = TabBar
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = tabBtn

    tabBtn.MouseButton1Click:Connect(function()
        for _, p in pairs(Pages) do p.Visible = false end
        for _, b in pairs(TabBar:GetChildren()) do
            if b:IsA("TextButton") then
                b.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
                b.TextColor3 = Color3.fromRGB(160, 160, 180)
            end
        end
        pageTarget.Visible = true
        tabBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 200)
        tabBtn.TextColor3 = Color3.fromRGB(10, 10, 14)
    end)
end

local function AddToggleToPage(page, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.96, 0, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    btn.Text = "  " .. text
    btn.TextColor3 = Color3.fromRGB(225, 225, 235)
    btn.TextSize = 8
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
    btn.Parent = page
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0, 10, 0, 10)
    indicator.Position = UDim2.new(0.9, -8, 0.5, -5)
    indicator.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    indicator.Parent = btn
    
    local indCorner = Instance.new("UICorner")
    indCorner.CornerRadius = UDim.new(1, 0)
    indCorner.Parent = indicator

    local state = false
    btn.MouseButton1Click:Connect(function()
        state = not state
        indicator.BackgroundColor3 = state and Color3.fromRGB(255, 100, 200) or Color3.fromRGB(50, 50, 65)
        if callback then
            callback(state)
        end
        if getgenv().Config.ShowNotifications then
            ShowNotification(text, state and "✓ Ativado" or "✗ Desativado", 2, Color3.fromRGB(255, 100, 200))
        end
    end)
end

-- CRIAR PÁGINAS
local PageFarm = CreatePage("Farm")
local PageCombat = CreatePage("Combat")
local PageSea = CreatePage("Sea")
local PageESP = CreatePage("ESP")
local PageFruits = CreatePage("Fruits")
local PageStats = CreatePage("Stats")
local PageVIP = CreatePage("VIP+")
local PageUpdate30 = CreatePage("UPDATE 30")
local Page2026 = CreatePage("2026")

-- CRIAR ABAS
CreateTabButton("Farm", PageFarm)
CreateTabButton("Combat", PageCombat)
CreateTabButton("Sea", PageSea)
CreateTabButton("ESP", PageESP)
CreateTabButton("Fruits", PageFruits)
CreateTabButton("Stats", PageStats)
CreateTabButton("VIP+", PageVIP)
CreateTabButton("UPD30", PageUpdate30)
CreateTabButton("2026", Page2026)

PageFarm.Visible = true

-- ADICIONAR TOGGLES
AddToggleToPage(PageFarm, "Auto Farm Level", function(v) getgenv().Config.AutoFarm = v end)
AddToggleToPage(PageFarm, "Fast Attack", function(v) getgenv().Config.FastAttack = v end)
AddToggleToPage(PageFarm, "Bring Mobs", function(v) getgenv().Config.BringMob = v end)
AddToggleToPage(PageFarm, "Auto Haki", function(v) getgenv().Config.AutoHaki = v end)

AddToggleToPage(PageCombat, "Elite Hunter", function(v) getgenv().Config.AutoEliteHunter = v end)
AddToggleToPage(PageCombat, "Boss Farm", function(v) getgenv().Config.AutoBossFarm = v end)
AddToggleToPage(PageCombat, "Auto Raid", function(v) getgenv().Config.AutoRaid = v end)

AddToggleToPage(PageSea, "Sea Beast", function(v) getgenv().Config.AutoSeaBeast = v end)
AddToggleToPage(PageSea, "Terror Shark", function(v) getgenv().Config.AutoTerrorShark = v end)
AddToggleToPage(PageSea, "Auto Bones", function(v) getgenv().Config.AutoBone = v end)

AddToggleToPage(PageESP, "ESP Players", function(v) getgenv().Config.ESPPlayer = v end)
AddToggleToPage(PageESP, "ESP Bosses", function(v) getgenv().Config.ESPBoss = v end)
AddToggleToPage(PageESP, "ESP Fruits", function(v) getgenv().Config.ESPFruit = v end)
AddToggleToPage(PageESP, "ESP Chests", function(v) getgenv().Config.ESPChest = v end)

AddToggleToPage(PageFruits, "Random Fruit", function(v) getgenv().Config.AutoRandomFruit = v end)
AddToggleToPage(PageFruits, "Store Fruit", function(v) getgenv().Config.AutoStoreFruit = v end)
AddToggleToPage(PageFruits, "Collect Fruits", function(v) getgenv().Config.AutoCollectFruits = v end)

AddToggleToPage(PageStats, "Auto Melee", function(v) getgenv().Config.AutoStatsMelee = v end)
AddToggleToPage(PageStats, "Auto Defense", function(v) getgenv().Config.AutoStatsDefense = v end)
AddToggleToPage(PageStats, "Auto Fruit", function(v) getgenv().Config.AutoStatsFruit = v end)
AddToggleToPage(PageStats, "Auto Gun", function(v) getgenv().Config.AutoStatsGun = v end)

AddToggleToPage(PageVIP, "∞ Stamina", function(v) getgenv().Config.InfiniteStamina = v end)
AddToggleToPage(PageVIP, "Speed Boost", function(v) getgenv().Config.SpeedBoost = v end)
AddToggleToPage(PageVIP, "Notifications", function(v) getgenv().Config.ShowNotifications = v end)
AddToggleToPage(PageVIP, "Show Stats", function(v) getgenv().Config.ShowStats = v end)

AddToggleToPage(PageUpdate30, "🧲 Magnet Fruit", function(v) getgenv().Config.AutoMagnetFruit = v end)
AddToggleToPage(PageUpdate30, "🗝️ Island Secrets", function(v) getgenv().Config.AutoIslandSecrets = v end)
AddToggleToPage(PageUpdate30, "⚡ Magnet Event", function(v) getgenv().Config.AutoMagnetEvent = v end)
AddToggleToPage(PageUpdate30, "🌊 Sea 1 Rework", function(v) getgenv().Config.AutoSeaOneRework = v end)
AddToggleToPage(PageUpdate30, "📈 Level 3000", function(v) getgenv().Config.AutoLevelTo3000 = v end)

AddToggleToPage(Page2026, "🌟 Celestial", function(v) getgenv().Config.AutoCelestialFruit = v end)
AddToggleToPage(Page2026, "👹 Oni", function(v) getgenv().Config.AutoOniFruit = v end)
AddToggleToPage(Page2026, "👥 Crew Farm", function(v) getgenv().Config.AutoCrewFarm = v end)

-- TOGGLE BUTTON
ToggleBtn.MouseButton1Click:Connect(function() 
    MainFrame.Visible = not MainFrame.Visible 
    StatsDisplay.Visible = not StatsDisplay.Visible
end)

-- =================================================================
-- MOVIMENTO & TELEPORTAÇÃO
-- =================================================================
local PartPivot = Instance.new("Part")
PartPivot.Size = Vector3.new(1, 1, 1)
PartPivot.Name = "Akail_Pivot"
PartPivot.Anchored = true
PartPivot.CanCollide = false
PartPivot.Transparency = 1
PartPivot.CFrame = CFrame.new(0, 100, 0)

pcall(function()
    PartPivot.Parent = workspace
end)

task.spawn(function()
    while task.wait() do
        pcall(function()
            if LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local root = LocalPlayer.Character.HumanoidRootPart
                if IsAutoFarmActive() then
                    if (root.Position - PartPivot.Position).Magnitude <= 350 then
                        root.CFrame = PartPivot.CFrame
                    else
                        PartPivot.CFrame = root.CFrame
                    end
                end
            end
        end)
    end
end)

local currentTween = nil

local function ToTarget(TargetCFrame)
    if not LocalPlayer or not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    
    pcall(function()
        local root = LocalPlayer.Character.HumanoidRootPart
        local dist = (TargetCFrame.Position - root.Position).Magnitude
        local speed = dist > 2500 and 650 or 380
        
        if currentTween then 
            currentTween:Cancel() 
            currentTween = nil
        end
        
        local duration = math.max(dist / speed, 0.05)
        duration = math.min(duration, 10)
        
        local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
        currentTween = TweenService:Create(PartPivot, tweenInfo, {CFrame = TargetCFrame})
        
        if currentTween then
            currentTween:Play()
        end
    end)
end

-- =================================================================
-- FUNÇÕES DE COMBATE
-- =================================================================
local function CheckHaki()
    if not getgenv().Config.AutoHaki then return end
    
    pcall(function()
        if not LocalPlayer or not LocalPlayer.Character then return end
        
        local char = LocalPlayer.Character
        if char:FindFirstChild("HasBuso") then return end
        
        if ReplicatedStorage and ReplicatedStorage:FindFirstChild("Remotes") then
            local remotes = ReplicatedStorage.Remotes
            if remotes:FindFirstChild("CommF_") then
                remotes.CommF_:InvokeServer("Buso")
            end
        end
    end)
end

local function BringMobsPro(MobName, TargetCFrame, maxMobs)
    if not getgenv().Config.BringMob then return end
    if not workspace:FindFirstChild("Enemies") then return end
    
    maxMobs = maxMobs or 10
    local broughtCount = 0
    
    pcall(function()
        for _, enemy in pairs(workspace.Enemies:GetChildren()) do
            if broughtCount >= maxMobs then break end
            
            if not enemy:FindFirstChild("HumanoidRootPart") or not enemy:FindFirstChild("Humanoid") then continue end
            
            local humanoid = enemy:FindFirstChild("Humanoid")
            if humanoid.Health <= 0 then continue end
            
            local enemyName = enemy.Name:lower()
            local mobNameLower = (MobName or ""):lower()
            
            if mobNameLower == "all" or enemyName:find(mobNameLower) then
                local root = enemy.HumanoidRootPart
                local dist = (root.Position - TargetCFrame).Magnitude
                
                if dist <= 450 then
                    root.CFrame = CFrame.new(TargetCFrame)
                    root.CanCollide = false
                    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    broughtCount = broughtCount + 1
                    
                    pcall(function()
                        humanoid.WalkSpeed = 0
                        humanoid.JumpPower = 0
                    end)
                end
            end
        end
    end)
end

task.spawn(function()
    while task.wait(getgenv().Config.FastAttackSpeed) do
        if IsAutoFarmActive() and getgenv().Config.FastAttack then
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
            end)
        end
    end
end)

local function AutoEquip()
    if not LocalPlayer or not LocalPlayer.Character then return end
    
    pcall(function()
        local char = LocalPlayer.Character
        local humanoid = char:FindFirstChild("Humanoid")
        
        if not humanoid then return end
        
        local equipped = char:FindFirstChildOfClass("Tool")
        if equipped and (equipped.Name == getgenv().Config.Weapon or equipped.Name:find(getgenv().Config.Weapon)) then 
            return 
        end
        
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if not backpack then return end
        
        for _, item in pairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                local itemName = item.Name:lower()
                local weaponName = (getgenv().Config.Weapon or ""):lower()
                
                if itemName:find(weaponName) or itemName == weaponName then
                    humanoid:EquipTool(item)
                    break
                end
            end
        end
    end)
end

-- =================================================================
-- ESP
-- =================================================================
local function CreateESP(obj, textName, color)
    if not obj or not obj.Parent then return end
    if obj:FindFirstChild("Akail_ESP") then return end
    
    pcall(function()
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "Akail_ESP"
        billboard.Size = UDim2.new(0, 100, 0, 40)
        billboard.AlwaysOnTop = true
        billboard.StudsOffset = Vector3.new(0, 2.5, 0)
        billboard.MaxDistance = 500
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = textName
        label.TextColor3 = color
        label.TextSize = 11
        label.Font = Enum.Font.GothamBold
        label.TextStrokeTransparency = 0.2
        label.Parent = billboard
        
        billboard.Parent = obj
    end)
end

task.spawn(function()
    while task.wait(1.5) do
        pcall(function()
            if getgenv().Config.ESPPlayer then
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        CreateESP(p.Character.HumanoidRootPart, p.Name, Color3.fromRGB(255, 60, 60))
                    end
                end
            end
            
            if getgenv().Config.ESPBoss and workspace:FindFirstChild("Enemies") then
                for _, v in pairs(workspace.Enemies:GetChildren()) do
                    if v:FindFirstChild("Humanoid") and v:FindFirstChild("HumanoidRootPart") then
                        local humanoid = v:FindFirstChild("Humanoid")
                        if humanoid.MaxHealth > 5000 then
                            CreateESP(v.HumanoidRootPart, "👑 " .. v.Name, Color3.fromRGB(255, 215, 0))
                        end
                    end
                end
            end
        end)
    end
end)

-- =================================================================
-- AUTO EVENTS
-- =================================================================
task.spawn(function()
    while task.wait(2) do
        if getgenv().Config.AutoMagnetFruit then
            pcall(function()
                if workspace:FindFirstChild("Dropped") then
                    for _, item in pairs(workspace.Dropped:GetChildren()) do
                        if item:IsA("Tool") and item.Name:lower():find("magnet") and item:FindFirstChild("Handle") then
                            ToTarget(item.Handle.CFrame)
                            ShowNotification("🧲 Magnet", "Coletando!", 1, Color3.fromRGB(255, 100, 200))
                        end
                    end
                end
            end)
        end
    end
end)

-- UPDATE STATS
task.spawn(function()
    while task.wait(1) do
        if getgenv().Config.ShowStats then
            pcall(function()
                local level = "?"
                local hp = "?"
                local magnetStatus = "OFF"
                
                if getgenv().Config.AutoMagnetFruit then magnetStatus = "ON ✅" end
                
                if LocalPlayer and LocalPlayer:FindFirstChild("Data") then
                    if LocalPlayer.Data:FindFirstChild("Level") then
                        level = tostring(LocalPlayer.Data.Level.Value)
                    end
                end
                
                if LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                    local hum = LocalPlayer.Character.Humanoid
                    hp = math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)
                end
                
                statsLabel.Text = "🎮 UPDATE 30\nLevel: " .. level .. "\nHp: " .. hp .. "\nMagnet: " .. magnetStatus
            end)
        end
    end
end)

Log("✅ AKAIL HUB CARREGADO COM SUCESSO!", "SUCCESS")
ShowNotification("🔥 UPDATE 30", "Hub ativado! Tudo pronto para farmar!", 5, Color3.fromRGB(255, 100, 200))
