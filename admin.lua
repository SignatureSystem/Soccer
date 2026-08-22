-- Slime Value Browser - LIVE CURRENT VALUE + Multi Select + Auto Equip + JAPAN
-- Batch pick/place/sell: parallel remote spam (not sequential)
-- Sell = inventory only (Sell Button per INV row + Sell Selected). Never sells placed.
-- Inventory + Placed slimes using the same CURRENT FINAL cash/s calculation
-- as the existing Place Slimes feature.
-- Added / fixed:
--   * checkbox on every row
--   * Select All / Clear All for currently visible rows
--   * Pick Up Selected for checked placed slimes
--   * Pick Up Remote also uses checked rows when any are marked
--   * batch pickup confirms each slime one-by-one before continuing
--   * single pickup automatically equips the picked slime
--   * batch pickup equips the LAST successfully picked slime after the batch
--   * inventory selection can Place in Free Slot using the game's Place Slime remote
--   * Exclude None checkbox beside Mutation filter hides unmutated slimes
--   * live Available Slots counter in the top-right

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)

local ALL_RARITIES = {
    "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret",
    "Slime God", "Divine", "Exclusive", "LIMITED", "OG", "Champions",
    "Spain", "Icons", "Japan",
}

local ALL_MUTATIONS = {
    "Golden", "Diamond", "Rainbow", "Cursed", "Divine", "Fallen",
    "Volcanic", "Toxic", "Taco", "Cosmic", "Slimey",
}

local state = {
    lib = nil,
    shared = nil,
    database = nil,
    modulesReady = false,
    pickupRemote = nil,
    placeRemote = nil,
    sellRemote = nil,
    sortMode = "Highest First",
    rarity = "All",
    mutation = "All",
    excludeNone = false,
    source = "All",
    search = "",
    selected = nil,
    autoRefresh = true,
    refreshInterval = 1.0,
    rows = {},

    -- NEW
    selectedChecks = {},
    visibleItems = {},
    batchBusy = false,
}

-- ============================================================
-- DATA / GAME HELPERS
-- ============================================================

local function resolveExactRemoteEvent(name)
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") and obj.Name == name then
            return obj
        end
    end
    return nil
end

local function bootstrapGameModules()
    local globalLib = _G._Lib
    if globalLib then
        state.lib = globalLib

        if globalLib.Shared then
            state.shared = globalLib.Shared
        end

        if globalLib.Database then
            state.database = globalLib.Database
        end
    end

    local sharedModules =
        ReplicatedStorage:FindFirstChild("SharedModules")
        or ReplicatedStorage:WaitForChild("SharedModules", 10)

    if sharedModules then
        if not state.shared then
            local sharedModule = sharedModules:FindFirstChild("Shared")

            if sharedModule and sharedModule:IsA("ModuleScript") then
                local ok, result = pcall(require, sharedModule)

                if ok and type(result) == "table" then
                    state.shared = result
                else
                    warn("[SlimeValueBrowser] Could not require Shared:", result)
                end
            end
        end

        if not state.database then
            local databaseModule = sharedModules:FindFirstChild("Database")

            if databaseModule and databaseModule:IsA("ModuleScript") then
                local ok, result = pcall(require, databaseModule)

                if ok and type(result) == "table" then
                    state.database = result
                else
                    warn("[SlimeValueBrowser] Could not require Database:", result)
                end
            end
        end
    end

    state.modulesReady =
        type(state.shared) == "table"
        and type(state.database) == "table"
        and type(state.database.Slimes) == "table"

    return state.modulesReady
end

local function getData()
    bootstrapGameModules()

    local lib = state.lib or _G._Lib
    state.lib = lib

    if lib and lib.Data then
        local ok, data = pcall(function()
            return lib.Data:Get()
        end)
        if ok and data then
            return data
        end
    end

    local sharedModules = ReplicatedStorage:FindFirstChild("SharedModules")
    local network = sharedModules and sharedModules:FindFirstChild("Network")
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

local function getBaseLevel(data)
    data = data or getData()
    if data and type(data.BaseLevel) == "number" then
        return data.BaseLevel
    end
    return tonumber(LocalPlayer:GetAttribute("BaseLevel")) or 0
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

-- Same occupied/free-slot checks used by the main Place Slimes feature.
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

    if playerSlimesFolder
        and playerSlimesFolder:FindFirstChild(slotName)
    then
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

        -- Ignore unrelated children that are not actual stands.
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

local function getRebirthCashMultiplier(playerData)
    bootstrapGameModules()

    local database = state.database
    if not playerData or not database or type(database.Rebirths) ~= "table" then
        return 1
    end

    local rebirth = playerData.Rebirth
    local def =
        database.Rebirths[rebirth]
        or database.Rebirths[tostring(rebirth)]

    return (def and tonumber(def.CashMulti)) or 1
end

local function resolveSlimeDefinition(entry)
    if type(entry) ~= "table" then
        return nil
    end

    bootstrapGameModules()

    local slimeId =
        entry.id
        or entry.Id
        or entry.slimeId
        or entry.slimeID

    local database = state.database
    local slimes = database and database.Slimes

    if slimeId == nil or type(slimes) ~= "table" then
        return nil
    end

    return slimes[slimeId]
        or slimes[tostring(slimeId)]
        or slimes[tonumber(slimeId)]
end

local function getBaseProductionMPS(entry, def)
    local baseMps = def and tonumber(def.MoneyPerSecond) or nil

    if baseMps == nil and entry then
        baseMps =
            tonumber(entry.production_mps)
            or tonumber(entry.money_per_second)
            or tonumber(entry.MoneyPerSecond)
            or tonumber(entry.mps)
            or tonumber(entry.base_mps)
    end

    return math.max(0, tonumber(baseMps) or 0)
end

-- Same final-current-cash path as the working Place Slimes logic.
local function calculateOwnedSlimeEarnings(entry, def, playerData)
    if type(entry) ~= "table" then
        return 0
    end

    bootstrapGameModules()

    local shared = state.shared
    local baseMps = getBaseProductionMPS(entry, def)
    local level = math.max(1, tonumber(entry.level or entry.Level) or 1)
    local rebirthMulti = getRebirthCashMultiplier(playerData)
    local earnings = baseMps

    if shared
        and typeof(shared.getRebirthScaledEarnings) == "function"
    then
        local ok, result = pcall(function()
            return shared.getRebirthScaledEarnings(
                baseMps,
                level,
                rebirthMulti
            )
        end)

        if ok and tonumber(result) then
            earnings = tonumber(result)
        else
            warn(
                "[SlimeValueBrowser] getRebirthScaledEarnings failed for",
                tostring(entry.id or entry.Id),
                result
            )
        end
    end

    local mutation = entry.mutation or entry.Mutation or "None"
    local eventMutations =
        entry.event_mutations
        or entry.EventMutations
        or {}

    local mutationMulti = 1

    if shared
        and typeof(shared.getMutationMulti) == "function"
    then
        local ok, result = pcall(function()
            return shared.getMutationMulti(
                mutation,
                eventMutations
            )
        end)

        if ok and tonumber(result) then
            mutationMulti = tonumber(result)
        else
            warn(
                "[SlimeValueBrowser] getMutationMulti failed for",
                tostring(entry.id or entry.Id),
                result
            )
        end
    end

    earnings = earnings * mutationMulti

    local inviteBonus =
        tonumber(playerData and playerData.InviteBonusMult) or 0

    local friendBonus =
        tonumber(LocalPlayer:GetAttribute("FriendPresenceBonus")) or 0

    local adminProductionMult =
        tonumber(Workspace:GetAttribute("AdminProductionMult")) or 1

    earnings =
        earnings
        * (1 + inviteBonus + friendBonus)
        * adminProductionMult

    earnings = tonumber(earnings) or 0

    if earnings ~= earnings then
        earnings = 0
    end

    return math.max(0, earnings)
end

local function isLuckyEntry(entry, def)
    local function hasLuckyWord(value)
        local s = string.lower(tostring(value or ""))
        return s:find("lucky", 1, true)
            or s:find("box", 1, true)
            or s:find("crate", 1, true)
    end

    if def then
        if tostring(def.Type or "") == "Lucky Block" then
            return true
        end
        if hasLuckyWord(def.Type) or hasLuckyWord(def.Category) or hasLuckyWord(def.Name) then
            return true
        end
    end

    if type(entry) == "table" then
        if entry.production_is_lucky_block == true then
            return true
        end
        if hasLuckyWord(entry.Type)
            or hasLuckyWord(entry.type)
            or hasLuckyWord(entry.Category)
            or hasLuckyWord(entry.category)
        then
            return true
        end
    end

    return false
end

local function normalizeRarity(value)
    local rarity = tostring(value or "Unknown")
    if rarity == "Player God" then
        rarity = "Slime God"
    end
    return rarity
end

local function getMutationInfo(entry)
    local base = entry and (entry.mutation or entry.Mutation) or nil
    local event = entry and (entry.event_mutations or entry.EventMutations) or nil

    local names = {}
    local seen = {}

    local function add(value)
        if value == nil then return end
        local text = tostring(value)
        local lower = string.lower(text)
        if text == "" or lower == "none" or lower == "normal" or text == "{}" then
            return
        end
        if not seen[lower] then
            seen[lower] = true
            table.insert(names, text)
        end
    end

    add(base)

    if type(event) == "table" then
        for k, v in pairs(event) do
            if type(k) == "string" and v == true then
                add(k)
            elseif type(v) == "string" then
                add(v)
            elseif type(k) == "string" then
                add(k)
            end
        end
    elseif event ~= nil then
        add(event)
    end

    if #names == 0 then
        return "None", {}, true
    end

    local lookup = {}
    for _, name in ipairs(names) do
        lookup[string.lower(name)] = true
    end

    return table.concat(names, "+"), lookup, false
end

local function getEntryUID(entry)
    if type(entry) ~= "table" then return nil end
    return entry.uid or entry.UID or entry.slimeUID
end

local function resolveRarityForEntry(entry, def, slotKey)
    local rarity =
        (def and (def.Rarity or def.rarity))
        or (entry and (entry.Rarity or entry.rarity))

    if (rarity == nil or tostring(rarity) == "")
        and slotKey ~= nil
    then
        local liveFolder = getPlayerSlimesFolder()
        local model =
            liveFolder
            and liveFolder:FindFirstChild(tostring(slotKey))

        if model then
            rarity =
                model:GetAttribute("Rarity")
                or model:GetAttribute("rarity")

            if rarity == nil then
                for _, obj in ipairs(model:GetDescendants()) do
                    if obj:IsA("TextLabel")
                        and obj.Name == "Rarity"
                        and obj.Text ~= ""
                    then
                        rarity = obj.Text
                        break
                    end
                end
            end
        end
    end

    return normalizeRarity(rarity)
end

local function formatCash(value)
    value = tonumber(value) or 0
    local abs = math.abs(value)
    local suffixes = {
        {1e33, "Dc"}, {1e30, "No"}, {1e27, "Oc"}, {1e24, "Sp"},
        {1e21, "Sx"}, {1e18, "Qi"}, {1e15, "Qa"}, {1e12, "T"},
        {1e9, "B"}, {1e6, "M"}, {1e3, "K"},
    }

    for _, pair in ipairs(suffixes) do
        if abs >= pair[1] then
            local n = value / pair[1]
            if math.abs(n) >= 100 then
                return string.format("%.0f%s", n, pair[2])
            elseif math.abs(n) >= 10 then
                return string.format("%.1f%s", n, pair[2])
            else
                return string.format("%.2f%s", n, pair[2])
            end
        end
    end

    if abs >= 100 then
        return string.format("%.0f", value)
    elseif abs >= 10 then
        return string.format("%.1f", value)
    else
        return string.format("%.2f", value)
    end
end

local function collectSlimes()
    local playerData = getData()
    local result = {}
    local placedUIDs = {}

    if not playerData then
        return result, "Player data unavailable"
    end

    bootstrapGameModules()

    if not state.modulesReady then
        return result,
            "Game Shared/Database modules are not ready yet; refusing to show base-value estimates."
    end

    local plotSlimes = playerData.PlotSlimes
    if type(plotSlimes) == "table" then
        for slotKey, entry in pairs(plotSlimes) do
            if type(entry) == "table" then
                local def = resolveSlimeDefinition(entry)
                if not isLuckyEntry(entry, def) then
                    local uid = getEntryUID(entry)
                    if uid ~= nil then
                        placedUIDs[tostring(uid)] = true
                    end

                    local rarity =
                        resolveRarityForEntry(entry, def, slotKey)
                    local mutationDisplay, mutationLookup, noMutation = getMutationInfo(entry)
                    local value = calculateOwnedSlimeEarnings(entry, def, playerData)

                    table.insert(result, {
                        source = "Placed",
                        sourceLabel = "S" .. tostring(slotKey),
                        slot = tostring(slotKey),
                        uid = uid,
                        entry = entry,
                        def = def,
                        value = value,
                        rarity = rarity,
                        mutation = mutationDisplay,
                        mutationLookup = mutationLookup,
                        noMutation = noMutation,
                        level = math.max(1, tonumber(entry.level or entry.Level) or 1),
                        displayName = tostring(
                            (def and def.Name)
                            or entry.Name
                            or entry.name
                            or entry.id
                            or "Unknown"
                        ),
                    })
                end
            end
        end
    end

    local inventory = playerData.Inventory
    if type(inventory) == "table" then
        for _, entry in pairs(inventory) do
            if type(entry) == "table" then
                local uid = getEntryUID(entry)
                local isAlreadyPlaced = uid ~= nil and placedUIDs[tostring(uid)] == true

                if not isAlreadyPlaced then
                    local def = resolveSlimeDefinition(entry)
                    if not isLuckyEntry(entry, def) then
                        local rarity =
                            resolveRarityForEntry(entry, def, nil)
                        local mutationDisplay, mutationLookup, noMutation = getMutationInfo(entry)
                        local value = calculateOwnedSlimeEarnings(entry, def, playerData)

                        table.insert(result, {
                            source = "Inventory",
                            sourceLabel = "INV",
                            slot = nil,
                            uid = uid,
                            entry = entry,
                            def = def,
                            value = value,
                            rarity = rarity,
                            mutation = mutationDisplay,
                            mutationLookup = mutationLookup,
                            noMutation = noMutation,
                            level = math.max(1, tonumber(entry.level or entry.Level) or 1),
                            displayName = tostring(
                                (def and def.Name)
                                or entry.Name
                                or entry.name
                                or entry.id
                                or "Unknown"
                            ),
                        })
                    end
                end
            end
        end
    end

    return result, nil
end

local function passesFilters(item)
    if state.source ~= "All" and item.source ~= state.source then
        return false
    end

    if state.rarity ~= "All" and string.lower(item.rarity) ~= string.lower(state.rarity) then
        return false
    end

    if state.mutation ~= "All" then
        if state.mutation == "None" then
            if not item.noMutation then
                return false
            end
        elseif not item.mutationLookup[string.lower(state.mutation)] then
            return false
        end
    end

    -- Optional quick filter: hide all slimes that have no mutation.
    if state.excludeNone and item.noMutation then
        return false
    end

    local query = string.lower(state.search or "")
    if query ~= "" then
        local haystack = string.lower(table.concat({
            item.displayName or "",
            item.rarity or "",
            item.mutation or "",
            item.source or "",
            item.sourceLabel or "",
            tostring(item.slot or ""),
            tostring(item.uid or ""),
        }, " "))

        if not haystack:find(query, 1, true) then
            return false
        end
    end

    return true
end

local function sortItems(items)
    table.sort(items, function(a, b)
        local av = tonumber(a.value) or 0
        local bv = tonumber(b.value) or 0

        if av ~= bv then
            if state.sortMode == "Lowest First" then
                return av < bv
            end
            return av > bv
        end

        if a.source ~= b.source then
            return a.source == "Placed"
        end

        if a.level ~= b.level then
            return a.level > b.level
        end

        return tostring(a.displayName) < tostring(b.displayName)
    end)
end

local function getToolByUID(uid)
    if uid == nil then return nil end
    local key = tostring(uid)

    local function scan(container)
        if not container then return nil end
        for _, obj in ipairs(container:GetChildren()) do
            if obj:IsA("Tool") and tostring(obj:GetAttribute("slimeUID")) == key then
                return obj
            end
        end
        return nil
    end

    return scan(LocalPlayer.Character) or scan(LocalPlayer:FindFirstChild("Backpack"))
end

-- NEW: common equip helper that can wait for a freshly picked slime Tool.
local function equipToolByUID(uid, timeout)
    if uid == nil then
        return false, "UID unavailable"
    end

    timeout = tonumber(timeout) or 3
    local deadline = os.clock() + timeout
    local tool

    while os.clock() < deadline do
        tool = getToolByUID(uid)
        if tool then
            break
        end
        task.wait(0.05)
    end

    if not tool then
        return false, "Picked, but Tool not found"
    end

    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not character or not humanoid then
        return false, "Character unavailable"
    end

    pcall(function()
        humanoid:UnequipTools()
    end)

    task.wait(0.05)

    pcall(function()
        humanoid:EquipTool(tool)
    end)

    -- executor fallback
    if tool.Parent ~= character then
        pcall(function()
            tool.Parent = character
        end)
    end

    task.wait(0.05)

    if tool.Parent == character then
        return true, "Equipped"
    end

    return false, "Equip failed"
end

local function equipInventoryItem(item)
    if not item or item.source ~= "Inventory" then
        return false, "Not an inventory slime"
    end

    return equipToolByUID(item.uid, 0.5)
end

local function teleportToPlacedItem(item)
    if not item or item.source ~= "Placed" or not item.slot then
        return false, "Not a placed slime"
    end

    local plot = getMyPlot()
    local stands = plot and plot:FindFirstChild("Stands")
    local stand = stands and stands:FindFirstChild(tostring(item.slot))
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    if not stand or not root then
        return false, "Slot/character unavailable"
    end

    local target = stand.PrimaryPart or stand:FindFirstChildWhichIsA("BasePart", true)
    if not target then
        return false, "Slot has no target part"
    end

    root.CFrame = target.CFrame * CFrame.new(0, 3, 5)
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    return true, "Teleported"
end

local function getItemKey(item)
    if not item then
        return nil
    end

    -- UID is the stable identity.  Using only source+slot made a checked
    -- slime fragile when live refresh changed it from Placed -> Inventory.
    if item.uid ~= nil then
        return "UID|" .. tostring(item.uid)
    end

    return table.concat({
        tostring(item.source or ""),
        tostring(item.slot or ""),
        tostring(item.displayName or ""),
    }, "|")
end

-- ============================================================
-- GUI
-- ============================================================

pcall(function()
    local old = PlayerGui and PlayerGui:FindFirstChild("SlimeValueBrowser")
    if old then old:Destroy() end
    old = CoreGui:FindFirstChild("SlimeValueBrowser")
    if old then old:Destroy() end
end)

local Gui = Instance.new("ScreenGui")
Gui.Name = "SlimeValueBrowser"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.DisplayOrder = 1000
Gui.IgnoreGuiInset = true
pcall(function() Gui.Parent = PlayerGui or CoreGui end)
if not Gui.Parent then Gui.Parent = CoreGui end

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 760, 0, 520)
Main.Position = UDim2.new(0.5, -380, 0.5, -260)
Main.BackgroundColor3 = Color3.fromRGB(23, 23, 29)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = Gui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
local MainStroke = Instance.new("UIStroke", Main)
MainStroke.Color = Color3.fromRGB(75, 75, 95)
MainStroke.Thickness = 1.5

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -54, 0, 34)
Title.Position = UDim2.new(0, 14, 0, 6)
Title.BackgroundTransparency = 1
Title.Text = "Slime Value Browser"
Title.TextColor3 = Color3.fromRGB(245, 245, 250)
Title.TextSize = 16
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Main

-- Live free-slot counter in the top-right.
-- Counts only unlocked stands that are currently not occupied.
local AvailableSlotsLabel = Instance.new("TextLabel")
AvailableSlotsLabel.Size = UDim2.new(0, 170, 0, 30)
AvailableSlotsLabel.Position = UDim2.new(1, -216, 0, 8)
AvailableSlotsLabel.BackgroundColor3 = Color3.fromRGB(31, 31, 40)
AvailableSlotsLabel.BackgroundTransparency = 0.08
AvailableSlotsLabel.BorderSizePixel = 0
AvailableSlotsLabel.Text = "Available Slots: ..."
AvailableSlotsLabel.TextColor3 = Color3.fromRGB(135, 235, 165)
AvailableSlotsLabel.TextSize = 10
AvailableSlotsLabel.Font = Enum.Font.GothamBold
AvailableSlotsLabel.TextXAlignment = Enum.TextXAlignment.Center
AvailableSlotsLabel.Parent = Main
Instance.new("UICorner", AvailableSlotsLabel).CornerRadius = UDim.new(0, 6)

local Close = Instance.new("TextButton")
Close.Size = UDim2.new(0, 30, 0, 30)
Close.Position = UDim2.new(1, -38, 0, 8)
Close.BackgroundColor3 = Color3.fromRGB(50, 35, 40)
Close.BorderSizePixel = 0
Close.Text = "Ã—"
Close.TextColor3 = Color3.fromRGB(255, 135, 145)
Close.TextSize = 20
Close.Font = Enum.Font.GothamBold
Close.Parent = Main
Instance.new("UICorner", Close).CornerRadius = UDim.new(0, 7)
Close.MouseButton1Click:Connect(function() Gui:Destroy() end)

local function makeDropButton(x, width, text)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, width, 0, 28)
    b.Position = UDim2.new(0, x, 0, 46)
    b.BackgroundColor3 = Color3.fromRGB(36, 36, 47)
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = Color3.fromRGB(225, 225, 235)
    b.TextSize = 10
    b.Font = Enum.Font.GothamBold
    b.ZIndex = 30
    b.Parent = Main
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local SortBtn = makeDropButton(14, 104, "Sort: High v")
local RarityBtn = makeDropButton(124, 104, "Rarity: All v")
local MutationBtn = makeDropButton(234, 120, "Mutation: All v")

-- NEW: quick checkbox beside Mutation filter.
-- When enabled, slimes whose mutation is None are hidden.
local ExcludeNoneBtn = Instance.new("TextButton")
ExcludeNoneBtn.Size = UDim2.new(0, 92, 0, 28)
ExcludeNoneBtn.Position = UDim2.new(0, 360, 0, 46)
ExcludeNoneBtn.BackgroundColor3 = Color3.fromRGB(36, 36, 47)
ExcludeNoneBtn.BorderSizePixel = 0
ExcludeNoneBtn.Text = "[ ] Exclude None"
ExcludeNoneBtn.TextColor3 = Color3.fromRGB(225, 225, 235)
ExcludeNoneBtn.TextSize = 9
ExcludeNoneBtn.Font = Enum.Font.GothamBold
ExcludeNoneBtn.Parent = Main
Instance.new("UICorner", ExcludeNoneBtn).CornerRadius = UDim.new(0, 6)

local SourceBtn = makeDropButton(458, 88, "Source: All v")

local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(0, 100, 0, 28)
SearchBox.Position = UDim2.new(0, 552, 0, 46)
SearchBox.BackgroundColor3 = Color3.fromRGB(36, 36, 47)
SearchBox.BorderSizePixel = 0
SearchBox.PlaceholderText = "Search name / slot..."
SearchBox.Text = ""
SearchBox.ClearTextOnFocus = false
SearchBox.TextColor3 = Color3.fromRGB(240, 240, 245)
SearchBox.PlaceholderColor3 = Color3.fromRGB(135, 135, 150)
SearchBox.TextSize = 10
SearchBox.Font = Enum.Font.Gotham
SearchBox.Parent = Main
Instance.new("UICorner", SearchBox).CornerRadius = UDim.new(0, 6)

local RefreshBtn = Instance.new("TextButton")
RefreshBtn.Size = UDim2.new(0, 86, 0, 28)
RefreshBtn.Position = UDim2.new(0, 658, 0, 46)
RefreshBtn.BackgroundColor3 = Color3.fromRGB(30, 49, 61)
RefreshBtn.BorderSizePixel = 0
RefreshBtn.Text = "Refresh"
RefreshBtn.TextColor3 = Color3.fromRGB(165, 220, 255)
RefreshBtn.TextSize = 10
RefreshBtn.Font = Enum.Font.GothamBold
RefreshBtn.Parent = Main
Instance.new("UICorner", RefreshBtn).CornerRadius = UDim.new(0, 6)

local Header = Instance.new("Frame")
Header.Size = UDim2.new(0, 526, 0, 26)
Header.Position = UDim2.new(0, 14, 0, 84)
Header.BackgroundColor3 = Color3.fromRGB(31, 31, 40)
Header.BorderSizePixel = 0
Header.Parent = Main
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 5)

-- NEW: Select All / Clear All checkbox.
local SelectAllBtn = Instance.new("TextButton")
SelectAllBtn.Size = UDim2.new(0, 24, 0, 20)
SelectAllBtn.Position = UDim2.new(0, 4, 0, 3)
SelectAllBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 57)
SelectAllBtn.BorderSizePixel = 0
SelectAllBtn.Text = "[ ]"
SelectAllBtn.TextColor3 = Color3.fromRGB(210, 210, 225)
SelectAllBtn.TextSize = 15
SelectAllBtn.Font = Enum.Font.GothamBold
SelectAllBtn.Parent = Header
Instance.new("UICorner", SelectAllBtn).CornerRadius = UDim.new(0, 4)

local function headerLabel(text, x, w)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0, w, 1, 0)
    l.Position = UDim2.new(0, x, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.fromRGB(185, 185, 200)
    l.TextSize = 9
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = Header
end

headerLabel("PLAYER", 34, 150)
headerLabel("CASH/S", 184, 86)
headerLabel("RARITY", 270, 84)
headerLabel("MUTATION", 354, 104)
headerLabel("SRC", 458, 58)

local List = Instance.new("ScrollingFrame")
List.Size = UDim2.new(0, 526, 0, 366)
List.Position = UDim2.new(0, 14, 0, 114)
List.BackgroundColor3 = Color3.fromRGB(27, 27, 35)
List.BorderSizePixel = 0
List.ScrollBarThickness = 5
List.CanvasSize = UDim2.new(0, 0, 0, 0)
List.AutomaticCanvasSize = Enum.AutomaticSize.Y
List.Parent = Main
Instance.new("UICorner", List).CornerRadius = UDim.new(0, 7)

local ListLayout = Instance.new("UIListLayout")
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding = UDim.new(0, 2)
ListLayout.Parent = List

local Detail = Instance.new("Frame")
Detail.Size = UDim2.new(0, 198, 0, 366)
Detail.Position = UDim2.new(0, 548, 0, 114)
Detail.BackgroundColor3 = Color3.fromRGB(30, 30, 39)
Detail.BorderSizePixel = 0
Detail.Visible = false
Detail.Parent = Main
Instance.new("UICorner", Detail).CornerRadius = UDim.new(0, 8)
local DetailStroke = Instance.new("UIStroke", Detail)
DetailStroke.Color = Color3.fromRGB(70, 70, 90)
DetailStroke.Thickness = 1

local DetailTitle = Instance.new("TextLabel")
DetailTitle.Size = UDim2.new(1, -20, 0, 38)
DetailTitle.Position = UDim2.new(0, 10, 0, 10)
DetailTitle.BackgroundTransparency = 1
DetailTitle.Text = "Selected Slime"
DetailTitle.TextColor3 = Color3.fromRGB(245, 245, 250)
DetailTitle.TextSize = 12
DetailTitle.Font = Enum.Font.GothamBold
DetailTitle.TextWrapped = true
DetailTitle.TextXAlignment = Enum.TextXAlignment.Left
DetailTitle.TextYAlignment = Enum.TextYAlignment.Top
DetailTitle.Parent = Detail

local DetailInfo = Instance.new("TextLabel")
DetailInfo.Size = UDim2.new(1, -20, 0, 180)
DetailInfo.Position = UDim2.new(0, 10, 0, 54)
DetailInfo.BackgroundTransparency = 1
DetailInfo.Text = ""
DetailInfo.TextColor3 = Color3.fromRGB(195, 195, 210)
DetailInfo.TextSize = 10
DetailInfo.Font = Enum.Font.Gotham
DetailInfo.TextWrapped = true
DetailInfo.TextXAlignment = Enum.TextXAlignment.Left
DetailInfo.TextYAlignment = Enum.TextYAlignment.Top
DetailInfo.Parent = Detail

local PrimaryAction = Instance.new("TextButton")
PrimaryAction.Size = UDim2.new(1, -20, 0, 34)
PrimaryAction.Position = UDim2.new(0, 10, 1, -84)
PrimaryAction.BackgroundColor3 = Color3.fromRGB(35, 57, 43)
PrimaryAction.BorderSizePixel = 0
PrimaryAction.Text = "Pick Up Remote"
PrimaryAction.TextColor3 = Color3.fromRGB(125, 255, 160)
PrimaryAction.TextSize = 11
PrimaryAction.Font = Enum.Font.GothamBold
PrimaryAction.Parent = Detail
Instance.new("UICorner", PrimaryAction).CornerRadius = UDim.new(0, 7)

local SecondaryAction = Instance.new("TextButton")
SecondaryAction.Size = UDim2.new(1, -20, 0, 30)
SecondaryAction.Position = UDim2.new(0, 10, 1, -44)
SecondaryAction.BackgroundColor3 = Color3.fromRGB(35, 43, 57)
SecondaryAction.BorderSizePixel = 0
SecondaryAction.Text = "Go To Slot"
SecondaryAction.TextColor3 = Color3.fromRGB(160, 205, 255)
SecondaryAction.TextSize = 10
SecondaryAction.Font = Enum.Font.GothamBold
SecondaryAction.Parent = Detail
Instance.new("UICorner", SecondaryAction).CornerRadius = UDim.new(0, 7)

-- NEW: batch pickup button.
local PickupSelectedBtn = Instance.new("TextButton")
PickupSelectedBtn.Size = UDim2.new(0, 120, 0, 24)
PickupSelectedBtn.Position = UDim2.new(0, 14, 0, 486)
PickupSelectedBtn.BackgroundColor3 = Color3.fromRGB(35, 57, 43)
PickupSelectedBtn.BorderSizePixel = 0
PickupSelectedBtn.Text = "Pick Up Selected"
PickupSelectedBtn.TextColor3 = Color3.fromRGB(125, 255, 160)
PickupSelectedBtn.TextSize = 9
PickupSelectedBtn.Font = Enum.Font.GothamBold
PickupSelectedBtn.Parent = Main
Instance.new("UICorner", PickupSelectedBtn).CornerRadius = UDim.new(0, 6)

local PlaceSelectedBtn = Instance.new("TextButton")
PlaceSelectedBtn.Size = UDim2.new(0, 120, 0, 24)
PlaceSelectedBtn.Position = UDim2.new(0, 172, 0, 486)
PlaceSelectedBtn.BackgroundColor3 = Color3.fromRGB(37, 47, 62)
PlaceSelectedBtn.BorderSizePixel = 0
PlaceSelectedBtn.Text = "Place Selected"
PlaceSelectedBtn.TextColor3 = Color3.fromRGB(160, 205, 255)
PlaceSelectedBtn.TextSize = 9
PlaceSelectedBtn.Font = Enum.Font.GothamBold
PlaceSelectedBtn.Parent = Main
Instance.new("UICorner", PlaceSelectedBtn).CornerRadius = UDim.new(0, 6)

local SellSelectedBtn = Instance.new("TextButton")
SellSelectedBtn.Size = UDim2.new(0, 120, 0, 24)
SellSelectedBtn.Position = UDim2.new(0, 300, 0, 486)
SellSelectedBtn.BackgroundColor3 = Color3.fromRGB(62, 38, 38)
SellSelectedBtn.BorderSizePixel = 0
SellSelectedBtn.Text = "Sell Selected"
SellSelectedBtn.TextColor3 = Color3.fromRGB(255, 150, 150)
SellSelectedBtn.TextSize = 9
SellSelectedBtn.Font = Enum.Font.GothamBold
SellSelectedBtn.Parent = Main
Instance.new("UICorner", SellSelectedBtn).CornerRadius = UDim.new(0, 6)

local Summary = Instance.new("TextLabel")
Summary.Size = UDim2.new(0, 360, 0, 24)
Summary.Position = UDim2.new(0, 180, 0, 486)
Summary.BackgroundTransparency = 1
Summary.Text = "Loading..."
Summary.TextColor3 = Color3.fromRGB(165, 165, 180)
Summary.TextSize = 9
Summary.Font = Enum.Font.Gotham
Summary.TextXAlignment = Enum.TextXAlignment.Left
Summary.Parent = Main

local AutoRefreshBtn = Instance.new("TextButton")
AutoRefreshBtn.Size = UDim2.new(0, 198, 0, 24)
AutoRefreshBtn.Position = UDim2.new(0, 548, 0, 486)
AutoRefreshBtn.BackgroundColor3 = Color3.fromRGB(30, 55, 41)
AutoRefreshBtn.BorderSizePixel = 0
AutoRefreshBtn.Text = "Live Refresh: ON"
AutoRefreshBtn.TextColor3 = Color3.fromRGB(125, 255, 160)
AutoRefreshBtn.TextSize = 9
AutoRefreshBtn.Font = Enum.Font.GothamBold
AutoRefreshBtn.Parent = Main
Instance.new("UICorner", AutoRefreshBtn).CornerRadius = UDim.new(0, 6)

-- ============================================================
-- DROPDOWNS
-- ============================================================

local openDropdown = nil
local function createDropdown(button, options, onSelect)
    local drop = Instance.new("ScrollingFrame")
    drop.Size = UDim2.new(
        0,
        button.AbsoluteSize.X > 0 and button.AbsoluteSize.X or button.Size.X.Offset,
        0,
        math.min(210, #options * 25)
    )
    drop.Position = UDim2.new(0, button.Position.X.Offset, 0, 76)
    drop.BackgroundColor3 = Color3.fromRGB(28, 28, 37)
    drop.BorderSizePixel = 0
    drop.ScrollBarThickness = 4
    drop.CanvasSize = UDim2.new(0, 0, 0, #options * 25)
    drop.Visible = false
    drop.ZIndex = 60
    drop.Parent = Main
    Instance.new("UICorner", drop).CornerRadius = UDim.new(0, 6)

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = drop

    for i, option in ipairs(options) do
        local item = Instance.new("TextButton")
        item.Size = UDim2.new(1, -4, 0, 24)
        item.BackgroundColor3 = Color3.fromRGB(38, 38, 49)
        item.BorderSizePixel = 0
        item.Text = "  " .. tostring(option)
        item.TextColor3 = Color3.fromRGB(225, 225, 235)
        item.TextSize = 10
        item.Font = Enum.Font.Gotham
        item.TextXAlignment = Enum.TextXAlignment.Left
        item.LayoutOrder = i
        item.ZIndex = 61
        item.Parent = drop

        item.MouseButton1Click:Connect(function()
            drop.Visible = false
            openDropdown = nil
            onSelect(option)
        end)
    end

    button.MouseButton1Click:Connect(function()
        if openDropdown and openDropdown ~= drop then
            openDropdown.Visible = false
        end
        drop.Visible = not drop.Visible
        openDropdown = drop.Visible and drop or nil
    end)

    return drop
end

local refreshList

local sortOptions = {"Highest First", "Lowest First"}
local rarityOptions = {"All"}
for _, value in ipairs(ALL_RARITIES) do table.insert(rarityOptions, value) end
local mutationOptions = {"All", "None"}
for _, value in ipairs(ALL_MUTATIONS) do table.insert(mutationOptions, value) end
local sourceOptions = {"All", "Placed", "Inventory"}

createDropdown(SortBtn, sortOptions, function(value)
    state.sortMode = value
    SortBtn.Text = value == "Highest First" and "Sort: High v" or "Sort: Low v"
    if refreshList then refreshList() end
end)

createDropdown(RarityBtn, rarityOptions, function(value)
    state.rarity = value
    RarityBtn.Text = "Rarity: " .. tostring(value) .. " v"
    if refreshList then refreshList() end
end)

createDropdown(MutationBtn, mutationOptions, function(value)
    state.mutation = value
    MutationBtn.Text = "Mutation: " .. tostring(value) .. " v"
    if refreshList then refreshList() end
end)

ExcludeNoneBtn.MouseButton1Click:Connect(function()
    state.excludeNone = not state.excludeNone

    if state.excludeNone then
        ExcludeNoneBtn.Text = "[X] Exclude None"
        ExcludeNoneBtn.BackgroundColor3 = Color3.fromRGB(35, 74, 49)
        ExcludeNoneBtn.TextColor3 = Color3.fromRGB(125, 255, 160)
    else
        ExcludeNoneBtn.Text = "[ ] Exclude None"
        ExcludeNoneBtn.BackgroundColor3 = Color3.fromRGB(36, 36, 47)
        ExcludeNoneBtn.TextColor3 = Color3.fromRGB(225, 225, 235)
    end

    if refreshList then
        refreshList()
    end
end)

createDropdown(SourceBtn, sourceOptions, function(value)
    state.source = value
    SourceBtn.Text = "Source: " .. tostring(value) .. " v"
    if refreshList then refreshList() end
end)

-- ============================================================
-- DETAILS / ROWS
-- ============================================================

local function updateDetail(item)
    state.selected = item

    if not item then
        Detail.Visible = false
        return
    end

    Detail.Visible = true
    DetailTitle.Text = item.displayName
    DetailInfo.Text = table.concat({
        "Source: " .. item.source .. (item.slot and (" (Slot " .. item.slot .. ")") or ""),
        "Cash/s: " .. formatCash(item.value),
        "Rarity: " .. item.rarity,
        "Mutation: " .. item.mutation,
        "Level: " .. tostring(item.level),
        "UID: " .. tostring(item.uid or "N/A"),
    }, "\n\n")

    if item.source == "Placed" then
        PrimaryAction.Visible = true
        SecondaryAction.Visible = true
        PrimaryAction.Text = "Pick Up Remote"
        PrimaryAction.BackgroundColor3 = Color3.fromRGB(35, 57, 43)
        PrimaryAction.TextColor3 = Color3.fromRGB(125, 255, 160)
        SecondaryAction.Text = "Go To Slot"
        SecondaryAction.BackgroundColor3 = Color3.fromRGB(35, 43, 57)
        SecondaryAction.TextColor3 = Color3.fromRGB(160, 205, 255)
    else
        PrimaryAction.Visible = true
        SecondaryAction.Visible = true
        PrimaryAction.Text = "Equip / Select"
        PrimaryAction.BackgroundColor3 = Color3.fromRGB(37, 47, 62)
        PrimaryAction.TextColor3 = Color3.fromRGB(165, 210, 255)
        SecondaryAction.Text = "Place in Free Slot"
        SecondaryAction.BackgroundColor3 = Color3.fromRGB(57, 45, 32)
        SecondaryAction.TextColor3 = Color3.fromRGB(255, 210, 135)
    end
end

local function clearRows()
    for _, row in ipairs(state.rows) do
        if row and row.Parent then
            row:Destroy()
        end
    end
    table.clear(state.rows)
end

local function countVisibleSelected()
    local count = 0
    for _, item in ipairs(state.visibleItems) do
        if state.selectedChecks[getItemKey(item)] then
            count += 1
        end
    end
    return count
end

local function updateSelectAllVisual()
    local total = #state.visibleItems
    local checked = countVisibleSelected()

    if total > 0 and checked == total then
        SelectAllBtn.Text = "[X]"
        SelectAllBtn.BackgroundColor3 = Color3.fromRGB(35, 74, 49)
    elseif checked > 0 then
        SelectAllBtn.Text = "-"
        SelectAllBtn.BackgroundColor3 = Color3.fromRGB(65, 58, 38)
    else
        SelectAllBtn.Text = "[ ]"
        SelectAllBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 57)
    end
end

local function createRow(item, order)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, -6, 0, 31)
    row.BackgroundColor3 = Color3.fromRGB(33, 33, 43)
    row.BorderSizePixel = 0
    row.Text = ""
    row.AutoButtonColor = false
    row.LayoutOrder = order
    row.Parent = List
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

    local key = getItemKey(item)

    local Check = Instance.new("TextButton")
    Check.Size = UDim2.new(0, 24, 0, 24)
    Check.Position = UDim2.new(0, 4, 0.5, -12)
    Check.BackgroundColor3 = Color3.fromRGB(46, 46, 59)
    Check.BorderSizePixel = 0
    Check.Text = ""
    Check.TextColor3 = Color3.fromRGB(125, 255, 160)
    Check.TextSize = 15
    Check.Font = Enum.Font.GothamBold
    Check.ZIndex = 5
    Check.Parent = row
    Instance.new("UICorner", Check).CornerRadius = UDim.new(0, 4)

    local function updateCheck()
        local selected = state.selectedChecks[key] == true
        Check.Text = selected and "[X]" or ""
        Check.BackgroundColor3 = selected
            and Color3.fromRGB(35, 74, 49)
            or Color3.fromRGB(46, 46, 59)
    end

    Check.MouseButton1Click:Connect(function()
        if state.selectedChecks[key] then
            state.selectedChecks[key] = nil
        else
            state.selectedChecks[key] = true
        end

        updateCheck()
        updateSelectAllVisual()
    end)

    updateCheck()

    local function cell(text, x, w, align, color)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0, w, 1, 0)
        label.Position = UDim2.new(0, x, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = color or Color3.fromRGB(225, 225, 235)
        label.TextSize = 9
        label.Font = Enum.Font.Gotham
        label.TextXAlignment = align or Enum.TextXAlignment.Left
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.Parent = row
        return label
    end

    cell(item.displayName, 34, 146, Enum.TextXAlignment.Left)
    cell(formatCash(item.value), 180, 86, Enum.TextXAlignment.Left, Color3.fromRGB(135, 235, 165))
    cell(item.rarity, 266, 84, Enum.TextXAlignment.Left)
    cell(item.mutation, 350, 104, Enum.TextXAlignment.Left)
    cell(
        item.sourceLabel,
        454,
        48,
        Enum.TextXAlignment.Left,
        item.source == "Placed"
            and Color3.fromRGB(255, 205, 125)
            or Color3.fromRGB(160, 205, 255)
    )

    -- Sell is inventory-only. Placed rows never get a sell button.
    if item.source == "Inventory" and item.uid ~= nil then
        local SellBtn = Instance.new("TextButton")
        SellBtn.Size = UDim2.new(0, 36, 0, 20)
        SellBtn.Position = UDim2.new(0, 504, 0.5, -10)
        SellBtn.BackgroundColor3 = Color3.fromRGB(70, 40, 42)
        SellBtn.BorderSizePixel = 0
        SellBtn.Text = "Sell"
        SellBtn.TextColor3 = Color3.fromRGB(255, 160, 160)
        SellBtn.TextSize = 9
        SellBtn.Font = Enum.Font.GothamBold
        SellBtn.ZIndex = 6
        SellBtn.Parent = row
        Instance.new("UICorner", SellBtn).CornerRadius = UDim.new(0, 4)

        SellBtn.MouseButton1Click:Connect(function()
            if state.batchBusy then
                return
            end

            SellBtn.Text = "..."
            task.spawn(function()
                local ok, message = sellOneInventory(item)
                if SellBtn and SellBtn.Parent then
                    SellBtn.Text = ok and "OK" or "Sell"
                end
                if type(message) == "string" and message ~= "Started" and Summary then
                    Summary.Text = tostring(message)
                end
            end)
        end)
    end

    row.MouseEnter:Connect(function()
        row.BackgroundColor3 = Color3.fromRGB(42, 42, 54)
    end)

    row.MouseLeave:Connect(function()
        if state.selected == item then
            row.BackgroundColor3 = Color3.fromRGB(43, 49, 59)
        else
            row.BackgroundColor3 = Color3.fromRGB(33, 33, 43)
        end
    end)

    row.MouseButton1Click:Connect(function()
        for _, existing in ipairs(state.rows) do
            if existing and existing.Parent then
                existing.BackgroundColor3 = Color3.fromRGB(33, 33, 43)
            end
        end
        row.BackgroundColor3 = Color3.fromRGB(43, 49, 59)
        updateDetail(item)
    end)

    table.insert(state.rows, row)
end

-- ============================================================
-- REFRESH
-- ============================================================

refreshList = function()
    if not Gui.Parent then return end

    local allItems, err = collectSlimes()
    local filtered = {}

    for _, item in ipairs(allItems) do
        if passesFilters(item) then
            table.insert(filtered, item)
        end
    end

    sortItems(filtered)
    state.visibleItems = filtered

    clearRows()

    for i, item in ipairs(filtered) do
        createRow(item, i)
    end

    local placedCount = 0
    local invCount = 0
    for _, item in ipairs(allItems) do
        if item.source == "Placed" then
            placedCount += 1
        else
            invCount += 1
        end
    end

    -- Keep the free-slot counter live. getAvailableSlots() uses the same
    -- unlocked + occupied checks as Place in Free Slot.
    local slotOk, freeSlots = pcall(getAvailableSlots)
    if slotOk and type(freeSlots) == "table" then
        AvailableSlotsLabel.Text = "Available Slots: " .. tostring(#freeSlots)
        if #freeSlots > 0 then
            AvailableSlotsLabel.TextColor3 = Color3.fromRGB(135, 235, 165)
        else
            AvailableSlotsLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
        end
    else
        AvailableSlotsLabel.Text = "Available Slots: ?"
        AvailableSlotsLabel.TextColor3 = Color3.fromRGB(210, 190, 130)
    end

    if err then
        Summary.Text = tostring(err)
    else
        Summary.Text = string.format(
            "%d/%d | P:%d I:%d | %s | LIVE",
            #filtered,
            #allItems,
            placedCount,
            invCount,
            state.sortMode == "Highest First" and "HIGH" or "LOW"
        )
    end

    updateSelectAllVisual()

    -- If the selected placed slime disappeared after pickup/refresh,
    -- close the detail panel.
    if state.selected then
        local stillExists = false
        for _, item in ipairs(allItems) do
            if state.selected.source == item.source
                and tostring(state.selected.uid or "") == tostring(item.uid or "")
                and tostring(state.selected.slot or "") == tostring(item.slot or "")
            then
                stillExists = true
                break
            end
        end
        if not stillExists then
            updateDetail(nil)
        end
    end
end

-- ============================================================
-- SELECT ALL / CLEAR ALL
-- ============================================================

SelectAllBtn.MouseButton1Click:Connect(function()
    local total = #state.visibleItems
    if total == 0 then
        return
    end

    local selected = countVisibleSelected()
    local shouldClear = selected == total

    for _, item in ipairs(state.visibleItems) do
        local key = getItemKey(item)
        if shouldClear then
            state.selectedChecks[key] = nil
        else
            state.selectedChecks[key] = true
        end
    end

    refreshList()
end)

-- ============================================================
-- FILTER / REFRESH EVENTS
-- ============================================================

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    state.search = SearchBox.Text
    refreshList()
end)

RefreshBtn.MouseButton1Click:Connect(function()
    RefreshBtn.Text = "Refreshing..."
    refreshList()
    task.delay(0.25, function()
        if RefreshBtn and RefreshBtn.Parent then
            RefreshBtn.Text = "Refresh"
        end
    end)
end)

AutoRefreshBtn.MouseButton1Click:Connect(function()
    state.autoRefresh = not state.autoRefresh
    AutoRefreshBtn.Text = state.autoRefresh and "Live Refresh: ON" or "Live Refresh: OFF"
    AutoRefreshBtn.TextColor3 = state.autoRefresh
        and Color3.fromRGB(125, 255, 160)
        or Color3.fromRGB(255, 135, 145)
    AutoRefreshBtn.BackgroundColor3 = state.autoRefresh
        and Color3.fromRGB(30, 55, 41)
        or Color3.fromRGB(55, 35, 40)
end)

-- ============================================================
-- PICKUP / PLACE ACTION HELPERS
-- ============================================================

local function getHumanoid()
    local character = LocalPlayer.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function unequipAllTools()
    local humanoid = getHumanoid()
    if humanoid then
        pcall(function()
            humanoid:UnequipTools()
        end)
    end
end

local function findPlacedEntryByUID(playerData, uid)
    if uid == nil or not playerData or type(playerData.PlotSlimes) ~= "table" then
        return nil, nil
    end

    local wanted = tostring(uid)

    for slotKey, entry in pairs(playerData.PlotSlimes) do
        if type(entry) == "table" then
            local entryUID = getEntryUID(entry)
            if entryUID ~= nil and tostring(entryUID) == wanted then
                return tostring(slotKey), entry
            end
        end
    end

    return nil, nil
end

local function waitForPickupTransition(item, timeout)
    timeout = tonumber(timeout) or 3.5
    local deadline = os.clock() + timeout
    local lastDataCheck = 0

    while os.clock() < deadline do
        -- Strongest confirmation: exact slime Tool now exists locally.
        local tool = getToolByUID(item.uid)
        if tool then
            return true, tool
        end

        -- Also confirm against live PlotSlimes so a delayed Tool creation
        -- does not cause us to fire the next pickup too early.
        if os.clock() - lastDataCheck >= 0.20 then
            lastDataCheck = os.clock()
            local data = getData()
            local slot = findPlacedEntryByUID(data, item.uid)

            if not slot then
                -- Server has removed it from the stand. Give Backpack a brief
                -- chance to materialize the Tool, but pickup itself is confirmed.
                local smallDeadline = os.clock() + 0.45
                while os.clock() < smallDeadline do
                    tool = getToolByUID(item.uid)
                    if tool then
                        return true, tool
                    end
                    task.wait(0.05)
                end
                return true, nil
            end
        end

        task.wait(0.05)
    end

    return false, nil
end

local function pickupOnePlaced(item)
    if not item or item.source ~= "Placed" or not item.slot then
        return false, "Not a placed slime"
    end

    state.pickupRemote = state.pickupRemote or resolveExactRemoteEvent("Pickup Slime")
    if not state.pickupRemote then
        return false, "Pickup Remote Missing"
    end

    -- Do not carry the previously picked/equipped slime while asking the
    -- server to pick the next stand. This was the main batch-stall risk.
    unequipAllTools()
    task.wait(0.08)

    -- Reconfirm this exact UID is still placed and use its LIVE slot.
    local latestData = getData()
    local liveSlot = findPlacedEntryByUID(latestData, item.uid)
    if not liveSlot then
        -- It may already have been picked by an earlier action/refresh.
        if getToolByUID(item.uid) then
            state.selectedChecks[getItemKey(item)] = nil
            return true, "Already picked"
        end
        return false, "Slime is no longer placed"
    end

    local fired, err = pcall(function()
        state.pickupRemote:FireServer(tostring(liveSlot))
    end)

    if not fired then
        return false, tostring(err)
    end

    local confirmed = waitForPickupTransition(item, 3.5)
    if not confirmed then
        return false, "Pickup not confirmed"
    end

    state.selectedChecks[getItemKey(item)] = nil
    return true, "Picked"
end

local function getCheckedPlacedSnapshot()
    local currentItems = collectSlimes()
    local selectedPlaced = {}

    for _, current in ipairs(currentItems) do
        if current.source == "Placed"
            and state.selectedChecks[getItemKey(current)]
        then
            table.insert(selectedPlaced, current)
        end
    end

    sortItems(selectedPlaced)
    return selectedPlaced
end

local function getCheckedInventorySnapshot()
    local currentItems = collectSlimes()
    local selectedInv = {}

    for _, current in ipairs(currentItems) do
        if current.source == "Inventory"
            and state.selectedChecks[getItemKey(current)]
            and current.uid ~= nil
        then
            table.insert(selectedInv, current)
        end
    end

    sortItems(selectedInv)
    return selectedInv
end

local function setBatchButtonText(text)
    if PickupSelectedBtn and PickupSelectedBtn.Parent then
        PickupSelectedBtn.Text = text
    end

    if PlaceSelectedBtn and PlaceSelectedBtn.Parent then
        PlaceSelectedBtn.Text = text
    end

    if SellSelectedBtn and SellSelectedBtn.Parent then
        SellSelectedBtn.Text = text
    end

    if PrimaryAction and PrimaryAction.Parent and Detail.Visible then
        local selected = state.selected
        if selected and selected.source == "Placed" then
            PrimaryAction.Text = text
        end
    end
end

-- Parallel spam pickup: fire Pickup Slime for every checked slot repeatedly
-- until each UID is no longer placed (or timeout). Not sequential.
local function startBatchPickup(selectedPlaced)
    if state.batchBusy then
        return false, "Batch already running"
    end

    selectedPlaced = selectedPlaced or getCheckedPlacedSnapshot()

    if #selectedPlaced == 0 then
        return false, "No placed selected"
    end

    state.pickupRemote = state.pickupRemote or resolveExactRemoteEvent("Pickup Slime")
    if not state.pickupRemote then
        return false, "Pickup Remote Missing"
    end

    local targets = {}
    for _, item in ipairs(selectedPlaced) do
        table.insert(targets, {
            uid = item.uid,
            slot = item.slot,
            key = getItemKey(item),
            done = false,
        })
    end

    state.batchBusy = true
    unequipAllTools()

    task.spawn(function()
        local remote = state.pickupRemote
        local deadline = os.clock() + 12
        local lastFire = 0

        while Gui.Parent and os.clock() < deadline do
            local remaining = 0
            local data = getData()

            for _, t in ipairs(targets) do
                if not t.done then
                    local liveSlot = findPlacedEntryByUID(data, t.uid)
                    if not liveSlot then
                        t.done = true
                        state.selectedChecks[t.key] = nil
                    else
                        remaining += 1
                        t.slot = liveSlot
                    end
                end
            end

            if remaining == 0 then
                break
            end

            -- Spam all remaining slots every ~0.05s
            if os.clock() - lastFire >= 0.05 then
                lastFire = os.clock()
                for _, t in ipairs(targets) do
                    if not t.done and t.slot then
                        pcall(function()
                            remote:FireServer(tostring(t.slot))
                        end)
                    end
                end
            end

            setBatchButtonText(string.format("Spam pick %d left", remaining))
            task.wait(0.03)
        end

        local picked = 0
        for _, t in ipairs(targets) do
            if t.done then
                picked += 1
            end
        end

        setBatchButtonText("Picked " .. tostring(picked) .. "/" .. tostring(#targets))
        refreshList()
        task.wait(0.7)

        if PickupSelectedBtn and PickupSelectedBtn.Parent then
            PickupSelectedBtn.Text = "Pick Up Selected"
        end
        if PlaceSelectedBtn and PlaceSelectedBtn.Parent then
            PlaceSelectedBtn.Text = "Place Selected"
        end
        if SellSelectedBtn and SellSelectedBtn.Parent then
            SellSelectedBtn.Text = "Sell Selected"
        end
        if PrimaryAction and PrimaryAction.Parent and Detail.Visible then
            local selected = state.selected
            if selected and selected.source == "Placed" then
                PrimaryAction.Text = "Pick Up Remote"
            end
        end

        state.batchBusy = false
    end)

    return true, "Started"
end

-- Parallel spam place: assign free slots to checked inventory UIDs and
-- fire Place Slime repeatedly until each UID appears in PlotSlimes.
local function startBatchPlace(selectedInv)
    if state.batchBusy then
        return false, "Batch already running"
    end

    selectedInv = selectedInv or getCheckedInventorySnapshot()

    if #selectedInv == 0 then
        return false, "No inventory selected"
    end

    state.placeRemote = state.placeRemote or resolveExactRemoteEvent("Place Slime")
    if not state.placeRemote then
        return false, 'RemoteEvent "Place Slime" missing'
    end

    local freeSlots = getAvailableSlots()
    if #freeSlots == 0 then
        return false, "No free unlocked slot"
    end

    local targets = {}
    local count = math.min(#selectedInv, #freeSlots)
    for i = 1, count do
        local item = selectedInv[i]
        table.insert(targets, {
            uid = item.uid,
            slot = freeSlots[i].name,
            key = getItemKey(item),
            done = false,
        })
    end

    state.batchBusy = true

    task.spawn(function()
        local remote = state.placeRemote
        local deadline = os.clock() + 12
        local lastFire = 0

        while Gui.Parent and os.clock() < deadline do
            local remaining = 0
            local data = getData()

            for _, t in ipairs(targets) do
                if not t.done then
                    local placedSlot = findPlacedEntryByUID(data, t.uid)
                    if placedSlot then
                        t.done = true
                        state.selectedChecks[t.key] = nil
                    else
                        remaining += 1
                    end
                end
            end

            if remaining == 0 then
                break
            end

            if os.clock() - lastFire >= 0.05 then
                lastFire = os.clock()
                for _, t in ipairs(targets) do
                    if not t.done then
                        pcall(function()
                            remote:FireServer(tostring(t.slot), t.uid)
                        end)
                    end
                end
            end

            setBatchButtonText(string.format("Spam place %d left", remaining))
            task.wait(0.03)
        end

        local placed = 0
        for _, t in ipairs(targets) do
            if t.done then
                placed += 1
            end
        end

        setBatchButtonText("Placed " .. tostring(placed) .. "/" .. tostring(#targets))
        refreshList()
        task.wait(0.7)

        if PickupSelectedBtn and PickupSelectedBtn.Parent then
            PickupSelectedBtn.Text = "Pick Up Selected"
        end
        if PlaceSelectedBtn and PlaceSelectedBtn.Parent then
            PlaceSelectedBtn.Text = "Place Selected"
        end
        if SellSelectedBtn and SellSelectedBtn.Parent then
            SellSelectedBtn.Text = "Sell Selected"
        end
        if SecondaryAction and SecondaryAction.Parent and Detail.Visible then
            local selected = state.selected
            if selected and selected.source == "Inventory" then
                SecondaryAction.Text = "Place in Free Slot"
            end
        end

        state.batchBusy = false
    end)

    return true, "Started"
end

local function findInventoryEntryByUID(playerData, uid)
    if uid == nil or not playerData or type(playerData.Inventory) ~= "table" then
        return nil
    end

    local wanted = tostring(uid)
    for _, entry in pairs(playerData.Inventory) do
        if type(entry) == "table" then
            local entryUID = getEntryUID(entry)
            if entryUID ~= nil and tostring(entryUID) == wanted then
                return entry
            end
        end
    end
    return nil
end

-- Inventory-only sell. Never uses placed/stand sell remotes.
local function startBatchSell(selectedInv)
    if state.batchBusy then
        return false, "Batch already running"
    end

    selectedInv = selectedInv or getCheckedInventorySnapshot()

    if #selectedInv == 0 then
        return false, "No inventory selected"
    end

    -- Strict filter: inventory only
    local filtered = {}
    for _, item in ipairs(selectedInv) do
        if item.source == "Inventory" and item.uid ~= nil then
            table.insert(filtered, item)
        end
    end

    if #filtered == 0 then
        return false, "No inventory selected"
    end

    state.sellRemote = state.sellRemote or resolveExactRemoteEvent("Sell Slime From Inventory")
    if not state.sellRemote then
        return false, 'RemoteEvent "Sell Slime From Inventory" missing'
    end

    local targets = {}
    for _, item in ipairs(filtered) do
        table.insert(targets, {
            uid = item.uid,
            key = getItemKey(item),
            done = false,
        })
    end

    state.batchBusy = true

    task.spawn(function()
        local remote = state.sellRemote
        local deadline = os.clock() + 12
        local lastFire = 0

        while Gui.Parent and os.clock() < deadline do
            local remaining = 0
            local data = getData()

            for _, t in ipairs(targets) do
                if not t.done then
                    local stillThere = findInventoryEntryByUID(data, t.uid)
                    if not stillThere then
                        t.done = true
                        state.selectedChecks[t.key] = nil
                    else
                        remaining += 1
                    end
                end
            end

            if remaining == 0 then
                break
            end

            if os.clock() - lastFire >= 0.05 then
                lastFire = os.clock()
                for _, t in ipairs(targets) do
                    if not t.done then
                        pcall(function()
                            remote:FireServer(t.uid)
                        end)
                    end
                end
            end

            setBatchButtonText(string.format("Spam sell %d left", remaining))
            task.wait(0.03)
        end

        local sold = 0
        for _, t in ipairs(targets) do
            if t.done then
                sold += 1
            end
        end

        setBatchButtonText("Sold " .. tostring(sold) .. "/" .. tostring(#targets))
        refreshList()
        task.wait(0.7)

        if PickupSelectedBtn and PickupSelectedBtn.Parent then
            PickupSelectedBtn.Text = "Pick Up Selected"
        end
        if PlaceSelectedBtn and PlaceSelectedBtn.Parent then
            PlaceSelectedBtn.Text = "Place Selected"
        end
        if SellSelectedBtn and SellSelectedBtn.Parent then
            SellSelectedBtn.Text = "Sell Selected"
        end

        state.batchBusy = false
    end)

    return true, "Started"
end

local function sellOneInventory(item)
    if not item or item.source ~= "Inventory" or item.uid == nil then
        return false, "Inventory only"
    end

    -- If multiple inventory rows are checked, sell ALL of them via spam.
    local checked = getCheckedInventorySnapshot()
    if #checked > 0 then
        return startBatchSell(checked)
    end

    state.sellRemote = state.sellRemote or resolveExactRemoteEvent("Sell Slime From Inventory")
    if not state.sellRemote then
        return false, 'RemoteEvent "Sell Slime From Inventory" missing'
    end

    state.batchBusy = true
    local remote = state.sellRemote
    local uid = item.uid
    local key = getItemKey(item)
    local deadline = os.clock() + 5
    local lastFire = 0
    local sold = false

    while os.clock() < deadline do
        local data = getData()
        if not findInventoryEntryByUID(data, uid) then
            sold = true
            break
        end

        if os.clock() - lastFire >= 0.05 then
            lastFire = os.clock()
            pcall(function()
                remote:FireServer(uid)
            end)
        end
        task.wait(0.03)
    end

    if sold then
        state.selectedChecks[key] = nil
    end

    state.batchBusy = false
    refreshList()
    return sold, sold and "Sold" or "Sell not confirmed"
end

local function placeInventoryItem(item)
    if not item or item.source ~= "Inventory" then
        return false, "Not an inventory slime"
    end

    if item.uid == nil then
        return false, "UID unavailable"
    end

    state.placeRemote = state.placeRemote or resolveExactRemoteEvent("Place Slime")
    if not state.placeRemote then
        return false, 'RemoteEvent "Place Slime" missing'
    end

    -- Re-read right before placement so the chosen slot is actually free NOW.
    local slots = getAvailableSlots()
    if #slots == 0 then
        return false, "No free unlocked slot"
    end

    local slot = slots[1]

    local equipped, equipMessage = equipToolByUID(item.uid, 1.25)
    if not equipped then
        return false, equipMessage
    end

    local fired, err = pcall(function()
        state.placeRemote:FireServer(slot.name, item.uid)
    end)

    if not fired then
        return false, tostring(err)
    end

    -- Confirm the exact UID moved into PlotSlimes.
    local deadline = os.clock() + 3.0
    while os.clock() < deadline do
        local data = getData()
        local placedSlot = findPlacedEntryByUID(data, item.uid)

        if placedSlot then
            return true, "Placed in Slot " .. tostring(placedSlot)
        end

        task.wait(0.10)
    end

    return false, "Place sent, not confirmed"
end

-- ============================================================
-- SINGLE / CHECKED PICKUP + EQUIP
-- ============================================================

PrimaryAction.MouseButton1Click:Connect(function()
    local item = state.selected
    if not item or state.batchBusy then
        return
    end

    if item.source == "Placed" then
        -- IMPORTANT: if any placed rows are checked, Pick Up Remote now acts
        -- on ALL checked rows via parallel remote spam.
        local checked = getCheckedPlacedSnapshot()

        if #checked > 0 then
            local started, message = startBatchPickup(checked)
            if not started then
                PrimaryAction.Text = tostring(message)
                task.delay(1, function()
                    if PrimaryAction.Parent and state.selected == item then
                        PrimaryAction.Text = "Pick Up Remote"
                    end
                end)
            end
            return
        end

        PrimaryAction.Text = "Picking..."

        task.spawn(function()
            local ok, message = pickupOnePlaced(item)

            if ok then
                PrimaryAction.Text = "Waiting for Tool..."

                -- Single pickup keeps the requested auto-equip behavior.
                local equipped, equipMessage = equipToolByUID(item.uid, 2.5)

                if equipped then
                    PrimaryAction.Text = "Picked + Equipped [X]"
                else
                    PrimaryAction.Text = "Picked | " .. tostring(equipMessage)
                end

                task.wait(0.10)
                refreshList()
            else
                PrimaryAction.Text = tostring(message)
            end

            task.delay(1.0, function()
                if PrimaryAction and PrimaryAction.Parent and state.selected == item then
                    PrimaryAction.Text = "Pick Up Remote"
                end
            end)
        end)
    else
        PrimaryAction.Text = "Selecting..."
        local ok, message = equipInventoryItem(item)
        PrimaryAction.Text = ok and "Selected [X]" or tostring(message)

        task.delay(0.8, function()
            if PrimaryAction and PrimaryAction.Parent and state.selected == item then
                PrimaryAction.Text = "Equip / Select"
            end
        end)
    end
end)

-- ============================================================
-- GO TO SLOT / PLACE IN FREE SLOT
-- ============================================================

SecondaryAction.MouseButton1Click:Connect(function()
    local item = state.selected
    if not item or state.batchBusy then
        return
    end

    if item.source == "Placed" then
        local ok, message = teleportToPlacedItem(item)
        SecondaryAction.Text = ok and "Teleported [X]" or tostring(message)

        task.delay(0.8, function()
            if SecondaryAction and SecondaryAction.Parent and state.selected == item then
                SecondaryAction.Text = "Go To Slot"
            end
        end)
    else
        -- If any inventory rows are checked, place ALL of them via parallel spam.
        local checked = getCheckedInventorySnapshot()
        if #checked > 0 then
            local started, message = startBatchPlace(checked)
            if not started then
                SecondaryAction.Text = tostring(message)
                task.delay(1, function()
                    if SecondaryAction.Parent and state.selected == item then
                        SecondaryAction.Text = "Place in Free Slot"
                    end
                end)
            end
            return
        end

        SecondaryAction.Text = "Finding free slot..."

        task.spawn(function()
            local ok, message = placeInventoryItem(item)
            SecondaryAction.Text = ok and (tostring(message) .. " [X]") or tostring(message)

            if ok then
                state.selectedChecks[getItemKey(item)] = nil
                task.wait(0.15)
                refreshList()
            end

            task.delay(1.0, function()
                if SecondaryAction and SecondaryAction.Parent and state.selected == item then
                    SecondaryAction.Text = "Place in Free Slot"
                end
            end)
        end)
    end
end)

-- ============================================================
-- BATCH PICKUP SELECTED
-- ============================================================

PickupSelectedBtn.MouseButton1Click:Connect(function()
    if state.batchBusy then
        return
    end

    local selectedPlaced = getCheckedPlacedSnapshot()
    local started, message = startBatchPickup(selectedPlaced)

    if not started then
        PickupSelectedBtn.Text = tostring(message)
        task.delay(1, function()
            if PickupSelectedBtn.Parent then
                PickupSelectedBtn.Text = "Pick Up Selected"
            end
        end)
    end
end)

PlaceSelectedBtn.MouseButton1Click:Connect(function()
    if state.batchBusy then
        return
    end

    local selectedInv = getCheckedInventorySnapshot()
    local started, message = startBatchPlace(selectedInv)

    if not started then
        PlaceSelectedBtn.Text = tostring(message)
        task.delay(1, function()
            if PlaceSelectedBtn.Parent then
                PlaceSelectedBtn.Text = "Place Selected"
            end
        end)
    end
end)

SellSelectedBtn.MouseButton1Click:Connect(function()
    if state.batchBusy then
        return
    end

    -- Inventory only — never placed.
    local selectedInv = getCheckedInventorySnapshot()
    local started, message = startBatchSell(selectedInv)

    if not started then
        SellSelectedBtn.Text = tostring(message)
        task.delay(1, function()
            if SellSelectedBtn.Parent then
                SellSelectedBtn.Text = "Sell Selected"
            end
        end)
    end
end)

-- ============================================================
-- INITIALIZE
-- ============================================================

-- Initialize the game's real Shared + Database modules directly.
-- _G._Lib is useful when present, but is no longer required for rarity/current cash.
task.spawn(function()
    local start = os.clock()

    while Gui.Parent and os.clock() - start < 30 do
        if bootstrapGameModules() then
            break
        end

        Summary.Text = "Loading game Shared/Database modules..."
        task.wait(0.5)
    end

    state.lib = _G._Lib or state.lib
    state.pickupRemote = resolveExactRemoteEvent("Pickup Slime")
    state.placeRemote = resolveExactRemoteEvent("Place Slime")
    state.sellRemote = resolveExactRemoteEvent("Sell Slime From Inventory")
    refreshList()
end)

task.spawn(function()
    while Gui.Parent do
        if state.autoRefresh and not state.batchBusy then
            pcall(refreshList)
        end
        task.wait(state.refreshInterval)
    end
end)

print("[SlimeValueBrowser] Loaded - JAPAN | spam pick/place/sell inventory-only | ASCII UI")