--============================================================--
-- AUTO FARM - BLOCO AJUSTADO
-- UI ORIGINAL PRESERVADA
--============================================================--

local FarmBusy = false
local FarmTarget = nil
local FarmTargetUID = nil
local FarmFlightConnection = nil
local FarmNoclipConnection = nil

local function GetCharacter()
    return LocalPlayer.Character
end

local function GetRoot()
    local Character = GetCharacter()
    if not Character then
        return nil
    end

    return Character:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid()
    local Character = GetCharacter()
    if not Character then
        return nil
    end

    return Character:FindFirstChildOfClass("Humanoid")
end

local function IsCharacterValid()
    local Character = GetCharacter()
    local Root = GetRoot()
    local Humanoid = GetHumanoid()

    return Character
        and Root
        and Humanoid
        and Humanoid.Health > 0
end

local function ClearFarmTarget()
    FarmTarget = nil
    FarmTargetUID = nil
end

local function GetEggPosition(Egg)
    if not Egg then
        return nil
    end

    if Egg:IsA("BasePart") then
        return Egg.Position
    end

    if Egg:IsA("Model") then
        local Primary = Egg.PrimaryPart

        if Primary then
            return Primary.Position
        end

        local Part = Egg:FindFirstChildWhichIsA("BasePart", true)

        if Part then
            return Part.Position
        end
    end

    return nil
end

local function GetEggCFrame(Egg)
    if not Egg then
        return nil
    end

    if Egg:IsA("BasePart") then
        return Egg.CFrame
    end

    if Egg:IsA("Model") then
        if Egg.PrimaryPart then
            return Egg.PrimaryPart.CFrame
        end

        local Part = Egg:FindFirstChildWhichIsA("BasePart", true)

        if Part then
            return Part.CFrame
        end
    end

    return nil
end

local function FindRenderedEgg(UID)
    if not UID then
        return nil
    end

    local WorkspaceEggs =
        workspace:FindFirstChild("RenderedEggs")
        or workspace:FindFirstChild("Eggs")
        or workspace:FindFirstChild("ActiveEggs")

    if not WorkspaceEggs then
        return nil
    end

    for _, Egg in ipairs(WorkspaceEggs:GetChildren()) do
        local EggUID =
            Egg:GetAttribute("UID")
            or Egg:GetAttribute("Id")
            or Egg:GetAttribute("ID")
            or Egg:GetAttribute("EggUID")

        if EggUID and tostring(EggUID) == tostring(UID) then
            return Egg
        end

        if tostring(Egg.Name) == tostring(UID) then
            return Egg
        end
    end

    return nil
end

local function FindPrompt(Egg)
    if not Egg then
        return nil
    end

    for _, Object in ipairs(Egg:GetDescendants()) do
        if Object:IsA("ProximityPrompt") then
            return Object
        end
    end

    return nil
end

local function FireEggPickup(UID)
    if not UID then
        return false
    end

    local GameFolder = ReplicatedStorage:FindFirstChild("Game")

    if not GameFolder then
        return false
    end

    local EggPickup = GameFolder:FindFirstChild("EggPickup")

    if not EggPickup then
        return false
    end

    local Success = false

    pcall(function()
        if EggPickup:IsA("RemoteEvent") then
            EggPickup:FireServer(UID)
            Success = true

        elseif EggPickup:IsA("RemoteFunction") then
            EggPickup:InvokeServer(UID)
            Success = true
        end
    end)

    return Success
end

local function PromptEggPickup(Egg)
    local Prompt = FindPrompt(Egg)

    if not Prompt then
        return false
    end

    local Success = false

    pcall(function()
        if type(fireproximityprompt) == "function" then
            fireproximityprompt(Prompt)
            Success = true
        end
    end)

    return Success
end

local function PickupFarmTarget()
    if not FarmTarget then
        return false
    end

    local UID = FarmTargetUID

    if State.FarmPickupMode == "Remote"
        or State.FarmPickupMode == "Auto" then

        if UID then
            if FireEggPickup(UID) then
                task.wait(State.FarmPickupWait or 0.25)

                if not FarmTarget or not FarmTarget.Parent then
                    return true
                end
            end
        end
    end

    if State.FarmPickupMode == "Prompt"
        or State.FarmPickupMode == "Auto" then

        if PromptEggPickup(FarmTarget) then
            task.wait(State.FarmPickupWait or 0.25)

            if not FarmTarget or not FarmTarget.Parent then
                return true
            end
        end
    end

    return not FarmTarget or not FarmTarget.Parent
end

local function EquipPetTool()
    local Character = GetCharacter()
    local Humanoid = GetHumanoid()

    if not Character or not Humanoid then
        return false
    end

    local Tool = nil

    for _, Object in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if Object:IsA("Tool") then
            Tool = Object
            break
        end
    end

    if not Tool then
        for _, Object in ipairs(Character:GetChildren()) do
            if Object:IsA("Tool") then
                Tool = Object
                break
            end
        end
    end

    if not Tool then
        return false
    end

    local Success = pcall(function()
        Humanoid:EquipTool(Tool)
    end)

    return Success
end

local function MoveFarmTo(CFrameTarget)
    local Root = GetRoot()

    if not Root or not CFrameTarget then
        return false
    end

    if State.FarmMoveMode == "Instant" then
        local Success = pcall(function()
            Root.CFrame = CFrameTarget
        end)

        return Success
    end

    local Distance =
        (Root.Position - CFrameTarget.Position).Magnitude

    local Speed =
        math.max(50, tonumber(State.FarmFlightSpeed) or 300)

    local Duration =
        math.clamp(Distance / Speed, 0.05, 10)

    local Success = false

    pcall(function()
        local TweenInfoObject = TweenInfo.new(
            Duration,
            Enum.EasingStyle.Linear,
            Enum.EasingDirection.Out
        )

        local Tween = TweenService:Create(
            Root,
            TweenInfoObject,
            {
                CFrame = CFrameTarget
            }
        )

        Tween:Play()
        Tween.Completed:Wait()

        Success = true
    end)

    return Success
end

local function GetTargetPosition(Egg)
    local Position = GetEggPosition(Egg)

    if not Position then
        return nil
    end

    local Height =
        tonumber(State.FarmPickupApproachHeight) or 6

    return Position + Vector3.new(0, Height, 0)
end

local function GetTargetUID(EggData, EggObject)
    if EggData then
        local UID =
            EggData.UID
            or EggData.Uid
            or EggData.uid
            or EggData.ID
            or EggData.Id
            or EggData.id

        if UID then
            return tostring(UID)
        end
    end

    if EggObject then
        local UID =
            EggObject:GetAttribute("UID")
            or EggObject:GetAttribute("Id")
            or EggObject:GetAttribute("ID")
            or EggObject:GetAttribute("EggUID")

        if UID then
            return tostring(UID)
        end

        return tostring(EggObject.Name)
    end

    return nil
end

local function IsTargetStillValid()
    if not FarmTarget then
        return false
    end

    if not FarmTarget.Parent then
        return false
    end

    local Position = GetEggPosition(FarmTarget)

    if not Position then
        return false
    end

    return true
end

local function StartFarmNoclip()
    if FarmNoclipConnection then
        FarmNoclipConnection:Disconnect()
        FarmNoclipConnection = nil
    end

    FarmNoclipConnection =
        RunService.Stepped:Connect(function()
            if not State.AutoFarm then
                return
            end

            local Character = GetCharacter()

            if not Character then
                return
            end

            for _, Object in ipairs(Character:GetDescendants()) do
                if Object:IsA("BasePart") then
                    Object.CanCollide = false
                end
            end
        end)
end

local function StopFarmNoclip()
    if FarmNoclipConnection then
        FarmNoclipConnection:Disconnect()
        FarmNoclipConnection = nil
    end
end

local function DestroyFarmFlightMovers()
    local Root = GetRoot()

    if not Root then
        return
    end

    for _, Object in ipairs(Root:GetChildren()) do
        if Object.Name == "MontarUmPetFarmVelocity"
            or Object.Name == "MontarUmPetFarmGyro"
            or Object.Name == "MontarUmPetFarmPosition" then

            pcall(function()
                Object:Destroy()
            end)
        end
    end
end

local function CancelGlide()
    if FarmFlightConnection then
        FarmFlightConnection:Disconnect()
        FarmFlightConnection = nil
    end

    DestroyFarmFlightMovers()
end

local function SelectBestFarmTarget()
    -- A seleção continua usando os dados existentes do script.
    -- Não altera a UI nem cria novos filtros.

    local ServerData = ReplicatedStorage:FindFirstChild("ServerData")

    if not ServerData then
        return nil, nil
    end

    local ActiveEggs = ServerData:FindFirstChild("ActiveEggs")

    if not ActiveEggs then
        return nil, nil
    end

    local BestEgg = nil
    local BestUID = nil
    local BestScore = nil

    for _, EggDataObject in ipairs(ActiveEggs:GetChildren()) do
        local UID =
            EggDataObject:GetAttribute("UID")
            or EggDataObject:GetAttribute("Id")
            or EggDataObject:GetAttribute("ID")
            or EggDataObject.Name

        if UID then
            local RenderedEgg =
                FindRenderedEgg(UID)

            if RenderedEgg then
                local Position =
                    GetEggPosition(RenderedEgg)

                if Position then
                    local Valid = true

                    if State.FarmMode == "Egg" then
                        if next(State.SelectedEggs) ~= nil then
                            local EggName =
                                EggDataObject:GetAttribute("Egg")
                                or EggDataObject:GetAttribute("EggName")
                                or EggDataObject.Name

                            Valid =
                                State.SelectedEggs[tostring(EggName)]
                                == true
                        end
                    end

                    if Valid and State.FarmMode == "Rarity" then
                        if next(State.SelectedRarities) ~= nil then
                            local Rarity =
                                EggDataObject:GetAttribute("Rarity")
                                or EggDataObject:GetAttribute("rarity")

                            if Rarity then
                                Valid =
                                    State.SelectedRarities[tostring(Rarity)]
                                    == true
                            end
                        end
                    end

                    if Valid then
                        local Root = GetRoot()

                        if Root then
                            local Distance =
                                (Root.Position - Position).Magnitude

                            local Score =
                                -Distance

                            if not BestScore
                                or Score > BestScore then

                                BestScore = Score
                                BestEgg = RenderedEgg
                                BestUID = tostring(UID)
                            end
                        end
                    end
                end
            end
        end
    end

    return BestEgg, BestUID
end

local function FarmOnce()
    if FarmBusy then
        return
    end

    if not State.AutoFarm then
        return
    end

    FarmBusy = true
    State.FarmPhase = "Searching"

    local Success, ErrorMessage =
        pcall(function()

            if not IsCharacterValid() then
                return
            end

            EquipPetTool()

            local Egg, UID =
                SelectBestFarmTarget()

            if not Egg or not UID then
                State.FarmPhase = "Waiting"
                return
            end

            FarmTarget = Egg
            FarmTargetUID = UID
            State.FarmPhase = "Approaching"

            local TargetPosition =
                GetTargetPosition(Egg)

            if not TargetPosition then
                ClearFarmTarget()
                return
            end

            MoveFarmTo(
                CFrame.new(TargetPosition)
            )

            if not State.AutoFarm then
                return
            end

            task.wait(
                tonumber(State.FarmArrivalPause) or 0.45
            )

            if not IsTargetStillValid() then
                ClearFarmTarget()
                return
            end

            State.FarmPhase = "Collecting"

            local Retries =
                math.max(
                    1,
                    tonumber(State.FarmPickupRetries) or 6
                )

            for _ = 1, Retries do
                if not State.AutoFarm then
                    break
                end

                if not IsTargetStillValid() then
                    break
                end

                PickupFarmTarget()

                task.wait(
                    tonumber(State.FarmPickupWait) or 0.25
                )
            end

            if State.AutoFarm then
                State.FarmPhase = "Returning"

                if State.ReturnToPlot then
                    -- A lógica original de retorno/depósito do script
                    -- permanece responsável por esta etapa.
                end
            end
        end)

    if not Success then
        warn(
            "[MontarUmPet][AutoFarm] Erro:",
            ErrorMessage
        )

        State.FarmPhase = "Error"
    end

    ClearFarmTarget()
    FarmBusy = false
end
