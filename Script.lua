local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "🔥 Akail Hub | Blox Fruits VIP",
   LoadingTitle = "Carregando Akail Hub...",
   LoadingSubtitle = "by Akail",
   ConfigurationSaving = {
      Enabled = false,
      FolderName = "AkailHub",
      FileName = "Config"
   },
   Discord = {
      Enabled = false,
      Invite = "noinvite",
      RememberJoins = true
   },
   KeySystem = false,
   KeySettings = {
      Title = "Akail Hub",
      Subtitle = "Key System",
      Note = "Nenhuma key necessária",
      FileName = "AkailKey",
      SaveKey = true,
      GrabKeyFromSite = false,
      Key = {""}
   }
})

-- ==================== ABAS ====================
local TabFarm = Window:CreateTab("⚔️ Farm", 4483362458)
local TabCombat = Window:CreateTab("🗡️ Combate", 4483362458)
local TabSea = Window:CreateTab("🌊 Sea Events", 4483362458)
local TabVIP = Window:CreateTab("⭐ VIP / Utils", 4483362458)

-- ==================== ABA FARM ====================
TabFarm:CreateSection("Autofarm Principal")

TabFarm:CreateToggle({
   Name = "Auto Farm Level",
   CurrentValue = false,
   Flag = "AutoFarm",
   Callback = function(Value)
      getgenv().Config_AutoFarm = Value
      Rayfield:Notify({
         Title = "Auto Farm",
         Content = Value and "Ativado com sucesso!" : "Desativado.",
         Duration = 2,
         Image = 4483362458,
      })
   end,
})

TabFarm:CreateToggle({
   Name = "Fast Attack (Ataque Rápido)",
   CurrentValue = true,
   Flag = "FastAttack",
   Callback = function(Value)
      getgenv().Config_FastAttack = Value
   end,
})

TabFarm:CreateToggle({
   Name = "Bring Mobs (Puxar Mobs)",
   CurrentValue = true,
   Flag = "BringMob",
   Callback = function(Value)
      getgenv().Config_BringMob = Value
   end,
})

-- ==================== ABA COMBATE ====================
TabCombat:CreateSection("Chefes e Missões")

TabCombat:CreateToggle({
   Name = "Auto Elite Hunter",
   CurrentValue = false,
   Flag = "EliteHunter",
   Callback = function(Value)
      -- Função aqui
   end,
})

TabCombat:CreateToggle({
   Name = "Auto Boss Farm",
   CurrentValue = false,
   Flag = "BossFarm",
   Callback = function(Value)
      -- Função aqui
   end,
})

-- ==================== ABA SEA EVENTS ====================
TabSea:CreateSection("Eventos do Mar")

TabSea:CreateToggle({
   Name = "Auto Sea Beast",
   CurrentValue = false,
   Flag = "SeaBeast",
   Callback = function(Value)
      -- Função aqui
   end,
})

TabSea:CreateToggle({
   Name = "Auto Terror Shark",
   CurrentValue = false,
   Flag = "TerrorShark",
   Callback = function(Value)
      -- Função aqui
   end,
})

-- ==================== ABA VIP ====================
TabVIP:CreateSection("Utilitários e Player")

TabVIP:CreateToggle({
   Name = "Infinite Stamina (Stamina Infinita)",
   CurrentValue = false,
   Flag = "InfStamina",
   Callback = function(Value)
      getgenv().Config_InfStamina = Value
   end,
})

TabVIP:CreateToggle({
   Name = "Anti-Lag (FPS Booster)",
   CurrentValue = true,
   Flag = "AntiLag",
   Callback = function(Value)
      if Value then
         pcall(function()
            game:GetService("Lighting").GlobalShadows = false
            settings().Rendering.QualityLevel = 1
         end)
      end
   end,
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

Rayfield:LoadConfiguration()
