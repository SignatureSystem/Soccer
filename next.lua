--[[
  NextGen Stealer + Event Mutation Farmer
  ----------------------------------------
  Loop:
    1) Always scan for active events: Cursed, Joker, Sky, Huge
    2) If any is active (Cursed / Joker / Sky / Huge ONLY):
         - Place ALL lucky boxes from inventory into free slots
         - Open those placed boxes + any existing lucky boxes already on plot
         - NEVER open outside those events
         - KEEP ONLY: Cursed, Stellar, Divine, Fallen, Joker, Huge
         - PICKUP + SELL ALL other junk from EVERY plot slot AND entire inventory
         - Hop server
    3) If no target event:
         - Steal Next Generation Lucky Boxes (solidify + stand on top + prompt)
         - If none after empty scans → hop to low-pop public server
    Keep ONLY Cursed / Stellar / Divine / Fallen / Joker / Huge — sell all other junk everywhere.
]]

local Players           = game:GetService("Players")
local TeleportService   = game:GetService("TeleportService")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

--------------------------------------------------
-- CONFIG
--------------------------------------------------
local TARGET = {
    Name = "Next Generation Lucky Block",
    Rarity = "Next Generation",
    ID = "2146",
}

local LUCKY_BLOCK_MODEL_NAMES = {
    ["Next Generation"] = {
        ["Next Generation Lucky Block"] = true,
        ["NextGen Lucky Block"] = true,
        ["Next Gen Lucky Block"] = true,
    },
}

-- Events that trigger place → open → selective pickup → sell → hop
local EVENT_ATTRIBUTES = {
    "event_Cursed",
    "event_Joker",
    "event_Sky",
    "event_Huge",
}

-- Mutations that must NEVER be sold / must be kept
-- Also always keep is_huge items (Huge trait), checked separately.
local KEEP_MUTATIONS = {
    cursed = true,
    stellar = true,
    divine = true,
    fallen = true,
    joker = true,
    huge = true, -- mutation label fallback if game tags mutation as Huge
}

local STAND_OFFSET = 3
local EMPTY_SCANS_BEFORE_HOP = 3
local SCAN_EMPTY_WAIT = 0.15
local HOP_COOLDOWN = 2.0
local MAX_SERVER_PLAYERS = math.huge -- no player limit; hop to any public server

--------------------------------------------------
-- STATE
--------------------------------------------------
local enabled = true
local busy = false
local hopping = false
local totalStolen = 0
local emptyScans = 0
local lastHopAt = 0
local sessionStart = os.clock()
local statusLbl, countLbl, timeLbl, eventLbl

--------------------------------------------------
-- Instant prompts
--------------------------------------------------
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

--------------------------------------------------
-- Basic helpers
--------------------------------------------------
local function root()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function fmtTime(sec)
    sec = math.max(0, math.floor(sec))
    return string.format("%02d:%02d", math.floor(sec / 60), sec % 60)
end

local function setStatus(text)
    if statusLbl then
        statusLbl.Text = tostring(text)
    end
end

--------------------------------------------------
-- Event detection
--------------------------------------------------
local function getActiveTargetEvents()
    local active = {}
    for _, attr in ipairs(EVENT_ATTRIBUTES) do
        local v = Workspace:GetAttribute(attr)
        if v ~= nil and v ~= false then
            -- attr is "event_Cursed" → "Cursed"
            local name = attr:gsub("^event_", "")
            table.insert(active, name)
        end
    end
    return active
end

local function hasTargetEvent()
    return #getActiveTargetEvents() > 0
end

--------------------------------------------------
-- NextGen detection
--------------------------------------------------
local function isNextGenBlock(m)
    if not m or not m:IsA("Model") then
        return false
    end

    local modelName = tostring(m.Name or "")
    local lowerName = modelName:lower()
    if lowerName:find("next generation lucky block", 1, true)
        or lowerName:find("next generation", 1, true)
        or lowerName:find("nextgen", 1, true)
        or lowerName:find("next gen", 1, true)
    then
        return true
    end

    local rarity =
        m:GetAttribute("Rarity")
        or m:GetAttribute("_Rarity")
        or m:GetAttribute("rarity")
    if rarity then
        local r = tostring(rarity):lower()
        if r == "next generation" or r == "nextgen" or r == "next gen" then
            return true
        end
    end

    local blockName =
        m:GetAttribute("LuckyBlockName")
        or m:GetAttribute("BlockName")
        or m:GetAttribute("DisplayName")
        or m:GetAttribute("Name")
    if blockName then
        local bn = tostring(blockName):lower()
        if bn:find("next generation", 1, true)
            or bn:find("nextgen", 1, true)
            or bn:find("next gen", 1, true)
        then
            return true
        end
    end

    local id =
        m:GetAttribute("ID")
        or m:GetAttribute("Id")
        or m:GetAttribute("id")
        or m:GetAttribute("_RegisteredID")
        or m:GetAttribute("RegisteredID")
        or m:GetAttribute("LuckyBlockID")
    if id and tostring(id) == TARGET.ID then
        return true
    end

    for _, childName in ipairs({
        "ID", "Id", "RegisteredID", "_RegisteredID",
        "Rarity", "_Rarity", "LuckyBlockName", "BlockName",
    }) do
        local obj = m:FindFirstChild(childName)
        if obj and obj:IsA("ValueBase") then
            local value = tostring(obj.Value)
            local vl = value:lower()
            if value == TARGET.ID
                or vl == "next generation"
                or vl == "nextgen"
                or vl:find("next generation", 1, true)
            then
                return true
            end
        end
    end

    local allowed = LUCKY_BLOCK_MODEL_NAMES["Next Generation"]
    if allowed and allowed[modelName] then
        return true
    end

    return false
end

local function countNextGenBlocks()
    local live = Workspace:FindFirstChild("Live")
    local folder = live and live:FindFirstChild("Slimes")
    if not folder then
        return 0
    end
    local n = 0
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model")
            and not m:GetAttribute("Carrying")
            and isNextGenBlock(m)
        then
            n += 1
        end
    end
    return n
end

local function getTargetLuckyBlock()
    local live = Workspace:FindFirstChild("Live")
    local slimes = live and live:FindFirstChild("Slimes")
    if not slimes then
        return nil
    end

    local r = root()
    local best, bestDist = nil, math.huge

    for _, model in ipairs(slimes:GetChildren()) do
        if model:IsA("Model")
            and not model:GetAttribute("Carrying")
            and isNextGenBlock(model)
        then
            local primary =
                model.PrimaryPart
                or model:FindFirstChildWhichIsA("BasePart")
            if primary then
                local dist = r and (r.Position - primary.Position).Magnitude or 0
                if dist < bestDist then
                    bestDist = dist
                    local prompt
                    for _, d in ipairs(model:GetDescendants()) do
                        if d:IsA("ProximityPrompt") and d.Enabled then
                            local at = tostring(d.ActionText or ""):lower()
                            prompt = d
                            if at:find("steal", 1, true)
                                or at:find("pick", 1, true)
                                or at:find("take", 1, true)
                            then
                                break
                            end
                        end
                    end
                    best = { model = model, part = primary, prompt = prompt }
                end
            end
        end
    end
    return best
end

--------------------------------------------------
-- Cloak / base
--------------------------------------------------
local function activateCloak()
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then
        return
    end

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
        if tool then
            break
        end
    end
    if not tool then
        return
    end

    if tool.Parent ~= char then
        pcall(function()
            hum:UnequipTools()
        end)
        task.wait(0.05)
        pcall(function()
            hum:EquipTool(tool)
        end)
        if tool.Parent ~= char then
            pcall(function()
                tool.Parent = char
            end)
        end
        task.wait(0.12)
    end

    local ca = tool:FindFirstChild("CanActivate")
    if ca and ca:IsA("BoolValue") then
        ca.Value = true
    end
    pcall(function()
        tool:Activate()
    end)

    for _, p in ipairs(char:GetDescendants()) do
        if (p:IsA("BasePart") and p.Name ~= "HumanoidRootPart")
            or p:IsA("Decal")
            or p:IsA("Texture")
        then
            p.Transparency = 1
        end
    end
end

local function toBase()
    local r = root()
    if not r then
        return false
    end

    local tp =
        _G.MyPlot
        and _G.MyPlot.Base
        and _G.MyPlot.Base.Teleport
    if tp and tp.WorldCFrame then
        r.CFrame = tp.WorldCFrame + Vector3.new(0, 3, 0)
        r.AssemblyLinearVelocity = Vector3.zero
        return true
    end

    local plots = Workspace:FindFirstChild("Plots")
    if not plots then
        return false
    end

    for _, plot in ipairs(plots:GetChildren()) do
        local o = plot:FindFirstChild("owner")
        if o and tostring(o.Value) == LP.Name then
            local b = plot:FindFirstChild("Base")
            local a = b and b:FindFirstChild("Teleport")
            if a and a:IsA("Attachment") and a.WorldCFrame then
                r.CFrame = a.WorldCFrame + Vector3.new(0, 3, 0)
                r.AssemblyLinearVelocity = Vector3.zero
                return true
            end
        end
    end
    return false
end

--------------------------------------------------
-- Steal helpers
--------------------------------------------------
local function makeLuckyBoxSolid(block)
    if not block then
        return
    end
    local parts = {}
    if block.model and block.model.Parent then
        for _, d in ipairs(block.model:GetDescendants()) do
            if d:IsA("BasePart") then
                table.insert(parts, d)
            end
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
            if part.Massless ~= nil then
                part.Massless = true
            end
        end)
    end
end

local function standOnBoxCFrame(part)
    if not part or not part.Parent then
        return nil
    end
    local topY = part.Size.Y * 0.5 + STAND_OFFSET
    return part.CFrame * CFrame.new(0, topY, 0)
end

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
        task.wait(0.05)
        prompt:InputHoldEnd()
    end)
    return ok
end

local function stealOne()
    if LP:GetAttribute("holdingSlime") == true then
        toBase()
        local t = os.clock() + 1.2
        while LP:GetAttribute("holdingSlime") and os.clock() < t do
            task.wait(0.08)
        end
        return "deposited"
    end

    local block = getTargetLuckyBlock()
    if not block then
        return false
    end

    makeLuckyBoxSolid(block)
    pcall(activateCloak)
    task.wait(0.15)

    local r = root()
    local hum = getHumanoid()
    if not r or not block.part or not block.part.Parent then
        return false
    end

    makeLuckyBoxSolid(block)

    for _, name in ipairs({ "LuckyFloat", "LuckyHoverPos", "LuckyHoverGyro" }) do
        local old = r:FindFirstChild(name)
        if old then
            old:Destroy()
        end
    end

    local bv = Instance.new("BodyVelocity")
    bv.Name = "LuckyFloat"
    bv.Velocity = Vector3.zero
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.P = 1250
    bv.Parent = r

    local bp = Instance.new("BodyPosition")
    bp.Name = "LuckyHoverPos"
    bp.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bp.P = 20000
    bp.D = 1500
    bp.Parent = r

    local bg = Instance.new("BodyGyro")
    bg.Name = "LuckyHoverGyro"
    bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    bg.P = 3000
    bg.D = 500
    bg.Parent = r

    if hum then
        pcall(function()
            hum.PlatformStand = true
            hum.AutoRotate = false
        end)
    end

    local hovering = true
    local hoverConn

    local function applyHover()
        if not hovering then
            return false
        end
        local rr = root()
        if not rr or not block.part or not block.part.Parent then
            return false
        end
        local cf = standOnBoxCFrame(block.part)
        if not cf then
            return false
        end
        rr.CFrame = cf
        rr.AssemblyLinearVelocity = Vector3.zero
        rr.AssemblyAngularVelocity = Vector3.zero
        if bp and bp.Parent then
            bp.Position = cf.Position
        end
        if bg and bg.Parent then
            bg.CFrame = CFrame.new(cf.Position)
        end
        local minY = block.part.Position.Y + (block.part.Size.Y * 0.5) + 1.5
        if rr.Position.Y < minY then
            local cf2 = standOnBoxCFrame(block.part)
            if cf2 then
                rr.CFrame = cf2
            else
                rr.CFrame = CFrame.new(rr.Position.X, minY, rr.Position.Z)
            end
            rr.AssemblyLinearVelocity = Vector3.zero
        end
        makeLuckyBoxSolid(block)
        return true
    end

    hoverConn = RunService.Heartbeat:Connect(function()
        if hovering then
            applyHover()
        end
    end)

    local function cleanupHover()
        hovering = false
        if hoverConn then
            hoverConn:Disconnect()
            hoverConn = nil
        end
        for _, name in ipairs({ "LuckyFloat", "LuckyHoverPos", "LuckyHoverGyro" }) do
            local rr = root()
            local obj = rr and rr:FindFirstChild(name)
            if obj then
                obj:Destroy()
            end
        end
        local rr = root()
        if rr then
            rr.AssemblyLinearVelocity = Vector3.zero
            rr.AssemblyAngularVelocity = Vector3.zero
        end
        if hum then
            pcall(function()
                hum.PlatformStand = false
                hum.AutoRotate = true
            end)
        end
    end

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

    local stolen = false
    for _ = 1, 10 do
        if not applyHover() then
            break
        end
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
        if LP:GetAttribute("holdingSlime") == true then
            stolen = true
            break
        end
        if block.model
            and (not block.model.Parent or block.model:GetAttribute("Carrying") == true)
        then
            stolen = true
            break
        end
        task.wait(0.08)
    end

    for _ = 1, 5 do
        applyHover()
        task.wait(0.05)
    end

    if LP:GetAttribute("holdingSlime") == true then
        stolen = true
    end

    cleanupHover()
    return stolen == true
end

--------------------------------------------------
-- Data / plot / remotes (from cycle script)
--------------------------------------------------
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
        local ok, data = pcall(function()
            return lib.Data:Get()
        end)
        if ok and data then
            return data
        end
    end

    local shared = ReplicatedStorage:FindFirstChild("SharedModules")
    local network = shared and shared:FindFirstChild("Network")
    local remotes = network and network:FindFirstChild("Remotes")
    local dataGet = remotes and remotes:FindFirstChild("Data: Get")
    if dataGet and dataGet:IsA("RemoteFunction") then
        local ok, data = pcall(function()
            return dataGet:InvokeServer()
        end)
        if ok and data then
            return data
        end
    end

    local broad = ReplicatedStorage:FindFirstChild("Data: Get", true)
    if broad and broad:IsA("RemoteFunction") then
        local ok, data = pcall(function()
            return broad:InvokeServer()
        end)
        if ok and data then
            return data
        end
    end
    return nil
end

local function getMyPlot()
    if _G.MyPlot and _G.MyPlot.Parent then
        return _G.MyPlot
    end
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then
        return nil
    end
    for _, plot in ipairs(plots:GetChildren()) do
        local owner = plot:FindFirstChild("owner")
        if owner and tostring(owner.Value) == LP.Name then
            return plot
        end
    end
    return nil
end

local function getPlayerSlimesFolder()
    local live = Workspace:FindFirstChild("Live")
    local playerSlimes = live and live:FindFirstChild("PlayerSlimes")
    return playerSlimes and playerSlimes:FindFirstChild(LP.Name)
end

local function getBaseLevel(data)
    data = data or getData()
    if data and type(data.BaseLevel) == "number" then
        return data.BaseLevel
    end
    return tonumber(LP:GetAttribute("BaseLevel")) or 0
end

local function isUnlocked(slotName, baseLevel)
    local n = tonumber(slotName)
    if not n then
        return true
    end
    return n <= 10 or (n - 10) <= (tonumber(baseLevel) or 0)
end

local function isOccupied(slotName, plotSlimes, playerSlimesFolder, stand)
    slotName = tostring(slotName)
    if type(plotSlimes) == "table" then
        if plotSlimes[slotName] then
            return true
        end
        local n = tonumber(slotName)
        if n and plotSlimes[n] then
            return true
        end
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
    if not plot then
        return free
    end
    local stands = plot:FindFirstChild("Stands")
    if not stands then
        return free
    end
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
    table.sort(free, function(a, b)
        return a.num < b.num
    end)
    return free
end

--------------------------------------------------
-- Mutation helpers — NEVER sell keep-list
--------------------------------------------------
local function normalizeMutation(value)
    if value == nil then
        return nil
    end
    local s = tostring(value):lower()
    s = s:gsub("^event_", "")
    s = s:gsub("%s+", "")
    s = s:gsub("[^%w]", "") -- strip punctuation
    if s == "" or s == "none" or s == "nil" or s == "null" then
        return nil
    end
    return s
end

local function mutationIsKeep(mut)
    local n = normalizeMutation(mut)
    return n ~= nil and KEEP_MUTATIONS[n] == true
end

-- Collect mutation strings from a PlotSlimes entry / tool / attributes / live model
local function collectMutationsFromEntry(entry, tool, slotName)
    local found = {}

    local function add(v)
        local n = normalizeMutation(v)
        if n then
            found[n] = true
        end
    end

    if type(entry) == "table" then
        add(entry.mutation)
        add(entry.Mutation)
        add(entry.mutationName)
        add(entry.MutationName)
        add(entry.mut)
        add(entry.Mut)

        local eventMutations = entry.event_mutations or entry.EventMutations or entry.eventMutations
        if type(eventMutations) == "table" then
            for k, v in pairs(eventMutations) do
                if type(k) == "string" and (v == true or v == 1 or type(v) == "number") then
                    add(k)
                elseif type(v) == "string" then
                    add(v)
                elseif type(k) == "string" and type(v) ~= "table" then
                    add(k)
                end
            end
        elseif eventMutations ~= nil then
            add(eventMutations)
        end
    end

    if tool then
        add(tool:GetAttribute("mutation"))
        add(tool:GetAttribute("Mutation"))
        add(tool:GetAttribute("event_mutation"))
        add(tool:GetAttribute("EventMutation"))
        add(tool:GetAttribute("eventMutation"))
    end

    -- Live placed model attributes (often more up-to-date right after open)
    if slotName ~= nil then
        local folder = getPlayerSlimesFolder()
        local model = folder and folder:FindFirstChild(tostring(slotName))
        if model then
            add(model:GetAttribute("mutation"))
            add(model:GetAttribute("Mutation"))
            add(model:GetAttribute("event_mutation"))
            add(model:GetAttribute("EventMutation"))
            add(model:GetAttribute("eventMutation"))
            add(model:GetAttribute("MutationName"))
            -- is_huge on live model
            if model:GetAttribute("is_huge") == true
                or model:GetAttribute("isHuge") == true
                or model:GetAttribute("slimeHuge") == true
            then
                found["huge"] = true
            end
            for _, child in ipairs(model:GetDescendants()) do
                if child:IsA("StringValue") or child:IsA("BoolValue") then
                    local cn = child.Name:lower()
                    if cn:find("mut", 1, true) or cn:find("event", 1, true) then
                        if child:IsA("StringValue") then
                            add(child.Value)
                        elseif child.Value == true then
                            add(child.Name)
                        end
                    end
                    if cn:find("huge", 1, true) and child:IsA("BoolValue") and child.Value == true then
                        found["huge"] = true
                    end
                end
            end
        end
    end

    return found
end

local function entryIsHuge(entry, tool)
    if type(entry) == "table" then
        if entry.is_huge == true or entry.isHuge == true or entry.IsHuge == true then
            return true
        end
        -- Some builds store huge as string flags
        local flag = entry.is_huge or entry.isHuge or entry.huge or entry.Huge
        if flag == true or tostring(flag):lower() == "true" or tostring(flag) == "1" then
            return true
        end
    end
    if tool then
        if tool:GetAttribute("is_huge") == true
            or tool:GetAttribute("slimeHuge") == true
            or tool:GetAttribute("IsHuge") == true
        then
            return true
        end
    end
    return false
end

-- Keep ONLY: Cursed / Stellar / Divine / Fallen / Joker / Huge
-- Everything else from opened boxes is junk → pickup + sell.
local function entryHasKeepMutation(entry, tool, slotName)
    if entryIsHuge(entry, tool) then
        return true, "huge"
    end

    local found = collectMutationsFromEntry(entry, tool, slotName)
    for name in pairs(found) do
        if KEEP_MUTATIONS[name] then
            return true, name
        end
        -- fuzzy: "cursedmutation", "eventcursed", etc.
        for keepName in pairs(KEEP_MUTATIONS) do
            if name:find(keepName, 1, true) then
                return true, keepName
            end
        end
    end
    return false, nil
end

local function isStillLuckyBlockEntry(entry)
    if type(entry) ~= "table" then
        return false
    end
    if entry.production_is_lucky_block == true then
        return true
    end
    local typ = string.lower(tostring(entry.Type or entry.type or ""))
    local nm = string.lower(tostring(entry.Name or entry.name or entry.id or ""))
    if typ:find("lucky", 1, true) or nm:find("lucky block", 1, true) then
        return true
    end
    return false
end

-- Existing unopened lucky boxes already on the player's plot slots
local function getExistingLuckyBoxSlots()
    local data = getData()
    local plotSlimes = (data and data.PlotSlimes) or {}
    local list, seen = {}, {}

    local function isLuckyEntry(entry)
        if type(entry) ~= "table" then
            return false
        end
        if entry.production_is_lucky_block == true then
            return true
        end
        local typ = string.lower(tostring(entry.Type or entry.type or ""))
        local nm = string.lower(tostring(entry.Name or entry.name or ""))
        local id = string.lower(tostring(entry.id or entry.Id or entry.slimeId or entry.slimeID or ""))
        if typ:find("lucky", 1, true)
            or nm:find("lucky", 1, true)
            or id:find("lucky", 1, true)
        then
            return true
        end
        return false
    end

    for slotKey, entry in pairs(plotSlimes) do
        if isLuckyEntry(entry) then
            local name = tostring(slotKey)
            if name ~= "" and not seen[name] then
                seen[name] = true
                table.insert(list, name)
            end
        end
    end

    table.sort(list, function(a, b)
        local an, bn = tonumber(a), tonumber(b)
        if an and bn then return an < bn end
        if an then return true end
        if bn then return false end
        return a < b
    end)
    return list
end

local function mergeSlotLists(...)
    local out, seen = {}, {}
    for i = 1, select("#", ...) do
        local list = select(i, ...)
        if type(list) == "table" then
            for _, name in ipairs(list) do
                name = tostring(name)
                if name ~= "" and not seen[name] then
                    seen[name] = true
                    table.insert(out, name)
                end
            end
        end
    end
    return out
end

--------------------------------------------------
-- Inventory lucky boxes
--------------------------------------------------
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
        if uid == nil then
            return
        end
        local key = tostring(uid)
        if seen[key] then
            return
        end

        local isLucky = false
        if tool then
            local n = string.lower(tostring(tool.Name))
            if n:find("lucky", 1, true) or n:find("box", 1, true) then
                isLucky = true
            end
            local t = tool:GetAttribute("Type") or tool:GetAttribute("type")
            if t and tostring(t):lower():find("lucky") then
                isLucky = true
            end
        end

        local entry = invByUID[key]
        if entry then
            local id = string.lower(tostring(entry.id or entry.Id or ""))
            local nm = string.lower(tostring(entry.Name or entry.name or ""))
            local typ = string.lower(tostring(entry.Type or entry.type or ""))
            if id:find("lucky")
                or nm:find("lucky")
                or typ:find("lucky")
                or entry.production_is_lucky_block == true
            then
                isLucky = true
            end
        end

        if isLucky then
            seen[key] = true
            table.insert(list, { uid = uid, tool = tool })
        end
    end

    local function scan(bag)
        if not bag then
            return
        end
        for _, item in ipairs(bag:GetChildren()) do
            if item:IsA("Tool") then
                tryAdd(item:GetAttribute("slimeUID"), item)
            end
        end
    end

    scan(LP:FindFirstChild("Backpack"))
    scan(LP.Character)

    for key, entry in pairs(invByUID) do
        if not seen[key] then
            tryAdd(entry.uid, nil)
        end
    end

    return list
end

--------------------------------------------------
-- Place all lucky boxes → returns list of slot names we targeted
--------------------------------------------------
local function doPlaceAllLuckyBoxes()
    ensureRemotes()
    if not PlaceRemote then
        setStatus("ERROR: Place Slime remote missing")
        return {}
    end

    local boxes = getAllLuckyBlockUIDs()
    local slots = getAvailableSlots()
    if #boxes == 0 or #slots == 0 then
        setStatus(string.format("Place: %d boxes / %d free slots", #boxes, #slots))
        return {}
    end

    local function findPlacedByUID(data, uid)
        if not data or type(data.PlotSlimes) ~= "table" or uid == nil then
            return nil
        end
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
        if not stand then
            return nil
        end
        local part =
            stand.PrimaryPart
            or stand:FindFirstChild("Main")
            or stand:FindFirstChildWhichIsA("BasePart", true)
        if part and part:IsA("BasePart") then
            return part.CFrame
        end
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

    setStatus(string.format("Placing %d lucky boxes...", total))
    local deadline = os.clock() + 14
    local hop = 1

    while os.clock() < deadline and enabled and not hopping do
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
        if #remaining == 0 then
            break
        end

        if hop > #remaining then
            hop = 1
        end
        local current = remaining[hop]
        hop += 1

        if current and current.stand then
            local r = root()
            local cf = getStandCF(current.stand)
            if r and cf then
                r.CFrame = cf * CFrame.new(0, 3, 3)
                r.AssemblyLinearVelocity = Vector3.zero
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

    -- Prefer actual placed slots from data; fallback to intended targets
    local placedSlots, seen = {}, {}
    local data = getData()
    for _, t in ipairs(targets) do
        local slot = findPlacedByUID(data, t.uid) or (t.done and t.slot) or nil
        if slot and not seen[slot] then
            seen[slot] = true
            table.insert(placedSlots, slot)
        end
    end

    -- If still empty but we fired, use intended slot list
    if #placedSlots == 0 then
        for _, t in ipairs(targets) do
            if not seen[t.slot] then
                seen[t.slot] = true
                table.insert(placedSlots, t.slot)
            end
        end
    end

    setStatus(string.format("Placed %d boxes", #placedSlots))
    return placedSlots
end

--------------------------------------------------
-- Open only the slots we placed
--------------------------------------------------
local function doOpenSlots(slotNames)
    ensureRemotes()
    if not OpenRemote then
        setStatus("ERROR: Open Lucky Block remote missing")
        return 0
    end
    if type(slotNames) ~= "table" or #slotNames == 0 then
        setStatus("Open: no target slots")
        return 0
    end

    -- SAFETY: never open unless a target event is active
    if not hasTargetEvent() then
        setStatus("Open blocked — no Cursed/Joker/Sky/Huge event")
        return 0
    end

    setStatus(string.format("Opening %d slots (event active)...", #slotNames))
    for _ = 1, 12 do
        if not enabled or hopping then
            break
        end
        if not hasTargetEvent() then
            setStatus("Event ended mid-open — stop opening")
            break
        end
        for _, name in ipairs(slotNames) do
            pcall(function()
                OpenRemote:FireServer(tostring(name))
            end)
        end
        task.wait(0.05)
    end
    task.wait(0.6)
    return #slotNames
end

--------------------------------------------------
-- Pickup ONLY from given slots, skipping keep-mutations
-- Returns UIDs that were picked into inventory and are safe to sell
--------------------------------------------------
local function doPickupFromSlotsExceptKeep(slotNames)
    ensureRemotes()
    if not PickupRemote then
        setStatus("ERROR: Pickup Slime remote missing")
        return {}
    end
    if type(slotNames) ~= "table" or #slotNames == 0 then
        return {}
    end

    -- ONLY slots this pipeline opened
    local targetSet = {}
    for _, s in ipairs(slotNames) do
        targetSet[tostring(s)] = true
    end

    -- Snapshot inventory UIDs before pickup
    local before = {}
    do
        local data = getData()
        if data and type(data.Inventory) == "table" then
            for _, entry in pairs(data.Inventory) do
                if type(entry) == "table" then
                    local u = entry.uid or entry.UID or entry.slimeUID
                    if u then
                        before[tostring(u)] = true
                    end
                end
            end
        end
    end

    -- Wait for opens to resolve (lucky → real slime)
    setStatus("Waiting for opens to resolve...")
    local resolveDeadline = os.clock() + 6
    while os.clock() < resolveDeadline and enabled and not hopping do
        local data = getData()
        local plotSlimes = (data and data.PlotSlimes) or {}
        local stillLucky = 0
        local anyPresent = 0
        for slotName in pairs(targetSet) do
            local entry = plotSlimes[slotName] or plotSlimes[tonumber(slotName)]
            if type(entry) == "table" then
                anyPresent += 1
                if isStillLuckyBlockEntry(entry) then
                    stillLucky += 1
                end
            end
        end
        if anyPresent > 0 and stillLucky == 0 then
            break
        end
        task.wait(0.15)
    end

    local keptOnPlot = 0
    local deadline = os.clock() + 22
    local lastFire = 0
    local lastStatus = 0

    setStatus("Pickup JUNK from opened slots (keep Cursed/Stellar/Divine/Fallen/Joker/Huge)...")

    while os.clock() < deadline and enabled and not hopping do
        local data = getData()
        local plotSlimes = (data and data.PlotSlimes) or {}
        local still = {}
        local keptNow = 0

        for slotName in pairs(targetSet) do
            local entry = plotSlimes[slotName] or plotSlimes[tonumber(slotName)]
            if type(entry) ~= "table" then
                -- Slot empty → already picked or never filled
                targetSet[slotName] = nil
            else
                -- If still a lucky block, keep trying open+pickup (open lag)
                if isStillLuckyBlockEntry(entry) then
                    if OpenRemote then
                        pcall(function()
                            OpenRemote:FireServer(tostring(slotName))
                        end)
                    end
                    table.insert(still, slotName)
                else
                    local keep, mutName = entryHasKeepMutation(entry, nil, slotName)
                    if keep then
                        -- LEAVE on plot: Cursed / Stellar / Divine / Fallen / Joker / Huge
                        keptNow += 1
                        targetSet[slotName] = nil
                    else
                        -- JUNK → must pick up then sell
                        table.insert(still, slotName)
                    end
                end
            end
        end

        keptOnPlot = math.max(keptOnPlot, keptNow)

        if #still == 0 then
            break
        end

        if os.clock() - lastFire >= 0.04 then
            lastFire = os.clock()
            for _, name in ipairs(still) do
                pcall(function()
                    PickupRemote:FireServer(tostring(name))
                end)
                -- Some builds accept number slot ids
                local n = tonumber(name)
                if n then
                    pcall(function()
                        PickupRemote:FireServer(n)
                    end)
                end
            end
        end

        if os.clock() - lastStatus >= 0.35 then
            lastStatus = os.clock()
            setStatus(string.format(
                "Pickup junk: %d left | kept on plot %d",
                #still,
                keptOnPlot
            ))
        end
        task.wait(0.03)
    end

    -- NEW inventory UIDs = sell candidates (non-keep only)
    task.wait(0.2)
    local sellable = {}
    local data = getData()
    if data and type(data.Inventory) == "table" then
        for _, entry in pairs(data.Inventory) do
            if type(entry) == "table" then
                local u = entry.uid or entry.UID or entry.slimeUID
                if u then
                    local key = tostring(u)
                    if not before[key] then
                        local keep = entryHasKeepMutation(entry, nil, nil)
                        if not keep then
                            table.insert(sellable, u)
                        end
                    end
                end
            end
        end
    end

    setStatus(string.format(
        "Pickup done | junk to sell %d | kept Cursed/Stellar/Divine/Fallen/Joker/Huge on plot",
        #sellable
    ))
    return sellable
end

local function doSellUIDs(uids)
    ensureRemotes()
    if not SellRemote then
        setStatus("ERROR: Sell remote missing")
        return 0
    end

    -- Always re-scan inventory for non-keep entries that we can sell.
    -- Prefer the UID list from pickup, but also catch any that slipped through.
    local data = getData()
    local invByUid = {}
    if data and type(data.Inventory) == "table" then
        for _, entry in pairs(data.Inventory) do
            if type(entry) == "table" then
                local u = entry.uid or entry.UID or entry.slimeUID
                if u then
                    invByUid[tostring(u)] = { uid = u, entry = entry }
                end
            end
        end
    end

    local safe = {}
    local seen = {}

    local function consider(uid)
        if uid == nil then
            return
        end
        local key = tostring(uid)
        if seen[key] then
            return
        end
        local row = invByUid[key]
        if row then
            if entryHasKeepMutation(row.entry, nil, nil) then
                return -- never sell keep muts
            end
            seen[key] = true
            table.insert(safe, row.uid)
        else
            -- UID claimed by pickup but not in inv map yet — still try
            seen[key] = true
            table.insert(safe, uid)
        end
    end

    if type(uids) == "table" then
        for _, uid in ipairs(uids) do
            consider(uid)
        end
    end

    -- Fallback: if pickup returned nothing but inventory has non-keep items
    -- that look like recent opens, user still wants junk sold.
    -- Only sell entries that are clearly NOT keep mutations.
    if #safe == 0 and data and type(data.Inventory) == "table" then
        for _, entry in pairs(data.Inventory) do
            if type(entry) == "table" then
                local u = entry.uid or entry.UID or entry.slimeUID
                if u and not entryHasKeepMutation(entry, nil, nil) then
                    -- Prefer selling lucky-block products / low value junk only if
                    -- we have an explicit uid list. Without list, skip mass-sell
                    -- of whole inventory to avoid selling pre-owned keepers.
                end
            end
        end
    end

    if #safe == 0 then
        setStatus("Nothing to sell (no junk UIDs in inventory)")
        return 0
    end

    setStatus(string.format("Selling %d junk (never keep muts)...", #safe))
    local targets = {}
    for _, uid in ipairs(safe) do
        table.insert(targets, { uid = uid, done = false })
    end

    local deadline = os.clock() + 20
    local lastFire = 0

    while os.clock() < deadline and enabled and not hopping do
        local data2 = getData()
        local stillHave = {}
        if data2 and type(data2.Inventory) == "table" then
            for _, entry in pairs(data2.Inventory) do
                if type(entry) == "table" then
                    local u = entry.uid or entry.UID or entry.slimeUID
                    if u then
                        stillHave[tostring(u)] = true
                    end
                end
            end
        end

        local remaining = 0
        for _, t in ipairs(targets) do
            if not t.done then
                if not stillHave[tostring(t.uid)] then
                    t.done = true
                else
                    remaining += 1
                end
            end
        end
        if remaining == 0 then
            break
        end

        if os.clock() - lastFire >= 0.04 then
            lastFire = os.clock()
            for _, t in ipairs(targets) do
                if not t.done then
                    pcall(function()
                        SellRemote:FireServer(t.uid)
                    end)
                    pcall(function()
                        SellRemote:FireServer(tostring(t.uid))
                    end)
                    local n = tonumber(t.uid)
                    if n then
                        pcall(function()
                            SellRemote:FireServer(n)
                        end)
                    end
                end
            end
        end
        setStatus(string.format("Selling junk: %d left", remaining))
        task.wait(0.03)
    end

    local sold = 0
    for _, t in ipairs(targets) do
        if t.done then
            sold += 1
        end
    end
    setStatus(string.format("Sold %d / %d junk", sold, #targets))
    return sold
end

--------------------------------------------------
-- GLOBAL JUNK PURGE
-- Keep ONLY on plot + inventory:
--   Cursed, Stellar, Divine, Fallen, Joker, Huge
-- Everything else (any slot, any inventory item) = junk → pickup + sell
--------------------------------------------------
local function doPurgeAllJunk()
    ensureRemotes()
    if not PickupRemote then
        setStatus("ERROR: Pickup remote missing")
        return 0, 0
    end
    if not SellRemote then
        setStatus("ERROR: Sell remote missing")
        return 0, 0
    end

    --------------------------------------------------
    -- 1) PICKUP every non-keep plot slot (existing + newly opened)
    --------------------------------------------------
    setStatus("Purge: pickup ALL junk from every plot slot...")
    local pickupDeadline = os.clock() + 22
    local lastFire = 0
    local keptSlots = 0

    while os.clock() < pickupDeadline and enabled and not hopping do
        local data = getData()
        local plotSlimes = (data and data.PlotSlimes) or {}
        local junkSlots = {}
        keptSlots = 0

        for slotKey, entry in pairs(plotSlimes) do
            if type(entry) == "table" then
                local slotName = tostring(slotKey)
                -- Skip pure unopened lucky boxes? User said sell junk from slots.
                -- Unopened boxes aren't "mutations" — leave boxes for open pipeline;
                -- only purge resolved non-keep players.
                if isStillLuckyBlockEntry(entry) then
                    -- leave lucky boxes alone here (opened in pipeline)
                else
                    local keep = entryHasKeepMutation(entry, nil, slotName)
                    if keep then
                        keptSlots += 1
                    else
                        table.insert(junkSlots, slotName)
                    end
                end
            end
        end

        if #junkSlots == 0 then
            break
        end

        if os.clock() - lastFire >= 0.04 then
            lastFire = os.clock()
            for _, name in ipairs(junkSlots) do
                pcall(function()
                    PickupRemote:FireServer(tostring(name))
                end)
                local n = tonumber(name)
                if n then
                    pcall(function()
                        PickupRemote:FireServer(n)
                    end)
                end
            end
        end
        setStatus(string.format(
            "Purge pickup junk slots: %d left | kept keep-muts on plot %d",
            #junkSlots,
            keptSlots
        ))
        task.wait(0.03)
    end

    task.wait(0.25)

    --------------------------------------------------
    -- 2) SELL every non-keep inventory item (entire inventory)
    --------------------------------------------------
    setStatus("Purge: sell ALL junk from inventory...")
    local sellDeadline = os.clock() + 22
    lastFire = 0
    local sold = 0

    while os.clock() < sellDeadline and enabled and not hopping do
        local data = getData()
        local junk = {}
        local keptInv = 0

        if data and type(data.Inventory) == "table" then
            for _, entry in pairs(data.Inventory) do
                if type(entry) == "table" then
                    local u = entry.uid or entry.UID or entry.slimeUID
                    if u then
                        if entryHasKeepMutation(entry, nil, nil) then
                            keptInv += 1
                        else
                            table.insert(junk, u)
                        end
                    end
                end
            end
        end

        if #junk == 0 then
            setStatus(string.format(
                "Purge done | kept on plot %d | kept in inv %d | sold junk OK",
                keptSlots,
                keptInv
            ))
            break
        end

        if os.clock() - lastFire >= 0.04 then
            lastFire = os.clock()
            for _, uid in ipairs(junk) do
                pcall(function()
                    SellRemote:FireServer(uid)
                end)
                pcall(function()
                    SellRemote:FireServer(tostring(uid))
                end)
                local n = tonumber(uid)
                if n then
                    pcall(function()
                        SellRemote:FireServer(n)
                    end)
                end
            end
            sold = #junk
        end
        setStatus(string.format(
            "Purge sell inventory junk: %d left | kept inv %d",
            #junk,
            keptInv
        ))
        task.wait(0.03)
    end

    return keptSlots, sold
end

local function runEventPipeline()
    local active = getActiveTargetEvents()
    if #active == 0 then
        setStatus("No target event — skip pipeline")
        return
    end

    setStatus("EVENT: " .. table.concat(active, ", ") .. " — place + open + purge junk")

    ensureRemotes()
    toBase()
    task.wait(0.2)

    if not hasTargetEvent() then
        setStatus("Event ended before place — abort")
        return
    end

    local existingBoxSlots = getExistingLuckyBoxSlots()
    local placedSlots = doPlaceAllLuckyBoxes()
    if not enabled or hopping then
        return
    end

    local openSlots = mergeSlotLists(placedSlots, existingBoxSlots)

    if type(openSlots) == "table" and #openSlots > 0 then
        active = getActiveTargetEvents()
        if #active == 0 then
            setStatus("Event ended before open — skip open, still purge junk")
        else
            setStatus(string.format(
                "Opening %d boxes (%d placed + %d existing) during %s...",
                #openSlots,
                type(placedSlots) == "table" and #placedSlots or 0,
                type(existingBoxSlots) == "table" and #existingBoxSlots or 0,
                table.concat(active, ", ")
            ))
            task.wait(0.25)
            doOpenSlots(openSlots)
            if not enabled or hopping then
                return
            end
            task.wait(0.6)
        end
    else
        setStatus("No boxes to open — purge existing junk only")
        task.wait(0.2)
    end

    -- GLOBAL RULE: keep ONLY Cursed/Stellar/Divine/Fallen/Joker/Huge
    -- Pickup + sell EVERYTHING else from ALL slots and ALL inventory
    setStatus("Purge junk everywhere (slots + inventory)...")
    doPurgeAllJunk()
    task.wait(0.35)
    setStatus("Event pipeline done — hopping")
end

--------------------------------------------------
-- Server hop
--------------------------------------------------
local function httpGet(url)
    local body
    local ok = pcall(function()
        if typeof(game.HttpGet) == "function" then
            body = game:HttpGet(url)
            return
        end
        if typeof(httpget) == "function" then
            body = httpget(url)
            return
        end
        if typeof(request) == "function" then
            local res = request({ Url = url, Method = "GET" })
            body = res and (res.Body or res.body)
            return
        end
        if typeof(http_request) == "function" then
            local res = http_request({ Url = url, Method = "GET" })
            body = res and (res.Body or res.body)
            return
        end
        if typeof(syn) == "table" and typeof(syn.request) == "function" then
            local res = syn.request({ Url = url, Method = "GET" })
            body = res and (res.Body or res.body)
            return
        end
        body = HttpService:GetAsync(url)
    end)
    if ok and type(body) == "string" and #body > 0 then
        return body
    end
    return nil
end

local function decodeJson(str)
    local ok, data = pcall(function()
        return HttpService:JSONDecode(str)
    end)
    if ok then
        return data
    end
    return nil
end

local function findAnyPublicJobId(placeId)
    local cursor = ""
    local candidates = {}
    local pages = 0

    while pages < 5 do
        pages += 1
        local url = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true%s",
            placeId,
            cursor ~= "" and ("&cursor=" .. cursor) or ""
        )
        local body = httpGet(url)
        if not body then
            break
        end
        local data = decodeJson(body)
        if type(data) ~= "table" or type(data.data) ~= "table" then
            break
        end

        for _, server in ipairs(data.data) do
            local playing = tonumber(server.playing) or 0
            local id = server.id or server.jobId
            if id
                and tostring(id) ~= ""
                and tostring(id) ~= tostring(game.JobId)
            then
                table.insert(candidates, {
                    id = tostring(id),
                    playing = playing,
                })
            end
        end

        cursor = data.nextPageCursor
        if type(cursor) ~= "string" or cursor == "" then
            break
        end
    end

    if #candidates == 0 then
        return nil, nil
    end

    -- Prefer lower pop when available, but NO hard player limit
    table.sort(candidates, function(a, b)
        return a.playing < b.playing
    end)

    local pick = candidates[1]
    return pick.id, pick.playing
end

local function hopServer(reason)
    if hopping then
        return
    end
    if os.clock() - lastHopAt < HOP_COOLDOWN then
        return
    end

    hopping = true
    lastHopAt = os.clock()
    enabled = false
    reason = reason or "hop"

    setStatus("Finding any public server...")
    local placeId = game.PlaceId
    local jobId, playing = findAnyPublicJobId(placeId)

    if not jobId then
        setStatus("No other public server found — retry later")
        hopping = false
        enabled = true
        emptyScans = 0
        task.wait(2)
        return
    end

    setStatus(string.format("Hop (%s) → %d players...", reason, tonumber(playing) or 0))

    local teleported = pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, jobId, LP)
    end)
    if not teleported then
        teleported = pcall(function()
            local opts = Instance.new("TeleportOptions")
            opts.ServerInstanceId = jobId
            TeleportService:TeleportAsync(placeId, { LP }, opts)
        end)
    end

    if not teleported then
        setStatus("Teleport failed — retry")
        hopping = false
        enabled = true
        emptyScans = 0
        return
    end

    task.delay(10, function()
        hopping = false
        enabled = true
        emptyScans = 0
        sessionStart = os.clock()
    end)
end

--------------------------------------------------
-- GUI
--------------------------------------------------
pcall(function()
    for _, name in ipairs({
        "NextGenStealer",
        "NextGenEventFarmer",
        "NextGenerationStealer",
    }) do
        local old = PG:FindFirstChild(name)
        if old then
            old:Destroy()
        end
    end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "NextGenEventFarmer"
gui.ResetOnSpawn = false
gui.Parent = PG

local f = Instance.new("Frame")
f.Size = UDim2.new(0, 230, 0, 168)
f.Position = UDim2.new(0, 16, 0.5, -84)
f.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
f.BorderSizePixel = 0
f.Active = true
f.Draggable = true
f.Parent = gui
Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(1, -20, 0, 34)
btn.Position = UDim2.new(0, 10, 0, 8)
btn.BackgroundColor3 = Color3.fromRGB(28, 52, 36)
btn.BorderSizePixel = 0
btn.Text = "NextGen+Event: ON"
btn.TextColor3 = Color3.fromRGB(80, 255, 120)
btn.TextSize = 13
btn.Font = Enum.Font.GothamBold
btn.Parent = f
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

timeLbl = Instance.new("TextLabel")
timeLbl.Size = UDim2.new(1, -16, 0, 18)
timeLbl.Position = UDim2.new(0, 8, 0, 46)
timeLbl.BackgroundTransparency = 1
timeLbl.Text = "Time: 00:00"
timeLbl.TextColor3 = Color3.fromRGB(200, 200, 210)
timeLbl.TextSize = 12
timeLbl.Font = Enum.Font.Gotham
timeLbl.TextXAlignment = Enum.TextXAlignment.Left
timeLbl.Parent = f

countLbl = Instance.new("TextLabel")
countLbl.Size = UDim2.new(1, -16, 0, 18)
countLbl.Position = UDim2.new(0, 8, 0, 64)
countLbl.BackgroundTransparency = 1
countLbl.Text = "Stolen NextGen: 0"
countLbl.TextColor3 = Color3.fromRGB(200, 200, 210)
countLbl.TextSize = 12
countLbl.Font = Enum.Font.Gotham
countLbl.TextXAlignment = Enum.TextXAlignment.Left
countLbl.Parent = f

eventLbl = Instance.new("TextLabel")
eventLbl.Size = UDim2.new(1, -16, 0, 18)
eventLbl.Position = UDim2.new(0, 8, 0, 82)
eventLbl.BackgroundTransparency = 1
eventLbl.Text = "Event: none"
eventLbl.TextColor3 = Color3.fromRGB(180, 210, 255)
eventLbl.TextSize = 12
eventLbl.Font = Enum.Font.GothamBold
eventLbl.TextXAlignment = Enum.TextXAlignment.Left
eventLbl.Parent = f

statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -16, 0, 48)
statusLbl.Position = UDim2.new(0, 8, 0, 104)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "Booting..."
statusLbl.TextColor3 = Color3.fromRGB(180, 190, 210)
statusLbl.TextSize = 11
statusLbl.Font = Enum.Font.Gotham
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.TextYAlignment = Enum.TextYAlignment.Top
statusLbl.TextWrapped = true
statusLbl.Parent = f

local function setOn(on)
    enabled = on
    btn.Text = on and "NextGen+Event: ON" or "NextGen+Event: OFF"
    btn.TextColor3 = on and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 90, 90)
    btn.BackgroundColor3 = on and Color3.fromRGB(28, 52, 36) or Color3.fromRGB(40, 40, 48)
    if on then
        totalStolen = 0
        emptyScans = 0
        sessionStart = os.clock()
        countLbl.Text = "Stolen NextGen: 0"
        timeLbl.Text = "Time: 00:00"
        setStatus("Scanning events + NextGen...")
    else
        busy = false
        setStatus("Paused")
    end
end

btn.MouseButton1Click:Connect(function()
    if hopping then
        return
    end
    setOn(not enabled)
end)

--------------------------------------------------
-- Timer + event label
--------------------------------------------------
task.spawn(function()
    while true do
        if enabled and sessionStart > 0 and not hopping then
            timeLbl.Text = "Time: " .. fmtTime(os.clock() - sessionStart)
        end
        local active = getActiveTargetEvents()
        if eventLbl then
            if #active > 0 then
                eventLbl.Text = "Event: " .. table.concat(active, ", ")
                eventLbl.TextColor3 = Color3.fromRGB(255, 200, 100)
            else
                eventLbl.Text = "Event: none"
                eventLbl.TextColor3 = Color3.fromRGB(180, 210, 255)
            end
        end
        task.wait(0.25)
    end
end)

--------------------------------------------------
-- MAIN LOOP
--------------------------------------------------
task.spawn(function()
    task.wait(0.5)
    ensureRemotes()
    setStatus("Auto-run | scan events + NextGen")

    while true do
        if hopping then
            task.wait(0.2)
            continue
        end

        if enabled and not busy then
            busy = true

            --------------------------------------------------
            -- 1) ALWAYS check events first (even with 0 NextGen)
            --------------------------------------------------
            if hasTargetEvent() then
                local ok, err = xpcall(runEventPipeline, debug.traceback)
                if not ok then
                    setStatus("Event pipeline error")
                    warn("[NextGenEventFarmer]", err)
                end
                busy = false
                if enabled then
                    hopServer("event-done")
                end
                task.wait(0.2)
                continue
            end

            --------------------------------------------------
            -- 2) Already carrying a steal
            --------------------------------------------------
            if LP:GetAttribute("holdingSlime") == true then
                setStatus("Carrying — return to base")
                emptyScans = 0
                toBase()
                local t = os.clock() + 5
                while enabled and LP:GetAttribute("holdingSlime") and os.clock() < t do
                    task.wait(0.1)
                end
                busy = false
                task.wait(0.1)
                continue
            end

            --------------------------------------------------
            -- 3) Steal NextGen
            --------------------------------------------------
            local nextGenCount = countNextGenBlocks()
            if nextGenCount <= 0 then
                emptyScans += 1
                setStatus(string.format(
                    "No NextGen (%d/%d) — will hop",
                    emptyScans,
                    EMPTY_SCANS_BEFORE_HOP
                ))
                busy = false
                if emptyScans >= EMPTY_SCANS_BEFORE_HOP then
                    hopServer("no-nextgen")
                else
                    task.wait(SCAN_EMPTY_WAIT)
                end
                continue
            end

            emptyScans = 0
            setStatus("NextGen found — steal...")
            local result = stealOne()

            if result == "deposited" then
                setStatus("Deposited held item")
                busy = false
                task.wait(0.15)
                continue
            end

            if result == true then
                totalStolen += 1
                countLbl.Text = "Stolen NextGen: " .. totalStolen
                setStatus("Stolen — depositing...")
                task.wait(0.25)
                toBase()
                task.wait(0.3)
                local t = os.clock() + 5
                while enabled and LP:GetAttribute("holdingSlime") and os.clock() < t do
                    task.wait(0.1)
                end
                setStatus("Scanning events + NextGen...")
            else
                setStatus("Steal failed — retry")
                task.wait(0.2)
            end

            busy = false
        end

        task.wait(0.08)
    end
end)

print(
    "[NextGenEventFarmer] NextGen steal + hop | Events Cursed/Joker/Sky/Huge →",
    "place+existing boxes → open → keep Cursed/Stellar/Divine/Fallen/Huge → sell rest → hop"
)
