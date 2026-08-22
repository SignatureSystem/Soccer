-- Minimal Japan-only Stealer + timer + count
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local TARGET = { Japan = true }
local enabled, busy, total = false, false, 0
local sessionStart = 0

local function root()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function fmtTime(sec)
    sec = math.max(0, math.floor(sec))
    local m = math.floor(sec / 60)
    local s = sec % 60
    return string.format("%02d:%02d", m, s)
end

local function activateCloak()
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local tool
    for _, bag in ipairs({ char, LP:FindFirstChild("Backpack") }) do
        if bag then
            for _, t in ipairs(bag:GetChildren()) do
                if t:IsA("Tool") then
                    local n = t.Name:lower()
                    if n:find("invis") or n:find("cloak") then
                        tool = t
                        break
                    end
                end
            end
        end
        if tool then break end
    end
    if not tool then return end
    if tool.Parent ~= char then
        pcall(function() hum:UnequipTools() end)
        task.wait(0.05)
        pcall(function() hum:EquipTool(tool) end)
        if tool.Parent ~= char then pcall(function() tool.Parent = char end) end
        task.wait(0.12)
    end
    local ca = tool:FindFirstChild("CanActivate")
    if ca and ca:IsA("BoolValue") then ca.Value = true end
    pcall(function() tool:Activate() end)
    for _, p in ipairs(char:GetDescendants()) do
        if (p:IsA("BasePart") and p.Name ~= "HumanoidRootPart") or p:IsA("Decal") or p:IsA("Texture") then
            p.Transparency = 1
        end
    end
end

local function toBase()
    local r = root()
    if not r then return end
    local tp = _G.MyPlot and _G.MyPlot.Base and _G.MyPlot.Base.Teleport
    if tp and tp.WorldCFrame then
        r.CFrame = tp.WorldCFrame + Vector3.new(0, 3, 0)
        r.AssemblyLinearVelocity = Vector3.zero
        return
    end
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return end
    for _, plot in ipairs(plots:GetChildren()) do
        local o = plot:FindFirstChild("owner")
        if o and tostring(o.Value) == LP.Name then
            local b = plot:FindFirstChild("Base")
            local a = b and b:FindFirstChild("Teleport")
            if a and a:IsA("Attachment") and a.WorldCFrame then
                r.CFrame = a.WorldCFrame + Vector3.new(0, 3, 0)
                r.AssemblyLinearVelocity = Vector3.zero
            end
            return
        end
    end
end

local function findBlock()
    local live = workspace:FindFirstChild("Live")
    local folder = live and live:FindFirstChild("Slimes")
    if not folder then return end
    local best, bestV
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") and not m:GetAttribute("Carrying") then
            local name = m.Name
            local rarity
            if name:find("Japan", 1, true) then rarity = "Japan" end
            if rarity and TARGET[rarity] then
                local part = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
                if part then
                    local v = tonumber(m:GetAttribute("Value"))
                        or tonumber(m:GetAttribute("MoneyPerSecond"))
                        or 7e6
                    if not bestV or v > bestV then
                        local prompt
                        for _, d in ipairs(m:GetDescendants()) do
                            if d:IsA("ProximityPrompt") and d.Enabled then
                                prompt = d
                                local at = tostring(d.ActionText or ""):lower()
                                if at:find("steal") or at:find("pick") or at:find("take") then break end
                            end
                        end
                        bestV = v
                        best = { rarity = rarity, part = part, prompt = prompt, model = m }
                    end
                end
            end
        end
    end
    return best
end

local function steal(prompt)
    if not prompt then return false end
    local hold = prompt.HoldDuration or 0
    if typeof(fireproximityprompt) == "function" then
        if pcall(fireproximityprompt, prompt) then
            task.wait(hold + 0.5)
            return true
        end
    end
    if pcall(function() prompt:Trigger() end) then
        task.wait(hold + 0.5)
        return true
    end
    return false
end

-- GUI
pcall(function()
    local o = PG:FindFirstChild("JapanStealer") or PG:FindFirstChild("JIStealer")
    if o then o:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "JapanStealer"
gui.ResetOnSpawn = false
gui.Parent = PG

local f = Instance.new("Frame")
f.Size = UDim2.new(0, 190, 0, 108)
f.Position = UDim2.new(0, 16, 0.5, -54)
f.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
f.BorderSizePixel = 0
f.Active = true
f.Draggable = true
f.Parent = gui
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1, -20, 0, 34)
btn.Position = UDim2.new(0, 10, 0, 8)
btn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
btn.BorderSizePixel = 0
btn.Text = "Steal: OFF"
btn.TextColor3 = Color3.fromRGB(255, 90, 90)
btn.TextSize = 14
btn.Font = Enum.Font.GothamBold
btn.Parent = f
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

local timeLbl = Instance.new("TextLabel")
timeLbl.Size = UDim2.new(1, -16, 0, 22)
timeLbl.Position = UDim2.new(0, 8, 0, 48)
timeLbl.BackgroundTransparency = 1
timeLbl.Text = "Time: 00:00"
timeLbl.TextColor3 = Color3.fromRGB(200, 200, 210)
timeLbl.TextSize = 13
timeLbl.Font = Enum.Font.Gotham
timeLbl.TextXAlignment = Enum.TextXAlignment.Left
timeLbl.Parent = f

local countLbl = Instance.new("TextLabel")
countLbl.Size = UDim2.new(1, -16, 0, 22)
countLbl.Position = UDim2.new(0, 8, 0, 72)
countLbl.BackgroundTransparency = 1
countLbl.Text = "Collected: 0"
countLbl.TextColor3 = Color3.fromRGB(200, 200, 210)
countLbl.TextSize = 13
countLbl.Font = Enum.Font.Gotham
countLbl.TextXAlignment = Enum.TextXAlignment.Left
countLbl.Parent = f

local function setOn(on)
    enabled = on
    btn.Text = on and "Steal: ON" or "Steal: OFF"
    btn.TextColor3 = on and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 90, 90)
    btn.BackgroundColor3 = on and Color3.fromRGB(28, 52, 36) or Color3.fromRGB(40, 40, 48)
    if on then
        total = 0
        sessionStart = os.clock()
        countLbl.Text = "Collected: 0"
        timeLbl.Text = "Time: 00:00"
    else
        busy = false
    end
end

btn.MouseButton1Click:Connect(function()
    setOn(not enabled)
end)

-- live timer while ON
task.spawn(function()
    while true do
        if enabled and sessionStart > 0 then
            timeLbl.Text = "Time: " .. fmtTime(os.clock() - sessionStart)
        end
        task.wait(0.25)
    end
end)

task.spawn(function()
    while true do
        if enabled and not busy then
            busy = true

            if LP:GetAttribute("holdingSlime") == true then
                toBase()
                local t = os.clock() + 5
                while enabled and LP:GetAttribute("holdingSlime") and os.clock() < t do
                    task.wait(0.1)
                end
                busy = false
                task.wait(0.1)
                continue
            end

            local b = findBlock()
            if not b then
                busy = false
                task.wait(0.5)
                continue
            end

            activateCloak()
            task.wait(0.2)

            local r = root()
            if not r or not b.part or not b.part.Parent then
                busy = false
                task.wait(0.2)
                continue
            end

            r.CFrame = b.part.CFrame * CFrame.new(0, -1, 0)
            r.AssemblyLinearVelocity = Vector3.zero

            local bv = Instance.new("BodyVelocity")
            bv.Name = "LuckyFloat"
            bv.Velocity = Vector3.zero
            bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            bv.P = 1250
            bv.Parent = r
            task.wait(0.15)

            local prompt = b.prompt
            if (not prompt or not prompt.Parent) and b.model then
                for _, d in ipairs(b.model:GetDescendants()) do
                    if d:IsA("ProximityPrompt") and d.Enabled then
                        prompt = d
                        break
                    end
                end
            end

            local ok = prompt and steal(prompt)
            if not ok and LP:GetAttribute("holdingSlime") == true then
                ok = true
            end

            if bv.Parent then bv:Destroy() end
            r = root()
            if r then r.AssemblyLinearVelocity = Vector3.zero end

            if ok then
                total += 1
                countLbl.Text = "Collected: " .. total
                task.wait(0.25)
                toBase()
                task.wait(0.3)
                local t = os.clock() + 5
                while enabled and LP:GetAttribute("holdingSlime") and os.clock() < t do
                    task.wait(0.1)
                end
            else
                task.wait(0.25)
            end

            busy = false
        end
        task.wait(0.1)
    end
end)