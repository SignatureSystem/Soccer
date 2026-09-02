--[[
  Lucky Box Cycle Auto
  ----------------------
  Flow (loops forever while ON):
    1. Collect 10 lucky boxes of EACH rarity (Common → Alternative)
       If none of the current rarity exist, auto-skip to the next
       available rarity that has boxes in the world.
    2. Place ALL lucky boxes into free slots (spam + teleport hop)
    3. Open ALL placed boxes (spam)
    4. Pick up ALL placed slimes (spam)
    5. Sell ALL inventory slimes (spam)
    6. Repeat

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
local BOXES_PER_RARITY = 10
-- 1 = on a single empty scan, immediately skip to the next rarity
-- that currently has boxes in the world.
local SKIP_AFTER_FAILS = 1

-- Full ordered list: Common → Alternative (all in-game lucky types)
local TARGET_RARITIES = {
    "Common",
    "Water",
    "Rare",
    "Volcanic",
    "Epic",
    "Ghost",
    "Legendary",
    "67",
    "Mythic",
    "Poison",
    "Secret",
    "Cosmic",
    "Soccer God",
    "Rainbow",
    "Exclusive",
    "Limited",
    "OG",
    "Champions",
    "Spain",
    "Icons",
    "Japan",
    "Alternative",
}

local TOTAL_TARGET = 100  -- hard cap (was 220 = 22 rarities * 10)

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
Main.Size = UDim2.new(0, 340, 0, 420)
Main.Position = UDim2.new(0, 20, 0.5, -210)
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

local ProgressLabel = Instance.new("TextLabel")
ProgressLabel.Size = UDim2.new(1, -24, 0, 40)
ProgressLabel.Position = UDim2.new(0, 12, 0, 78)
ProgressLabel.BackgroundTransparency = 1
ProgressLabel.Text = "0 / 80 boxes | Phase: Idle"
ProgressLabel.TextColor3 = Color3.fromRGB(150, 220, 170)
ProgressLabel.TextSize = 12
ProgressLabel.Font = Enum.Font.GothamBold
ProgressLabel.TextXAlignment = Enum.TextXAlignment.Left
ProgressLabel.TextYAlignment = Enum.TextYAlignment.Top
ProgressLabel.TextWrapped = true
ProgressLabel.Parent = Main

local LogFrame = Instance.new("ScrollingFrame")
LogFrame.Size = UDim2.new(1, -24, 0, 280)
LogFrame.Position = UDim2.new(0, 12, 0, 125)
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

-- Exact attemptSteal from AutoFarm
local function attemptSteal(prompt)
    if not prompt or not prompt.Parent then
        return false
    end

    pcall(function()
        prompt.HoldDuration = 0
    end)

    if typeof(fireproximityprompt) == "function" then
        local ok = pcall(function()
            fireproximityprompt(prompt)
        end)
        if ok then
            return true
        end
    end

    local ok = pcall(function()
        prompt:InputHoldBegin()
        prompt:InputHoldEnd()
    end)

    return ok
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
            and allowed[tostring(model.Name)] == true
        then
            return true
        end
    end
    return false
end

-- Find the next rarity (from startIndex onward, wrapping once) that still
-- needs boxes AND currently has at least one block in the world.
local function findNextAvailableRarity(startIndex)
    local n = #TARGET_RARITIES
    for offset = 0, n - 1 do
        local i = ((startIndex - 1 + offset) % n) + 1
        local rarity = TARGET_RARITIES[i]
        if countsByRarity[rarity] < BOXES_PER_RARITY
            and hasLuckyBlockOfType(rarity)
        then
            return i, rarity
        end
    end
    return nil, nil
end

-- Exact getTargetLuckyBlock from AutoFarm (filtered by rarity).
-- Prefers highest Value, then nearest. Prompt prefers steal/open/pick/take.
local function getTargetLuckyBlock(rarityName)
    local live = Workspace:FindFirstChild("Live")
    if not live then return nil end
    local slimes = live:FindFirstChild("Slimes")
    if not slimes then return nil end

    local allowed = LUCKY_BLOCK_MODEL_NAMES[rarityName]
    if not allowed then return nil end

    local root = getRoot()
    local best = nil
    local bestValue = -math.huge
    local bestDistance = math.huge

    for _, model in ipairs(slimes:GetChildren()) do
        if model:IsA("Model") and not model:GetAttribute("Carrying") then
            local modelName = tostring(model.Name)
            if allowed[modelName] == true then
                local primary =
                    model.PrimaryPart
                    or model:FindFirstChildWhichIsA("BasePart")

                if primary then
                    local value =
                        tonumber(model:GetAttribute("Value"))
                        or tonumber(model:GetAttribute("MoneyPerSecond"))
                        or 0

                    local distance =
                        root and (root.Position - primary.Position).Magnitude
                        or math.huge

                    local prompt = nil
                    for _, d in ipairs(model:GetDescendants()) do
                        if d:IsA("ProximityPrompt") and d.Enabled then
                            local at = string.lower(tostring(d.ActionText or ""))
                            if at:find("steal", 1, true)
                                or at:find("open", 1, true)
                                or at:find("pick", 1, true)
                                or at:find("take", 1, true)
                                or not prompt
                            then
                                prompt = d
                                if at:find("steal", 1, true)
                                    or at:find("open", 1, true)
                                    or at:find("pick", 1, true)
                                    or at:find("take", 1, true)
                                then
                                    break
                                end
                            end
                        end
                    end

                    if value > bestValue
                        or (value == bestValue and distance < bestDistance)
                    then
                        bestValue = value
                        bestDistance = distance
                        best = {
                            name = modelName,
                            type = rarityName,
                            value = value,
                            part = primary,
                            prompt = prompt,
                            model = model,
                        }
                    end
                end
            end
        end
    end

    return best
end

-- Confirm steal before counting / returning to base.
-- Success if holdingSlime, model removed, or Carrying attribute set.
local function waitForStealConfirm(block, timeout)
    timeout = tonumber(timeout) or 1.25
    local deadline = os.clock() + timeout

    while os.clock() < deadline do
        if LocalPlayer:GetAttribute("holdingSlime") == true then
            return true, "holdingSlime"
        end
        if block and block.model then
            if not block.model.Parent then
                return true, "modelRemoved"
            end
            if block.model:GetAttribute("Carrying") == true then
                return true, "carryingAttr"
            end
        end
        task.wait(0.05)
    end

    if LocalPlayer:GetAttribute("holdingSlime") == true then
        return true, "holdingSlime"
    end
    return false, "timeout"
end

--[[
  Steal flow:
    1) If already holding → deposit at base (not a new collect)
    2) Find target block of this rarity
    3) activateCloak
    4) Teleport UNDER the block (CFrame * (0, -1, 0))
    5) BodyVelocity float
    6) Force ALL prompts HoldDuration = 0
    7) Trigger proximity prompt IMMEDIATELY (no pre-wait)
    8) Wait 1 second (prompt must fire before leaving)
    9) CONFIRM steal (holdingSlime / model gone / Carrying)
   10) Only if confirmed → destroy BV, zero velocity, teleportToBase
   11) Wait until deposit finishes before returning "stolen"
]]
local function stealOne(rarityName)
    -- 1) already carrying → base only
    if LocalPlayer:GetAttribute("holdingSlime") == true then
        addLog("Already holding → returning to base")
        teleportToBase()
        local t = os.clock() + 1.5
        while LocalPlayer:GetAttribute("holdingSlime") and os.clock() < t do
            task.wait(0.1)
        end
        return "deposited"
    end

    -- 2) find target
    local block = getTargetLuckyBlock(rarityName)
    if not block then
        return false
    end

    addLog(string.format("Found %s — stealing...", tostring(block.name)))

    -- 3) cloak
    pcall(function()
        activateCloak()
    end)
    task.wait(0.2)

    -- 4) teleport under target
    local root = getRoot()
    if not root or not block.part or not block.part.Parent then
        return false
    end

    root.CFrame = block.part.CFrame * CFrame.new(0, -1, 0)
    root.AssemblyLinearVelocity = Vector3.zero

    -- 5) BodyVelocity float
    local bv = Instance.new("BodyVelocity")
    bv.Name = "LuckyFloat"
    bv.Velocity = Vector3.zero
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.P = 1250
    bv.Parent = root

    task.wait(0.05)

    -- 6) force zero hold on every prompt
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v.ClassName == "ProximityPrompt" then
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
        if bv and bv.Parent then bv:Destroy() end
        addLog("Prompt missing — abort")
        return false
    end

    prompt.HoldDuration = 0

    -- 7) trigger proximity prompt IMMEDIATELY (before any long wait / base return)
    addLog("Triggering proximity prompt...")
    local fired = attemptSteal(prompt)
    if not fired then
        -- retry once while still under the block
        task.wait(0.05)
        if prompt and prompt.Parent then
            prompt.HoldDuration = 0
            fired = attemptSteal(prompt)
        end
    end

    if not fired then
        if bv and bv.Parent then bv:Destroy() end
        addLog("Prompt fire failed — abort (not returning to base as stolen)")
        return false
    end

    -- 8) wait 1 second AFTER prompt was triggered (still under block)
    addLog("Prompt fired — waiting 1s before base...")
    task.wait(1)

    -- 9) CONFIRM before leaving
    local confirmed, reason = waitForStealConfirm(block, 0.75)

    if bv and bv.Parent then
        bv:Destroy()
    end
    root = getRoot()
    if root then
        root.AssemblyLinearVelocity = Vector3.zero
    end

    if not confirmed then
        -- Still held after the 1s wait counts as success too
        if LocalPlayer:GetAttribute("holdingSlime") == true then
            confirmed = true
            reason = "holdingSlime-after-wait"
        end
    end

    if not confirmed then
        addLog(string.format(
            "Steal NOT confirmed (%s) — will skip rarity",
            tostring(reason)
        ))
        return false
    end

    addLog(string.format("Steal confirmed (%s) → base", tostring(reason)))

    -- 10) return to base ONLY after prompt was triggered + wait + confirm
    teleportToBase()

    -- 11) wait for deposit
    local t = os.clock() + 2.0
    while LocalPlayer:GetAttribute("holdingSlime") == true and os.clock() < t do
        task.wait(0.08)
    end

    return "stolen"
end

-- Always leave the current rarity index (wraps). Prefer a rarity that
-- still needs boxes AND has one in the world; otherwise just +1.
local function advanceRarityIndex(fromIndex)
    local nextIdx, nextName = findNextAvailableRarity(fromIndex + 1)
    if nextIdx and nextName then
        return nextIdx, nextName, true
    end
    local i = fromIndex + 1
    if i > #TARGET_RARITIES then
        i = 1
    end
    return i, TARGET_RARITIES[i], false
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
-- MAIN CYCLE
-- ============================================================
local function resetCycleCounters()
    collectedThisCycle = 0
    currentRarityIndex = 1
    for _, r in ipairs(TARGET_RARITIES) do
        countsByRarity[r] = 0
    end
end

local function runCycle()
    resetCycleCounters()
    setPhase("Collecting")
    addLog(string.format(
        "=== NEW CYCLE — up to %d boxes (10 each, Common→Alternative) ===",
        TOTAL_TARGET
    ))

    local idleRounds = 0
    local fullRotationsWithoutSteal = 0
    local indexAtRotationStart = currentRarityIndex

    -- Phase 1: Collect 10 of each rarity.
    -- ONE empty scan → leave that rarity immediately (never stick on Japan/etc).
    while running and collectedThisCycle < TOTAL_TARGET do
        local rarity = TARGET_RARITIES[currentRarityIndex]
        if not rarity then break end

        -- Already finished this rarity → advance
        if countsByRarity[rarity] >= BOXES_PER_RARITY then
            local nextIdx, nextName = advanceRarityIndex(currentRarityIndex)
            currentRarityIndex = nextIdx
            -- Detect full pass of completed rarities
            local allDone = true
            for _, r in ipairs(TARGET_RARITIES) do
                if countsByRarity[r] < BOXES_PER_RARITY then
                    allDone = false
                    break
                end
            end
            if allDone then
                addLog("All rarities hit 10/10 — collect phase done")
                break
            end
            rarity = TARGET_RARITIES[currentRarityIndex]
            addLog(string.format("Quota filled → next: %s", tostring(rarity)))
        end

        setPhase(string.format(
            "Collect %s (%d/%d)",
            rarity,
            countsByRarity[rarity],
            BOXES_PER_RARITY
        ))

        -- Pre-check: if this rarity has zero boxes in the world right now,
        -- skip on this single scan without even attempting a steal.
        if not hasLuckyBlockOfType(rarity) then
            local nextIdx, nextName, foundLive = advanceRarityIndex(currentRarityIndex)
            addLog(string.format(
                "No %s in world → skip to %s%s",
                rarity,
                tostring(nextName),
                foundLive and " (live)" or ""
            ))
            currentRarityIndex = nextIdx

            if nextIdx == indexAtRotationStart then
                fullRotationsWithoutSteal += 1
                idleRounds += 1
                addLog(string.format(
                    "Full rarity rotation with nothing live (idle %d)",
                    idleRounds
                ))
                task.wait(0.8)
                if idleRounds >= 5 and collectedThisCycle > 0 then
                    addLog(string.format(
                        "Idle with %d boxes — proceeding to Place+Open",
                        collectedThisCycle
                    ))
                    break
                end
            end
            task.wait(0.05)
            continue
        end

        local result = stealOne(rarity)

        if result == "stolen" then
            idleRounds = 0
            fullRotationsWithoutSteal = 0
            indexAtRotationStart = currentRarityIndex
            task.wait(0.35)
            countsByRarity[rarity] = countsByRarity[rarity] + 1
            collectedThisCycle += 1
            ProgressLabel.Text = string.format(
                "%d / %d boxes | %s: %d/%d",
                collectedThisCycle,
                TOTAL_TARGET,
                rarity,
                countsByRarity[rarity],
                BOXES_PER_RARITY
            )
            addLog(string.format(
                "Got %s [%d/%d]  total %d/%d",
                rarity,
                countsByRarity[rarity],
                BOXES_PER_RARITY,
                collectedThisCycle,
                TOTAL_TARGET
            ))
        elseif result == "deposited" then
            addLog("Deposited held slime — not counted")
            task.wait(0.15)
        else
            -- Steal attempted but failed (prompt gone, etc.) → leave this rarity now.
            local nextIdx, nextName, foundLive = advanceRarityIndex(currentRarityIndex)
            addLog(string.format(
                "Missed %s → skip to %s%s",
                rarity,
                tostring(nextName),
                foundLive and " (live)" or ""
            ))
            currentRarityIndex = nextIdx
        end

        task.wait(0.08)
    end

    if not running then return end

    if collectedThisCycle == 0 then
        addLog("Collected 0 boxes this cycle — waiting before retry...")
        task.wait(2)
        return
    end

    addLog(string.format("Collected %d boxes — starting Place + Open", collectedThisCycle))

    -- Phase 2: Place
    setPhase("Placing boxes")
    local placed = doPlaceBoxesOnly()
    task.wait(0.30)

    if not running then return end

    -- Phase 3: Open
    setPhase("Opening boxes")
    local opened = doOpenBoxesOnly()
    task.wait(0.80) -- let opens resolve into slimes

    if not running then return end

    -- Phase 4: Pickup all
    setPhase("Picking up")
    doPickupAllSpam()
    task.wait(0.40)

    if not running then return end

    -- Phase 5: Sell all
    setPhase("Selling")
    doSellAllSpam()
    task.wait(0.30)

    if not running then return end

    setPhase("Cycle complete")
    addLog("=== CYCLE COMPLETE — restarting ===")
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
addLog("Ready. All rarities: Common → Alternative")
addLog(string.format(
    "Up to %d boxes (%d per rarity × %d types) | auto-skip if none available",
    TOTAL_TARGET,
    BOXES_PER_RARITY,
    #TARGET_RARITIES
))
setPhase("Idle")
print("[LuckyBoxCycle] Loaded — all rarities (10 each) → auto-skip → Place+Open → Pickup → Sell → loop")