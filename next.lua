-- Minimal Next Generation Lucky Block Stealer + timer + count
-- Target:
-- Name: Next Generation Lucky Block
-- Rarity: Next Generation
-- ID: 2146
-- Auto-starts on execute.
-- Steal flow (from Lucky Box Cycle):
--   find target → solidify box → cloak → stand ON TOP → hover lock
--   → zero HoldDuration → fire prompt (up to 10 tries) → base on success
-- Fast scan; hops to lowest-pop public server (max 1 player)
-- if no Next Generation target exists.

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local TARGET = {
    Name = "Next Generation Lucky Block",
    Rarity = "Next Generation",
    ID = "2146",
    MinValue = 10000000
}

-- Model name lookup (exact names used by getTargetLuckyBlock)
local LUCKY_BLOCK_MODEL_NAMES = {
    ["Next Generation"] = {
        ["Next Generation Lucky Block"] = true,
        ["NextGen Lucky Block"] = true,
        ["Next Gen Lucky Block"] = true,
    },
}

local STAND_OFFSET = 3

local enabled, busy, total = true, false, 0
local sessionStart = os.clock()

local hopping = false
local emptyScans = 0

local EMPTY_SCANS_BEFORE_HOP = 3
local SCAN_EMPTY_WAIT = 0.15
local HOP_COOLDOWN = 2.0
local lastHopAt = 0

local statusLbl

--------------------------------------------------
-- Instant prompts (global + future)
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
    local m = math.floor(sec / 60)
    local s = sec % 60
    return string.format("%02d:%02d", m, s)
end


-- Robust Next Generation detection (name / rarity / ID / attrs / ValueBases)
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
        "Rarity", "_Rarity", "LuckyBlockName", "BlockName"
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

    -- Exact model-name table match
    local allowed = LUCKY_BLOCK_MODEL_NAMES["Next Generation"]
    if allowed and allowed[modelName] then
        return true
    end

    return false
end


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
        return
    end

    local tp =
        _G.MyPlot
        and _G.MyPlot.Base
        and _G.MyPlot.Base.Teleport

    if tp and tp.WorldCFrame then
        r.CFrame = tp.WorldCFrame + Vector3.new(0, 3, 0)
        r.AssemblyLinearVelocity = Vector3.zero
        return
    end

    local plots = workspace:FindFirstChild("Plots")
    if not plots then
        return
    end

    for _, plot in ipairs(plots:GetChildren()) do
        local o = plot:FindFirstChild("owner")
        if o and tostring(o.Value) == LP.Name then
            local b = plot:FindFirstChild("Base")
            local a = b and b:FindFirstChild("Teleport")
            if a and a:IsA("Attachment") and a.WorldCFrame then
                r.CFrame = a.WorldCFrame + Vector3.new(0, 3, 0)
                r.AssemblyLinearVelocity = Vector3.zero
            end
            return
        end
    end
end


--------------------------------------------------
-- Find nearest Next Gen target (cycle-style)
--------------------------------------------------
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
                local dist =
                    r and (r.Position - primary.Position).Magnitude
                    or 0

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
                    best = {
                        model = model,
                        part = primary,
                        prompt = prompt,
                    }
                end
            end
        end
    end

    return best
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


--------------------------------------------------
-- Solidify box (stand-on platform)
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


--------------------------------------------------
-- Full cycle-style steal: solidify → cloak → on top → hover → prompt
--------------------------------------------------
local function stealOne()
    -- Already holding → deposit only
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

    -- Clear previous float objects
    for _, name in ipairs({ "LuckyFloat", "LuckyHoverPos", "LuckyHoverGyro" }) do
        local old = r:FindFirstChild(name)
        if old then
            old:Destroy()
        end
    end

    -- BodyVelocity float
    local bv = Instance.new("BodyVelocity")
    bv.Name = "LuckyFloat"
    bv.Velocity = Vector3.zero
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.P = 1250
    bv.Parent = r

    -- BodyPosition lock
    local bp = Instance.new("BodyPosition")
    bp.Name = "LuckyHoverPos"
    bp.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bp.P = 20000
    bp.D = 1500
    bp.Parent = r

    -- BodyGyro
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

        -- Never sink through the box
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
        if not hovering then
            return
        end
        applyHover()
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

    -- Settle on top
    for _ = 1, 6 do
        if not applyHover() then
            cleanupHover()
            return false
        end
        task.wait(0.03)
    end

    -- Zero all prompt holds
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

    -- Fire while locked on top (up to 10 tries)
    local stolen = false
    for try = 1, 10 do
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

    -- Brief settle for server register
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
-- HTTP helpers (server hop)
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
        local HttpService = game:GetService("HttpService")
        body = HttpService:GetAsync(url)
    end)

    if ok and type(body) == "string" and #body > 0 then
        return body
    end
    return nil
end


local function decodeJson(str)
    local HttpService = game:GetService("HttpService")
    local ok, data = pcall(function()
        return HttpService:JSONDecode(str)
    end)
    if ok then
        return data
    end
    return nil
end


local MAX_SERVER_PLAYERS = 1

local function findLowPopJobId(placeId)
    local cursor = ""
    local bestId
    local bestPlaying = math.huge
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
            local playing = tonumber(server.playing) or 999
            local id = server.id or server.jobId

            if id
                and tostring(id) ~= ""
                and tostring(id) ~= tostring(game.JobId)
            then
                if playing <= MAX_SERVER_PLAYERS and playing < bestPlaying then
                    bestPlaying = playing
                    bestId = tostring(id)
                    if playing == 0 then
                        return bestId, bestPlaying
                    end
                end
            end
        end

        if bestId and bestPlaying <= MAX_SERVER_PLAYERS then
            return bestId, bestPlaying
        end

        cursor = data.nextPageCursor
        if type(cursor) ~= "string" or cursor == "" then
            break
        end
    end

    return bestId, bestPlaying
end


local function hopServer()
    if hopping then
        return
    end
    if os.clock() - lastHopAt < HOP_COOLDOWN then
        return
    end

    hopping = true
    lastHopAt = os.clock()
    enabled = false

    local placeId = game.PlaceId

    pcall(function()
        if statusLbl then
            statusLbl.Text =
                "Finding server with <= "
                .. tostring(MAX_SERVER_PLAYERS)
                .. " players..."
        end
    end)

    local jobId, playing = findLowPopJobId(placeId)

    if not jobId then
        pcall(function()
            if statusLbl then
                statusLbl.Text = "No 0-1 player server found — retry later"
            end
        end)
        hopping = false
        enabled = true
        emptyScans = 0
        task.wait(2)
        return
    end

    pcall(function()
        if statusLbl then
            statusLbl.Text = string.format(
                "Hop -> %d player server...",
                tonumber(playing) or 0
            )
        end
    end)

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
        pcall(function()
            if statusLbl then
                statusLbl.Text = "Teleport failed — will retry"
            end
        end)
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
        "JapanStealer", "JIStealer", "AlternativeStealer",
        "AlternateStealer", "NextGenStealer", "NextGenerationStealer"
    }) do
        local old = PG:FindFirstChild(name)
        if old then
            old:Destroy()
        end
    end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "NextGenStealer"
gui.ResetOnSpawn = false
gui.Parent = PG

local f = Instance.new("Frame")
f.Size = UDim2.new(0, 200, 0, 132)
f.Position = UDim2.new(0, 16, 0.5, -66)
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
btn.Text = "Steal NextGen: ON"
btn.TextColor3 = Color3.fromRGB(80, 255, 120)
btn.TextSize = 14
btn.Font = Enum.Font.GothamBold
btn.Parent = f
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

local timeLbl = Instance.new("TextLabel")
timeLbl.Size = UDim2.new(1, -16, 0, 20)
timeLbl.Position = UDim2.new(0, 8, 0, 46)
timeLbl.BackgroundTransparency = 1
timeLbl.Text = "Time: 00:00"
timeLbl.TextColor3 = Color3.fromRGB(200, 200, 210)
timeLbl.TextSize = 13
timeLbl.Font = Enum.Font.Gotham
timeLbl.TextXAlignment = Enum.TextXAlignment.Left
timeLbl.Parent = f

local countLbl = Instance.new("TextLabel")
countLbl.Size = UDim2.new(1, -16, 0, 20)
countLbl.Position = UDim2.new(0, 8, 0, 68)
countLbl.BackgroundTransparency = 1
countLbl.Text = "Collected: 0"
countLbl.TextColor3 = Color3.fromRGB(200, 200, 210)
countLbl.TextSize = 13
countLbl.Font = Enum.Font.Gotham
countLbl.TextXAlignment = Enum.TextXAlignment.Left
countLbl.Parent = f

statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -16, 0, 28)
statusLbl.Position = UDim2.new(0, 8, 0, 92)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "Auto-run | scanning NextGen..."
statusLbl.TextColor3 = Color3.fromRGB(180, 190, 210)
statusLbl.TextSize = 11
statusLbl.Font = Enum.Font.Gotham
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.TextWrapped = true
statusLbl.Parent = f


local function setOn(on)
    enabled = on
    btn.Text = on and "Steal NextGen: ON" or "Steal NextGen: OFF"
    btn.TextColor3 = on
        and Color3.fromRGB(80, 255, 120)
        or Color3.fromRGB(255, 90, 90)
    btn.BackgroundColor3 = on
        and Color3.fromRGB(28, 52, 36)
        or Color3.fromRGB(40, 40, 48)

    if on then
        total = 0
        emptyScans = 0
        sessionStart = os.clock()
        countLbl.Text = "Collected: 0"
        timeLbl.Text = "Time: 00:00"
        statusLbl.Text = "Scanning Next Generation Lucky Block..."
    else
        busy = false
        statusLbl.Text = "Paused"
    end
end

btn.MouseButton1Click:Connect(function()
    if hopping then
        return
    end
    setOn(not enabled)
end)


--------------------------------------------------
-- Timer
--------------------------------------------------
task.spawn(function()
    while true do
        if enabled and sessionStart > 0 and not hopping then
            timeLbl.Text = "Time: " .. fmtTime(os.clock() - sessionStart)
        end
        task.wait(0.25)
    end
end)


--------------------------------------------------
-- Main loop
--------------------------------------------------
task.spawn(function()
    task.wait(0.35)

    while true do
        if hopping then
            task.wait(0.2)
            continue
        end

        if enabled and not busy then
            busy = true

            ------------------------------------------
            -- Already carrying
            ------------------------------------------
            if LP:GetAttribute("holdingSlime") == true then
                statusLbl.Text = "Carrying — returning to base"
                emptyScans = 0
                toBase()
                local t = os.clock() + 5
                while enabled
                    and LP:GetAttribute("holdingSlime")
                    and os.clock() < t
                do
                    task.wait(0.1)
                end
                busy = false
                task.wait(0.1)
                continue
            end

            ------------------------------------------
            -- Presence scan
            ------------------------------------------
            local nextGenCount = countNextGenBlocks()

            if nextGenCount <= 0 then
                emptyScans += 1
                statusLbl.Text = string.format(
                    "No NextGen (%d/%d) — will hop",
                    emptyScans,
                    EMPTY_SCANS_BEFORE_HOP
                )
                busy = false

                if emptyScans >= EMPTY_SCANS_BEFORE_HOP then
                    hopServer()
                else
                    task.wait(SCAN_EMPTY_WAIT)
                end
                continue
            end

            emptyScans = 0
            statusLbl.Text = "Next Generation found — solidify + stand on top..."

            ------------------------------------------
            -- Cycle-style steal
            ------------------------------------------
            local result = stealOne()

            if result == "deposited" then
                statusLbl.Text = "Deposited held item"
                busy = false
                task.wait(0.15)
                continue
            end

            if result == true then
                total += 1
                countLbl.Text = "Collected: " .. total
                statusLbl.Text = "NextGen stolen — depositing..."

                task.wait(0.25)
                toBase()
                task.wait(0.3)

                local t = os.clock() + 5
                while enabled
                    and LP:GetAttribute("holdingSlime")
                    and os.clock() < t
                do
                    task.wait(0.1)
                end

                statusLbl.Text = "Scanning Next Generation Lucky Block..."
            else
                statusLbl.Text = "Steal failed — retry"
                task.wait(0.2)
            end

            busy = false
        end

        task.wait(0.08)
    end
end)


print(
    "[NextGenStealer] TARGET:",
    TARGET.Name,
    "| Rarity:",
    TARGET.Rarity,
    "| ID:",
    TARGET.ID,
    "| Steal: solidify + stand ON TOP + hover lock + zero hold prompt",
    "| hop to <=1 player servers if target absent after",
    EMPTY_SCANS_BEFORE_HOP,
    "empty scans"
)
