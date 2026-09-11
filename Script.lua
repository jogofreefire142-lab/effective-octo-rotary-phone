local OrionLib = loadstring(game:HttpGet('https://raw.githubusercontent.com/jensonhirst/Orion/main/source'))()

local Window = OrionLib:MakeWindow({
    Name = "🔥 Akail Hub | Blox Fruits VIP (Update 30)", 
    HidePremium = false, 
    SaveConfig = true, 
    ConfigFolder = "AkailHubConfig",
    IntroText = "Carregando Akail Hub Ultimate...",
    IntroEnabled = true
})

-- ==================== SERVIÇOS & CONFIGURAÇÕES ====================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

getgenv().Config = {
    AutoFarm = false,
    Weapon = "Melee",
    FastAttack = true,
    FastAttackSpeed = 0.0004,
    BringMob = true,
    AutoHaki = true,
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
    AutoMagnetFruit = false,
    AutoIslandSecrets = false,
    InfiniteStamina = false,
    SpeedBoost = false,
    SpeedMultiplier = 1.5,
    ShowNotifications = true
}

local function ShowNotification(title, message, duration)
    if not getgenv().Config.ShowNotifications then return end
    OrionLib:MakeNotification({
        Title = title,
        Content = message,
        Image = "rbxassetid://4483362458",
        Time = duration or 3
    })
end

-- ==================== ABAS ====================
local TabFarm = Window:MakeTab({Name = "⚔️ Farm", Icon = "rbxassetid://4483362458"})
local TabCombat = Window:MakeTab({Name = "🗡️ Combate", Icon = "rbxassetid://4483362458"})
local TabSea = Window:MakeTab({Name = "🌊 Sea Events", Icon = "rbxassetid://4483362458"})
local TabESP = Window:MakeTab({Name = "👁️ ESP", Icon = "rbxassetid://4483362458"})
local TabFruits = Window:MakeTab({Name = "🍎 Frutas", Icon = "rbxassetid://4483362458"})
local TabVIP = Window:MakeTab({Name = "⭐ VIP+", Icon = "rbxassetid://4483362458"})
local TabUpdate30 = Window:MakeTab({Name = "🚀 Update 30", Icon = "rbxassetid://4483362458"})

-- ==================== ABA FARM ====================
TabFarm:AddSection({Name = "Autofarm Principal"})

TabFarm:AddToggle({
    Name = "Auto Farm Level",
    Default = false,
    Callback = function(Value)
        getgenv().Config.AutoFarm = Value
        ShowNotification("Auto Farm", Value and "Ativado" or "Desativado")
    end
})

TabFarm:AddToggle({
    Name = "Fast Attack (Ataque Rápido)",
    Default = true,
    Callback = function(Value)
        getgenv().Config.FastAttack = Value
    end
})

TabFarm:AddToggle({
    Name = "Bring Mobs (Puxar Mobs)",
    Default = true,
    Callback = function(Value)
        getgenv().Config.BringMob = Value
    end
})

TabFarm:AddToggle({
    Name = "Auto Haki",
    Default = true,
    Callback = function(Value)
        getgenv().Config.AutoHaki = Value
    end
})

-- ==================== ABA COMBATE ====================
TabCombat:AddSection({Name = "Chefes e Missões"})

TabCombat:AddToggle({
    Name = "Auto Elite Hunter",
    Default = false,
    Callback = function(Value)
        getgenv().Config.AutoEliteHunter = Value
    end
})

TabCombat:AddToggle({
    Name = "Auto Boss Farm",
    Default = false,
    Callback = function(Value)
        getgenv().Config.AutoBossFarm = Value
    end
})

TabCombat:AddToggle({
    Name = "Auto Raid",
    Default = false,
    Callback = function(Value)
        getgenv().Config.AutoRaid = Value
    end
})

-- ==================== ABA SEA EVENTS ====================
TabSea:AddSection({Name = "Eventos do Mar"})

TabSea:AddToggle({
    Name = "Auto Sea Beast",
    Default = false,
    Callback = function(Value)
        getgenv().Config.AutoSeaBeast = Value
    end
})

TabSea:AddToggle({
    Name = "Auto Terror Shark",
    Default = false,
    Callback = function(Value)
        getgenv().Config.AutoTerrorShark = Value
    end
})

TabSea:AddToggle({
    Name = "Auto Bones",
    Default = false,
    Callback = function(Value)
        getgenv().Config.AutoBone = Value
    end
})

-- ==================== ABA ESP ====================
TabESP:AddSection({Name = "Visualizadores (ESP)"})

TabESP:AddToggle({
    Name = "ESP Players",
    Default = false,
    Callback = function(Value)
        getgenv().Config.ESPPlayer = Value
    end
})

TabESP:AddToggle({
    Name = "ESP Bosses",
    Default = false,
    Callback = function(Value)
        getgenv().Config.ESPBoss = Value
    end
})

TabESP:AddToggle({
    Name = "ESP Fruits",
    Default = false,
    Callback = function(Value)
        getgenv().Config.ESPFruit = Value
    end
})

TabESP:AddToggle({
    Name = "ESP Chests",
    Default = false,
    Callback = function(Value)
        getgenv().Config.ESPChest = Value
    end
})

-- ==================== ABA FRUTAS ====================
TabFruits:AddSection({Name = "Gerenciamento de Frutas"})

TabFruits:AddToggle({
    Name = "Auto Random Fruit",
    Default = false,
    Callback = function(Value)
        getgenv().Config.AutoRandomFruit = Value
    end
})

TabFruits:AddToggle({
    Name = "Auto Store Fruit",
    Default = false,
    Callback = function(Value)
        getgenv().Config.AutoStoreFruit = Value
    end
})

TabFruits:AddToggle({
    Name = "Collect Fruits (Chão)",
    Default = false,
    Callback = function(Value)
        getgenv().Config.AutoCollectFruits = Value
    end
})

-- ==================== ABA VIP+ ====================
TabVIP:AddSection({Name = "Melhorias do Jogador"})

TabVIP:AddToggle({
    Name = "Infinite Stamina",
    Default = false,
    Callback = function(Value)
        getgenv().Config.InfiniteStamina = Value
    end
})

TabVIP:AddToggle({
    Name = "Speed Boost",
    Default = false,
    Callback = function(Value)
        getgenv().Config.SpeedBoost = Value
    end
})

TabVIP:AddToggle({
    Name = "Notificações na Tela",
    Default = true,
    Callback = function(Value)
        getgenv().Config.ShowNotifications = Value
    end
})

TabVIP:AddToggle({
    Name = "Anti-Lag (FPS Booster)",
    Default = true,
    Callback = function(Value)
        if Value then
            pcall(function()
                Lighting.GlobalShadows = false
                Lighting.FogEnd = 9e9
                settings().Rendering.QualityLevel = 1
            end)
        end
    end
})

-- ==================== ABA UPDATE 30 ====================
TabUpdate30:AddSection({Name = "Novidades Exclusivas"})

TabUpdate30:AddToggle({
    Name = "🧲 Magnet Fruit",
    Default = false,
    Callback = function(Value)
        getgenv().Config.AutoMagnetFruit = Value
    end
})

TabUpdate30:AddToggle({
    Name = "🗝️ Island Secrets",
    Default = false,
    Callback = function(Value)
        getgenv().Config.AutoIslandSecrets = Value
    end
})

-- ==================== LOGICA E MOTORES DO SCRIPT ====================

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
end

-- Pivot para Movimentação
local PartPivot = Instance.new("Part")
PartPivot.Size = Vector3.new(1, 1, 1)
PartPivot.Name = "Akail_Pivot"
PartPivot.Anchored = true
PartPivot.CanCollide = false
PartPivot.Transparency = 1
PartPivot.CFrame = CFrame.new(0, 100, 0)
pcall(function() PartPivot.Parent = workspace end)

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

-- Fast Attack Engine
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

-- Infinite Stamina Engine
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

-- Speed Boost Engine
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

OrionLib:Init()
ShowNotification("🔥 Akail Hub", "Carregado com sucesso na Orion Lib!", 4)
