--[[
  Lucky Box Cycle Auto
  ----------------------
  Flow (loops forever while ON):
    Rarity filter (dropdown):
      - "All" (default) → Priority HIGHEST → LOWEST (Alternative first, Common last)
      - Specific rarity → only that rarity
    For each selected rarity batch of up to 100:
      - First scan: if none of that rarity in world → skip whole batch
      - Else collect up to 100 of THAT rarity only
      - Carry up to 6 steals, then teleport to base (deposit), repeat
      - If any collected → Place + Open + Pickup + Sell
      - Then next lower rarity batch (if All)
    After pass, restart.

  Mechanisms reused from your AutoFarm + Slime Value Browser scripts.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local CoreGui           = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui", 10)

-- ============================================================
-- CONFIG
-- ============================================================
-- Each batch targets ONE rarity and collects up to BATCH_SIZE boxes
-- of that rarity only, then Place → Open → Pickup → Sell.
-- Priority is HIGHEST → LOWEST (Alternative first, Common last).
-- If the FIRST scan of a rarity finds zero boxes, skip that whole batch.
local BATCH_SIZE = 100
-- How many lucky boxes to steal in one trip before teleporting back to base
local CARRY_BEFORE_BASE = 6

-- Highest value first → lowest last
local TARGET_RARITIES = {
    "Alternative",
    "Japan",
    "Icons",
    "Spain",
    "Champions",
    "OG",
    "Limited",
    "Exclusive",
    "Rainbow",
    "Soccer God",
    "Cosmic",
    "Secret",
    "Poison",
    "Mythic",
    "67",
    "Legendary",
    "Ghost",
    "Epic",
    "Volcanic",
    "Rare",
    "Water",
    "Common",
}

local TOTAL_TARGET = BATCH_SIZE  -- per-batch cap (shown in UI)

local LUCKY_BLOCK_MODEL_NAMES = {
    ["Common"]      = { ["Common Lucky Block"] = true },
    ["Water"]       = { ["Water Lucky Block"] = true },
    ["Rare"]        = { ["Rare Lucky Block"] = true },
    ["Volcanic"]    = { ["Volcanic Lucky Block"] = true },
    ["Epic"]        = { ["Epic Lucky Block"] = true },
    ["Ghost"]       = { ["Ghost Lucky Block"] = true },
    ["Legendary"]   = { ["Legendary Lucky Block"] = true },
    ["67"]          = { ["67 Lucky Block"] = true },
    ["Mythic"]      = { ["Mythic Lucky Block"] = true },
    ["Poison"]      = { ["Poison Lucky Block"] = true },
    ["Secret"]      = { ["Secret Lucky Block"] = true },
    ["Cosmic"]      = { ["Cosmic Lucky Block"] = true },
    ["Soccer God"]  = {
        ["Slime God Lucky Block"] = true,
        ["Soccer God Lucky Block"] = true,
    },
    ["Rainbow"]     = { ["Rainbow Lucky Block"] = true },
    ["Exclusive"]   = { ["Exclusive Lucky Block"] = true },
    ["Limited"]     = { ["Limited Lucky Block"] = true },
    ["OG"]          = { ["OG Lucky Block"] = true },
    ["Champions"]   = { ["Champions Lucky Block"] = true },
    ["Spain"]       = { ["Spain Lucky Block"] = true },
    ["Icons"]       = { ["Icons Lucky Block"] = true },
    ["Japan"]       = { ["Japan Lucky Block"] = true },
    ["Alternative"] = { ["Alternative Lucky Block"] = true },
}

-- ============================================================
-- STATE
-- ============================================================
local running = false
local phase   = "Idle"
local collectedThisCycle = 0
local countsByRarity = {}
local currentRarityIndex = 1
local selectedRarity = "All"  -- "All" or one of TARGET_RARITIES
local logLines = {}
local MAX_LOG = 80

for _, r in ipairs(TARGET_RARITIES) do
    countsByRarity[r] = 0
end

-- ============================================================
-- INSTANT PROMPTS
-- ============================================================
for _, v in ipairs(Workspace:GetDescendants()) do
    if v:IsA("ProximityPrompt") then
        v.HoldDuration = 0
    end
end
Workspace.DescendantAdded:Connect(function(v)
    if v:IsA("ProximityPrompt") then
        v.HoldDuration = 0
    end
end)

-- ============================================================
-- GUI
-- ============================================================
pcall(function()
    local old = PlayerGui and PlayerGui:FindFirstChild("LuckyBoxCycleGui")
    if old then old:Destroy() end
    old = CoreGui:FindFirstChild("LuckyBoxCycleGui")
    if old then old:Destroy() end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LuckyBoxCycleGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
ScreenGui.IgnoreGuiInset = true
pcall(function() ScreenGui.Parent = PlayerGui or CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = CoreGui end

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 340, 0, 470)
Main.Position = UDim2.new(0, 20, 0.5, -235)
Main.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", Main)
stroke.Color = Color3.fromRGB(70, 70, 95)
stroke.Thickness = 1.5

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -16, 0, 28)
Title.Position = UDim2.new(0, 10, 0, 6)
Title.BackgroundTransparency = 1
Title.Text = "Lucky Box Cycle Auto"
Title.TextColor3 = Color3.fromRGB(245, 245, 250)
Title.TextSize = 15
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Main

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 150, 0, 32)
ToggleBtn.Position = UDim2.new(0, 12, 0, 40)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 35, 40)
ToggleBtn.BorderSizePixel = 0
ToggleBtn.Text = "START"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 120, 130)
ToggleBtn.TextSize = 13
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = Main
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 7)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(0, 160, 0, 32)
StatusLabel.Position = UDim2.new(0, 170, 0, 40)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Idle"
StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
StatusLabel.TextSize = 11
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextYAlignment = Enum.TextYAlignment.Center
StatusLabel.TextWrapped = true
StatusLabel.Parent = Main

-- Rarity dropdown
local RarityLabel = Instance.new("TextLabel")
RarityLabel.Size = UDim2.new(0, 70, 0, 26)
RarityLabel.Position = UDim2.new(0, 12, 0, 78)
RarityLabel.BackgroundTransparency = 1
RarityLabel.Text = "Rarity:"
RarityLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
RarityLabel.TextSize = 12
RarityLabel.Font = Enum.Font.Gotham
RarityLabel.TextXAlignment = Enum.TextXAlignment.Left
RarityLabel.Parent = Main

local RarityDropBtn = Instance.new("TextButton")
RarityDropBtn.Size = UDim2.new(0, 240, 0, 26)
RarityDropBtn.Position = UDim2.new(0, 82, 0, 78)
RarityDropBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
RarityDropBtn.BorderSizePixel = 0
RarityDropBtn.Text = "All (highest → lowest)"
RarityDropBtn.TextColor3 = Color3.fromRGB(200, 220, 255)
RarityDropBtn.TextSize = 11
RarityDropBtn.Font = Enum.Font.GothamBold
RarityDropBtn.Parent = Main
Instance.new("UICorner", RarityDropBtn).CornerRadius = UDim.new(0, 6)

local RarityDropList = Instance.new("ScrollingFrame")
RarityDropList.Size = UDim2.new(0, 240, 0, 0)
RarityDropList.Position = UDim2.new(0, 82, 0, 106)
RarityDropList.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
RarityDropList.BorderSizePixel = 0
RarityDropList.ScrollBarThickness = 4
RarityDropList.Visible = false
RarityDropList.ZIndex = 50
RarityDropList.CanvasSize = UDim2.new(0, 0, 0, 0)
RarityDropList.AutomaticCanvasSize = Enum.AutomaticSize.Y
RarityDropList.Parent = Main
Instance.new("UICorner", RarityDropList).CornerRadius = UDim.new(0, 6)
local RarityDropLayout = Instance.new("UIListLayout")
RarityDropLayout.SortOrder = Enum.SortOrder.LayoutOrder
RarityDropLayout.Padding = UDim.new(0, 1)
RarityDropLayout.Parent = RarityDropList

local RARITY_OPTIONS = { "All" }
for _, r in ipairs(TARGET_RARITIES) do
    table.insert(RARITY_OPTIONS, r)
end

local function setRaritySelection(name)
    selectedRarity = name
    if name == "All" then
        RarityDropBtn.Text = "All (highest → lowest)"
    else
        RarityDropBtn.Text = name
    end
    RarityDropList.Visible = false
    RarityDropList.Size = UDim2.new(0, 240, 0, 0)
    addLog("Rarity filter → " .. (name == "All" and "All (priority order)" or name))
end

for i, opt in ipairs(RARITY_OPTIONS) do
    local item = Instance.new("TextButton")
    item.Size = UDim2.new(1, -4, 0, 22)
    item.BackgroundColor3 = Color3.fromRGB(40, 40, 58)
    item.BorderSizePixel = 0
    item.Text = opt == "All" and "All (highest → lowest)" or opt
    item.TextColor3 = Color3.fromRGB(210, 210, 230)
    item.TextSize = 11
    item.Font = Enum.Font.Gotham
    item.LayoutOrder = i
    item.ZIndex = 51
    item.Parent = RarityDropList
    Instance.new("UICorner", item).CornerRadius = UDim.new(0, 4)
    item.MouseButton1Click:Connect(function()
        setRaritySelection(opt)
    end)
end

RarityDropBtn.MouseButton1Click:Connect(function()
    local open = not RarityDropList.Visible
    RarityDropList.Visible = open
    if open then
        local h = math.min(#RARITY_OPTIONS * 24, 180)
        RarityDropList.Size = UDim2.new(0, 240, 0, h)
    else
        RarityDropList.Size = UDim2.new(0, 240, 0, 0)
    end
end)

local ProgressLabel = Instance.new("TextLabel")
ProgressLabel.Size = UDim2.new(1, -24, 0, 36)
ProgressLabel.Position = UDim2.new(0, 12, 0, 112)
ProgressLabel.BackgroundTransparency = 1
ProgressLabel.Text = "0 / 100 boxes | Phase: Idle"
ProgressLabel.TextColor3 = Color3.fromRGB(150, 220, 170)
ProgressLabel.TextSize = 12
ProgressLabel.Font = Enum.Font.GothamBold
ProgressLabel.TextXAlignment = Enum.TextXAlignment.Left
ProgressLabel.TextYAlignment = Enum.TextYAlignment.Top
ProgressLabel.TextWrapped = true
ProgressLabel.Parent = Main

local LogFrame = Instance.new("ScrollingFrame")
LogFrame.Size = UDim2.new(1, -24, 0, 300)
LogFrame.Position = UDim2.new(0, 12, 0, 152)
LogFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
LogFrame.BorderSizePixel = 0
LogFrame.ScrollBarThickness = 5
LogFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
LogFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
LogFrame.Parent = Main
Instance.new("UICorner", LogFrame).CornerRadius = UDim.new(0, 6)

local LogLayout = Instance.new("UIListLayout")
LogLayout.SortOrder = Enum.SortOrder.LayoutOrder
LogLayout.Padding = UDim.new(0, 2)
LogLayout.Parent = LogFrame

local function addLog(msg)
    local ts = os.date("%H:%M:%S")
    local line = string.format("[%s] %s", ts, tostring(msg))
    table.insert(logLines, line)
    if #logLines > MAX_LOG then
        table.remove(logLines, 1)
    end

    for _, child in ipairs(LogFrame:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    for i, text in ipairs(logLines) do
        local lab = Instance.new("TextLabel")
        lab.Size = UDim2.new(1, -8, 0, 16)
        lab.BackgroundTransparency = 1
        lab.Text = text
        lab.TextColor3 = Color3.fromRGB(200, 200, 215)
        lab.TextSize = 10
        lab.Font = Enum.Font.Gotham
        lab.TextXAlignment = Enum.TextXAlignment.Left
        lab.LayoutOrder = i
        lab.Parent = LogFrame
    end

    task.defer(function()
        LogFrame.CanvasPosition = Vector2.new(0, LogFrame.AbsoluteCanvasSize.Y)
    end)
end

local function setPhase(name)
    phase = name
    StatusLabel.Text = name
    ProgressLabel.Text = string.format(
        "%d / %d boxes | Phase: %s",
        collectedThisCycle,
        TOTAL_TARGET,
        name
    )
end

-- ============================================================
-- GAME HELPERS (from your scripts)
-- ============================================================
local function getRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function ResolveRemoteEventExact(name)
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") and v.Name == name then
            return v
        end
    end
    return nil
end

local PlaceRemote, OpenRemote, PickupRemote, SellRemote

local function ensureRemotes()
    PlaceRemote  = PlaceRemote  or ResolveRemoteEventExact("Place Slime")
    OpenRemote   = OpenRemote   or ResolveRemoteEventExact("Open Lucky Block")
    PickupRemote = PickupRemote or ResolveRemoteEventExact("Pickup Slime")
    SellRemote   = SellRemote   or ResolveRemoteEventExact("Sell Slime From Inventory")
end

local function getData()
    local lib = rawget(_G, "_Lib")
    if lib and lib.Data then
        local ok, data = pcall(function() return lib.Data:Get() end)
        if ok and data then return data end
    end
    local shared = ReplicatedStorage:FindFirstChild("SharedModules")
    local network = shared and shared:FindFirstChild("Network")
    local remotes = network and network:FindFirstChild("Remotes")
    local dataGet = remotes and remotes:FindFirstChild("Data: Get")
    if dataGet and dataGet:IsA("RemoteFunction") then
        local ok, data = pcall(function() return dataGet:InvokeServer() end)
        if ok and data then return data end
    end
    local broad = ReplicatedStorage:FindFirstChild("Data: Get", true)
    if broad and broad:IsA("RemoteFunction") then
        local ok, data = pcall(function() return broad:InvokeServer() end)
        if ok and data then return data end
    end
    return nil
end

local function getMyPlot()
    if _G.MyPlot and _G.MyPlot.Parent then return _G.MyPlot end
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, plot in ipairs(plots:GetChildren()) do
        local owner = plot:FindFirstChild("owner")
        if owner and tostring(owner.Value) == LocalPlayer.Name then
            return plot
        end
    end
    return nil
end

local function getPlayerSlimesFolder()
    local live = Workspace:FindFirstChild("Live")
    local playerSlimes = live and live:FindFirstChild("PlayerSlimes")
    return playerSlimes and playerSlimes:FindFirstChild(LocalPlayer.Name)
end

local function getBaseLevel(data)
    data = data or getData()
    if data and type(data.BaseLevel) == "number" then return data.BaseLevel end
    return tonumber(LocalPlayer:GetAttribute("BaseLevel")) or 0
end

local function isUnlocked(slotName, baseLevel)
    local n = tonumber(slotName)
    if not n then return true end
    return n <= 10 or (n - 10) <= (tonumber(baseLevel) or 0)
end

local function isOccupied(slotName, plotSlimes, playerSlimesFolder, stand)
    slotName = tostring(slotName)
    if type(plotSlimes) == "table" then
        if plotSlimes[slotName] then return true end
        local n = tonumber(slotName)
        if n and plotSlimes[n] then return true end
    end
    if playerSlimesFolder and playerSlimesFolder:FindFirstChild(slotName) then
        return true
    end
    if stand then
        local main = stand:FindFirstChild("Main")
        local holder = main and main:FindFirstChild("Holder")
        local pick = holder and holder:FindFirstChild("Pick Up")
        if pick and pick:IsA("ProximityPrompt") and pick.Enabled then
            return true
        end
    end
    return false
end

local function getAvailableSlots()
    local data = getData()
    local baseLevel = getBaseLevel(data)
    local plotSlimes = (data and data.PlotSlimes) or {}
    local plot = getMyPlot()
    local liveFolder = getPlayerSlimesFolder()
    local free = {}
    if not plot then return free end
    local stands = plot:FindFirstChild("Stands")
    if not stands then return free end
    for _, stand in ipairs(stands:GetChildren()) do
        local n = tonumber(stand.Name)
        if n ~= nil or stand:FindFirstChild("Main") then
            if isUnlocked(stand.Name, baseLevel)
                and not isOccupied(stand.Name, plotSlimes, liveFolder, stand)
            then
                table.insert(free, {
                    name = tostring(stand.Name),
                    num = n or 9999,
                    stand = stand,
                })
            end
        end
    end
    table.sort(free, function(a, b) return a.num < b.num end)
    return free
end

local function getAllOccupiedSlots()
    local data = getData()
    local plotSlimes = (data and data.PlotSlimes) or {}
    local plot = getMyPlot()
    local liveFolder = getPlayerSlimesFolder()
    local list = {}
    if not plot then return list end
    local stands = plot:FindFirstChild("Stands")
    if not stands then return list end
    for _, stand in ipairs(stands:GetChildren()) do
        if stand:IsA("Model") then
            local name = tostring(stand.Name)
            if isOccupied(name, plotSlimes, liveFolder, stand) then
                table.insert(list, { name = name, stand = stand })
            end
        end
    end
    return list
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
        end
    end
    return false
end

-- Cloak helpers (minimal)
local function findCloakTool()
    local function scan(bag)
        if not bag then return nil end
        for _, t in ipairs(bag:GetChildren()) do
            if t:IsA("Tool") then
                local n = string.lower(t.Name)
                if n:find("cloak", 1, true) or n:find("invis", 1, true) then
                    return t
                end
            end
        end
        return nil
    end
    return scan(LocalPlayer.Character) or scan(LocalPlayer:FindFirstChild("Backpack"))
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
        if tool.Parent ~= char then pcall(function() tool.Parent = char end) end
        task.wait(0.12)
    end
    local canAct = tool:FindFirstChild("CanActivate")
    if canAct and canAct:IsA("BoolValue") then canAct.Value = true end
    pcall(function() tool:Activate() end)
    return true
end

local function attemptSteal(prompt)
    if not prompt or not prompt.Parent then return false end
    prompt.HoldDuration = 0
    pcall(function()
        if fireproximityprompt then
            fireproximityprompt(prompt)
        else
            prompt:InputHoldBegin()
            task.wait(0.05)
            prompt:InputHoldEnd()
        end
    end)
    return true
end

-- True if at least one non-carrying block of this rarity exists in Live.Slimes
local function hasLuckyBlockOfType(rarityName)
    local allowed = LUCKY_BLOCK_MODEL_NAMES[rarityName]
    if not allowed then return false end
    local live = Workspace:FindFirstChild("Live")
    local slimes = live and live:FindFirstChild("Slimes")
    if not slimes then return false end
    for _, model in ipairs(slimes:GetChildren()) do
        if model:IsA("Model")
            and not model:GetAttribute("Carrying")
            and allowed[tostring(model.Name)]
        then
            return true
        end
    end
    return false
end

-- Find the next rarity (from startIndex onward, wrapping once) that still
-- needs boxes AND currently has at least one block in the world.
-- Returns index + name, or nil if nothing available.
local function findNextAvailableRarity(startIndex)
    local n = #TARGET_RARITIES
    for offset = 0, n - 1 do
        local i = ((startIndex - 1 + offset) % n) + 1
        local rarity = TARGET_RARITIES[i]
        if countsByRarity[rarity] < BATCH_SIZE
            and hasLuckyBlockOfType(rarity)
        then
            return i, rarity
        end
    end
    return nil, nil
end

-- Find one target lucky block of the given type
local function getTargetLuckyBlock(rarityName)
    local live = Workspace:FindFirstChild("Live")
    if not live then return nil end
    local slimes = live:FindFirstChild("Slimes")
    if not slimes then return nil end

    local allowed = LUCKY_BLOCK_MODEL_NAMES[rarityName]
    if not allowed then return nil end

    local root = getRoot()
    local best, bestDist = nil, math.huge

    for _, model in ipairs(slimes:GetChildren()) do
        if model:IsA("Model") and not model:GetAttribute("Carrying") then
            if allowed[tostring(model.Name)] then
                local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
                if primary then
                    local dist = root and (root.Position - primary.Position).Magnitude or 0
                    if dist < bestDist then
                        bestDist = dist
                        local prompt
                        for _, d in ipairs(model:GetDescendants()) do
                            if d:IsA("ProximityPrompt") and d.Enabled then
                                prompt = d
                                break
                            end
                        end
                        best = { model = model, part = primary, prompt = prompt }
                    end
                end
            end
        end
    end
    return best
end

-- Extra height above the TOP of the solid lucky box (humanoid hip height-ish).
local STAND_OFFSET = 3

local RunService = game:GetService("RunService")

-- Make the lucky box solid locally so the player can stand on it.
-- Sets CanCollide on every BasePart in the model (client-side collision).
local function makeLuckyBoxSolid(block)
    if not block then return end

    local parts = {}
    if block.model and block.model.Parent then
        for _, d in ipairs(block.model:GetDescendants()) do
            if d:IsA("BasePart") then
                table.insert(parts, d)
            end
        end
        if block.model:IsA("BasePart") then
            table.insert(parts, block.model)
        end
    end
    if block.part and block.part:IsA("BasePart") then
        table.insert(parts, block.part)
    end

    for _, part in ipairs(parts) do
        pcall(function()
            part.CanCollide = true
            part.CanTouch = true
            part.CanQuery = true
            -- Keep massless so server physics on the box itself don't go crazy
            if part.Massless ~= nil then
                part.Massless = true
            end
        end)
    end
end

-- World CFrame standing on top of the box (uses part size so feet sit on surface).
local function standOnBoxCFrame(part)
    if not part or not part.Parent then return nil end
    local topY = part.Size.Y * 0.5 + STAND_OFFSET
    return part.CFrame * CFrame.new(0, topY, 0)
end

-- Steal one box of current rarity.
-- Solidify the box, stand on top of it (no ground), fire prompt, then base.
local function stealOne(rarityName)
    -- Already holding something → deposit at base only (not a new steal)
    if LocalPlayer:GetAttribute("holdingSlime") == true then
        teleportToBase()
        local t = os.clock() + 1.2
        while LocalPlayer:GetAttribute("holdingSlime") and os.clock() < t do
            task.wait(0.08)
        end
        return "deposited"
    end

    local block = getTargetLuckyBlock(rarityName)
    if not block then return false end

    -- Make the lucky box solid so we can stand on it
    makeLuckyBoxSolid(block)

    pcall(activateCloak)
    task.wait(0.15)

    local root = getRoot()
    local hum = getHumanoid()
    if not root or not block.part or not block.part.Parent then return false end

    -- Re-apply solidity in case the model streamed parts late
    makeLuckyBoxSolid(block)

    -- Clear any previous float objects
    for _, name in ipairs({ "LuckyFloat", "LuckyHoverPos", "LuckyHoverGyro" }) do
        local old = root:FindFirstChild(name)
        if old then old:Destroy() end
    end

    local function hoverCFrame()
        if not block.part or not block.part.Parent then return nil end
        -- Stand on the solid top of the box — never the ground
        return standOnBoxCFrame(block.part)
    end

    local cf0 = hoverCFrame()
    if not cf0 then return false end

    root.CFrame = cf0
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    -- 1) BodyVelocity: zero velocity + extreme force = cancels gravity completely
    local bv = Instance.new("BodyVelocity")
    bv.Name = "LuckyFloat"
    bv.Velocity = Vector3.zero
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.P = 50000
    bv.Parent = root

    -- 2) BodyPosition: hard lock world position in the air
    local bp = Instance.new("BodyPosition")
    bp.Name = "LuckyHoverPos"
    bp.Position = cf0.Position
    bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bp.P = 50000
    bp.D = 2500
    bp.Parent = root

    -- 3) BodyGyro: keep upright
    local bg = Instance.new("BodyGyro")
    bg.Name = "LuckyHoverGyro"
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.P = 50000
    bg.CFrame = CFrame.new(cf0.Position) -- upright
    bg.Parent = root

    -- Freeze humanoid so it cannot walk/fall/jump into the ground
    if hum then
        pcall(function()
            hum.PlatformStand = true
            hum.AutoRotate = false
            hum:ChangeState(Enum.HumanoidStateType.Physics)
        end)
    end

    local hoverConn = nil
    local hovering = true

    local function applyHover()
        local r = getRoot()
        if not r or not hovering then return false end
        local cf = hoverCFrame()
        if not cf then return false end

        -- Hard snap every frame so gravity never wins a single tick
        r.CFrame = cf
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero

        if bv and bv.Parent then
            bv.Velocity = Vector3.zero
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        end
        if bp and bp.Parent then
            bp.Position = cf.Position
            bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        end
        if bg and bg.Parent then
            bg.CFrame = CFrame.new(cf.Position)
        end

        -- Safety: never sink through the box / onto the ground
        if block.part and block.part.Parent then
            local minY = block.part.Position.Y + (block.part.Size.Y * 0.5) + 1.5
            if r.Position.Y < minY then
                local cf = standOnBoxCFrame(block.part)
                if cf then
                    r.CFrame = cf
                else
                    r.CFrame = CFrame.new(r.Position.X, minY, r.Position.Z)
                end
                r.AssemblyLinearVelocity = Vector3.zero
            end
            -- Keep the box solid every frame (some games reset CanCollide)
            makeLuckyBoxSolid(block)
        end

        return true
    end

    -- Every frame lock while hovering — player cannot touch the ground
    hoverConn = RunService.Heartbeat:Connect(function()
        if not hovering then return end
        applyHover()
    end)

    local function cleanupHover()
        hovering = false
        if hoverConn then
            hoverConn:Disconnect()
            hoverConn = nil
        end
        for _, name in ipairs({ "LuckyFloat", "LuckyHoverPos", "LuckyHoverGyro" }) do
            local r = getRoot()
            local obj = r and r:FindFirstChild(name)
            if obj then obj:Destroy() end
        end
        local r = getRoot()
        if r then
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
        end
        if hum then
            pcall(function()
                hum.PlatformStand = false
                hum.AutoRotate = true
            end)
        end
    end

    -- Settle in the air
    for _ = 1, 6 do
        if not applyHover() then
            cleanupHover()
            return false
        end
        task.wait(0.03)
    end

    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            v.HoldDuration = 0
        end
    end

    local prompt = block.prompt
    if (not prompt or not prompt.Parent) and block.model then
        for _, d in ipairs(block.model:GetDescendants()) do
            if d:IsA("ProximityPrompt") and d.Enabled then
                prompt = d
                break
            end
        end
    end

    if not prompt or not prompt.Parent then
        cleanupHover()
        return false
    end

    -- Fire prompt while locked in the air (never leave hover until done)
    local stolen = false
    for try = 1, 10 do
        if not applyHover() then break end

        if not prompt.Parent and block.model and block.model.Parent then
            for _, d in ipairs(block.model:GetDescendants()) do
                if d:IsA("ProximityPrompt") and d.Enabled then
                    prompt = d
                    break
                end
            end
        end

        if prompt and prompt.Parent then
            prompt.HoldDuration = 0
            attemptSteal(prompt)
        end

        if LocalPlayer:GetAttribute("holdingSlime") == true then
            stolen = true
            break
        end
        if block.model and (not block.model.Parent or block.model:GetAttribute("Carrying") == true) then
            stolen = true
            break
        end
        task.wait(0.08)
    end

    -- Stay airborne a bit longer for server register
    for _ = 1, 5 do
        applyHover()
        task.wait(0.05)
    end

    if LocalPlayer:GetAttribute("holdingSlime") == true then
        stolen = true
    end

    -- Successful steal: do NOT go to base here.
    -- Caller (runCycle) returns to base every CARRY_BEFORE_BASE (6) steals.
    cleanupHover()
    if stolen then
        return true
    end
    return false
end

-- Count lucky boxes currently in inventory (by checking tools + data)
local function countInventoryLuckyBoxes()
    local n = 0
    local data = getData()
    if data and type(data.Inventory) == "table" then
        for _, entry in pairs(data.Inventory) do
            if type(entry) == "table" then
                local id = tostring(entry.id or entry.Id or "")
                local name = tostring(entry.Name or entry.name or "")
                if id:lower():find("lucky") or name:lower():find("lucky") then
                    n += 1
                end
            end
        end
    end
    -- also tools
    local function scan(bag)
        if not bag then return end
        for _, t in ipairs(bag:GetChildren()) do
            if t:IsA("Tool") then
                local nm = string.lower(t.Name)
                if nm:find("lucky", 1, true) and nm:find("block", 1, true) then
                    n += 1
                end
            end
        end
    end
    scan(LocalPlayer:FindFirstChild("Backpack"))
    scan(LocalPlayer.Character)
    return n
end

-- ============================================================
-- PLACE ALL LUCKY BOXES (spam + teleport hop) — from soccer.lua
-- ============================================================
local function getAllLuckyBlockUIDs()
    local list, seen = {}, {}
    local data = getData()
    local invByUID = {}
    if data and type(data.Inventory) == "table" then
        for _, entry in pairs(data.Inventory) do
            if type(entry) == "table" and entry.uid ~= nil then
                invByUID[tostring(entry.uid)] = entry
            end
        end
    end

    local function tryAdd(uid, tool)
        if uid == nil then return end
        local key = tostring(uid)
        if seen[key] then return end
        local isLucky = false
        if tool then
            local n = string.lower(tostring(tool.Name))
            if n:find("lucky", 1, true) then isLucky = true end
        end
        local entry = invByUID[key]
        if entry then
            local id = string.lower(tostring(entry.id or entry.Id or ""))
            local nm = string.lower(tostring(entry.Name or entry.name or ""))
            if id:find("lucky") or nm:find("lucky") then isLucky = true end
        end
        if isLucky then
            seen[key] = true
            table.insert(list, { uid = uid, tool = tool })
        end
    end

    local function scan(bag)
        if not bag then return end
        for _, item in ipairs(bag:GetChildren()) do
            if item:IsA("Tool") then
                tryAdd(item:GetAttribute("slimeUID"), item)
            end
        end
    end
    scan(LocalPlayer:FindFirstChild("Backpack"))
    scan(LocalPlayer.Character)

    for key, entry in pairs(invByUID) do
        if not seen[key] then
            tryAdd(entry.uid, nil)
        end
    end
    return list
end

local function doPlaceBoxesOnly()
    ensureRemotes()
    if not PlaceRemote then
        addLog("ERROR: Place Slime remote missing")
        return 0
    end

    local boxes = getAllLuckyBlockUIDs()
    local slots = getAvailableSlots()
    if #boxes == 0 or #slots == 0 then
        addLog(string.format("Place: %d boxes / %d free slots", #boxes, #slots))
        return 0
    end

    local function findPlacedByUID(data, uid)
        if not data or type(data.PlotSlimes) ~= "table" or uid == nil then return nil end
        local wanted = tostring(uid)
        for slotKey, entry in pairs(data.PlotSlimes) do
            if type(entry) == "table" then
                local euid = entry.uid or entry.UID or entry.slimeUID
                if euid and tostring(euid) == wanted then
                    return tostring(slotKey)
                end
            end
        end
        return nil
    end

    local function getStandCF(stand)
        if not stand then return nil end
        local part = stand.PrimaryPart
            or stand:FindFirstChild("Main")
            or stand:FindFirstChildWhichIsA("BasePart", true)
        if part and part:IsA("BasePart") then return part.CFrame end
        return nil
    end

    local targets = {}
    local total = math.min(#boxes, #slots)
    for i = 1, total do
        table.insert(targets, {
            uid = boxes[i].uid,
            slot = slots[i].name,
            stand = slots[i].stand,
            done = false,
        })
    end

    addLog(string.format("Placing %d lucky boxes...", total))
    local deadline = os.clock() + 14
    local hop = 1

    while os.clock() < deadline and running do
        local remaining = {}
        local data = getData()
        for _, t in ipairs(targets) do
            if not t.done then
                if findPlacedByUID(data, t.uid) then
                    t.done = true
                else
                    table.insert(remaining, t)
                end
            end
        end
        if #remaining == 0 then break end

        if hop > #remaining then hop = 1 end
        local current = remaining[hop]
        hop += 1

        if current and current.stand then
            local root = getRoot()
            local cf = getStandCF(current.stand)
            if root and cf then
                root.CFrame = cf * CFrame.new(0, 3, 3)
                root.AssemblyLinearVelocity = Vector3.zero
            end
            task.wait(0.04)
            pcall(function()
                PlaceRemote:FireServer(tostring(current.slot), current.uid)
            end)
            for _, t in ipairs(remaining) do
                if t ~= current then
                    pcall(function()
                        PlaceRemote:FireServer(tostring(t.slot), t.uid)
                    end)
                end
            end
        else
            for _, t in ipairs(remaining) do
                pcall(function()
                    PlaceRemote:FireServer(tostring(t.slot), t.uid)
                end)
            end
            task.wait(0.05)
        end
    end

    local placed = 0
    for _, t in ipairs(targets) do
        if t.done then placed += 1 end
    end
    addLog(string.format("Placed %d / %d boxes", placed, total))
    return placed
end

-- ============================================================
-- OPEN ALL BOXES (spam) — from soccer.lua
-- ============================================================
local function doOpenBoxesOnly()
    ensureRemotes()
    if not OpenRemote then
        addLog("ERROR: Open Lucky Block remote missing")
        return 0
    end

    local occupied = getAllOccupiedSlots()
    local slotNames, seen = {}, {}
    for _, s in ipairs(occupied) do
        local n = tostring(s.name)
        if n ~= "" and not seen[n] then
            seen[n] = true
            table.insert(slotNames, n)
        end
    end

    if #slotNames == 0 then
        addLog("Open: no occupied slots")
        return 0
    end

    addLog(string.format("Opening %d slots (spam x10)...", #slotNames))
    for _ = 1, 10 do
        if not running then break end
        for _, name in ipairs(slotNames) do
            pcall(function() OpenRemote:FireServer(name) end)
        end
        task.wait(0.04)
    end
    return #slotNames
end

-- ============================================================
-- PICK UP ALL PLACED (spam) — from admin.lua pattern
-- ============================================================
local function doPickupAllSpam()
    ensureRemotes()
    if not PickupRemote then
        addLog("ERROR: Pickup Slime remote missing")
        return 0
    end

    local deadline = os.clock() + 15
    local lastFire = 0
    local lastCount = -1

    addLog("Picking up all placed slimes (spam)...")

    while os.clock() < deadline and running do
        local occupied = getAllOccupiedSlots()
        if #occupied == 0 then
            addLog("All stands empty")
            return 0
        end

        if #occupied ~= lastCount then
            addLog(string.format("Still placed: %d", #occupied))
            lastCount = #occupied
        end

        if os.clock() - lastFire >= 0.05 then
            lastFire = os.clock()
            for _, s in ipairs(occupied) do
                pcall(function()
                    PickupRemote:FireServer(tostring(s.name))
                end)
            end
        end
        task.wait(0.03)
    end

    local left = #getAllOccupiedSlots()
    addLog(string.format("Pickup done | remaining: %d", left))
    return left
end

-- ============================================================
-- SELL ALL INVENTORY (spam) — from admin.lua
-- ============================================================
local function getInventoryUIDs()
    local list = {}
    local data = getData()
    if not data or type(data.Inventory) ~= "table" then return list end
    for _, entry in pairs(data.Inventory) do
        if type(entry) == "table" then
            local uid = entry.uid or entry.UID or entry.slimeUID
            if uid ~= nil then
                table.insert(list, tostring(uid))
            end
        end
    end
    return list
end

local function doSellAllSpam()
    ensureRemotes()
    if not SellRemote then
        addLog("ERROR: Sell Slime From Inventory remote missing")
        return 0
    end

    local uids = getInventoryUIDs()
    if #uids == 0 then
        addLog("Inventory empty — nothing to sell")
        return 0
    end

    addLog(string.format("Selling %d inventory items (spam)...", #uids))
    local deadline = os.clock() + 12
    local lastFire = 0
    local targets = {}
    for _, uid in ipairs(uids) do
        table.insert(targets, { uid = uid, done = false })
    end

    while os.clock() < deadline and running do
        local data = getData()
        local remaining = 0
        local stillHave = {}
        if data and type(data.Inventory) == "table" then
            for _, entry in pairs(data.Inventory) do
                if type(entry) == "table" then
                    local u = entry.uid or entry.UID or entry.slimeUID
                    if u then stillHave[tostring(u)] = true end
                end
            end
        end

        for _, t in ipairs(targets) do
            if not t.done then
                if not stillHave[t.uid] then
                    t.done = true
                else
                    remaining += 1
                end
            end
        end

        if remaining == 0 then break end

        if os.clock() - lastFire >= 0.05 then
            lastFire = os.clock()
            for _, t in ipairs(targets) do
                if not t.done then
                    pcall(function() SellRemote:FireServer(t.uid) end)
                end
            end
        end
        task.wait(0.03)
    end

    local sold = 0
    for _, t in ipairs(targets) do
        if t.done then sold += 1 end
    end
    addLog(string.format("Sold %d / %d", sold, #targets))
    return sold
end

-- ============================================================
-- MAIN CYCLE — highest → lowest, 100 per batch
-- ============================================================
local function resetCycleCounters()
    collectedThisCycle = 0
    currentRarityIndex = 1
    for _, r in ipairs(TARGET_RARITIES) do
        countsByRarity[r] = 0
    end
end

-- Run Place → Open → Pickup → Sell for whatever was collected this batch
local function runPostCollectPipeline()
    addLog(string.format(
        "Batch collected %d — Place → Open → Pickup → Sell",
        collectedThisCycle
    ))

    setPhase("Placing boxes")
    doPlaceBoxesOnly()
    task.wait(0.30)
    if not running then return end

    setPhase("Opening boxes")
    doOpenBoxesOnly()
    task.wait(0.80)
    if not running then return end

    setPhase("Picking up")
    doPickupAllSpam()
    task.wait(0.40)
    if not running then return end

    setPhase("Selling")
    doSellAllSpam()
    task.wait(0.30)
end

--[[
  One full pass = walk rarities from HIGHEST → LOWEST.
  For each rarity:
    - First scan: if ZERO of that type in world → skip entire batch
    - Else collect up to BATCH_SIZE (100) of THAT rarity only
    - If we got any boxes → Place+Open+Pickup+Sell, then next rarity batch
]]
local function runCycle()
    resetCycleCounters()

    -- Build the rarity list for this pass from the dropdown filter
    local rarityList = {}
    if selectedRarity == "All" then
        for _, r in ipairs(TARGET_RARITIES) do
            table.insert(rarityList, r)
        end
        addLog("=== NEW PASS — All rarities (highest→lowest) | 100/batch | carry 6 → base ===")
    else
        table.insert(rarityList, selectedRarity)
        addLog(string.format(
            "=== NEW PASS — only %s | 100/batch | carry 6 → base ===",
            selectedRarity
        ))
    end

    for rarityIndex = 1, #rarityList do
        if not running then return end

        currentRarityIndex = rarityIndex
        local rarity = rarityList[rarityIndex]
        collectedThisCycle = 0
        countsByRarity[rarity] = 0

        -- FIRST SCAN: if none of this rarity exist, skip whole batch
        if not hasLuckyBlockOfType(rarity) then
            addLog(string.format(
                "Batch %s: none in world on first scan → SKIP",
                rarity
            ))
            continue
        end

        addLog(string.format(
            "=== BATCH START: %s (target %d, carry %d) ===",
            rarity,
            BATCH_SIZE,
            CARRY_BEFORE_BASE
        ))
        setPhase(string.format("Batch %s 0/%d", rarity, BATCH_SIZE))

        local emptyStreak = 0
        local carryCount = 0  -- steals this trip before returning to base

        while running and collectedThisCycle < BATCH_SIZE do
            setPhase(string.format(
                "Batch %s %d/%d (carry %d/%d)",
                rarity,
                collectedThisCycle,
                BATCH_SIZE,
                carryCount,
                CARRY_BEFORE_BASE
            ))

            -- Mid-batch: if none left in world, end this batch
            if not hasLuckyBlockOfType(rarity) then
                emptyStreak += 1
                if emptyStreak >= 3 then
                    addLog(string.format(
                        "Batch %s: no more in world after %d — ending batch (%d collected)",
                        rarity,
                        emptyStreak,
                        collectedThisCycle
                    ))
                    break
                end
                task.wait(0.25)
                continue
            end
            emptyStreak = 0

            local result = stealOne(rarity)

            if result == "deposited" then
                -- Was holding → deposited; reset trip counter
                carryCount = 0
                addLog("Deposited held item at base")
                task.wait(0.15)
            elseif result == true then
                -- Successful steal — stay out, no base yet
                task.wait(0.20)
                countsByRarity[rarity] = countsByRarity[rarity] + 1
                collectedThisCycle += 1
                carryCount += 1

                ProgressLabel.Text = string.format(
                    "%d / %d | %s | trip %d/%d",
                    collectedThisCycle,
                    BATCH_SIZE,
                    rarity,
                    carryCount,
                    CARRY_BEFORE_BASE
                )
                addLog(string.format(
                    "Got %s [%d/%d] trip %d/%d",
                    rarity,
                    collectedThisCycle,
                    BATCH_SIZE,
                    carryCount,
                    CARRY_BEFORE_BASE
                ))

                -- After 6 steals → return to base, then continue
                if carryCount >= CARRY_BEFORE_BASE then
                    addLog(string.format(
                        "Carried %d — returning to base",
                        carryCount
                    ))
                    teleportToBase()
                    carryCount = 0
                    task.wait(0.25)
                end
            else
                -- Steal miss while boxes still exist — brief retry
                task.wait(0.15)
            end

            task.wait(0.08)
        end

        -- End of batch: if still carrying from a partial trip, deposit
        if carryCount > 0 then
            addLog(string.format(
                "Batch end with %d carried — returning to base",
                carryCount
            ))
            teleportToBase()
            carryCount = 0
            task.wait(0.25)
        end

        if not running then return end

        -- Only run pipeline if this batch collected something
        if collectedThisCycle > 0 then
            runPostCollectPipeline()
            if not running then return end
            addLog(string.format(
                "=== BATCH DONE: %s (%d boxes) ===",
                rarity,
                collectedThisCycle
            ))
        else
            addLog(string.format(
                "Batch %s collected 0 — skip pipeline, next rarity",
                rarity
            ))
        end

        task.wait(0.20)
    end

    setPhase("Pass complete")
    addLog("=== FULL PASS DONE — looping ===")
    task.wait(0.50)
end

-- ============================================================
-- CONTROL
-- ============================================================
ToggleBtn.MouseButton1Click:Connect(function()
    running = not running
    if running then
        ToggleBtn.Text = "STOP"
        ToggleBtn.TextColor3 = Color3.fromRGB(120, 255, 150)
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 55, 40)
        addLog("Automation STARTED")
        task.spawn(function()
            while running do
                local ok, err = xpcall(runCycle, debug.traceback)
                if not ok then
                    addLog("ERROR: " .. tostring(err):match("^[^\n]+"))
                    warn("[LuckyBoxCycle]", err)
                    task.wait(1)
                end
                if running then
                    task.wait(0.2)
                end
            end
            setPhase("Idle")
            addLog("Automation STOPPED")
        end)
    else
        ToggleBtn.Text = "START"
        ToggleBtn.TextColor3 = Color3.fromRGB(255, 120, 130)
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 35, 40)
        setPhase("Stopping...")
    end
end)

ensureRemotes()
addLog("Ready. Dropdown: All (highest→lowest) or pick a rarity")
addLog(string.format(
    "Batch %d/rarity | carry %d then base | first-scan empty = skip",
    BATCH_SIZE,
    CARRY_BEFORE_BASE
))
setPhase("Idle")
print("[LuckyBoxCycle] Loaded — rarity dropdown + carry 6 → base → Place+Open+Pickup+Sell → loop")