-- Lucky Box Rarity Cycle
-- Process up to 20 Lucky Blocks per rarity, 10 at a time.
--
-- Flow:
--   Common -> Rare -> Epic -> ... -> Alternative -> loop back to Common
--
-- For each rarity:
--   1) Select up to 10 matching Lucky Blocks from Inventory
--   2) Teleport beside each free stand and Place Slime(slot, boxUID)
--   3) Open those exact placed Lucky Blocks
--   4) Wait 1 second
--   5) Identify ONLY the new slimes generated in those batch slots
--   6) Pick up those exact generated slimes
--   7) Sell those exact inventory UIDs using "Sell Slime From Inventory"
--   8) Repeat until up to 20 boxes of the current rarity were processed
--   9) Move to the next rarity
--
-- Dynamic stands: NO fixed 100-slot limit.
-- Server remains authoritative for placement/open/pickup/sell.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)

-- ============================================================
-- CONFIG
-- ============================================================

local BOXES_PER_RARITY = 20
local BATCH_SIZE = 10

local TELEPORT_SETTLE = 0.04
local PLACE_CONFIRM_TIMEOUT = 2.0

local OPEN_SPAM_ROUNDS = 8
local OPEN_SPAM_GAP = 0.05

local OPEN_TO_SELL_DELAY = 1.0

local GENERATED_WAIT_TIMEOUT = 4.0
local PICKUP_CONFIRM_TIMEOUT = 3.0
local SELL_CONFIRM_TIMEOUT = 4.0

local BETWEEN_BOXES = 0.03
local BETWEEN_BATCHES = 0.20
local EMPTY_RARITY_DELAY = 0.20
local FULL_LOOP_DELAY = 1.0

-- Least Lucky Block sell value -> highest.
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
-- SMALL GUI
-- ============================================================

pcall(function()
    local old = PlayerGui and PlayerGui:FindFirstChild("LuckyBoxRarityCycleGui")
    if old then
        old:Destroy()
    end

    old = CoreGui:FindFirstChild("LuckyBoxRarityCycleGui")
    if old then
        old:Destroy()
    end
end)

local Gui = Instance.new("ScreenGui")
Gui.Name = "LuckyBoxRarityCycleGui"
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
Frame.Size = UDim2.new(0, 260, 0, 118)
Frame.Position = UDim2.new(0, 20, 0.5, -59)
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
Title.Text = "Lucky Box Rarity Cycle"
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
Status.Size = UDim2.new(1, -20, 0, 42)
Status.Position = UDim2.new(0, 10, 0, 70)
Status.BackgroundTransparency = 1
Status.Text = "Ready | 20 per rarity | batches of 10"
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
            "Starting from "
            .. tostring(RARITY_ORDER[currentRarityIndex])
            .. "..."
    else
        Status.Text = "Stopped"
    end
end)

-- ============================================================
-- REMOTE / DATA HELPERS
-- ============================================================

local function resolveExactRemoteEvent(name)
    local direct =
        ReplicatedStorage
        :FindFirstChild("SharedModules")

    direct =
        direct
        and direct:FindFirstChild("Network")

    direct =
        direct
        and direct:FindFirstChild("Remotes")

    direct =
        direct
        and direct:FindFirstChild(name)

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
-- CURRENT CATALOG / LUCKY BLOCK IDENTIFICATION
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

    -- Current game catalog.
    local catalog =
        _Lib
        and _Lib.SoccerGameCatalog
        and _Lib.SoccerGameCatalog.SoccerPlayerCatalog

    if type(catalog) == "table" then
        local def =
            catalog[id]
            or catalog[tostring(id)]
            or catalog[tonumber(id)]

        if def then
            return def
        end
    end

    -- Legacy database fallback.
    local db =
        _Lib
        and _Lib.Database
        and _Lib.Database.Slimes

    if type(db) == "table" then
        return
            db[id]
            or db[tostring(id)]
            or db[tonumber(id)]
    end

    return nil
end

local function normalizeRarity(value)
    local rarity = tostring(value or "")

    if rarity == "Player God"
        or rarity == "Soccer God"
    then
        return "Slime God"
    end

    if string.lower(rarity) == "limited" then
        return "LIMITED"
    end

    return rarity
end

local function isLuckyBlockEntry(entry, def)
    if type(entry) ~= "table" then
        return false
    end

    if entry.production_is_lucky_block == true then
        return true
    end

    if def
        and string.lower(tostring(def.Type or ""))
            == "lucky block"
    then
        return true
    end

    local function hasLucky(value)
        local s = string.lower(tostring(value or ""))

        return
            s:find("lucky block", 1, true) ~= nil
            or s:find("lucky", 1, true) ~= nil
            or s:find("box", 1, true) ~= nil
            or s:find("crate", 1, true) ~= nil
    end

    return
        hasLucky(def and def.Type)
        or hasLucky(def and def.Name)
        or hasLucky(entry.Type)
        or hasLucky(entry.type)
        or hasLucky(entry.Name)
        or hasLucky(entry.name)
end

local function getLuckyBlockRarity(entry, def)
    return normalizeRarity(
        (def and (def.Rarity or def.rarity))
        or entry.Rarity
        or entry.rarity
    )
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
        string.lower(
            normalizeRarity(rarity)
        )

    for _, entry in pairs(inventory) do
        if type(entry) == "table" then
            local uid = getEntryUID(entry)

            if uid ~= nil
                and not seen[tostring(uid)]
            then
                local def =
                    resolveSlimeDefinition(entry)

                if isLuckyBlockEntry(entry, def) then
                    local entryRarity =
                        string.lower(
                            getLuckyBlockRarity(
                                entry,
                                def
                            )
                        )

                    if entryRarity == wanted then
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

-- ============================================================
-- DYNAMIC STANDS / OCCUPANCY
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
    -- NO fixed numeric limit.
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
    -- Same mechanism as the working Place Boxes script.
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
    local char = LocalPlayer.Character

    local root =
        char
        and char:FindFirstChild(
            "HumanoidRootPart"
        )

    local cf =
        getStandCFrame(stand)

    if not root or not cf then
        return false
    end

    root.CFrame =
        cf * CFrame.new(0, 3, 3)

    root.AssemblyLinearVelocity =
        Vector3.zero

    root.AssemblyAngularVelocity =
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
-- PLACE BOX
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

    -- Exact working box mechanism:
    -- teleport near target stand -> tiny settle -> fire slot + UID.
    for attempt = 1, 5 do
        if not enabled then
            return false, "stopped"
        end

        if not teleportToStand(slot.stand) then
            return false, "teleport failed"
        end

        task.wait(TELEPORT_SETTLE)

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

            -- The opened result must not be the original box UID.
            if currentUID ~= nil
                and tostring(currentUID)
                    ~= tostring(target.boxUID)
            then
                local def =
                    resolveSlimeDefinition(entry)

                if not isLuckyBlockEntry(
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
-- PICK GENERATED SLIME -> INVENTORY
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

        -- Teleport beside the exact generated slime stand for reliability.
        if stand then
            teleportToStand(stand)
            task.wait(TELEPORT_SETTLE)
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
                -- Allow inventory replication a short moment.
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
-- SELL EXACT GENERATED INVENTORY UID
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
-- ONE BATCH: up to 10 boxes
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

    local boxes =
        getInventoryLuckyBoxesByRarity(
            rarity
        )

    if #boxes == 0 then
        return 0, 0, 0
    end

    local freeSlots =
        getAvailableSlots()

    if #freeSlots == 0 then
        Status.Text =
            rarity
            .. " | no free stands"

        return 0, 0, 0
    end

    local count =
        math.min(
            wantedCount,
            #boxes,
            #freeSlots
        )

    local targets = {}

    -- PLACE
    for i = 1, count do
        if not enabled then
            break
        end

        local box =
            boxes[i]

        local slot =
            freeSlots[i]

        Status.Text =
            string.format(
                "%s | placing %d/%d",
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

    -- OPEN exact batch slots
    Status.Text =
        string.format(
            "%s | opening %d boxes",
            rarity,
            #targets
        )

    openBatch(targets)

    -- User-requested wait after opening.
    Status.Text =
        string.format(
            "%s | opened %d | wait 1s",
            rarity,
            #targets
        )

    task.wait(OPEN_TO_SELL_DELAY)

    -- Find only the newly-generated slimes in this batch's formerly-free slots.
    local generated = {}

    for _, target in ipairs(targets) do
        if not enabled then
            break
        end

        local result =
            waitForGeneratedSlime(target)

        if result then
            table.insert(generated, result)
        end
    end

    -- PICK UP generated slimes so the inventory-only sell remote can be used.
    local picked = {}

    for i, result in ipairs(generated) do
        if not enabled then
            break
        end

        Status.Text =
            string.format(
                "%s | pickup result %d/%d",
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

    -- SELL exact generated UIDs only.
    local sold = 0

    for i, result in ipairs(picked) do
        if not enabled then
            break
        end

        Status.Text =
            string.format(
                "%s | selling %d/%d",
                rarity,
                i,
                #picked
            )

        if sellGeneratedUID(result.uid) then
            sold += 1
        end
    end

    return
        #targets,
        #generated,
        sold
end

-- ============================================================
-- RARITY CYCLE WORKER
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

                local processedForRarity = 0
                local soldForRarity = 0

                local value =
                    LUCKY_BLOCK_VALUES[rarity]
                    or 0

                Status.Text =
                    string.format(
                        "%s ($%s) | starting",
                        rarity,
                        tostring(value)
                    )

                -- Up to 20 per rarity, 10 at a time.
                while enabled
                    and processedForRarity
                        < BOXES_PER_RARITY
                do
                    local remaining =
                        BOXES_PER_RARITY
                        - processedForRarity

                    local wanted =
                        math.min(
                            BATCH_SIZE,
                            remaining
                        )

                    local available =
                        getInventoryLuckyBoxesByRarity(
                            rarity
                        )

                    if #available == 0 then
                        break
                    end

                    local placedCount,
                        generatedCount,
                        soldCount =
                        processBatch(
                            rarity,
                            wanted
                        )

                    processedForRarity +=
                        placedCount

                    soldForRarity +=
                        soldCount

                    Status.Text =
                        string.format(
                            "%s | %d/%d boxes | sold %d",
                            rarity,
                            processedForRarity,
                            BOXES_PER_RARITY,
                            soldForRarity
                        )

                    if placedCount == 0 then
                        break
                    end

                    task.wait(BETWEEN_BATCHES)
                end

                if enabled then
                    Status.Text =
                        string.format(
                            "%s done | boxes %d/%d | sold %d | next...",
                            rarity,
                            processedForRarity,
                            BOXES_PER_RARITY,
                            soldForRarity
                        )

                    if processedForRarity == 0 then
                        task.wait(
                            EMPTY_RARITY_DELAY
                        )
                    else
                        task.wait(
                            BETWEEN_BATCHES
                        )
                    end

                    currentRarityIndex += 1

                    if currentRarityIndex
                        > #RARITY_ORDER
                    then
                        currentRarityIndex = 1

                        Status.Text =
                            "Full rarity loop complete -> Common"

                        task.wait(
                            FULL_LOOP_DELAY
                        )
                    end
                end
            end, debug.traceback)

        if not ok then
            warn(
                "[LuckyBoxRarityCycle] ERROR:",
                err
            )

            Status.Text =
                "Error: "
                .. tostring(err):match(
                    "^[^\n]+"
                )

            task.wait(0.50)
        end

        busy = false
        task.wait(0.05)
    end
end)

updateToggle()

print("====================================================")
print("[LuckyBoxRarityCycle] Loaded")
print("20 boxes per rarity | 10 per batch")
print("Place -> Open -> wait 1s -> Pickup generated -> Sell exact UID")
print("Dynamic stands | no fixed 100-slot limit")
print("====================================================")