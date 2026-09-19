-- Minimal Coach Lucky Block Stealer + timer + count
-- Target ONLY:
--   Coach Lucky Block | Rarity/Name: Coach / Coaches
-- Auto-starts on execute.
-- Steal flow:
--   find target → solidify box → cloak → teleport EXACTLY on top (no hover lock)
--   → zero HoldDuration → fire prompt → base on success
-- Fast scan; hops after 20s countdown or if no Coach after empty scans.

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local TARGETS = {
    {
        Key = "Coach",
        Name = "Coach Lucky Block",
        Rarity = "Coach",
        ID = nil, -- no fixed ID; match by name
        Priority = 1,
    },
}

local LUCKY_BLOCK_MODEL_NAMES = {
    ["Coach"] = {
        ["Coach Lucky Block"] = true,
        ["Coach"] = true,
        ["Coaches"] = true,
        ["CoachesTactical"] = true,
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
-- Always hop after this many seconds in a server, even mid-steal
local MAX_SERVER_TIME = 20


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


-- Returns target Key ("Coach") or nil
local function classifyTargetBlock(m)
    if not m or not m:IsA("Model") then
        return nil
    end

    local modelName = tostring(m.Name or "")
    local lowerName = modelName:lower()

    local rarity =
        m:GetAttribute("Rarity")
        or m:GetAttribute("_Rarity")
        or m:GetAttribute("rarity")
        or m:GetAttribute("rarityName")
    local r = rarity and tostring(rarity):lower() or ""

    local blockName =
        m:GetAttribute("LuckyBlockName")
        or m:GetAttribute("BlockName")
        or m:GetAttribute("DisplayName")
        or m:GetAttribute("Name")
    local bn = blockName and tostring(blockName):lower() or ""

    local id =
        m:GetAttribute("ID")
        or m:GetAttribute("Id")
        or m:GetAttribute("id")
        or m:GetAttribute("_RegisteredID")
        or m:GetAttribute("RegisteredID")
        or m:GetAttribute("LuckyBlockID")
        or m:GetAttribute("RegisteredId")
    local idStr = id and tostring(id) or ""

    -- ValueBase children (only set fields from matching child names)
    for _, childName in ipairs({
        "ID", "Id", "RegisteredID", "_RegisteredID", "RegisteredId",
        "Rarity", "_Rarity", "LuckyBlockName", "BlockName", "rarityName"
    }) do
        local obj = m:FindFirstChild(childName)
        if obj and obj:IsA("ValueBase") then
            local value = tostring(obj.Value)
            local vl = value:lower()
            local cn = childName:lower()
            if idStr == "" and (cn == "id" or cn:find("registered", 1, true)) then
                idStr = value
            end
            if r == "" and cn:find("rarity", 1, true) then
                r = vl
            end
            if bn == "" and (cn:find("name", 1, true) or cn:find("block", 1, true)) then
                bn = vl
            end
        end
    end

    -- CollectionService tags
    pcall(function()
        local CS = game:GetService("CollectionService")
        for _, tag in ipairs(CS:GetTags(m)) do
            local tl = tostring(tag):lower()
            if tl:find("coach", 1, true) then
                r = r ~= "" and r or "coach"
            end
        end
    end)

    -- Exact model-name table match first
    local coachNames = LUCKY_BLOCK_MODEL_NAMES["Coach"]
    if coachNames and coachNames[modelName] then
        return "Coach"
    end
    -- Coach by name / rarity / attributes
    if lowerName:find("coach", 1, true)
        or r:find("coach", 1, true)
        or bn:find("coach", 1, true)
    then
        return "Coach"
    end

    -- Everything else ignored (Coach only)
    return nil
end

local function isTargetBlock(m)
    return classifyTargetBlock(m) ~= nil
end

local function targetPriority(key)
    for _, t in ipairs(TARGETS) do
        if t.Key == key then
            return t.Priority
        end
    end
    return 99
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
-- Find nearest Coach target (cycle-style)
--------------------------------------------------
-- preferredKind: "Coach" | nil
local function getTargetLuckyBlock(preferredKind)
    local live = Workspace:FindFirstChild("Live")
    local slimes = live and live:FindFirstChild("Slimes")
    if not slimes then
        return nil
    end

    local r = root()
    local best, bestDist, bestPri = nil, math.huge, 99

    for _, model in ipairs(slimes:GetChildren()) do
        if model:IsA("Model") and not model:GetAttribute("Carrying") then
            local kind = classifyTargetBlock(model)
            if kind and (preferredKind == nil or kind == preferredKind) then
                local primary =
                    model.PrimaryPart
                    or model:FindFirstChildWhichIsA("BasePart")

                if primary then
                    local dist =
                        r and (r.Position - primary.Position).Magnitude
                        or 0
                    local pri = targetPriority(kind)

                    -- Prefer closer; if roughly same distance, prefer higher priority
                    local better =
                        dist + (pri * 0.01) < bestDist + (bestPri * 0.01)

                    if better then
                        bestDist = dist
                        bestPri = pri
                        local prompt
                        for _, d in ipairs(model:GetDescendants()) do
                            if d:IsA("ProximityPrompt") then
                                local at = tostring(d.ActionText or ""):lower()
                                if at:find("steal", 1, true)
                                    or at:find("pick", 1, true)
                                    or at:find("take", 1, true)
                                    or at == ""
                                then
                                    prompt = d
                                    if d.Enabled then
                                        break
                                    end
                                elseif not prompt then
                                    prompt = d
                                end
                            end
                        end
                        best = {
                            model = model,
                            part = primary,
                            prompt = prompt,
                            kind = kind,
                        }
                    end
                end
            end
        end
    end

    return best
end


local function countTargetBlocks()
    local live = Workspace:FindFirstChild("Live")
    local folder = live and live:FindFirstChild("Slimes")
    if not folder then
        return 0, 0, 0
    end

    local total, coachCount = 0, 0
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") and not m:GetAttribute("Carrying") then
            local kind = classifyTargetBlock(m)
            if kind == "Coach" then
                coachCount += 1
                total += 1
            end
        end
    end
    return total, coachCount, 0
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


-- Exactly on top of the box top face (small lift so HRP isn't clipped inside)
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
-- Steal: solidify → cloak → teleport EXACTLY on top → prompt (no hover lock)
--------------------------------------------------
local function stealOne(preferredKind)
    -- Already holding → deposit only
    if LP:GetAttribute("holdingSlime") == true then
        toBase()
        local t = os.clock() + 1.2
        while LP:GetAttribute("holdingSlime") and os.clock() < t do
            task.wait(0.08)
        end
        return "deposited"
    end

    local block = getTargetLuckyBlock("Coach")
        or getTargetLuckyBlock(nil)
    if not block then
        return false
    end

    makeLuckyBoxSolid(block)
    pcall(activateCloak)
    task.wait(0.1)

    local r = root()
    local hum = getHumanoid()
    if not r or not block.part or not block.part.Parent then
        return false
    end

    makeLuckyBoxSolid(block)

    -- Remove any leftover float objects from older versions
    for _, name in ipairs({ "LuckyFloat", "LuckyHoverPos", "LuckyHoverGyro" }) do
        local old = r:FindFirstChild(name)
        if old then
            old:Destroy()
        end
    end

    -- Spawn exactly on top of the lucky box (no BodyMovers / hover lock)
    local cf = standOnBoxCFrame(block.part)
    if not cf then
        return false
    end

    if hum then
        pcall(function()
            hum.PlatformStand = false
            hum.AutoRotate = true
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end)
    end

    r.CFrame = cf
    r.AssemblyLinearVelocity = Vector3.zero
    r.AssemblyAngularVelocity = Vector3.zero
    task.wait(0.05)

    -- Re-assert position once (in case physics nudged you)
    if block.part and block.part.Parent then
        local cf2 = standOnBoxCFrame(block.part)
        if cf2 then
            r = root()
            if r then
                r.CFrame = cf2
                r.AssemblyLinearVelocity = Vector3.zero
            end
        end
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
            if d:IsA("ProximityPrompt") then
                prompt = d
                if d.Enabled then
                    break
                end
            end
        end
    end

    if not prompt or not prompt.Parent then
        return false
    end

    pcall(function()
        prompt.Enabled = true
        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance, 20)
    end)

    local stolen = false
    for try = 1, 14 do
        -- Stay on top each try (teleport only, no hover lock)
        r = root()
        if r and block.part and block.part.Parent then
            local cf3 = standOnBoxCFrame(block.part)
            if cf3 then
                r.CFrame = cf3
                r.AssemblyLinearVelocity = Vector3.zero
            end
        end

        if (not prompt or not prompt.Parent) and block.model and block.model.Parent then
            for _, d in ipairs(block.model:GetDescendants()) do
                if d:IsA("ProximityPrompt") then
                    prompt = d
                    break
                end
            end
        end

        if prompt and prompt.Parent then
            pcall(function()
                prompt.Enabled = true
                prompt.HoldDuration = 0
            end)
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

    if LP:GetAttribute("holdingSlime") == true then
        stolen = true
    end

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


-- force=true: ignore cooldown (used by 20s countdown)
local function hopServer(force)
    if hopping then
        return
    end
    if not force and os.clock() - lastHopAt < HOP_COOLDOWN then
        return
    end

    hopping = true
    lastHopAt = os.clock()
    enabled = false
    busy = false

    local placeId = game.PlaceId

    pcall(function()
        if statusLbl then
            statusLbl.Text =
                "HOP NOW — finding server ( <= "
                .. tostring(MAX_SERVER_PLAYERS)
                .. " players )..."
        end
    end)

    local jobId, playing = findLowPopJobId(placeId)

    -- If no low-pop job found, still try a random public server teleport
    if not jobId then
        pcall(function()
            if statusLbl then
                statusLbl.Text = "No low-pop job — Teleport random public..."
            end
        end)
        local teleportedAny = pcall(function()
            TeleportService:Teleport(placeId, LP)
        end)
        if not teleportedAny then
            pcall(function()
                if statusLbl then
                    statusLbl.Text = "Teleport failed — retry in 2s"
                end
            end)
            hopping = false
            enabled = true
            emptyScans = 0
            -- restart countdown so we keep trying
            sessionStart = os.clock()
            task.wait(2)
            return
        end
        task.delay(12, function()
            hopping = false
            enabled = true
            emptyScans = 0
            sessionStart = os.clock()
        end)
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
        teleported = pcall(function()
            TeleportService:Teleport(placeId, LP)
        end)
    end

    if not teleported then
        pcall(function()
            if statusLbl then
                statusLbl.Text = "Teleport failed — retry countdown"
            end
        end)
        hopping = false
        enabled = true
        emptyScans = 0
        sessionStart = os.clock()
        return
    end

    task.delay(12, function()
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
        "AlternateStealer", "NextGenStealer", "NextGenerationStealer",
        "BacklineStealer", "BacklineLegendsStealer", "CoachStealer"
    }) do
        local old = PG:FindFirstChild(name)
        if old then
            old:Destroy()
        end
    end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "CoachStealer"
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
btn.Text = "Steal Coach: ON"
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
statusLbl.Text = "Auto-run | scanning Coach only..."
statusLbl.TextColor3 = Color3.fromRGB(180, 190, 210)
statusLbl.TextSize = 11
statusLbl.Font = Enum.Font.Gotham
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.TextWrapped = true
statusLbl.Parent = f


local function setOn(on)
    enabled = on
    btn.Text = on and "Steal Coach: ON" or "Steal Coach: OFF"
    btn.TextColor3 = on
        and Color3.fromRGB(80, 255, 120)
        or Color3.fromRGB(255, 90, 90)
    btn.BackgroundColor3 = on
        and Color3.fromRGB(28, 52, 36)
        or Color3.fromRGB(40, 40, 48)

    if on then
        total = 0
        emptyScans = 0
        sessionStart = os.clock() -- restart 20s countdown
        countLbl.Text = "Collected: 0"
        timeLbl.Text = string.format("Hop in: %ds", MAX_SERVER_TIME)
        statusLbl.Text = "Scanning Coach only..."
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
-- Countdown 20 → 0 (always visible). Force-hop at 0 even mid-steal.
--------------------------------------------------
task.spawn(function()
    while true do
        if hopping then
            timeLbl.Text = "Hopping..."
            task.wait(0.15)
            continue
        end

        if sessionStart <= 0 then
            sessionStart = os.clock()
        end

        local elapsed = os.clock() - sessionStart
        local left = math.max(0, math.ceil(MAX_SERVER_TIME - elapsed))

        if enabled then
            timeLbl.Text = string.format("Hop in: %ds", left)
        else
            timeLbl.Text = string.format("Paused | Hop in: %ds", left)
        end

        -- Independent of busy / stealOne: always hop when countdown hits 0
        if enabled and not hopping and elapsed >= MAX_SERVER_TIME then
            statusLbl.Text = "Countdown 0 — FORCE HOP (even if stealing)"
            busy = false
            hopServer(true)
        end

        task.wait(0.2)
    end
end)


--------------------------------------------------
-- Main loop
--------------------------------------------------
task.spawn(function()
    task.wait(0.35)
    sessionStart = os.clock() -- fresh 20s countdown on run

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
            local targetCount, coachCount = countTargetBlocks()

            if targetCount <= 0 then
                emptyScans += 1
                statusLbl.Text = string.format(
                    "No Coach (%d/%d) — will hop",
                    emptyScans,
                    EMPTY_SCANS_BEFORE_HOP
                )
                busy = false

                if emptyScans >= EMPTY_SCANS_BEFORE_HOP then
                    hopServer(true)
                else
                    task.wait(SCAN_EMPTY_WAIT)
                end
                continue
            end

            emptyScans = 0
            statusLbl.Text = string.format(
                "Coach found (%d) — teleport on top",
                coachCount
            )

            local okSteal, result = pcall(stealOne, "Coach")
            if not okSteal then
                statusLbl.Text = "Steal error: " .. tostring(result):sub(1, 40)
                warn("[CoachStealer] stealOne", result)
                busy = false
                task.wait(0.25)
                continue
            end

            if result == "deposited" then
                statusLbl.Text = "Deposited held item"
                busy = false
                task.wait(0.15)
                continue
            end

            if result == true then
                total += 1
                countLbl.Text = "Collected: " .. total
                statusLbl.Text = "Stolen — depositing..."

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

                statusLbl.Text = "Scanning Coach only..."
            else
                statusLbl.Text = "Coach steal failed — retry"
                task.wait(0.2)
            end

            busy = false
        end

        task.wait(0.08)
    end
end)


print(
    "[CoachStealer] ONLY Coach Lucky Block",
    "| teleport exactly ON TOP of box (no hover lock)",
    "| solidify + zero hold prompt",
    "| hop after empty scans or",
    MAX_SERVER_TIME,
    "s countdown"
)
