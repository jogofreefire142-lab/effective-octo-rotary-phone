local OrionLib = loadstring(game:HttpGet('https://raw.githubusercontent.com/jensonhirst/Orion/main/source'))()

local Window = OrionLib:MakeWindow({
    Name = "🔥 Akail Hub | Blox Fruits VIP", 
    HidePremium = false, 
    SaveConfig = true, 
    ConfigFolder = "AkailHubConfig",
    IntroText = "Carregando Akail Hub...",
    IntroEnabled = true
})

-- ==================== ABAS ====================
local TabFarm = Window:MakeTab({
    Name = "⚔️ Farm & Level",
    Icon = "rbxassetid://4483362458",
    PremiumOnly = false
})

local TabCombat = Window:MakeTab({
    Name = "🗡️ Combate & Boss",
    Icon = "rbxassetid://4483362458",
    PremiumOnly = false
})

local TabSea = Window:MakeTab({
    Name = "🌊 Sea Events",
    Icon = "rbxassetid://4483362458",
    PremiumOnly = false
})

local TabSettings = Window:MakeTab({
    Name = "⚙️ Configurações",
    Icon = "rbxassetid://4483362458",
    PremiumOnly = false
})

-- ==================== ABA FARM ====================
TabFarm:AddSection({
    Name = "Autofarm Principal"
})

TabFarm:AddToggle({
    Name = "Auto Farm Level",
    Default = false,
    Callback = function(Value)
        getgenv().Config_AutoFarm = Value
        OrionLib:MakeNotification({
            Title = "Auto Farm",
            Content = Value and "Farm ativado com sucesso!" or "Farm desativado.",
            Image = "rbxassetid://4483362458",
            Time = 3
        })
    end
})

TabFarm:AddToggle({
    Name = "Fast Attack (Ataque Rápido)",
    Default = true,
    Callback = function(Value)
        getgenv().Config_FastAttack = Value
    end
})

TabFarm:AddToggle({
    Name = "Bring Mobs (Puxar Mobs)",
    Default = true,
    Callback = function(Value)
        getgenv().Config_BringMob = Value
    end
})

-- ==================== ABA COMBATE ====================
TabCombat:AddSection({
    Name = "Caça e Chefes"
})

TabCombat:AddToggle({
    Name = "Auto Elite Hunter",
    Default = false,
    Callback = function(Value)
        getgenv().Config_Elite = Value
    end
})

TabCombat:AddToggle({
    Name = "Auto Boss Farm",
    Default = false,
    Callback = function(Value)
        getgenv().Config_Boss = Value
    end
})

-- ==================== ABA SEA EVENTS ====================
TabSea:AddSection({
    Name = "Eventos do Mar (Update 30)"
})

TabSea:AddToggle({
    Name = "Auto Sea Beast",
    Default = false,
    Callback = function(Value)
        getgenv().Config_SeaBeast = Value
    end
})

TabSea:AddToggle({
    Name = "Auto Terror Shark",
    Default = false,
    Callback = function(Value)
        getgenv().Config_TerrorShark = Value
    end
})

-- ==================== ABA CONFIGURAÇÕES ====================
TabSettings:AddSection({
    Name = "Utilitários do Jogador"
})

TabSettings:AddToggle({
    Name = "Infinite Stamina (Stamina Infinita)",
    Default = false,
    Callback = function(Value)
        getgenv().Config_InfStamina = Value
    end
})

TabSettings:AddToggle({
    Name = "Anti-Lag (FPS Booster)",
    Default = true,
    Callback = function(Value)
        if Value then
            pcall(function()
                game:GetService("Lighting").GlobalShadows = false
                settings().Rendering.QualityLevel = 1
            end)
        end
    end
})

TabSettings:AddButton({
    Name = "Fechar / Destruir UI",
    Callback = function()
        OrionLib:Destroy()
    end
})

-- ==================== LOOPS DE SUPORTE ====================
task.spawn(function()
    while task.wait(0.1) do
        if getgenv().Config_InfStamina and game.Players.LocalPlayer.Character then
            pcall(function()
                local stamina = game.Players.LocalPlayer.Character:FindFirstChild("Stamina")
                if stamina then stamina.Value = 100 end
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(0.01) do
        if getgenv().Config_FastAttack then
            pcall(function()
                game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, true, game, 1)
                game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, false, game, 1)
            end)
        end
    end
end)

OrionLib:Init()
