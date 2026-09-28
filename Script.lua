-- SCRIPT DE TESTE COMPLETO: PEGAR, GUARDAR NO BAÚ E SERVER HOP

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local jogador = Players.LocalPlayer

-- 1. FUNÇÃO PARA PEGAR A FRUTA DO CHÃO
local function pegarFruta()
    for _, objeto in pairs(Workspace:GetChildren()) do
        if string.find(objeto.Name, "Fruit") and objeto:IsA("Tool") then
            local rootPart = jogador.Character and jogador.Character:FindFirstChild("HumanoidRootPart")
            local frutaHandle = objeto:FindFirstChild("Handle") or objeto:FindFirstChildHandle()
            
            if rootPart and frutaHandle then
                print("[FRUTA]: Encontrada! Teleportando para " .. objeto.Name)
                rootPart.CFrame = frutaHandle.CFrame
                task.wait(1.5) -- Espera pegar do chão
                return objeto.Name
            end
        end
    end
    return nil
end

-- 2. FUNÇÃO PARA ARMAZENAR NO BAÚ DO BLOX FRUITS
local function armazenarNoBau(nomeDaFruta)
    -- O Blox Fruits usa esse evento para salvar a fruta permanentemente na sua conta
    local eventoArmazenar = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes") 
        and game:GetService("ReplicatedStorage").Remotes:FindFirstChild("CommF_")
    
    if eventoArmazenar then
        print("[BAÚ]: Tentando armazenar no inventário do jogo...")
        -- Envia o comando para o jogo guardar a fruta que está na sua mão
        local sucesso = eventoArmazenar:InvokeServer("StoreFruit", nomeDaFruta, jogador.Character:FindFirstChild(nomeDaFruta))
        if sucesso then
            print("[SUCESSO]: Fruta salva no seu baú!")
        else
            print("[AVISO]: Não foi possível guardar (talvez seu baú já tenha essa fruta).")
        end
    else
        print("[ERRO]: Evento de armazenamento não encontrado.")
    end
end

-- 3. FUNÇÃO PARA TROCAR DE SERVIDOR (SERVER HOP)
local function trocarDeServidor()
    print("[SERVER HOP]: Buscando nova sala pública...")
    local placeId = game.PlaceId
    local url = "https://roblox.com" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
    
    local sucesso, resultado = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    
    if sucesso and resultado and resultado.data then
        for _, servidor in pairs(resultado.data) do
            if servidor.playing < servidor.maxPlayers and servidor.id ~= game.JobId then
                print("[TELEPORTE]: Conectando ao servidor: " .. servidor.id)
                TeleportService:TeleportToPlaceInstance(placeId, servidor.id, jogador)
                return
            end
        end
    end
    TeleportService:Teleport(placeId, jogador)
end

-- --- EXECUÇÃO DO SCRIPT ---
local frutaNome = pegarFruta()

if frutaNome then
    task.wait(1)
    armazenarNoBau(frutaNome)
else
    print("[STATUS]: Nenhuma fruta no chão. Mudando de servidor direto...")
end

task.wait(3) -- Tempo para ler o log antes de sumir da sala
trocarDeServidor()
