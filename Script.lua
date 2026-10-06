local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local antigo = PlayerGui:FindFirstChild("TesteDeltaGUI")
if antigo then
    antigo:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TesteDeltaGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

local Frame = Instance.new("Frame")
Frame.Size = UDim2.fromOffset(220, 100)
Frame.Position = UDim2.new(0.5, -110, 0.5, -50)
Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
Frame.BorderSizePixel = 0
Frame.Parent = ScreenGui

local Canto = Instance.new("UICorner")
Canto.CornerRadius = UDim.new(0, 10)
Canto.Parent = Frame

local Texto = Instance.new("TextLabel")
Texto.Size = UDim2.new(1, 0, 1, 0)
Texto.BackgroundTransparency = 1
Texto.Text = "DELTA FUNCIONOU!"
Texto.TextColor3 = Color3.new(1, 1, 1)
Texto.Font = Enum.Font.SourceSansBold
Texto.TextSize = 18
Texto.Parent = Frame

print("[DELTA] Interface criada.")
