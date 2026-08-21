-- ============================================================
-- JAPAN LUCKY BLOCK AUTO COLLECTOR  (PICKUP FIXED)
-- ============================================================

local Players          = game:GetService("Players")
local TeleportService  = game:GetService("TeleportService")
local HttpService      = game:GetService("HttpService")
local CoreGui          = game:GetService("CoreGui")

local player      = Players.LocalPlayer
local PLACE_ID    = game.PlaceId
local CURRENT_JOB = game.JobId

local SCAN_WAIT              = 2.5
local PICKUP_TRIES           = 7
local PICKUP_CONFIRM_TIMEOUT = 2.2
local DEPOSIT_TIMEOUT        = 6

-- ============================================================
-- STOP OLD INSTANCE
-- ============================================================
local RUN_TOKEN = {}
_G.__JapanLuckyCollector = RUN_TOKEN
local function running()
    return _G.__JapanLuckyCollector == RUN_TOKEN
end

-- ============================================================
-- UI
-- ============================================================
pcall(function()
    local old = CoreGui:FindFirstChild("JapanCollectorDebug")
    if old then old:Destroy() end
end)
pcall(function()
    local pg = player:FindFirstChild("PlayerGui")
    if pg then
        local old = pg:FindFirstChild("JapanCollectorDebug")
        if old then old:Destroy() end
    end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "JapanCollectorDebug"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
if not pcall(function() gui.Parent = CoreGui end) then
    gui.Parent = player:WaitForChild("PlayerGui")
end

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 440, 0, 310)
frame.Position = UDim2.new(0, 20, 0, 100)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 32)
title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.Text = "JAPAN LUCKY BOX COLLECTOR"
title.TextColor3 = Color3.fromRGB(255, 220, 70)
title.TextSize = 17
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 26)
status.Position = UDim2.new(0, 10, 0, 38)
status.BackgroundTransparency = 1
status.Text = "Status: BOOTING..."
status.TextColor3 = Color3.fromRGB(100, 255, 130)
status.TextSize = 14
status.Font = Enum.Font.GothamBold
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = frame

local counter = Instance.new("TextLabel")
counter.Size = UDim2.new(1, -20, 0, 20)
counter.Position = UDim2.new(0, 10, 0, 64)
counter.BackgroundTransparency = 1
counter.Text = "Collected: 0"
counter.TextColor3 = Color3.fromRGB(210, 210, 220)
counter.TextSize = 13
counter.Font = Enum.Font.Gotham
counter.TextXAlignment = Enum.TextXAlignment.Left
counter.Parent = frame

local logs = Instance.new("TextLabel")
logs.Size = UDim2.new(1, -20, 1, -100)
logs.Position = UDim2.new(0, 10, 0, 90)
logs.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
logs.BorderSizePixel = 0
logs.Text = ""
logs.TextColor3 = Color3.fromRGB(230, 230, 235)
logs.TextSize = 12
logs.Font = Enum.Font.Code
logs.TextWrapped = true
logs.TextXAlignment = Enum.TextXAlignment.Left
logs.TextYAlignment = Enum.TextYAlignment.Top
logs.Parent = frame
Instance.new("UICorner", logs).CornerRadius = UDim.new(0, 7)

local messages = {}
local function LOG(text)
    text = tostring(text)
    table.insert(messages, "[" .. os.date("%H:%M:%S") .. "] " .. text)
    while #messages > 13 do table.remove(messages, 1) end
    logs.Text = table.concat(messages, "\n")
    print("[JAPAN]", text)
end

local function STATUS(text)
    status.Text = "Status: " .. tostring(text)
    LOG("> " .. tostring(text))
end

STATUS("SCRIPT LAUNCHED")

-- ============================================================
-- HELPERS
-- ============================================================
local function getRoot()
    local c = player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local c = player.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getSlimesFolder()
    local live = workspace:FindFirstChild("Live")
    return live and live:FindFirstChild("Slimes")
end

local function isJapanLuckyBlock(name)
    name = string.lower(tostring(name or ""))
    if not string.find(name, "japan", 1, true) then return false end
    return string.find(name, "lucky", 1, true)
        or string.find(name, "block", 1, true)
end

-- Prefer StealPrompt / ActionText "Collect" (this game's real steal prompt)
local function findBestPrompt(model)
    local best, fallback
    for _, obj in ipairs(model:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            local name = string.lower(obj.Name or "")
            local at   = string.lower(tostring(obj.ActionText or ""))

            if name == "stealprompt"
                or at:find("collect", 1, true)
                or at:find("steal", 1, true)
                or at:find("pick", 1, true)
                or at:find("take", 1, true)
            then
                best = obj
                break
            end
            fallback = fallback or obj
        end
    end
    return best or fallback
end

local function findJapanBoxes()
    local slimes = getSlimesFolder()
    if not slimes then return {} end

    local results = {}
    for _, model in ipairs(slimes:GetChildren()) do
        if model:IsA("Model")
            and isJapanLuckyBlock(model.Name)
            and not model:GetAttribute("Carrying")
        then
            local part = model.PrimaryPart
                or model:FindFirstChildWhichIsA("BasePart")
            if part then
                table.insert(results, {
                    model  = model,
                    part   = part,
                    prompt = findBestPrompt(model),
                })
            end
        end
    end
    return results
end

-- ============================================================
-- CLOAK (best-effort, never blocks pickup)
-- ============================================================
local function findCloak()
    local function scan(container)
        if not container then return nil end
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") then
                local n = string.lower(tool.Name)
                if n:find("invis", 1, true) or n:find("cloak", 1, true) then
                    return tool
                end
            end
        end
    end
    return scan(player.Character) or scan(player:FindFirstChild("Backpack"))
end

local function activateCloak()
    local tool = findCloak()
    if not tool then return false end
    local hum = getHumanoid()
    if not hum then return false end
    if tool.Parent ~= player.Character then
        pcall(function() hum:EquipTool(tool) end)
        task.wait(0.1)
    end
    pcall(function() tool:Activate() end)
    return true
end

-- ============================================================
-- HOLD / BASE
-- ============================================================
local function isHolding()
    return player:GetAttribute("holdingSlime") == true
end

local function waitPickup()
    local deadline = os.clock() + PICKUP_CONFIRM_TIMEOUT
    while running() and os.clock() < deadline do
        if isHolding() then return true end
        task.wait(0.05)
    end
    return isHolding()
end

local function findMyPlot()
    if _G.MyPlot and _G.MyPlot.Parent then
        return _G.MyPlot
    end
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, plot in ipairs(plots:GetChildren()) do
        local owner = plot:FindFirstChild("owner")
            or plot:FindFirstChild("Owner")
        if owner and owner:IsA("ValueBase") then
            if tostring(owner.Value) == player.Name
                or tostring(owner.Value) == tostring(player.UserId)
            then
                return plot
            end
        end
        if tostring(plot:GetAttribute("Owner") or "") == player.Name then
            return plot
        end
    end
    return nil
end

local function teleportBase()
    local root = getRoot()
    if not root then return false end

    if _G.MyPlot and _G.MyPlot.Base and _G.MyPlot.Base.Teleport then
        local tp = _G.MyPlot.Base.Teleport
        if tp:IsA("Attachment") and tp.WorldCFrame then
            root.CFrame = tp.WorldCFrame + Vector3.new(0, 3, 0)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            return true
        end
    end

    local plot = findMyPlot()
    if not plot then
        LOG("My plot not found")
        return false
    end
    local base = plot:FindFirstChild("Base")
    local tp = base and (base:FindFirstChild("Teleport") or base:FindFirstChild("TeleportToBase"))
    if not tp then
        LOG("Base teleport missing")
        return false
    end
    if tp:IsA("Attachment") then
        root.CFrame = tp.WorldCFrame + Vector3.new(0, 3, 0)
    elseif tp:IsA("BasePart") then
        root.CFrame = tp.CFrame + Vector3.new(0, 3, 0)
    else
        return false
    end
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    return true
end

local function waitDeposit()
    STATUS("Depositing...")
    local deadline = os.clock() + DEPOSIT_TIMEOUT
    while running() and isHolding() and os.clock() < deadline do
        task.wait(0.1)
    end
    return not isHolding()
end

-- ============================================================
-- PICKUP  (matches the working farm script)
-- ============================================================
local function attemptSteal(prompt)
    if not prompt or not prompt.Parent then return false end

    local hold = tonumber(prompt.HoldDuration) or 0.5

    -- Primary method used by the working auto-farm
    if typeof(fireproximityprompt) == "function" then
        local ok = pcall(function()
            fireproximityprompt(prompt)
        end)
        if ok then
            task.wait(hold + 0.55)
            return true
        end
    end

    -- Fallback
    local ok = pcall(function()
        prompt:Trigger()
    end)
    if ok then
        task.wait(hold + 0.55)
        return true
    end

    -- Last resort
    pcall(function()
        prompt:InputHoldBegin()
        task.wait(math.max(hold, 0.1))
        prompt:InputHoldEnd()
    end)
    task.wait(0.4)
    return false
end

local function collectBox(box)
    STATUS("Japan box found")
    pcall(activateCloak)   -- best-effort only

    local root = getRoot()
    if not root or not box.part or not box.part.Parent then
        LOG("Target/root gone")
        return false
    end

    -- Stay close (MaxActivationDistance is ~14)
    STATUS("Moving to box")
    root.CFrame = box.part.CFrame * CFrame.new(0, 2.5, 3)
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    task.wait(0.2)

    for attempt = 1, PICKUP_TRIES do
        if not running() then return false end
        if isHolding() then
            LOG("Already holding")
            return true
        end

        STATUS("Pickup try " .. attempt .. "/" .. PICKUP_TRIES)

        -- Keep next to the box
        if box.part and box.part.Parent then
            local r = getRoot()
            if r then
                r.CFrame = box.part.CFrame * CFrame.new(0, 2.5, 3)
                r.AssemblyLinearVelocity = Vector3.zero
            end
        end

        -- Re-find live prompt every try
        local prompt = nil
        if box.model and box.model.Parent then
            prompt = findBestPrompt(box.model)
        end
        prompt = prompt or box.prompt

        if prompt and prompt.Parent then
            LOG(string.format(
                "Prompt: %s | Action='%s' | Hold=%.2f",
                prompt.Name,
                tostring(prompt.ActionText),
                tonumber(prompt.HoldDuration) or 0
            ))
            attemptSteal(prompt)

            if waitPickup() then
                LOG("holdingSlime = TRUE  ✓")
                return true
            end
            LOG("holdingSlime still false")
        else
            LOG("No prompt found on model")
        end

        task.wait(0.25)
    end

    LOG("All pickup tries failed")
    return false
end

-- ============================================================
-- SERVER HOP
-- ============================================================
local requestFunction =
    (syn and syn.request)
    or (http and http.request)
    or http_request
    or request

local visited = { [CURRENT_JOB] = true }

local function getServer()
    if not requestFunction then
        LOG("No HTTP request (need executor request)")
        return nil
    end
    local cursor = nil
    for _ = 1, 6 do
        local url = "https://games.roblox.com/v1/games/"
            .. PLACE_ID
            .. "/servers/Public?sortOrder=Asc&limit=100"
        if cursor then
            url = url .. "&cursor=" .. HttpService:UrlEncode(cursor)
        end
        local ok, resp = pcall(function()
            return requestFunction({ Url = url, Method = "GET" })
        end)
        if not ok or not resp then return nil end
        local body = resp.Body or resp.body
        if not body then return nil end
        local decoded
        if not pcall(function() decoded = HttpService:JSONDecode(body) end) then
            return nil
        end
        for _, server in ipairs(decoded.data or {}) do
            local id = server.id
            local playing = tonumber(server.playing) or 0
            local maxp = tonumber(server.maxPlayers) or 0
            if id and not visited[id] and playing < maxp then
                visited[id] = true
                return id
            end
        end
        cursor = decoded.nextPageCursor
        if not cursor then break end
    end
    return nil
end

local function serverHop()
    STATUS("No Japan box – hopping")
    local serverId = getServer()
    if not serverId then
        LOG("No free server")
        return false
    end
    LOG("Hop → " .. serverId)
    task.wait(0.4)
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(PLACE_ID, serverId, player)
    end)
    if not ok then
        LOG("Teleport failed: " .. tostring(err))
        return false
    end
    return true
end

-- ============================================================
-- MAIN
-- ============================================================
local collected = 0

STATUS("Waiting for world")
task.wait(2.5)

while running() do
    if isHolding() then
        STATUS("Already holding – base")
        teleportBase()
        task.wait(0.35)
        waitDeposit()
        task.wait(0.25)
        continue
    end

    STATUS("Scanning...")
    local boxes = findJapanBoxes()
    LOG("Japan boxes: " .. #boxes)

    if #boxes == 0 then
        task.wait(SCAN_WAIT)
        boxes = findJapanBoxes()
        if #boxes == 0 then
            if serverHop() then break end
            task.wait(4)
            continue
        end
    end

    for _, box in ipairs(boxes) do
        if not running() then break end
        if box.model and box.model.Parent and not isHolding() then
            if collectBox(box) then
                collected += 1
                counter.Text = "Collected: " .. collected
                STATUS("COLLECTED! (" .. collected .. ")")
                teleportBase()
                task.wait(0.35)
                waitDeposit()
                task.wait(0.3)
            end
        end
    end

    task.wait(0.6)
    if #findJapanBoxes() == 0 then
        if serverHop() then break end
    end
    task.wait(0.8)
end

STATUS("Stopped / hopped – re-execute on new server")
