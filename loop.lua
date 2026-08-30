-- ============================================================
-- LUCKY BOX RARITY CYCLE - WORLD STEAL VERSION
-- NO SERVER HOP
-- ============================================================
--
-- IMPORTANT CHANGE:
-- Lucky Blocks are NOT expected to already be in Inventory.
-- This script first steals/picks them from:
--
--     workspace.Live.Slimes
--
-- using the EXACT proven Lucky Block collector movement/pickup mechanism:
--
--   find world Lucky Block
--   -> activate cloak
--   -> root.CFrame = box.part.CFrame * CFrame.new(0, 3, 4)
--   -> zero AssemblyLinearVelocity / AssemblyAngularVelocity
--   -> wait 0.2
--   -> up to 5 ProximityPrompt attempts
--   -> confirm holdingSlime == true
--   -> teleport to Base.Teleport + Vector3.new(0,3,0)
--   -> wait 0.35
--   -> confirm holdingSlime == false (deposit)
--   -> wait 0.2
--   -> resolve the NEW Lucky Block UID in Inventory
--
-- RARITY FLOW:
-- Common -> Rare -> Epic -> Legendary -> Mythic -> Secret
-- -> Slime God -> Divine -> Exclusive -> LIMITED -> OG
-- -> Champions -> Spain -> Icons -> Japan -> Alternative
-- -> back to Common
--
-- PER RARITY:
--   * process ONE batch of up to 10 boxes
--   * fully finish that batch before touching the next rarity
--
-- EACH RARITY MUST COMPLETE THIS ENTIRE FLOW:
--   1) Steal up to 10 world Lucky Blocks of the CURRENT rarity
--   2) Confirm their new Inventory UIDs
--   3) STOP STEALING
--   4) Teleport to free stands and place those exact UIDs
--   5) Open those exact slots
--   6) Wait 1 second
--   7) Detect only newly-created slimes in those opened slots
--   8) Pick those generated slimes into Inventory
--   9) Sell those exact generated UIDs using
--          Sell Slime From Inventory
--  10) ONLY AFTER SELLING is complete, advance to next rarity
--
-- Dynamic stands: NO fixed 100-slot limit.
-- Server authoritative.
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)

-- ============================================================
-- CONFIG
-- ============================================================

-- One complete batch per rarity.
-- The script MUST finish steal -> place -> open -> sell
-- before it starts collecting the next rarity.
local BOXES_PER_RARITY = 10
local BATCH_SIZE = 10

local WORLD_SCAN_INTERVAL = 0.08
local NO_TARGET_RETRY_DELAY = 0.20

-- EXACT working collector pickup values.
local PICKUP_TRIES = 5
local PICKUP_CONFIRM_TIMEOUT = 1.5
local DEPOSIT_TIMEOUT = 5.0

-- Exact world target offset:
-- root.CFrame = box.part.CFrame * CFrame.new(0, 3, 4)
local WORLD_TELEPORT_OFFSET = CFrame.new(0, 3, 4)
local WORLD_TELEPORT_SETTLE = 0.20

-- Exact collector return/deposit timing.
local BASE_RETURN_SETTLE = 0.35
local POST_DEPOSIT_SETTLE = 0.20

local INVENTORY_CONFIRM_TIMEOUT = 4.0

local STAND_TELEPORT_SETTLE = 0.04
local PLACE_CONFIRM_TIMEOUT = 2.0

local OPEN_SPAM_ROUNDS = 8
local OPEN_SPAM_GAP = 0.05

local OPEN_TO_SELL_DELAY = 1.0

local GENERATED_WAIT_TIMEOUT = 4.0
local PICKUP_CONFIRM_TIMEOUT = 3.0
local SELL_CONFIRM_TIMEOUT = 4.0

local BETWEEN_STEALS = 0.05
local BETWEEN_BOXES = 0.03
local BETWEEN_BATCHES = 0.20
local EMPTY_RARITY_DELAY = 0.30
local FULL_LOOP_DELAY = 1.0

-- If an invis/cloak Tool exists, use it before stealing.
local USE_CLOAK_IF_AVAILABLE = true

-- Lowest Lucky Block value -> highest.
local RARITY_ORDER = {
    "Common",
    "Rare",
    "Epic",
    "Legendary",
    "Mythic",
    "Secret",
    "Slime God",
    "Divine",
    "Exclusive",
    "LIMITED",
    "OG",
    "Champions",
    "Spain",
    "Icons",
    "Japan",
    "Alternative",
}

local LUCKY_BLOCK_VALUES = {
    Common = 25,
    Rare = 100,
    Epic = 250,
    Legendary = 750,
    Mythic = 2500,
    Secret = 10000,
    ["Slime God"] = 30000,
    Divine = 50000,
    Exclusive = 75000,
    LIMITED = 75000,
    OG = 500000,
    Champions = 1000000,
    Spain = 2500000,
    Icons = 5000000,
    Japan = 7000000,
    Alternative = 9000000,
}

-- Known exact live target from the supplied stealer.
local KNOWN_IDS = {
    Alternative = "1263",
}

-- ============================================================
-- STATE
-- ============================================================

local enabled = false
local busy = false
local currentRarityIndex = 1

local _Lib = nil

local PlaceRemote = nil
local OpenRemote = nil
local PickupRemote = nil
local SellRemote = nil

-- ============================================================
-- GUI
-- ============================================================

pcall(function()
    local old = PlayerGui and PlayerGui:FindFirstChild("LuckyBoxWorldCycleGui")
    if old then old:Destroy() end

    old = CoreGui:FindFirstChild("LuckyBoxWorldCycleGui")
    if old then old:Destroy() end
end)

local Gui = Instance.new("ScreenGui")
Gui.Name = "LuckyBoxWorldCycleGui"
Gui.ResetOnSpawn = false
Gui.DisplayOrder = 1100
Gui.IgnoreGuiInset = true
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

pcall(function()
    Gui.Parent = PlayerGui or CoreGui
end)

if not Gui.Parent then
    Gui.Parent = CoreGui
end

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 285, 0, 135)
Frame.Position = UDim2.new(0, 20, 0.5, -67)
Frame.BackgroundColor3 = Color3.fromRGB(24, 24, 31)
Frame.BorderSizePixel = 0
Frame.Active = true
Frame.Draggable = true
Frame.Parent = Gui

Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 9)

local Stroke = Instance.new("UIStroke", Frame)
Stroke.Color = Color3.fromRGB(80, 80, 100)
Stroke.Thickness = 1.5

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -12, 0, 24)
Title.Position = UDim2.new(0, 6, 0, 4)
Title.BackgroundTransparency = 1
Title.Text = "Lucky Box World Steal Cycle"
Title.TextColor3 = Color3.fromRGB(245, 245, 250)
Title.TextSize = 13
Title.Font = Enum.Font.GothamBold
Title.Parent = Frame

local Toggle = Instance.new("TextButton")
Toggle.Size = UDim2.new(1, -20, 0, 34)
Toggle.Position = UDim2.new(0, 10, 0, 31)
Toggle.BackgroundColor3 = Color3.fromRGB(48, 36, 40)
Toggle.BorderSizePixel = 0
Toggle.Text = "Cycle: OFF"
Toggle.TextColor3 = Color3.fromRGB(255, 110, 120)
Toggle.TextSize = 12
Toggle.Font = Enum.Font.GothamBold
Toggle.Parent = Frame
Instance.new("UICorner", Toggle).CornerRadius = UDim.new(0, 7)

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -20, 0, 59)
Status.Position = UDim2.new(0, 10, 0, 70)
Status.BackgroundTransparency = 1
Status.Text = "Ready | 10 per rarity | finish batch before next"
Status.TextColor3 = Color3.fromRGB(185, 185, 200)
Status.TextSize = 10
Status.Font = Enum.Font.Gotham
Status.TextWrapped = true
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.TextYAlignment = Enum.TextYAlignment.Top
Status.Parent = Frame

local function updateToggle()
    if enabled then
        Toggle.Text = "Cycle: ON"
        Toggle.TextColor3 = Color3.fromRGB(105, 255, 145)
        Toggle.BackgroundColor3 = Color3.fromRGB(30, 62, 43)
    else
        Toggle.Text = "Cycle: OFF"
        Toggle.TextColor3 = Color3.fromRGB(255, 110, 120)
        Toggle.BackgroundColor3 = Color3.fromRGB(48, 36, 40)
    end
end

Toggle.MouseButton1Click:Connect(function()
    enabled = not enabled
    updateToggle()

    if enabled then
        Status.Text =
            "Starting world steal: "
            .. tostring(RARITY_ORDER[currentRarityIndex])
    else
        Status.Text = "Stopped"
    end
end)

-- ============================================================
-- BASIC HELPERS
-- ============================================================

local function root()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function normalizeRarity(value)
    local s = tostring(value or "")

    if s == "" then
        return ""
    end

    local lower = s:lower()

    if lower == "player god"
        or lower == "soccer god"
        or lower == "slime god"
    then
        return "Slime God"
    end

    if lower == "limited" then
        return "LIMITED"
    end

    if lower == "alternative"
        or lower == "alternate"
    then
        return "Alternative"
    end

    for _, rarity in ipairs(RARITY_ORDER) do
        if lower == rarity:lower() then
            return rarity
        end
    end

    return s
end

local function resolveExactRemoteEvent(name)
    local shared =
        ReplicatedStorage:FindFirstChild("SharedModules")

    local network =
        shared and shared:FindFirstChild("Network")

    local remotes =
        network and network:FindFirstChild("Remotes")

    local direct =
        remotes and remotes:FindFirstChild(name)

    if direct and direct:IsA("RemoteEvent") then
        return direct
    end

    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") and obj.Name == name then
            return obj
        end
    end

    return nil
end

local function resolveRemotes()
    PlaceRemote =
        PlaceRemote
        or resolveExactRemoteEvent("Place Slime")

    OpenRemote =
        OpenRemote
        or resolveExactRemoteEvent("Open Lucky Block")

    PickupRemote =
        PickupRemote
        or resolveExactRemoteEvent("Pickup Slime")

    SellRemote =
        SellRemote
        or resolveExactRemoteEvent("Sell Slime From Inventory")

    return
        PlaceRemote ~= nil
        and OpenRemote ~= nil
        and PickupRemote ~= nil
        and SellRemote ~= nil
end

local function getData()
    _Lib = _G._Lib or _Lib

    if _Lib and _Lib.Data then
        local ok, data =
            pcall(function()
                return _Lib.Data:Get()
            end)

        if ok and data then
            return data
        end
    end

    local shared =
        ReplicatedStorage:FindFirstChild("SharedModules")

    local network =
        shared and shared:FindFirstChild("Network")

    local remotes =
        network and network:FindFirstChild("Remotes")

    local dataGet =
        remotes and remotes:FindFirstChild("Data: Get")

    if dataGet and dataGet:IsA("RemoteFunction") then
        local ok, data =
            pcall(function()
                return dataGet:InvokeServer()
            end)

        if ok and data then
            return data
        end
    end

    local broad =
        ReplicatedStorage:FindFirstChild("Data: Get", true)

    if broad and broad:IsA("RemoteFunction") then
        local ok, data =
            pcall(function()
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

        if owner
            and tostring(owner.Value) == LocalPlayer.Name
        then
            return plot
        end
    end

    return nil
end

local function getPlayerSlimesFolder()
    local live = Workspace:FindFirstChild("Live")
    local ps = live and live:FindFirstChild("PlayerSlimes")
    return ps and ps:FindFirstChild(LocalPlayer.Name)
end

local function getEntryUID(entry)
    if type(entry) ~= "table" then
        return nil
    end

    return
        entry.uid
        or entry.UID
        or entry.slimeUID
end

-- ============================================================
-- OWN BASE TELEPORT - FROM SUPPLIED STEALER
-- ============================================================

local function toBase()
    local r = root()

    if not r then
        return false
    end

    local plot = getMyPlot()

    if not plot then
        return false
    end

    local base =
        plot:FindFirstChild("Base")

    local tp =
        base and base:FindFirstChild("Teleport")

    if not tp then
        return false
    end

    -- EXACT collector return mechanism.
    if tp:IsA("Attachment") then
        r.CFrame =
            tp.WorldCFrame
            + Vector3.new(0, 3, 0)

    elseif tp:IsA("BasePart") then
        r.CFrame =
            tp.CFrame
            + Vector3.new(0, 3, 0)

    else
        return false
    end

    r.AssemblyLinearVelocity =
        Vector3.zero

    r.AssemblyAngularVelocity =
        Vector3.zero

    return true
end

local function isHolding()
    return
        LocalPlayer:GetAttribute(
            "holdingSlime"
        ) == true
end

local function waitPickup()
    local timeout =
        os.clock()
        + PICKUP_CONFIRM_TIMEOUT

    while enabled
        and os.clock() < timeout
    do
        if isHolding() then
            return true
        end

        task.wait(0.05)
    end

    return isHolding()
end

local function waitDeposit()
    local timeout =
        os.clock()
        + DEPOSIT_TIMEOUT

    while enabled
        and isHolding()
        and os.clock() < timeout
    do
        task.wait(0.10)
    end

    return not isHolding()
end

-- ============================================================
-- OPTIONAL INVIS CLOAK - SAME IDEA AS SUPPLIED STEALER
-- ============================================================

local function activateCloak()
    if not USE_CLOAK_IF_AVAILABLE then
        return false
    end

    local char = LocalPlayer.Character
    local hum =
        char and char:FindFirstChildOfClass("Humanoid")

    if not hum then
        return false
    end

    local tool = nil

    for _, container in ipairs({
        char,
        LocalPlayer:FindFirstChild("Backpack"),
    }) do
        if container then
            for _, obj in ipairs(container:GetChildren()) do
                if obj:IsA("Tool") then
                    local n =
                        tostring(obj.Name):lower()

                    if n:find("invis", 1, true)
                        or n:find("cloak", 1, true)
                    then
                        tool = obj
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
        return false
    end

    if tool.Parent ~= char then
        pcall(function()
            hum:UnequipTools()
        end)

        task.wait(0.04)

        pcall(function()
            hum:EquipTool(tool)
        end)

        if tool.Parent ~= char then
            pcall(function()
                tool.Parent = char
            end)
        end

        task.wait(0.08)
    end

    local canActivate =
        tool:FindFirstChild("CanActivate")

    if canActivate
        and canActivate:IsA("BoolValue")
    then
        canActivate.Value = true
    end

    pcall(function()
        tool:Activate()
    end)

    return true
end

-- ============================================================
-- CURRENT CATALOG / INVENTORY LUCKY BLOCK HELPERS
-- ============================================================

local function resolveSlimeDefinition(entry)
    if type(entry) ~= "table" then
        return nil
    end

    _Lib = _G._Lib or _Lib

    local id =
        entry.id
        or entry.Id
        or entry.slimeId
        or entry.slimeID

    if id == nil then
        return nil
    end

    local currentCatalog =
        _Lib
        and _Lib.SoccerGameCatalog
        and _Lib.SoccerGameCatalog.SoccerPlayerCatalog

    if type(currentCatalog) == "table" then
        local def =
            currentCatalog[id]
            or currentCatalog[tostring(id)]
            or currentCatalog[tonumber(id)]

        if def then
            return def
        end
    end

    local legacy =
        _Lib
        and _Lib.Database
        and _Lib.Database.Slimes

    if type(legacy) == "table" then
        return
            legacy[id]
            or legacy[tostring(id)]
            or legacy[tonumber(id)]
    end

    return nil
end

local function hasLuckyWord(value)
    local s = tostring(value or ""):lower()

    return
        s:find("lucky block", 1, true) ~= nil
        or s:find("lucky", 1, true) ~= nil
        or s:find("box", 1, true) ~= nil
        or s:find("crate", 1, true) ~= nil
end

local function isLuckyInventoryEntry(entry, def)
    if type(entry) ~= "table" then
        return false
    end

    if entry.production_is_lucky_block == true then
        return true
    end

    if def
        and tostring(def.Type or ""):lower()
            == "lucky block"
    then
        return true
    end

    return
        hasLuckyWord(def and def.Type)
        or hasLuckyWord(def and def.Name)
        or hasLuckyWord(entry.Type)
        or hasLuckyWord(entry.type)
        or hasLuckyWord(entry.Name)
        or hasLuckyWord(entry.name)
end

local function getInventoryEntryRarity(entry, def)
    return normalizeRarity(
        (def and (def.Rarity or def.rarity))
        or entry.Rarity
        or entry.rarity
    )
end

local function getInventoryLuckyUIDSet(rarity)
    local data = getData()
    local inventory = data and data.Inventory
    local set = {}

    if type(inventory) ~= "table" then
        return set
    end

    local wanted =
        normalizeRarity(rarity):lower()

    for _, entry in pairs(inventory) do
        if type(entry) == "table" then
            local uid = getEntryUID(entry)

            if uid ~= nil then
                local def =
                    resolveSlimeDefinition(entry)

                if isLuckyInventoryEntry(entry, def) then
                    local r =
                        getInventoryEntryRarity(entry, def)

                    if r:lower() == wanted then
                        set[tostring(uid)] = true
                    end
                end
            end
        end
    end

    return set
end

local function getInventoryLuckyBoxesByRarity(rarity)
    local data = getData()
    local inventory = data and data.Inventory
    local result = {}
    local seen = {}

    if type(inventory) ~= "table" then
        return result
    end

    local wanted =
        normalizeRarity(rarity):lower()

    for _, entry in pairs(inventory) do
        if type(entry) == "table" then
            local uid = getEntryUID(entry)

            if uid ~= nil
                and not seen[tostring(uid)]
            then
                local def =
                    resolveSlimeDefinition(entry)

                if isLuckyInventoryEntry(entry, def) then
                    local r =
                        getInventoryEntryRarity(entry, def)

                    if r:lower() == wanted then
                        seen[tostring(uid)] = true

                        table.insert(result, {
                            uid = uid,
                            entry = entry,
                            def = def,
                            name =
                                tostring(
                                    (def and def.Name)
                                    or entry.Name
                                    or entry.name
                                    or entry.id
                                    or uid
                                ),
                        })
                    end
                end
            end
        end
    end

    table.sort(result, function(a, b)
        return tostring(a.uid) < tostring(b.uid)
    end)

    return result
end

local function waitForNewLuckyInventoryUID(
    rarity,
    beforeSet,
    timeout
)
    timeout =
        tonumber(timeout)
        or INVENTORY_CONFIRM_TIMEOUT

    local deadline =
        os.clock() + timeout

    while enabled
        and os.clock() < deadline
    do
        local boxes =
            getInventoryLuckyBoxesByRarity(
                rarity
            )

        for _, box in ipairs(boxes) do
            local key =
                tostring(box.uid)

            if not beforeSet[key] then
                return box
            end
        end

        task.wait(0.08)
    end

    return nil
end

-- ============================================================
-- WORLD LUCKY BLOCK DETECTION
-- ============================================================

local function readModelIdentifier(model)
    if not model then
        return nil
    end

    return
        model:GetAttribute("ID")
        or model:GetAttribute("Id")
        or model:GetAttribute("id")
        or model:GetAttribute("_RegisteredID")
        or model:GetAttribute("RegisteredID")
        or model:GetAttribute("LuckyBlockID")
end

local function readModelRarity(model)
    if not model then
        return ""
    end

    local rarity =
        model:GetAttribute("Rarity")
        or model:GetAttribute("_Rarity")
        or model:GetAttribute("rarity")

    if rarity ~= nil then
        return normalizeRarity(rarity)
    end

    for _, name in ipairs({
        "Rarity",
        "_Rarity",
    }) do
        local obj =
            model:FindFirstChild(name)

        if obj and obj:IsA("ValueBase") then
            return normalizeRarity(obj.Value)
        end
    end

    return ""
end

local function readWorldDisplayName(model)
    if not model then
        return ""
    end

    local attrName =
        model:GetAttribute("LuckyBlockName")
        or model:GetAttribute("BlockName")
        or model:GetAttribute("DisplayName")
        or model:GetAttribute("Name")

    if attrName ~= nil then
        return tostring(attrName)
    end

    for _, childName in ipairs({
        "LuckyBlockName",
        "BlockName",
        "DisplayName",
    }) do
        local obj =
            model:FindFirstChild(childName)

        if obj and obj:IsA("ValueBase") then
            return tostring(obj.Value)
        end
    end

    return tostring(model.Name or "")
end

local function modelNameMatchesRarity(model, rarity)
    local wanted =
        normalizeRarity(rarity)

    local lowerWanted =
        wanted:lower()

    local allText =
        (
            tostring(model.Name or "")
            .. " "
            .. readWorldDisplayName(model)
        ):lower()

    if wanted == "Alternative" then
        return
            allText:find("alternative", 1, true) ~= nil
            or allText:find("alternate lucky block", 1, true) ~= nil
    end

    if wanted == "Slime God" then
        return
            allText:find("slime god", 1, true) ~= nil
            or allText:find("player god", 1, true) ~= nil
            or allText:find("soccer god", 1, true) ~= nil
    end

    if wanted == "LIMITED" then
        return
            allText:find("limited", 1, true) ~= nil
    end

    return
        allText:find(
            lowerWanted,
            1,
            true
        ) ~= nil
end

local function isWorldLuckyBlockOfRarity(model, rarity)
    if not model
        or not model:IsA("Model")
    then
        return false
    end

    if model:GetAttribute("Carrying") then
        return false
    end

    local wanted =
        normalizeRarity(rarity)

    -- 1) Exact rarity attrs/values.
    local modelRarity =
        readModelRarity(model)

    if modelRarity ~= ""
        and modelRarity:lower()
            == wanted:lower()
    then
        return true
    end

    -- 2) Known exact ID when available.
    local knownID =
        KNOWN_IDS[wanted]

    if knownID then
        local id =
            readModelIdentifier(model)

        if id
            and tostring(id)
                == tostring(knownID)
        then
            return true
        end

        for _, childName in ipairs({
            "ID",
            "Id",
            "RegisteredID",
            "_RegisteredID",
            "LuckyBlockID",
        }) do
            local obj =
                model:FindFirstChild(childName)

            if obj
                and obj:IsA("ValueBase")
                and tostring(obj.Value)
                    == tostring(knownID)
            then
                return true
            end
        end
    end

    -- 3) Model/display name.
    if modelNameMatchesRarity(
        model,
        wanted
    ) then
        -- Keep this constrained to objects that look like Lucky Blocks.
        local text =
            (
                tostring(model.Name or "")
                .. " "
                .. readWorldDisplayName(model)
            ):lower()

        if text:find("lucky", 1, true)
            or text:find("block", 1, true)
            or model:GetAttribute("LuckyBlockID")
            or model:GetAttribute("Rarity")
        then
            return true
        end
    end

    return false
end

local function findStealPrompt(model)
    if not model then
        return nil
    end

    local fallback = nil

    for _, obj in ipairs(model:GetDescendants()) do
        if obj:IsA("ProximityPrompt")
            and obj.Enabled
        then
            fallback = fallback or obj

            local action =
                tostring(
                    obj.ActionText or ""
                ):lower()

            if action:find("steal", 1, true)
                or action:find("pick", 1, true)
                or action:find("take", 1, true)
                or action:find("grab", 1, true)
                or action:find("collect", 1, true)
            then
                return obj
            end
        end
    end

    return fallback
end

local function getWorldBlockPart(model)
    if not model then
        return nil
    end

    return
        model.PrimaryPart
        or model:FindFirstChildWhichIsA(
            "BasePart",
            true
        )
end

local function findWorldLuckyBlock(rarity)
    local live =
        Workspace:FindFirstChild("Live")

    local folder =
        live and live:FindFirstChild("Slimes")

    if not folder then
        return nil
    end

    local best = nil
    local bestDistance = math.huge

    local r = root()

    for _, model in ipairs(folder:GetChildren()) do
        if isWorldLuckyBlockOfRarity(
            model,
            rarity
        ) then
            local part =
                getWorldBlockPart(model)

            local prompt =
                findStealPrompt(model)

            if part and prompt then
                local dist = 0

                if r then
                    dist =
                        (
                            r.Position
                            - part.Position
                        ).Magnitude
                end

                if not best
                    or dist < bestDistance
                then
                    bestDistance = dist

                    best = {
                        model = model,
                        part = part,
                        prompt = prompt,
                        rarity =
                            normalizeRarity(rarity),
                        id =
                            readModelIdentifier(model),
                        name =
                            readWorldDisplayName(model),
                    }
                end
            end
        end
    end

    return best
end

-- ============================================================
-- EXACT STEAL MECHANISM FROM SUPPLIED SCRIPT
-- ============================================================

local function firePrompt(prompt)
    if not prompt
        or not prompt.Parent
    then
        return false
    end

    -- Exact preferred executor path.
    if typeof(fireproximityprompt)
        == "function"
    then
        local success =
            pcall(function()
                fireproximityprompt(prompt)
            end)

        if success then
            return true
        end
    end

    -- Exact working fallback from the collector.
    return pcall(function()
        prompt:InputHoldBegin()

        task.wait(
            math.max(
                tonumber(
                    prompt.HoldDuration
                ) or 0,
                0.05
            )
        )

        prompt:InputHoldEnd()
    end)
end

local function teleportToWorldBlock(target)
    local r = root()

    if not r
        or not target
        or not target.part
        or not target.part.Parent
    then
        return false
    end

    -- EXACT working collector teleport:
    r.CFrame =
        target.part.CFrame
        * CFrame.new(0, 3, 4)

    r.AssemblyLinearVelocity =
        Vector3.zero

    r.AssemblyAngularVelocity =
        Vector3.zero

    -- Exact settle before pickup attempts.
    task.wait(0.20)

    return true
end

local function stealOneWorldLuckyBlock(rarity)
    if not enabled then
        return nil, "stopped"
    end

    -- Snapshot BEFORE stealing so we can identify the deposited box UID.
    local before =
        getInventoryLuckyUIDSet(
            rarity
        )

    local target =
        findWorldLuckyBlock(
            rarity
        )

    if not target then
        return nil, "no world target"
    end

    Status.Text =
        tostring(rarity)
        .. " | box found"

    -- EXACT collector sequence starts with cloak activation.
    activateCloak()

    if not teleportToWorldBlock(
        target
    ) then
        return nil, "teleport failed"
    end

    local picked = false

    -- EXACT collector retry loop.
    for attempt = 1, PICKUP_TRIES do
        if not enabled then
            return nil, "stopped"
        end

        Status.Text =
            string.format(
                "%s | pickup attempt %d/%d",
                rarity,
                attempt,
                PICKUP_TRIES
            )

        -- Never go to base until the server says we're holding it.
        if isHolding() then
            picked = true
            break
        end

        -- Collector re-activates cloak on every attempt.
        activateCloak()

        -- Re-find the prompt from the still-live model each attempt.
        local prompt =
            target.model
            and target.model.Parent
            and findStealPrompt(
                target.model
            )

        if prompt then
            firePrompt(prompt)

            -- Exact confirmation:
            -- LocalPlayer:GetAttribute("holdingSlime") == true
            if waitPickup() then
                picked = true
                break
            end
        end

        task.wait(0.20)
    end

    if not picked
        or not isHolding()
    then
        return nil, "pickup not confirmed"
    end

    -- EXACT main-loop behavior:
    -- holdingSlime TRUE -> teleport base -> wait .35 -> waitDeposit -> .2
    Status.Text =
        tostring(rarity)
        .. " | holding confirmed -> base"

    if not toBase() then
        return nil, "base teleport failed"
    end

    task.wait(BASE_RETURN_SETTLE)

    if not waitDeposit() then
        return nil, "deposit not confirmed"
    end

    task.wait(POST_DEPOSIT_SETTLE)

    -- After deposit is confirmed, resolve the exact new inventory UID.
    local newBox =
        waitForNewLuckyInventoryUID(
            rarity,
            before,
            INVENTORY_CONFIRM_TIMEOUT
        )

    if newBox then
        return newBox, "collected"
    end

    return nil, "deposited but inventory UID not confirmed"
end

local function acquireWorldBatch(
    rarity,
    wantedCount
)
    wantedCount =
        math.max(
            1,
            math.min(
                BATCH_SIZE,
                tonumber(wantedCount)
                    or BATCH_SIZE
            )
        )

    local collected = {}
    local seen = {}

    local emptyScans = 0
    local maxEmptyScans = 5

    while enabled
        and #collected < wantedCount
    do
        local box, reason =
            stealOneWorldLuckyBlock(
                rarity
            )

        if box then
            local key =
                tostring(box.uid)

            if not seen[key] then
                seen[key] = true
                table.insert(collected, box)
            end

            emptyScans = 0

            Status.Text =
                string.format(
                    "%s | stolen %d/%d",
                    rarity,
                    #collected,
                    wantedCount
                )

            task.wait(BETWEEN_STEALS)
        else
            emptyScans += 1

            Status.Text =
                string.format(
                    "%s | no target (%d/%d) | %s",
                    rarity,
                    emptyScans,
                    maxEmptyScans,
                    tostring(reason)
                )

            if emptyScans >= maxEmptyScans then
                break
            end

            task.wait(NO_TARGET_RETRY_DELAY)
        end
    end

    return collected
end

-- ============================================================
-- DYNAMIC FREE STANDS
-- ============================================================

local function isOccupied(
    slotName,
    plotSlimes,
    liveFolder,
    stand
)
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

    if liveFolder
        and liveFolder:FindFirstChild(slotName)
    then
        return true
    end

    if stand then
        local main =
            stand:FindFirstChild("Main")

        local holder =
            main and main:FindFirstChild("Holder")

        local prompt =
            holder and holder:FindFirstChild("Pick Up")

        if prompt
            and prompt:IsA("ProximityPrompt")
            and prompt.Enabled
        then
            return true
        end
    end

    return false
end

local function getAvailableSlots()
    -- NO 1-100 cap.
    local data = getData()

    local plotSlimes =
        (data and data.PlotSlimes)
        or {}

    local plot = getMyPlot()

    local liveFolder =
        getPlayerSlimesFolder()

    local free = {}

    if not plot then
        return free
    end

    local stands =
        plot:FindFirstChild("Stands")

    if not stands then
        return free
    end

    for _, stand in ipairs(stands:GetChildren()) do
        if stand:IsA("Model") then
            local slotName =
                tostring(stand.Name)

            if not isOccupied(
                slotName,
                plotSlimes,
                liveFolder,
                stand
            ) then
                table.insert(free, {
                    name = slotName,
                    num =
                        tonumber(slotName)
                        or math.huge,
                    stand = stand,
                })
            end
        end
    end

    table.sort(free, function(a, b)
        if a.num ~= b.num then
            return a.num < b.num
        end

        return tostring(a.name)
            < tostring(b.name)
    end)

    return free
end

local function getStandCFrame(stand)
    if not stand or not stand.Parent then
        return nil
    end

    local part =
        stand.PrimaryPart
        or stand:FindFirstChild("Main")
        or stand:FindFirstChildWhichIsA(
            "BasePart",
            true
        )

    if part and part:IsA("BasePart") then
        return part.CFrame
    end

    if part and part:IsA("Model") then
        local sub =
            part.PrimaryPart
            or part:FindFirstChildWhichIsA(
                "BasePart",
                true
            )

        if sub then
            return sub.CFrame
        end
    end

    return nil
end

local function teleportToStand(stand)
    local r = root()
    local cf = getStandCFrame(stand)

    if not r or not cf then
        return false
    end

    r.CFrame =
        cf * CFrame.new(0, 3, 3)

    r.AssemblyLinearVelocity =
        Vector3.zero

    r.AssemblyAngularVelocity =
        Vector3.zero

    return true
end

local function findPlacedSlotByUID(data, uid)
    if uid == nil
        or not data
        or type(data.PlotSlimes) ~= "table"
    then
        return nil, nil
    end

    local wanted = tostring(uid)

    for slotKey, entry
        in pairs(data.PlotSlimes)
    do
        if type(entry) == "table" then
            local entryUID =
                getEntryUID(entry)

            if entryUID ~= nil
                and tostring(entryUID) == wanted
            then
                return tostring(slotKey), entry
            end
        end
    end

    return nil, nil
end

local function getPlacedEntryAtSlot(slotName)
    local data = getData()
    local plotSlimes =
        data and data.PlotSlimes

    if type(plotSlimes) ~= "table" then
        return nil
    end

    return
        plotSlimes[tostring(slotName)]
        or plotSlimes[tonumber(slotName)]
end

-- ============================================================
-- PLACE STOLEN BOX
-- ============================================================

local function placeLuckyBox(box, slot)
    if not enabled then
        return false, "stopped"
    end

    if not PlaceRemote then
        return false, "Place Slime missing"
    end

    if not box
        or box.uid == nil
        or not slot
        or not slot.stand
    then
        return false, "bad box/slot"
    end

    for attempt = 1, 5 do
        if not enabled then
            return false, "stopped"
        end

        if not teleportToStand(slot.stand) then
            return false, "stand teleport failed"
        end

        task.wait(STAND_TELEPORT_SETTLE)

        pcall(function()
            PlaceRemote:FireServer(
                tostring(slot.name),
                box.uid
            )
        end)

        local deadline =
            os.clock()
            + PLACE_CONFIRM_TIMEOUT

        while enabled
            and os.clock() < deadline
        do
            local data = getData()

            local placedSlot =
                findPlacedSlotByUID(
                    data,
                    box.uid
                )

            if placedSlot then
                return true, placedSlot
            end

            task.wait(0.06)
        end
    end

    return false, "place not confirmed"
end

-- ============================================================
-- OPEN BATCH
-- ============================================================

local function openBatch(targets)
    if not OpenRemote then
        return false
    end

    for round = 1, OPEN_SPAM_ROUNDS do
        if not enabled then
            return false
        end

        for _, target in ipairs(targets) do
            pcall(function()
                OpenRemote:FireServer(
                    tostring(target.slot)
                )
            end)
        end

        if round < OPEN_SPAM_ROUNDS then
            task.wait(OPEN_SPAM_GAP)
        end
    end

    return true
end

local function waitForGeneratedSlime(target)
    local deadline =
        os.clock()
        + GENERATED_WAIT_TIMEOUT

    while enabled
        and os.clock() < deadline
    do
        local entry =
            getPlacedEntryAtSlot(
                target.slot
            )

        if type(entry) == "table" then
            local currentUID =
                getEntryUID(entry)

            if currentUID ~= nil
                and tostring(currentUID)
                    ~= tostring(target.boxUID)
            then
                local def =
                    resolveSlimeDefinition(entry)

                if not isLuckyInventoryEntry(
                    entry,
                    def
                ) then
                    return {
                        slot =
                            tostring(target.slot),
                        uid = currentUID,
                        entry = entry,
                        def = def,
                    }
                end
            end
        end

        task.wait(0.08)
    end

    return nil
end

-- ============================================================
-- PICK GENERATED SLIME
-- ============================================================

local function inventoryHasUID(uid)
    local data = getData()
    local inventory =
        data and data.Inventory

    if type(inventory) ~= "table" then
        return false
    end

    local wanted = tostring(uid)

    for _, entry in pairs(inventory) do
        if type(entry) == "table" then
            local entryUID =
                getEntryUID(entry)

            if entryUID ~= nil
                and tostring(entryUID) == wanted
            then
                return true
            end
        end
    end

    return false
end

local function pickupGenerated(generated)
    if not generated
        or not generated.slot
        or generated.uid == nil
    then
        return false
    end

    local plot = getMyPlot()

    local stands =
        plot and plot:FindFirstChild("Stands")

    local stand =
        stands
        and stands:FindFirstChild(
            tostring(generated.slot)
        )

    for attempt = 1, 5 do
        if not enabled then
            return false
        end

        if stand then
            teleportToStand(stand)
            task.wait(STAND_TELEPORT_SETTLE)
        end

        pcall(function()
            PickupRemote:FireServer(
                tostring(generated.slot)
            )
        end)

        local deadline =
            os.clock()
            + PICKUP_CONFIRM_TIMEOUT

        while enabled
            and os.clock() < deadline
        do
            if inventoryHasUID(
                generated.uid
            ) then
                return true
            end

            local data = getData()

            local stillPlaced =
                findPlacedSlotByUID(
                    data,
                    generated.uid
                )

            if not stillPlaced then
                local small =
                    os.clock() + 0.40

                while enabled
                    and os.clock() < small
                do
                    if inventoryHasUID(
                        generated.uid
                    ) then
                        return true
                    end

                    task.wait(0.05)
                end
            end

            task.wait(0.06)
        end
    end

    return false
end

-- ============================================================
-- SELL EXACT GENERATED UID
-- ============================================================

local function sellGeneratedUID(uid)
    if uid == nil then
        return false
    end

    local deadline =
        os.clock()
        + SELL_CONFIRM_TIMEOUT

    local lastFire = 0

    while enabled
        and os.clock() < deadline
    do
        if not inventoryHasUID(uid) then
            return true
        end

        if os.clock() - lastFire >= 0.06 then
            lastFire = os.clock()

            pcall(function()
                SellRemote:FireServer(uid)
            end)
        end

        task.wait(0.04)
    end

    return not inventoryHasUID(uid)
end

-- ============================================================
-- ONE BATCH
-- ============================================================

local function processBatch(
    rarity,
    wantedCount
)
    wantedCount =
        math.max(
            1,
            math.min(
                BATCH_SIZE,
                tonumber(wantedCount)
                    or BATCH_SIZE
            )
        )

    -- --------------------------------------------------------
    -- STEP 1: STEAL WORLD BOXES
    -- --------------------------------------------------------

    Status.Text =
        string.format(
            "%s | stealing up to %d world boxes",
            rarity,
            wantedCount
        )

    local boxes =
        acquireWorldBatch(
            rarity,
            wantedCount
        )

    if #boxes == 0 then
        return 0, 0, 0
    end

    -- --------------------------------------------------------
    -- STEP 2: FIND FREE STANDS
    -- --------------------------------------------------------

    local freeSlots =
        getAvailableSlots()

    if #freeSlots == 0 then
        Status.Text =
            rarity
            .. " | stolen "
            .. tostring(#boxes)
            .. " but no free stands"

        return 0, 0, 0
    end

    local count =
        math.min(
            #boxes,
            #freeSlots
        )

    local targets = {}

    -- --------------------------------------------------------
    -- STEP 3: PLACE STOLEN BOX UIDS
    -- --------------------------------------------------------

    for i = 1, count do
        if not enabled then
            break
        end

        local box = boxes[i]
        local slot = freeSlots[i]

        Status.Text =
            string.format(
                "%s | placing stolen box %d/%d",
                rarity,
                i,
                count
            )

        local placed, placedSlot =
            placeLuckyBox(
                box,
                slot
            )

        if placed then
            table.insert(
                targets,
                {
                    rarity = rarity,
                    boxUID = box.uid,
                    boxName = box.name,
                    slot =
                        tostring(
                            placedSlot
                            or slot.name
                        ),
                    stand = slot.stand,
                }
            )
        end

        task.wait(BETWEEN_BOXES)
    end

    if #targets == 0 then
        return 0, 0, 0
    end

    -- --------------------------------------------------------
    -- STEP 4: OPEN
    -- --------------------------------------------------------

    Status.Text =
        string.format(
            "%s | opening %d",
            rarity,
            #targets
        )

    openBatch(targets)

    -- --------------------------------------------------------
    -- STEP 5: EXACT 1 SECOND WAIT
    -- --------------------------------------------------------

    Status.Text =
        string.format(
            "%s | opened %d | waiting 1 second",
            rarity,
            #targets
        )

    task.wait(OPEN_TO_SELL_DELAY)

    -- --------------------------------------------------------
    -- STEP 6: CAPTURE GENERATED SLIMES
    -- --------------------------------------------------------

    local generated = {}

    for _, target in ipairs(targets) do
        if not enabled then
            break
        end

        local result =
            waitForGeneratedSlime(
                target
            )

        if result then
            table.insert(
                generated,
                result
            )
        end
    end

    -- --------------------------------------------------------
    -- STEP 7: PICK GENERATED SLIMES
    -- --------------------------------------------------------

    local picked = {}

    for i, result in ipairs(generated) do
        if not enabled then
            break
        end

        Status.Text =
            string.format(
                "%s | picking result %d/%d",
                rarity,
                i,
                #generated
            )

        if pickupGenerated(result) then
            table.insert(
                picked,
                result
            )
        end
    end

    -- --------------------------------------------------------
    -- STEP 8: SELL ONLY THOSE GENERATED UIDS
    -- --------------------------------------------------------

    local sold = 0

    for i, result in ipairs(picked) do
        if not enabled then
            break
        end

        Status.Text =
            string.format(
                "%s | selling result %d/%d",
                rarity,
                i,
                #picked
            )

        if sellGeneratedUID(
            result.uid
        ) then
            sold += 1
        end
    end

    return
        #targets,
        #generated,
        sold
end

-- ============================================================
-- MAIN RARITY LOOP
-- ============================================================

task.spawn(function()
    while Gui.Parent do
        if not enabled then
            busy = false
            task.wait(0.15)
            continue
        end

        if busy then
            task.wait(0.05)
            continue
        end

        busy = true

        local ok, err =
            xpcall(function()
                if not resolveRemotes() then
                    Status.Text =
                        "Waiting for game remotes..."

                    task.wait(0.50)
                    return
                end

                _Lib = _G._Lib or _Lib

                local rarity =
                    RARITY_ORDER[
                        currentRarityIndex
                    ]

                Status.Text =
                    string.format(
                        "%s | collect up to %d -> place -> open -> sell",
                        rarity,
                        BATCH_SIZE
                    )

                -- EXACT SEQUENCE:
                -- ONE rarity only.
                -- processBatch() itself blocks until the entire current batch
                -- has completed:
                --
                -- steal current rarity
                -- -> place
                -- -> open
                -- -> wait 1 second
                -- -> identify generated slimes
                -- -> pick generated slimes
                -- -> sell generated UIDs
                --
                -- No next-rarity pickup can start before this returns.
                local placedCount,
                    generatedCount,
                    soldCount =
                    processBatch(
                        rarity,
                        BATCH_SIZE
                    )

                if not enabled then
                    return
                end

                Status.Text =
                    string.format(
                        "%s COMPLETE | boxes %d | generated %d | sold %d",
                        rarity,
                        placedCount,
                        generatedCount,
                        soldCount
                    )

                -- Only NOW can the next rarity begin.
                if placedCount == 0 then
                    task.wait(EMPTY_RARITY_DELAY)
                else
                    task.wait(BETWEEN_BATCHES)
                end

                currentRarityIndex += 1

                if currentRarityIndex
                    > #RARITY_ORDER
                then
                    currentRarityIndex = 1

                    Status.Text =
                        "All rarities complete -> restarting Common"

                    task.wait(FULL_LOOP_DELAY)
                else
                    Status.Text =
                        "Next rarity -> "
                        .. tostring(
                            RARITY_ORDER[
                                currentRarityIndex
                            ]
                        )
                end
            end, debug.traceback)

        if not ok then
            warn(
                "[LuckyBoxWorldCycle] ERROR:",
                err
            )

            Status.Text =
                "Error: "
                .. tostring(err):match("^[^\n]+")

            task.wait(0.50)
        end

        busy = false
        task.wait(0.05)
    end
end)

updateToggle()

print("====================================================")
print("[LuckyBoxWorldCycle] Loaded")
print("NO SERVER HOP")
print("WORLD STEAL = teleport -> ProximityPrompt -> own base -> confirm UID")
print("ONE batch per rarity | up to 10 boxes")
print("STRICT: collect rarity -> place -> open -> wait 1s -> pick generated -> sell -> NEXT rarity")
print("Dynamic stands | NO 100-slot limit")
print("====================================================")