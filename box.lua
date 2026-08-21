-- ============================================================
-- ICONS LUCKY BLOCK AUTO COLLECTOR
-- + LIVE LOG UI
-- + AUTO SERVER HOP WHEN NONE FOUND
-- ============================================================

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local PLACE_ID = game.PlaceId
local CURRENT_JOB = game.JobId

local TARGET_NAMES = {
    "Japan Lucky Block",
    "Icons Lucky Block",
    "Spain Lucky Block",
    "Champions Lucky Block"
}

-- Collection filters
local CollectFilter = {
    Japan = true,
    Icons = true,
    Spain = false,
    Champions = false
}

local SCAN_WAIT = 3
local PICKUP_TRIES = 5
local PICKUP_CONFIRM_TIMEOUT = 4
local DEPOSIT_TIMEOUT = 5

-- ============================================================
-- STOP OLD INSTANCE
-- ============================================================

local RUN_TOKEN = {}
_G.__IconsLuckyCollector = RUN_TOKEN

local function running()
    return _G.__IconsLuckyCollector == RUN_TOKEN
end

-- ============================================================
-- UI FIRST
-- ============================================================

pcall(function()
    CoreGui.IconicCollectorDebug:Destroy()
end)

pcall(function()
    player.PlayerGui.IconicCollectorDebug:Destroy()
end)

local gui = Instance.new("ScreenGui")
gui.Name = "IconicCollectorDebug"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true

local ok = pcall(function()
    gui.Parent = CoreGui
end)

if not ok then
    gui.Parent = player:WaitForChild("PlayerGui")
end

local frame = Instance.new("Frame")
frame.Parent = gui
frame.Size = UDim2.new(0, 430, 0, 285)
frame.Position = UDim2.new(0, 20, 0, 100)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
frame.BorderSizePixel = 0

Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Parent = frame
title.Size = UDim2.new(1, -20, 0, 35)
title.Position = UDim2.new(0, 10, 0, 5)
title.BackgroundTransparency = 1
title.Text = "LUCKY BLOCK FILTER COLLECTOR"
title.TextColor3 = Color3.fromRGB(255, 220, 70)
title.TextSize = 18
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left

local status = Instance.new("TextLabel")
status.Parent = frame
status.Size = UDim2.new(1, -20, 0, 30)
status.Position = UDim2.new(0, 10, 0, 40)
status.BackgroundTransparency = 1
status.Text = "BOOTING..."
status.TextColor3 = Color3.fromRGB(100, 255, 130)
status.TextSize = 15
status.Font = Enum.Font.GothamBold
status.TextXAlignment = Enum.TextXAlignment.Left

local counter = Instance.new("TextLabel")
counter.Parent = frame
counter.Size = UDim2.new(1, -20, 0, 22)
counter.Position = UDim2.new(0, 10, 0, 67)
counter.BackgroundTransparency = 1
counter.Text = "Collected: 0"
counter.TextColor3 = Color3.fromRGB(220, 220, 220)
counter.TextSize = 13
counter.Font = Enum.Font.Gotham
counter.TextXAlignment = Enum.TextXAlignment.Left

local logs = Instance.new("TextLabel")
logs.Parent = frame
logs.Size = UDim2.new(1, -20, 1, -105)
logs.Position = UDim2.new(0, 10, 0, 94)
logs.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
logs.BorderSizePixel = 0
logs.Text = ""
logs.TextColor3 = Color3.fromRGB(235, 235, 235)
logs.TextSize = 12
logs.Font = Enum.Font.Code
logs.TextWrapped = true
logs.TextXAlignment = Enum.TextXAlignment.Left
logs.TextYAlignment = Enum.TextYAlignment.Top

Instance.new("UICorner", logs).CornerRadius = UDim.new(0, 7)

local messages = {}

local function LOG(text)
    text = tostring(text)

    table.insert(messages, "[" .. os.date("%H:%M:%S") .. "] " .. text)

    while #messages > 11 do
        table.remove(messages, 1)
    end

    logs.Text = table.concat(messages, "\n")
    print("[ICONIC]", text)
end

local function STATUS(text)
    status.Text = "Status: " .. tostring(text)
    LOG("> " .. tostring(text))
end


-- ============================================================
-- LUCKY BLOCK CHECKBOX FILTER UI
-- ============================================================

local function createCheckbox(name, key, y)
    local box = Instance.new("TextButton")
    box.Parent = frame
    box.Size = UDim2.new(0, 170, 0, 25)
    box.Position = UDim2.new(0, 240, 0, y)
    box.BackgroundColor3 = Color3.fromRGB(40,40,40)
    box.TextColor3 = Color3.fromRGB(255,255,255)
    box.TextSize = 13
    box.Font = Enum.Font.Gotham

    local function update()
        box.Text = name .. ": " .. (CollectFilter[key] and "ON" or "OFF")
    end

    update()

    box.MouseButton1Click:Connect(function()
        CollectFilter[key] = not CollectFilter[key]
        update()
        LOG(name .. " collection " .. (CollectFilter[key] and "enabled" or "disabled"))
    end)
end

createCheckbox("Japan", "Japan", 120)
createCheckbox("Icons", "Icons", 150)
createCheckbox("Spain", "Spain", 180)
createCheckbox("Champions", "Champions", 210)

STATUS("SCRIPT LAUNCHED")

-- ============================================================
-- CHARACTER
-- ============================================================

local function getCharacter()
    return player.Character
end

local function getRoot()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

-- ============================================================
-- GAME FOLDERS
-- ============================================================

local function getSlimesFolder()
    local live = workspace:FindFirstChild("Live")
    return live and live:FindFirstChild("Slimes")
end

-- ============================================================
-- FIND ICONS BOX
-- ============================================================

local function findPrompt(model)
    for _, obj in ipairs(model:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            return obj
        end
    end

    return nil
end

local function isTargetLuckyBlock(name)
    local n = string.lower(tostring(name))

    if n:find("japan", 1, true)
        and n:find("lucky", 1, true)
        and CollectFilter.Japan then
        return true
    end

    if n:find("icons", 1, true)
        and n:find("lucky", 1, true)
        and CollectFilter.Icons then
        return true
    end

    if n:find("spain", 1, true)
        and n:find("lucky", 1, true)
        and CollectFilter.Spain then
        return true
    end

    if n:find("champions", 1, true)
        and n:find("lucky", 1, true)
        and CollectFilter.Champions then
        return true
    end

    return false
end


local function countLuckyBoxes()
    local slimes = getSlimesFolder()

    local japan = 0
    local icons = 0
    local total = 0

    if not slimes then
        return japan, icons, total
    end

    for _, model in ipairs(slimes:GetChildren()) do
        if model:IsA("Model") then
            local n = string.lower(model.Name)

            if n == "japan lucky block"
                or (n:find("japan", 1, true) and n:find("lucky", 1, true)) then
                japan += 1
                total += 1

            elseif n == "icons lucky block"
                or (n:find("icons", 1, true) and n:find("lucky", 1, true)) then
                icons += 1
                total += 1
            end
        end
    end

    return japan, icons, total
end


local function findIconsBoxes()
    local slimes = getSlimesFolder()

    if not slimes then
        return {}
    end

    local results = {}

    for _, model in ipairs(slimes:GetChildren()) do
        if model:IsA("Model")
            and isTargetLuckyBlock(model.Name)
            and not model:GetAttribute("Carrying") then

            local part =
                model.PrimaryPart
                or model:FindFirstChildWhichIsA("BasePart")

            if part then
                table.insert(results, {
                    model = model,
                    part = part,
                    prompt = findPrompt(model)
                })
            end
        end
    end

    return results
end

-- ============================================================
-- INVISIBILITY CLOAK
-- ============================================================

local function findCloak()
    local function scan(container)
        if not container then
            return nil
        end

        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") then
                local n = string.lower(tool.Name)

                if n:find("invisibility", 1, true)
                    or n:find("cloak", 1, true)
                    or n:find("invis", 1, true) then

                    return tool
                end
            end
        end
    end

    return scan(player.Character)
        or scan(player:FindFirstChild("Backpack"))
end

local function activateCloak()
    local tool = findCloak()

    if not tool then
        LOG("Cloak not found.")
        return false
    end

    local humanoid = getHumanoid()
    local char = player.Character

    if not humanoid or not char then
        return false
    end

    if tool.Parent ~= char then
        pcall(function()
            humanoid:EquipTool(tool)
        end)

        task.wait(0.15)
    end

    pcall(function()
        tool:Activate()
    end)

    LOG("Cloak activated.")
    return true
end

-- ============================================================
-- HOLD STATE
-- ============================================================

local function isHolding()
    return player:GetAttribute("holdingSlime") == true
end

local function waitPickup()
    local timeout = os.clock() + PICKUP_CONFIRM_TIMEOUT

    while running() and os.clock() < timeout do
        if isHolding() then
            return true
        end

        task.wait(0.05)
    end

    return isHolding()
end

-- ============================================================
-- BASE
-- ============================================================

local function findMyPlot()
    if _G.MyPlot and _G.MyPlot.Parent then
        return _G.MyPlot
    end

    local plots = workspace:FindFirstChild("Plots")
    if not plots then
        return nil
    end

    for _, plot in ipairs(plots:GetChildren()) do
        local owner = plot:FindFirstChild("owner")

        if owner and tostring(owner.Value) == player.Name then
            return plot
        end
    end
end

local function teleportBase()
    local root = getRoot()

    if not root then
        LOG("Root missing while returning.")
        return false
    end

    local plot = findMyPlot()

    if not plot then
        LOG("My plot not found.")
        return false
    end

    local base = plot:FindFirstChild("Base")
    local tp = base and base:FindFirstChild("Teleport")

    if not tp then
        LOG("Base teleport missing.")
        return false
    end

    if tp:IsA("Attachment") then
        root.CFrame = tp.WorldCFrame + Vector3.new(0, 3, 0)

    elseif tp:IsA("BasePart") then
        root.CFrame = tp.CFrame + Vector3.new(0, 3, 0)

    else
        LOG("Unknown base teleport type.")
        return false
    end

    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    LOG("Returned to base.")
    return true
end

local function waitDeposit()
    STATUS("Depositing box")

    local timeout = os.clock() + DEPOSIT_TIMEOUT

    while running()
        and isHolding()
        and os.clock() < timeout do

        task.wait(0.1)
    end

    if not isHolding() then
        LOG("Deposit confirmed.")
        return true
    end

    LOG("Deposit timeout.")
    return false
end

-- ============================================================
-- PICKUP
-- ============================================================

local function firePrompt(prompt)
    if not prompt or not prompt.Parent then
        return false
    end

    if typeof(fireproximityprompt) == "function" then
        local success = pcall(function()
            fireproximityprompt(prompt)
        end)

        if success then
            return true
        end
    end

    return pcall(function()
        prompt:InputHoldBegin()

        task.wait(
            math.max(
                tonumber(prompt.HoldDuration) or 0,
                0.05
            )
        )

        prompt:InputHoldEnd()
    end)
end

local function collectBox(box)
    STATUS("Iconic box found")

    activateCloak()

    local root = getRoot()

    if not root or not box.part or not box.part.Parent then
        LOG("Target/root disappeared.")
        return false
    end

    STATUS("Teleporting to Iconic box")

    root.CFrame =
        box.part.CFrame
        * CFrame.new(0, 3, 4)

    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    -- Give the proximity prompt time to load after teleport
    task.wait(1)

    for attempt = 1, PICKUP_TRIES do
        STATUS(
            "Pickup attempt "
            .. attempt
            .. "/"
            .. PICKUP_TRIES
        )

        -- Never return to base unless pickup is confirmed
        if isHolding() then
            LOG("Already holding box.")
            return true
        end

        activateCloak()

        local prompt =
            box.model
            and box.model.Parent
            and findPrompt(box.model)

        if prompt then
            LOG("Firing pickup prompt.")

            firePrompt(prompt)

            -- Wait until server confirms holdingSlime
            if waitPickup() then
                LOG("Pickup successful - holdingSlime TRUE")
                return true
            end
        else
            LOG("Prompt not ready, waiting.")
        end

        task.wait(0.5)
    end

    LOG("Pickup failed after all attempts.")
    return false
end

-- ============================================================
-- HTTP REQUEST
-- ============================================================

local requestFunction =
    request
    or http_request
    or (syn and syn.request)
    or (http and http.request)

-- ============================================================
-- ============================================================
-- SERVER HOP REMOVED
-- Script will remain in the same server and keep scanning
-- ============================================================

-- MAIN
-- ============================================================

local collected = 0

-- Allow game objects to finish loading
STATUS("Waiting for game to load")
task.wait(2)

while running() do

    if isHolding() then
        STATUS("Already holding Iconic box")

        teleportBase()

        task.wait(0.35)
        waitDeposit()

        task.wait(0.2)
        continue
    end

    STATUS("Scanning server")

    local boxes = findIconsBoxes()

    local japanCount, iconsCount, totalCount = countLuckyBoxes()

    LOG(
        "Lucky Boxes Map | Japan: "
        .. tostring(japanCount)
        .. " | Icons: "
        .. tostring(iconsCount)
        .. " | Total: "
        .. tostring(totalCount)
    )

    LOG(
        "Collectable boxes found: "
        .. tostring(#boxes)
    )

    -- ========================================================
    -- NONE FOUND -> SERVER HOP
    -- ========================================================

    if #boxes == 0 then
        STATUS("No Japan Lucky Box found - rescanning same server")

        task.wait(SCAN_WAIT)

        boxes = findIconsBoxes()

        if #boxes == 0 then
            LOG("No Japan Lucky Block yet. Continuing scan in same server.")
            task.wait(SCAN_WAIT)
            continue
        end
    end

    -- ========================================================
    -- COLLECT EVERYTHING FOUND
    -- ========================================================

    for _, box in ipairs(boxes) do
        if not running() then
            break
        end

        if box.model and box.model.Parent then

            local success = collectBox(box)

            if success and isHolding() then
                collected += 1
                counter.Text = "Collected: " .. collected

                STATUS("COLLECTED!")

                teleportBase()
                task.wait(0.35)

                waitDeposit()

                task.wait(0.25)
            end
        end
    end

    -- ========================================================
    -- AFTER COLLECTION RESCAN
    -- ========================================================

    task.wait(0.5)

    local remaining = findIconsBoxes()

    if #remaining == 0 then
        LOG("No more Iconic boxes in this server.")
        STATUS("Preparing next server")

        task.wait(1)

        LOG("Continuing scan in same server.")
        task.wait(SCAN_WAIT)
    end

    task.wait(1)
end