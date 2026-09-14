-- Toggle GUI: while ON, teleport 1 stud behind the ball every 0.5s
-- Q still does one snap.

pcall(function()
    local g = getgenv and getgenv() or _G
    if type(g.stopBehind) == "function" then g.stopBehind() end
    g._BehindBallGen = (tonumber(g._BehindBallGen) or 0) + 1
end)

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer
local cam = workspace.CurrentCamera

local BEHIND = 1
local INTERVAL = 0.2
local GEN = ((getgenv and getgenv() or _G)._BehindBallGen) or 1
local on = false

local function getHui()
    local ok, h = pcall(function() return gethui and gethui() end)
    if ok and h then return h end
    return LP:FindFirstChild("PlayerGui") or CoreGui
end

pcall(function()
    for _, parent in ipairs({getHui(), CoreGui, LP:FindFirstChild("PlayerGui")}) do
        if parent then
            local old = parent:FindFirstChild("BehindBallGui")
            if old then old:Destroy() end
        end
    end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "BehindBallGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(gui) end
end)
gui.Parent = getHui()

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(210, 72)
frame.Position = UDim2.new(0, 18, 0.4, 0)
frame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
frame.Active = true
frame.Draggable = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1, -16, 0, 36)
btn.Position = UDim2.new(0, 8, 0, 8)
btn.BackgroundColor3 = Color3.fromRGB(45, 32, 36)
btn.Text = "Behind Ball: OFF"
btn.TextColor3 = Color3.fromRGB(255, 110, 110)
btn.TextSize = 15
btn.Font = Enum.Font.GothamBold
btn.Parent = frame
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, -16, 0, 20)
hint.Position = UDim2.new(0, 8, 0, 46)
hint.BackgroundTransparency = 1
hint.Text = "Q = once   |   toggle = every 0.5s"
hint.TextColor3 = Color3.fromRGB(180, 180, 195)
hint.TextSize = 11
hint.Font = Enum.Font.Gotham
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Parent = frame

local function getRoot()
    local c = LP.Character
    return c and (c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart)
end

local function getHum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function partOf(obj)
    if not obj then return end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
    end
    if obj:IsA("ValueBase") then return partOf(obj.Value) end
end

local function findBall()
    for _, name in ipairs({"SoccerBall", "CurrentBall", "PenaltyBall", "Ball"}) do
        local p = partOf(workspace:FindFirstChild(name, true))
        if p then return p end
    end
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ValueBase") and v.Name == "CurrentBall" then
            local p = partOf(v.Value)
            if p then return p end
        end
        local n = string.lower(v.Name)
        if v:IsA("BasePart") and (n == "soccerball" or n == "currentball" or n == "penaltyball") then
            return v
        end
    end
end

local function flatten(v)
    local f = Vector3.new(v.X, 0, v.Z)
    if f.Magnitude < 0.05 then return Vector3.new(0, 0, -1) end
    return f.Unit
end

local function teleportBehind()
    local ball = findBall()
    local r = getRoot()
    local hum = getHum()
    if not ball or not r then return false end
    if hum then
        hum.PlatformStand = false
        hum.Sit = false
        hum.AutoRotate = true
    end
    local vel = ball.AssemblyLinearVelocity
    local dir
    if math.abs(vel.X) + math.abs(vel.Z) > 1 then
        dir = flatten(vel)
    elseif cam then
        dir = flatten(cam.CFrame.LookVector)
    else
        dir = flatten(r.CFrame.LookVector)
    end
    local ballR = math.max(ball.Size.X, ball.Size.Y, ball.Size.Z) * 0.5
    local x = ball.Position.X - dir.X * BEHIND
    local z = ball.Position.Z - dir.Z * BEHIND
    local floor = ball.Position.Y - ballR
    local hip = ((hum and tonumber(hum.HipHeight)) or 2) + r.Size.Y * 0.5
    local y = floor + hip
    local pos = Vector3.new(x, y, z)
    local face = Vector3.new(ball.Position.X, y, ball.Position.Z)
    r.CFrame = CFrame.lookAt(pos, face)
    return true
end

local function setOn(v)
    on = v
    if on then
        btn.Text = "Behind Ball: ON"
        btn.TextColor3 = Color3.fromRGB(90, 255, 140)
        btn.BackgroundColor3 = Color3.fromRGB(28, 55, 38)
    else
        btn.Text = "Behind Ball: OFF"
        btn.TextColor3 = Color3.fromRGB(255, 110, 110)
        btn.BackgroundColor3 = Color3.fromRGB(45, 32, 36)
    end
end

btn.MouseButton1Click:Connect(function()
    setOn(not on)
end)

UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Q then
        teleportBehind()
    end
end)

task.spawn(function()
    while true do
        local g = getgenv and getgenv() or _G
        if g._BehindBallGen ~= GEN then break end
        if on then
            teleportBehind()
        end
        task.wait(INTERVAL)
    end
end)

pcall(function()
    local g = getgenv and getgenv() or _G
    g.stopBehind = function()
        on = false
        g._BehindBallGen = (tonumber(g._BehindBallGen) or 0) + 1
        if gui then gui:Destroy() end
        print("[BehindBall] stopped")
    end
end)

print("[BehindBall] toggle GUI ready")
