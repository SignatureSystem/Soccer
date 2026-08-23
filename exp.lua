--[[
  SECURITY AUDIT — Privileged remote probe
  --------------------------------------
  PURPOSE (owner / QA only):
    Run on a NORMAL (non-admin) account and confirm every call is REJECTED
    and that cash / jump / admin / VIP / mutations do NOT change.

  If anything succeeds on a non-admin account, that remote is a real hole.

  HOW TO USE:
    1. Join the live game on an alt that is NOT in your admin group.
    2. Execute this script.
    3. Read the output table in the console / on-screen GUI.
    4. Check your cash, jump, admin UI, inventory mutations, VIP.

  This script does NOT bypass security. It only calls the same remotes
  any executor could call, so you can see what your server allows.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local function findRemote(name)
	-- Preferred path used by this game
	local sm = ReplicatedStorage:FindFirstChild("SharedModules")
	local net = sm and sm:FindFirstChild("Network")
	local folder = net and net:FindFirstChild("Remotes")
	if folder then
		local r = folder:FindFirstChild(name)
		if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then
			return r
		end
	end
	-- Fallback: deep search
	for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
		if obj.Name == name and (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then
			return obj
		end
	end
	return nil
end

local function snapshot()
	local cash = LP:GetAttribute("Cash") or LP:GetAttribute("cash")
	-- try common leaderstats
	local ls = LP:FindFirstChild("leaderstats")
	if ls then
		local c = ls:FindFirstChild("Cash") or ls:FindFirstChild("Money")
		if c then cash = c.Value end
	end
	return {
		cash = cash,
		jump = LP:GetAttribute("Jump") or LP:GetAttribute("JumpPower"),
		admin = LP:GetAttribute("IsAdmin") or LP:GetAttribute("Admin"),
		base = LP:GetAttribute("BaseLevel"),
	}
end

local function fireRemote(remote, args)
	if not remote then
		return false, "NOT_FOUND"
	end
	local ok, err = pcall(function()
		if remote:IsA("RemoteFunction") then
			if typeof(remote.InvokeServer) == "function" then
				return remote:InvokeServer(table.unpack(args or {}))
			end
			-- some registry wrappers
			if typeof(remote.Fire) == "function" then
				return remote:Fire(table.unpack(args or {}))
			end
		elseif remote:IsA("RemoteEvent") then
			remote:FireServer(table.unpack(args or {}))
			return "FIRED"
		end
		error("unknown remote type")
	end)
	if ok then
		return true, err
	end
	return false, tostring(err)
end

--[[
  Targets: name, args to try, what a SUCCESS would mean (bad on non-admin)
]]
local TESTS = {
	{
		name = "Give Me Cash",
		args = { 999999999 }, -- amount guess; server may ignore args
		risk = "CRITICAL — direct economy break if accepted",
		explain = "Should no-op unless caller is privileged. Success = free cash.",
	},
	{
		name = "Give Me Admin",
		args = {},
		risk = "CRITICAL — privilege escalation if accepted",
		explain = "Should never grant admin from a client fire alone.",
	},
	{
		name = "Give Me Jump",
		args = { 999 },
		risk = "HIGH — progression skip if accepted",
		explain = "Should no-op or only apply for admins/studio.",
	},
	{
		name = "AdminCommand",
		args = { "help" }, -- benign probe; try a second wave manually if needed
		risk = "CRITICAL — full admin surface if accepted",
		explain = "Any successful command on a non-admin account is a break.",
	},
	{
		name = "AdminForceMutation",
		args = { "Rainbow" }, -- common mutation name probe
		risk = "CRITICAL — free high-value mutation if accepted",
		explain = "Must require admin + valid target ownership checks.",
	},
	{
		name = "Gift VIP To Player",
		args = { LP.Name }, -- self-target probe
		risk = "CRITICAL — free VIP / product grant if accepted",
		explain = "Must require real purchase/receipt or admin; never free grant.",
	},
	{
		name = "AdminGUIOpen",
		args = {},
		risk = "MEDIUM — usually opens UI only; still an admin channel",
		explain = "Opening UI is minor; dangerous only if UI then fires privileged commands without re-checking admin.",
	},
	{
		name = "AdminFeedback",
		args = { "audit_ping" },
		risk = "LOW–MEDIUM — feedback channel",
		explain = "Should be server→client or admin-only. Client fire should not grant rewards.",
	},
	{
		name = "AdminToast",
		args = { "audit_toast" },
		risk = "LOW — cosmetic toast",
		explain = "Cosmetic if server ignores; ensure it cannot be used to spoof system messages for social engineering only.",
	},
}

-- Optional GameRemoteRegistry path used by this game
local function registryFire(name, ...)
	local ok, reg = pcall(function()
		local sm = ReplicatedStorage:WaitForChild("SharedModules", 2)
		return require(sm:WaitForChild("GameRemoteRegistry", 2))
	end)
	if not ok or type(reg) ~= "table" or type(reg.new) ~= "function" then
		return false, "NO_REGISTRY"
	end
	local remote = reg.new(name, "RemoteEvent")
	if not remote then
		remote = reg.new(name, "RemoteFunction")
	end
	if not remote then
		return false, "REGISTRY_MISS"
	end
	local args = { ... }
	local ok2, res = pcall(function()
		if remote:IsA("RemoteFunction") or typeof(remote.InvokeServer) == "function" then
			return remote:InvokeServer(table.unpack(args))
		end
		if typeof(remote.Fire) == "function" then
			return remote:Fire(table.unpack(args))
		end
		remote:FireServer(table.unpack(args))
		return "FIRED"
	end)
	return ok2, res
end

local before = snapshot()
print("========== PRIVILEGED REMOTE AUDIT ==========")
print("Player:", LP.Name, "UserId:", LP.UserId)
print("Snapshot BEFORE:", before)
print("---------------------------------------------")

local results = {}

for _, test in ipairs(TESTS) do
	local remote = findRemote(test.name)
	local ok, res
	if remote then
		ok, res = fireRemote(remote, test.args)
	else
		-- try registry wrapper
		ok, res = registryFire(test.name, table.unpack(test.args or {}))
	end

	local row = {
		name = test.name,
		found = remote ~= nil or ok,
		firedOk = ok,
		response = res,
		risk = test.risk,
		explain = test.explain,
	}
	table.insert(results, row)

	print(string.format(
		"[%s] found=%s fired=%s resp=%s",
		test.name,
		tostring(remote ~= nil),
		tostring(ok),
		tostring(res)
	))
	print("  Risk:", test.risk)
	print("  Expect on non-admin: REJECT / no gameplay effect")
end

task.wait(1.25) -- allow server replicate
local after = snapshot()
print("---------------------------------------------")
print("Snapshot AFTER:", after)
print("Compare cash/jump/admin manually. Any increase on a non-admin account = HOLE.")
print("=============================================")

-- Minimal on-screen summary
pcall(function()
	local pg = LP:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild("AdminRemoteAuditGui")
	if old then old:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "AdminRemoteAuditGui"
	gui.ResetOnSpawn = false
	gui.Parent = pg

	local f = Instance.new("Frame")
	f.Size = UDim2.new(0, 420, 0, 360)
	f.Position = UDim2.new(0.5, -210, 0.5, -180)
	f.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	f.BorderSizePixel = 0
	f.Parent = gui
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -16, 0, 28)
	title.Position = UDim2.new(0, 8, 0, 6)
	title.BackgroundTransparency = 1
	title.Text = "Privileged Remote Audit (non-admin must FAIL)"
	title.TextColor3 = Color3.fromRGB(255, 220, 120)
	title.TextSize = 14
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = f

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -16, 1, -44)
	scroll.Position = UDim2.new(0, 8, 0, 36)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.new(0, 0, 0, #results * 52)
	scroll.Parent = f

	for i, row in ipairs(results) do
		local lab = Instance.new("TextLabel")
		lab.Size = UDim2.new(1, -8, 0, 48)
		lab.Position = UDim2.new(0, 0, 0, (i - 1) * 52)
		lab.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
		lab.BorderSizePixel = 0
		lab.Text = string.format(
			"%s\nfired=%s | %s",
			row.name,
			tostring(row.firedOk),
			row.risk
		)
		lab.TextColor3 = Color3.fromRGB(220, 220, 230)
		lab.TextSize = 11
		lab.Font = Enum.Font.Gotham
		lab.TextXAlignment = Enum.TextXAlignment.Left
		lab.TextYAlignment = Enum.TextYAlignment.Top
		lab.Parent = scroll
		Instance.new("UICorner", lab).CornerRadius = UDim.new(0, 6)
	end
end)

--[[
  MANUAL FOLLOW-UPS (if a remote needs different args):
  - AdminCommand: try your real command strings from AdminConsole (server still must auth).
  - AdminForceMutation: may need (slotName, mutationName) or (uid, mutationName) —
    check your server handler; wrong args still must not grant on non-admin.
  - Give Me Cash: may take no args or (amount). Either way non-admin must get 0.

  PASS criteria for production:
    Every test on a non-admin account → no currency, no admin flag, no VIP,
    no mutation, no jump unlock, no admin-only side effects.
]]