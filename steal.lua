-- Simple Lucky Block Stealer
-- ONE toggle: only steals Japan + Icons
-- Mechanism: invis → 1 stud underground → BodyVelocity hold → prompt → base

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local TARGET_RARITIES = {
    ["Japan"] = true,
    ["Icons"] = true,
}

local RARITY_VALUE = {
    ["Japan"] = 7000000,
    ["Icons"] = 5000000,
    ["Spain"] = 2500000,
    ["Champions"] = 1000000,
    ["OG"] = 500000,
}

-- ============================================
-- HELPERS
-- ============================================

local function getRoot()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function findCloakTool()
    local function scan(bag)
        if not bag then return nil end
        for _, item in ipairs(bag:GetChildren()) do
            if item:IsA("Tool") then
                local n = string.lower(item.Name)
                if n:find("invisibility") or n:find("cloak") or n:find("invis") then
                    return item
                end
            end
        end
    end
    return scan(LocalPlayer.Character) or scan(LocalPlayer:FindFirstChild("Backpack"))
end

local function setLocalInvisible(on)
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            if on then
                if part:GetAttribute("_OrigTrans") == nil then
                    part:SetAttribute("_OrigTrans", part.Transparency)
                end
                part.Transparency = 1
            else
                local orig = part:GetAttribute("_OrigTrans")
                if orig ~= nil then
                    part.Transparency = orig
                    part:SetAttribute("_OrigTrans", nil)
                end
            end
        elseif part:IsA("Decal") or part:IsA("Texture") then
            if on then
                if part:GetAttribute("_OrigTrans") == nil then
                    part:SetAttribute("_OrigTrans", part.Transparency)
                end
                part.Transparency = 1
            else
                local orig = part:GetAttribute("_OrigTrans")
                if orig ~= nil then
                    part.Transparency = orig
                    part:SetAttribute("_OrigTrans", nil)
                end
            end
        end
    end
    for _, acc in ipairs(char:GetChildren()) do
        if acc:IsA("Accessory") then
            local handle = acc:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                if on then
                    if handle:GetAttribute("_OrigTrans") == nil then
                        handle:SetAttribute("_OrigTrans", handle.Transparency)
                    end
                    handle.Transparency = 1
                else
                    local orig = handle:GetAttribute("_OrigTrans")
                    if orig ~= nil then
                        handle.Transparency = orig
                        handle:SetAttribute("_OrigTrans", nil)
                    end
                end
            end
        end
    end
end

local function activateCloak()
    local tool = findCloakTool()
    if not tool then return false end
    local hum = getHumanoid()
    local char = LocalPlayer.Character
    if not hum or not char then return false end
    if tool.Parent ~= char then
        pcall(function() hum:UnequipTools() end)
        task.wait(0.05)
        pcall(function() hum:EquipTool(tool) end)
        if tool.Parent ~= char then
            pcall(function() tool.Parent = char end)
        end
        task.wait(0.15)
    end
    local canAct = tool:FindFirstChild("CanActivate")
    if canAct and canAct:IsA("BoolValue") then
        canAct.Value = true
    end
    pcall(function() tool:Activate() end)
    setLocalInvisible(true)
    return true
end

local function getMyPlot()
    if _G.MyPlot and _G.MyPlot.Parent then return _G.MyPlot end
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, plot in ipairs(plots:GetChildren()) do
        local owner = plot:FindFirstChild("owner")
        if owner and tostring(owner.Value) == LocalPlayer.Name then
            return plot
        end
    end
    return nil
end

local function teleportToBase()
    local root = getRoot()
    if not root then return false end
    if _G.MyPlot and _G.MyPlot.Base and _G.MyPlot.Base.Teleport and _G.MyPlot.Base.Teleport.WorldCFrame then
        root.CFrame = _G.MyPlot.Base.Teleport.WorldCFrame + Vector3.new(0, 3, 0)
        root.AssemblyLinearVelocity = Vector3.zero
        return true
    end
    local plot = getMyPlot()
    if plot then
        local base = plot:FindFirstChild("Base")
        if base then
            local tp = base:FindFirstChild("Teleport")
            if tp and tp:IsA("Attachment") and tp.WorldCFrame then
                root.CFrame = tp.WorldCFrame + Vector3.new(0, 3, 0)
                root.AssemblyLinearVelocity = Vector3.zero
                return true
            end
            local basePart = base:FindFirstChildWhichIsA("BasePart")
            if basePart then
                root.CFrame = basePart.CFrame + Vector3.new(0, 5, 0)
                root.AssemblyLinearVelocity = Vector3.zero
                return true
            end
        end
    end
    return false
end

local function getRarityValue(name)
    name = tostring(name or "")
    for rarity, value in pairs(RARITY_VALUE) do
        if string.find(name, rarity, 1, true) then
            return value, rarity
        end
    end
    return 1, "Unknown"
end

local function getTargetLuckyBlock()
    local live = workspace:FindFirstChild("Live")
    if not live then return nil end
    local slimes = live:FindFirstChild("Slimes")
    if not slimes then return nil end

    local best, bestValue = nil, 0

    for _, model in ipairs(slimes:GetChildren()) do
        if model:IsA("Model") and not model:GetAttribute("Carrying") then
            local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
            if not primary then continue end

            local _, rarity = getRarityValue(model.Name)
            if not TARGET_RARITIES[rarity] then continue end

            local value = RARITY_VALUE[rarity] or 0
            local attr = model:GetAttribute("Value") or model:GetAttribute("MoneyPerSecond")
            if attr and tonumber(attr) then
                value = tonumber(attr)
            end

            local prompt = nil
            for _, d in ipairs(model:GetDescendants()) do
                if d:IsA("ProximityPrompt") and d.Enabled then
                    local at = tostring(d.ActionText or ""):lower()
                    if at:find("steal") or at:find("open") or at:find("pick") or at:find("take") or not prompt then
                        prompt = d
                        if at:find("steal") or at:find("open") or at:find("pick") or at:find("take") then
                            break
                        end
                    end
                end
            end

            if value > bestValue then
                bestValue = value
                best = {
                    name = model.Name,
                    rarity = rarity,
                    value = value,
                    part = primary,
                    prompt = prompt,
                    model = model,
                }
            end
        end
    end

    return best
end

local function attemptSteal(prompt)
    if not prompt then return false end
    local hold = prompt.HoldDuration or 0
    if typeof(fireproximityprompt) == "function" then
        local ok = pcall(function() fireproximityprompt(prompt) end)
        if ok then
            task.wait(hold + 0.5)
            return true
        end
    end
    local ok = pcall(function() prompt:Trigger() end)
    if ok then
        task.wait(hold + 0.5)
        return true
    end
    return false
end

-- ============================================
-- GUI (one toggle)
-- ============================================

pcall(function()
    local old = PlayerGui:FindFirstChild("JapanIconsStealer")
    if old then old:Destroy() end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "JapanIconsStealer"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 200, 0, 90)
Frame.Position = UDim2.new(0, 20, 0.5, -45)
Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
Frame.BorderSizePixel = 0
Frame.Active = true
Frame.Draggable = true
Frame.Parent = ScreenGui
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 24)
Title.BackgroundTransparency = 1
Title.Text = "Japan / Icons Stealer"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 13
Title.Font = Enum.Font.GothamBold
Title.Parent = Frame

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 170, 0, 36)
ToggleBtn.Position = UDim2.new(0, 15, 0, 30)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
ToggleBtn.BorderSizePixel = 0
ToggleBtn.Text = "Steal: OFF"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 90, 90)
ToggleBtn.TextSize = 14
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = Frame
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 8)

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -20, 0, 18)
Status.Position = UDim2.new(0, 10, 0, 68)
Status.BackgroundTransparency = 1
Status.Text = "Ready"
Status.TextColor3 = Color3.fromRGB(180, 180, 190)
Status.TextSize = 11
Status.Font = Enum.Font.Gotham
Status.Parent = Frame

-- ============================================
-- STATE + LOOP
-- ============================================

local enabled = false
local busy = false
local total = 0

local function setEnabled(on)
    enabled = on
    if on then
        ToggleBtn.Text = "Steal: ON"
        ToggleBtn.TextColor3 = Color3.fromRGB(80, 255, 120)
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 55, 40)
        Status.Text = "Targeting Japan / Icons..."
        total = 0
    else
        ToggleBtn.Text = "Steal: OFF"
        ToggleBtn.TextColor3 = Color3.fromRGB(255, 90, 90)
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        Status.Text = "Stopped"
        busy = false
    end
end

ToggleBtn.MouseButton1Click:Connect(function()
    setEnabled(not enabled)
end)

task.spawn(function()
    while true do
        if enabled and not busy then
            busy = true

            if LocalPlayer:GetAttribute("holdingSlime") == true then
                Status.Text = "Carrying → base"
                teleportToBase()
                task.wait(0.35)
                local deadline = os.clock() + 5
                while enabled and LocalPlayer:GetAttribute("holdingSlime") == true and os.clock() < deadline do
                    task.wait(0.1)
                end
                busy = false
                task.wait(0.1)
                continue
            end

            local block = getTargetLuckyBlock()
            if not block then
                Status.Text = string.format("No Japan/Icons | #%d", total)
                busy = false
                task.wait(0.5)
                continue
            end

            local root = getRoot()
            if not root then
                busy = false
                task.wait(0.5)
                continue
            end

            -- 1) Invis before TP
            Status.Text = "Invis..."
            pcall(activateCloak)
            task.wait(0.25)

            if not block.part or not block.part.Parent then
                Status.Text = "Target gone"
                busy = false
                task.wait(0.25)
                continue
            end

            -- 2) 1 stud underground
            root = getRoot()
            if root then
                root.CFrame = block.part.CFrame * CFrame.new(0, -1, 0)
                root.AssemblyLinearVelocity = Vector3.zero
                pcall(function()
                    root.Velocity = Vector3.zero
                    root.RotVelocity = Vector3.zero
                end)
            end

            -- 3) Hold
            local bv = Instance.new("BodyVelocity")
            bv.Name = "LuckyFloat"
            bv.Velocity = Vector3.zero
            bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            bv.P = 1250
            if root then bv.Parent = root end

            Status.Text = "Under: " .. tostring(block.rarity)
            task.wait(0.2)

            -- 4) Steal
            local prompt = block.prompt
            if (not prompt or not prompt.Parent) and block.model and block.model.Parent then
                for _, d in ipairs(block.model:GetDescendants()) do
                    if d:IsA("ProximityPrompt") and d.Enabled then
                        local at = tostring(d.ActionText or ""):lower()
                        if at:find("steal") or at:find("pick") or at:find("take") or at:find("open") or not prompt then
                            prompt = d
                            if at:find("steal") or at:find("pick") or at:find("take") then break end
                        end
                    end
                end
            end

            local success = false
            if prompt and prompt.Parent then
                Status.Text = "Stealing " .. tostring(block.rarity) .. "..."
                success = attemptSteal(prompt) == true
                if not success and LocalPlayer:GetAttribute("holdingSlime") == true then
                    success = true
                end
            else
                Status.Text = "No prompt"
            end

            if bv and bv.Parent then bv:Destroy() end
            root = getRoot()
            if root then
                root.AssemblyLinearVelocity = Vector3.zero
            end

            if success then
                total += 1
                Status.Text = string.format("✓ %s (#%d) → base", block.rarity, total)
                task.wait(0.3)
                teleportToBase()
                task.wait(0.35)
                local clearUntil = os.clock() + 5
                while enabled and LocalPlayer:GetAttribute("holdingSlime") == true and os.clock() < clearUntil do
                    task.wait(0.1)
                end
                Status.Text = string.format("Done #%d | next...", total)
            else
                Status.Text = "Failed — retry"
                task.wait(0.3)
            end

            busy = false
        end
        task.wait(0.1)
    end
end)

print("[Japan/Icons Stealer] Loaded — one toggle, underground + invis")
