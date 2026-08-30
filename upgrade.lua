-- ============================================================
-- SIMPLE AUTO UPGRADE - VERIFIED AGAINST CURRENT GAME FILES
-- LOWEST NEXT-UPGRADE COST FIRST
-- ONE GUI BUTTON ONLY
-- ============================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer

-- GUI must appear immediately.
-- Game references are resolved in the background after the button exists.
local Lib = nil
local MyPlot = nil
local Stands = nil
local UpgradeRemote = nil
local gameReady = false

local enabled = false

-- Stop an older copy of this exact script.
local RUN_TOKEN = {}
_G.__SimpleLowestCostUpgrade = RUN_TOKEN

local function running()
    return _G.__SimpleLowestCostUpgrade == RUN_TOKEN
end

-- ============================================================
-- GUI - ONE BUTTON ONLY
-- ============================================================

pcall(function()
    local old = CoreGui:FindFirstChild("SimpleLowestCostUpgradeGUI")
    if old then
        old:Destroy()
    end
end)

pcall(function()
    local pg = player:FindFirstChild("PlayerGui")
    local old = pg and pg:FindFirstChild("SimpleLowestCostUpgradeGUI")
    if old then
        old:Destroy()
    end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "SimpleLowestCostUpgradeGUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 999999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = true

-- Executor GUI parenting:
-- 1) gethui() (best for Delta/mobile executors)
-- 2) CoreGui
-- 3) PlayerGui
local guiParent = nil

if typeof(gethui) == "function" then
    local okHui, hui = pcall(function()
        return gethui()
    end)

    if okHui and hui then
        guiParent = hui
    end
end

if not guiParent then
    local okCore = pcall(function()
        gui.Parent = CoreGui
    end)

    if okCore and gui.Parent then
        guiParent = CoreGui
    end
end

if not guiParent then
    local PlayerGui = player:FindFirstChildOfClass("PlayerGui")
        or player:FindFirstChild("PlayerGui")

    if not PlayerGui then
        PlayerGui = player:WaitForChild("PlayerGui", 5)
    end

    if PlayerGui then
        guiParent = PlayerGui
    end
end

if guiParent then
    if typeof(syn) == "table"
        and typeof(syn.protect_gui) == "function"
    then
        pcall(function()
            syn.protect_gui(gui)
        end)
    end

    gui.Parent = guiParent
else
    error("[SimpleAutoUpgrade] Could not find a usable GUI parent")
end

print(
    "[SimpleAutoUpgrade] GUI parent:",
    gui.Parent and gui.Parent:GetFullName() or "nil"
)

local button = Instance.new("TextButton")
button.Name = "AutoUpgradeButton"
button.Size = UDim2.fromOffset(230, 52)
button.Position = UDim2.fromOffset(25, 80)
button.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
button.BackgroundTransparency = 0
button.BorderSizePixel = 0
button.Text = "Auto Upgrade: LOADING..."
button.TextColor3 = Color3.fromRGB(255, 210, 100)
button.TextTransparency = 0
button.TextSize = 16
button.Font = Enum.Font.GothamBold
button.Visible = true
button.Active = true
button.AutoButtonColor = true
button.ZIndex = 999999
button.Parent = gui

-- Simple touch/mouse dragging that works on mobile.
do
    local UIS = game:GetService("UserInputService")
    local dragging = false
    local dragStart = nil
    local startPos = nil
    local dragInput = nil

    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            dragging = true
            dragStart = input.Position
            startPos = button.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    button.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        then
            dragInput = input
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if dragging and input == dragInput and dragStart and startPos then
            local delta = input.Position - dragStart

            button.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

Instance.new("UICorner", button).CornerRadius = UDim.new(0, 9)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(90, 90, 110)
stroke.Thickness = 1.5
stroke.Parent = button

local function updateButton()
    if not gameReady then
        button.Text = "Auto Upgrade: LOADING..."
        button.TextColor3 = Color3.fromRGB(255, 210, 100)
        button.BackgroundColor3 = Color3.fromRGB(60, 52, 30)
        return
    end

    if enabled then
        button.Text = "Auto Upgrade: ON"
        button.TextColor3 = Color3.fromRGB(100, 255, 135)
        button.BackgroundColor3 = Color3.fromRGB(30, 65, 42)
    else
        button.Text = "Auto Upgrade: OFF"
        button.TextColor3 = Color3.fromRGB(255, 100, 100)
        button.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    end
end

button.MouseButton1Click:Connect(function()
    if not gameReady then
        updateButton()
        return
    end

    enabled = not enabled
    updateButton()
end)

-- Resolve the live game objects AFTER GUI creation.
task.spawn(function()
    local started = os.clock()

    while running() and os.clock() - started < 60 do
        local lib = rawget(_G, "_Lib")
        local plot = rawget(_G, "MyPlot")

        if lib and plot then
            local stands = plot:FindFirstChild("Stands")

            if stands
                and lib.GameRemoteRegistry
                and typeof(lib.GameRemoteRegistry.new) == "function"
            then
                local okRemote, remote = pcall(function()
                    return lib.GameRemoteRegistry.new(
                        "Upgrade Slime",
                        "RemoteEvent"
                    )
                end)

                if okRemote and remote then
                    Lib = lib
                    MyPlot = plot
                    Stands = stands
                    UpgradeRemote = remote
                    gameReady = true
                    updateButton()
                    print("[SimpleAutoUpgrade] Game systems ready")
                    return
                end
            end
        end

        task.wait(0.25)
    end

    if running() and not gameReady then
        button.Text = "Auto Upgrade: GAME NOT READY"
        button.TextColor3 = Color3.fromRGB(255, 120, 120)
        warn("[SimpleAutoUpgrade] _G._Lib / _G.MyPlot / Upgrade Slime route not ready")
    end
end)

-- ============================================================
-- GAME DATA
-- ============================================================

local function getData()
    if not gameReady or not Lib or not Lib.Data then
        return nil
    end

    local okData, data = pcall(function()
        return Lib.Data:Get()
    end)

    if okData then
        return data
    end

    return nil
end

local function getCatalogDefinition(id)
    if not gameReady or not Lib then
        return nil
    end

    local catalog =
        Lib.SoccerGameCatalog
        and Lib.SoccerGameCatalog.SoccerPlayerCatalog

    if type(catalog) ~= "table" or id == nil then
        return nil
    end

    return catalog[id]
        or catalog[tostring(id)]
        or catalog[tonumber(id)]
end

local function getLiveLevel(slotName, entry)
    local stand =
        Stands
        and Stands:FindFirstChild(tostring(slotName))
        or nil

    -- PlotStandInteractionController writes the current level
    -- onto the Stand's "level" attribute.
    local standLevel =
        stand and tonumber(stand:GetAttribute("level"))

    if standLevel then
        return standLevel
    end

    if type(entry) == "table" then
        return tonumber(entry.level) or 1
    end

    return 1
end

local function buildUpgradeList()
    local data = getData()

    if not data or type(data.PlotSlimes) ~= "table" then
        return {}, data
    end

    local shared = Lib.GameplaySharedRegistry

    if not shared
        or typeof(shared.getUpgradePrice) ~= "function"
    then
        return {}, data
    end

    local maxLevel =
        tonumber(shared.MAX_SLIME_LEVEL)
        or 100

    local list = {}

    for slotName, entry in pairs(data.PlotSlimes) do
        if type(entry) == "table"
            and entry.id ~= nil
        then
            local def = getCatalogDefinition(entry.id)

            -- PlotStandInteractionController only creates Upgrade
            -- controls for normal players, never Lucky Blocks.
            if def
                and tostring(def.Type or "Normal") ~= "Lucky Block"
            then
                local level =
                    getLiveLevel(slotName, entry)

                if level < maxLevel then
                    local sellPrice =
                        tonumber(def.SellPrice)

                    if sellPrice and sellPrice > 0 then
                        local okPrice, price =
                            pcall(function()
                                return shared.getUpgradePrice(
                                    sellPrice,
                                    level
                                )
                            end)

                        price =
                            okPrice
                            and tonumber(price)
                            or nil

                        if price and price >= 0 then
                            table.insert(list, {
                                slot = tostring(slotName),
                                level = level,
                                cost = price,
                            })
                        end
                    end
                end
            end
        end
    end

    -- LOWEST CURRENT NEXT-UPGRADE COST FIRST.
    table.sort(list, function(a, b)
        if a.cost ~= b.cost then
            return a.cost < b.cost
        end

        if a.level ~= b.level then
            return a.level < b.level
        end

        return
            (tonumber(a.slot) or math.huge)
            <
            (tonumber(b.slot) or math.huge)
    end)

    return list, data
end

local function waitForUpgrade(candidate)
    local beforeLevel =
        tonumber(candidate.level)
        or 1

    local timeout =
        os.clock() + 0.8

    while running()
        and enabled
        and os.clock() < timeout
    do
        task.wait(0.06)

        local data = getData()
        local plotSlimes =
            data and data.PlotSlimes

        local entry =
            plotSlimes
            and (
                plotSlimes[candidate.slot]
                or plotSlimes[tonumber(candidate.slot)]
            )

        if entry then
            local currentLevel =
                getLiveLevel(
                    candidate.slot,
                    entry
                )

            if currentLevel > beforeLevel then
                return true
            end
        end
    end

    return false
end

-- ============================================================
-- AUTO UPGRADE LOOP
-- ============================================================

task.spawn(function()
    while running() do
        if not gameReady or not enabled then
            task.wait(0.25)
            continue
        end

        local upgrades, data =
            buildUpgradeList()

        if #upgrades == 0 then
            task.wait(0.35)
            continue
        end

        local cheapest =
            upgrades[1]

        -- PlotStandInteractionController compares upgrade price
        -- directly with Data:Get().Cash.
        local cash =
            tonumber(data and data.Cash)
            or 0

        -- Because candidates are sorted cheapest-first:
        -- if #1 is unaffordable, everything else is too.
        if cheapest.cost > cash then
            task.wait(0.30)
            continue
        end

        local fired =
            pcall(function()
                UpgradeRemote:Fire(
                    cheapest.slot
                )
            end)

        if fired then
            waitForUpgrade(cheapest)
        end

        -- The real controller uses a 0.2 s upgrade debounce.
        -- Keep slightly above it.
        task.wait(0.22)
    end
end)

updateButton()

print(
    "[SimpleAutoUpgrade] GUI loaded | waiting for game systems..."
)