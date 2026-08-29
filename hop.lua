-- Minimal Alternate Lucky Block Stealer + timer + count
-- Auto-starts on execute. Fast scan; hops to lowest-pop public server (max 1 player) if no Alternate Lucky Blocks.
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local TARGET = { Alternative = true }
local enabled, busy, total = true, false, 0
local sessionStart = os.clock()
local hopping = false
local emptyScans = 0
local EMPTY_SCANS_BEFORE_HOP = 3   -- consecutive empty fast scans before hop
local SCAN_EMPTY_WAIT = 0.15
local HOP_COOLDOWN = 2.0
local lastHopAt = 0

local function root()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function fmtTime(sec)
    sec = math.max(0, math.floor(sec))
    local m = math.floor(sec / 60)
    local s = sec % 60
    return string.format("%02d:%02d", m, s)
end

local function activateCloak()
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
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
        if tool then break end
    end
    if not tool then return end
    if tool.Parent \~= char then
        pcall(function() hum:UnequipTools() end)
        task.wait(0.05)
        pcall(function() hum:EquipTool(tool) end)
        if tool.Parent \~= char then pcall(function() tool.Parent = char end) end
        task.wait(0.12)
    end
    local ca = tool:FindFirstChild("CanActivate")
    if ca and ca:IsA("BoolValue") then ca.Value = true end
    pcall(function() tool:Activate() end)
    for _, p in ipairs(char:GetDescendants()) do
        if (p:IsA("BasePart") and p.Name \~= "HumanoidRootPart") or p:IsA("Decal") or p:IsA("Texture") then
            p.Transparency = 1
        end
    end
end

local function toBase()
    local r = root()
    if not r then return end
    local tp = _G.MyPlot and _G.MyPlot.Base and _G.MyPlot.Base.Teleport
    if tp and tp.WorldCFrame then
        r.CFrame = tp.WorldCFrame + Vector3.new(0, 3, 0)
        r.AssemblyLinearVelocity = Vector3.zero
        return
    end
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return end
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

local function findBlock()
    local live = workspace:FindFirstChild("Live")
    local folder = live and live:FindFirstChild("Slimes")
    if not folder then return nil end
    local best, bestV
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") and not m:GetAttribute("Carrying") then
            local name = m.Name
            -- Match "Alternate Lucky Block" (or anything containing both words)
            if (name:find("Alternate", 1, true) and name:find("Lucky", 1, true)) and TARGET.Alternative then
                local part = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
                if part then
                    local v = tonumber(m:GetAttribute("Value"))
                        or tonumber(m:GetAttribute("MoneyPerSecond"))
                        or 7e6
                    if not bestV or v > bestV then
                        local prompt
                        for _, d in ipairs(m:GetDescendants()) do
                            if d:IsA("ProximityPrompt") and d.Enabled then
                                prompt = d
                                local at = tostring(d.ActionText or ""):lower()
                                if at:find("steal") or at:find("pick") or at:find("take") then
                                    break
                                end
                            end
                        end
                        bestV = v
                        best = { rarity = "Alternative", part = part, prompt = prompt, model = m }
                    end
                end
            end
        end
    end
    return best
end

local function countTargetBlocks()
    local live = workspace:FindFirstChild("Live")
    local folder = live and live:FindFirstChild("Slimes")
    if not folder then return 0 end
    local n = 0
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model")
            and not m:GetAttribute("Carrying")
            and tostring(m.Name):find("Alternate", 1, true)
            and tostring(m.Name):find("Lucky", 1, true)
        then
            n += 1
        end
    end
    return n
end

local function steal(prompt)
    if not prompt then return false end
    local hold = prompt.HoldDuration or 0
    if typeof(fireproximityprompt) == "function" then
        if pcall(fireproximityprompt, prompt) then
            task.wait(hold + 0.5)
            return true
        end
    end
    if pcall(function() prompt:Trigger() end) then
        task.wait(hold + 0.5)
        return true
    end
    return false
end

-- HTTP helpers (executor-friendly; falls back when available)
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
    if ok then return data end
    return nil
end

-- Find public servers with the fewest players (prefer 0, allow only <= MAX_SERVER_PLAYERS)
local MAX_SERVER_PLAYERS = 1

local function findLowPopJobId(placeId)
    local cursor = ""
    local bestId, bestPlaying = nil, math.huge
    local pages = 0

    while pages < 5 do
        pages += 1
        local url = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true%s",
            placeId,
            cursor \~= "" and ("&cursor=" .. cursor) or ""
        )
        local body = httpGet(url)
        if not body then
            break
        end

        local data = decodeJson(body)
        if type(data) \~= "table" or type(data.data) \~= "table" then
            break
        end

        for _, server in ipairs(data.data) do
            local playing = tonumber(server.playing) or 999
            local maxPlayers = tonumber(server.maxPlayers) or 0
            local id = server.id or server.jobId

            -- Skip current server and invalid ids
            if id and tostring(id) \~= "" and tostring(id) \~= tostring(game.JobId) then
                if playing <= MAX_SERVER_PLAYERS and playing < bestPlaying then
                    bestPlaying = playing
                    bestId = tostring(id)
                    -- Perfect: empty server
                    if playing == 0 then
                        return bestId, bestPlaying
                    end
                end
            end
        end

        -- sortOrder=Asc already prefers low pop; if we found any <= limit, use it
        if bestId and bestPlaying <= MAX_SERVER_PLAYERS then
            return bestId, bestPlaying
        end

        cursor = data.nextPageCursor
        if type(cursor) \~= "string" or cursor == "" then
            break
        end
    end

    return bestId, bestPlaying
end

local function hopServer()
    if hopping then return end
    if os.clock() - lastHopAt < HOP_COOLDOWN then return end
    hopping = true
    lastHopAt = os.clock()
    enabled = false

    local placeId = game.PlaceId

    pcall(function()
        if statusLbl then
            statusLbl.Text = "Finding server with <= " .. tostring(MAX_SERVER_PLAYERS) .. " players..."
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
            statusLbl.Text = string.format("Hop -> %d player server...", tonumber(playing) or 0)
        end
    end)

    local teleported = false

    -- Prefer exact instance (low-pop)
    teleported = pcall(function()
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

    -- If teleport fails/stalls, allow retry later
    task.delay(10, function()
        hopping = false
        enabled = true
        emptyScans = 0
        sessionStart = os.clock()
    end)
end

-- GUI
pcall(function()
    local o = PG:FindFirstChild("AltLuckyStealer") or PG:FindFirstChild("JapanStealer") or PG:FindFirstChild("JIStealer")
    if o then o:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "AltLuckyStealer"
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
btn.Text = "Steal: ON"
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

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -16, 0, 28)
statusLbl.Position = UDim2.new(0, 8, 0, 92)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "Auto-run | scanning Alternate Lucky..."
statusLbl.TextColor3 = Color3.fromRGB(180, 190, 210)
statusLbl.TextSize = 11
statusLbl.Font = Enum.Font.Gotham
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.TextWrapped = true
statusLbl.Parent = f

local function setOn(on)
    enabled = on
    btn.Text = on and "Steal: ON" or "Steal: OFF"
    btn.TextColor3 = on and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 90, 90)
    btn.BackgroundColor3 = on and Color3.fromRGB(28, 52, 36) or Color3.fromRGB(40, 40, 48)
    if on then
        total = 0
        emptyScans = 0
        sessionStart = os.clock()
        countLbl.Text = "Collected: 0"
        timeLbl.Text = "Time: 00:00"
        statusLbl.Text = "Scanning Alternate Lucky Blocks..."
    else
        busy = false
        statusLbl.Text = "Paused"
    end
end

btn.MouseButton1Click:Connect(function()
    if hopping then return end
    setOn(not enabled)
end)

-- live timer while ON
task.spawn(function()
    while true do
        if enabled and sessionStart > 0 and not hopping then
            timeLbl.Text = "Time: " .. fmtTime(os.clock() - sessionStart)
        end
        task.wait(0.25)
    end
end)

-- Main loop: auto-run, fast scan, hop if empty
task.spawn(function()
    -- brief wait so Live/Slimes can replicate after execute
    task.wait(0.35)

    while true do
        if hopping then
            task.wait(0.2)
            continue
        end

        if enabled and not busy then
            busy = true

            if LP:GetAttribute("holdingSlime") == true then
                statusLbl.Text = "Carrying — returning to base"
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

            -- Fast presence scan first
            local targetCount = countTargetBlocks()
            if targetCount <= 0 then
                emptyScans += 1
                statusLbl.Text = string.format(
                    "No Alternate (%d/%d) — will hop",
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
            local b = findBlock()
            if not b then
                -- count said some exist but none targetable this tick
                statusLbl.Text = "Alternate seen — retargeting..."
                busy = false
                task.wait(0.12)
                continue
            end

            statusLbl.Text = "Alternate found — stealing..."
            activateCloak()
            task.wait(0.2)

            local r = root()
            if not r or not b.part or not b.part.Parent then
                busy = false
                task.wait(0.15)
                continue
            end

            r.CFrame = b.part.CFrame * CFrame.new(0, -1, 0)
            r.AssemblyLinearVelocity = Vector3.zero

            local bv = Instance.new("BodyVelocity")
            bv.Name = "LuckyFloat"
            bv.Velocity = Vector3.zero
            bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            bv.P = 1250
            bv.Parent = r
            task.wait(0.15)

            local prompt = b.prompt
            if (not prompt or not prompt.Parent) and b.model then
                for _, d in ipairs(b.model:GetDescendants()) do
                    if d:IsA("ProximityPrompt") and d.Enabled then
                        prompt = d
                        break
                    end
                end
            end

            local ok = prompt and steal(prompt)
            if not ok and LP:GetAttribute("holdingSlime") == true then
                ok = true
            end

            if bv.Parent then bv:Destroy() end
            r = root()
            if r then r.AssemblyLinearVelocity = Vector3.zero end

            if ok then
                total += 1
                countLbl.Text = "Collected: " .. total
                statusLbl.Text = "Stolen — depositing..."
                task.wait(0.25)
                toBase()
                task.wait(0.3)
                local t = os.clock() + 5
                while enabled and LP:GetAttribute("holdingSlime") and os.clock() < t do
                    task.wait(0.1)
                end
                statusLbl.Text = "Scanning Alternate Lucky Blocks..."
            else
                statusLbl.Text = "Steal failed — retry"
                task.wait(0.2)
            end

            busy = false
        end
        task.wait(0.08)
    end
end)

print("[AltLuckyStealer] Auto-run ON | hop to <=1 player servers if no Alternate Lucky Block after", EMPTY_SCANS_BEFORE_HOP, "empty scans")