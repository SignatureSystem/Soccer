--[[
  SECURITY AUDIT — Privileged remote probe (clickable buttons)
  Run on a NON-ADMIN account. Each button fires one remote.
  PASS = nothing valuable changes. FAIL = cash/admin/jump/VIP/mutation applied.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local function findRemote(name)
	local sm = ReplicatedStorage:FindFirstChild("SharedModules")
	local net = sm and sm:FindFirstChild("Network")
	local folder = net and net:FindFirstChild("Remotes")
	if folder then
		local r = folder:FindFirstChild(name)
		if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then
			return r
		end
	end
	for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
		if obj.Name == name and (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then
			return obj
		end
	end
	return nil
end

local function registryRemote(name)
	local ok, reg = pcall(function()
		local sm = ReplicatedStorage:FindFirstChild("SharedModules")
		if not sm then return nil end
		local mod = sm:FindFirstChild("GameRemoteRegistry")
		if not mod then return nil end
		return require(mod)
	end)
	if not ok or type(reg) ~= "table" or type(reg.new) ~= "function" then
		return nil
	end
	local r = reg.new(name, "RemoteEvent")
	if r then return r end
	return reg.new(name, "RemoteFunction")
end

local function fireRemote(name, args)
	args = args or {}
	local remote = findRemote(name) or registryRemote(name)
	if not remote then
		return false, "NOT_FOUND"
	end
	local ok, res = pcall(function()
		if remote:IsA("RemoteFunction") then
			if typeof(remote.InvokeServer) == "function" then
				return remote:InvokeServer(table.unpack(args))
			end
			if typeof(remote.Fire) == "function" then
				return remote:Fire(table.unpack(args))
			end
		end
		if typeof(remote.FireServer) == "function" then
			remote:FireServer(table.unpack(args))
			return "FIRED_EVENT"
		end
		if typeof(remote.Fire) == "function" then
			return remote:Fire(table.unpack(args))
		end
		error("no fire method")
	end)
	if ok then
		return true, res
	end
	return false, tostring(res)
end

local function getCash()
	local ls = LP:FindFirstChild("leaderstats")
	if ls then
		local c = ls:FindFirstChild("Cash") or ls:FindFirstChild("Money")
		if c then return tonumber(c.Value) end
	end
	return tonumber(LP:GetAttribute("Cash")) or tonumber(LP:GetAttribute("cash"))
end

local TESTS = {
	{ name = "Give Me Cash", args = { 999999999 }, risk = "CRITICAL economy", color = Color3.fromRGB(90, 35, 35) },
	{ name = "Give Me Admin", args = {}, risk = "CRITICAL privilege", color = Color3.fromRGB(90, 35, 35) },
	{ name = "Give Me Jump", args = { 999 }, risk = "HIGH progression", color = Color3.fromRGB(90, 55, 30) },
	{ name = "AdminCommand", args = { "help" }, risk = "CRITICAL admin surface", color = Color3.fromRGB(90, 35, 35) },
	{ name = "AdminForceMutation", args = { "Rainbow" }, risk = "CRITICAL mutation", color = Color3.fromRGB(90, 35, 35) },
	{ name = "Gift VIP To Player", args = { LP.Name }, risk = "CRITICAL VIP grant", color = Color3.fromRGB(90, 35, 35) },
	{ name = "AdminGUIOpen", args = {}, risk = "MEDIUM admin UI", color = Color3.fromRGB(70, 60, 30) },
	{ name = "AdminFeedback", args = { "audit_ping" }, risk = "LOW feedback", color = Color3.fromRGB(40, 55, 40) },
	{ name = "AdminToast", args = { "audit_toast" }, risk = "LOW cosmetic", color = Color3.fromRGB(40, 55, 40) },
}

-- GUI
pcall(function()
	local old = PG:FindFirstChild("AdminRemoteAuditGui")
	if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "AdminRemoteAuditGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 10000
gui.IgnoreGuiInset = true
gui.Parent = PG

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 440, 0, 520)
frame.Position = UDim2.new(0, 20, 0.5, -260)
frame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 0, 32)
title.Position = UDim2.new(0, 12, 0, 8)
title.BackgroundTransparency = 1
title.Text = "Privileged Remote Audit"
title.TextColor3 = Color3.fromRGB(255, 220, 120)
title.TextSize = 16
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -40, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 180, 180)
closeBtn.TextSize = 16
closeBtn.Font = Enum.Font.GothamBold
closeBtn.AutoButtonColor = true
closeBtn.Parent = frame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
closeBtn.MouseButton1Click:Connect(function()
	gui:Destroy()
end)

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.new(1, -24, 0, 40)
status.Position = UDim2.new(0, 12, 0, 44)
status.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
status.Text = "Click a button to fire that remote.\nNon-admin: nothing valuable should change."
status.TextColor3 = Color3.fromRGB(200, 200, 210)
status.TextSize = 12
status.Font = Enum.Font.Gotham
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = frame
Instance.new("UICorner", status).CornerRadius = UDim.new(0, 8)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -24, 1, -140)
scroll.Position = UDim2.new(0, 12, 0, 92)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.CanvasSize = UDim2.new(0, 0, 0, #TESTS * 58 + 60)
scroll.Active = true
scroll.ScrollingEnabled = true
scroll.Parent = frame

local list = Instance.new("UIListLayout")
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Padding = UDim.new(0, 8)
list.Parent = scroll

local function setStatus(text, color)
	status.Text = text
	if color then
		status.TextColor3 = color
	else
		status.TextColor3 = Color3.fromRGB(200, 200, 210)
	end
end

local function makeTestButton(test, order)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -8, 0, 50)
	btn.BackgroundColor3 = test.color
	btn.BorderSizePixel = 0
	btn.Text = ""
	btn.AutoButtonColor = true
	btn.Active = true
	btn.Selectable = true
	btn.LayoutOrder = order
	btn.ZIndex = 5
	btn.Parent = scroll
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, -12, 0, 24)
	nameLbl.Position = UDim2.new(0, 10, 0, 4)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = test.name
	nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLbl.TextSize = 14
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.ZIndex = 6
	-- critical: labels must not swallow clicks
	nameLbl.Active = false
	nameLbl.Parent = btn

	local riskLbl = Instance.new("TextLabel")
	riskLbl.Size = UDim2.new(1, -12, 0, 18)
	riskLbl.Position = UDim2.new(0, 10, 0, 28)
	riskLbl.BackgroundTransparency = 1
	riskLbl.Text = test.risk .. "  |  click to fire"
	riskLbl.TextColor3 = Color3.fromRGB(220, 200, 180)
	riskLbl.TextSize = 11
	riskLbl.Font = Enum.Font.Gotham
	riskLbl.TextXAlignment = Enum.TextXAlignment.Left
	riskLbl.ZIndex = 6
	riskLbl.Active = false
	riskLbl.Parent = btn

	btn.MouseButton1Click:Connect(function()
		local cashBefore = getCash()
		setStatus("Firing: " .. test.name .. " ...", Color3.fromRGB(255, 230, 120))
		btn.Text = ""
		local ok, res = fireRemote(test.name, test.args)
		task.wait(0.4)
		local cashAfter = getCash()
		local cashNote = ""
		if cashBefore ~= nil and cashAfter ~= nil and cashAfter ~= cashBefore then
			cashNote = string.format(" | CASH CHANGED %s -> %s (FAIL)", tostring(cashBefore), tostring(cashAfter))
			setStatus(test.name .. " fired | " .. tostring(res) .. cashNote, Color3.fromRGB(255, 100, 100))
		else
			setStatus(
				string.format("%s | ok=%s res=%s | check admin/VIP/jump manually", test.name, tostring(ok), tostring(res)),
				ok and Color3.fromRGB(160, 255, 180) or Color3.fromRGB(255, 160, 120)
			)
		end
		print("[Audit]", test.name, "ok=", ok, "res=", res, "cash", cashBefore, "->", cashAfter)
	end)

	return btn
end

for i, test in ipairs(TESTS) do
	makeTestButton(test, i)
end

-- Run all
local allBtn = Instance.new("TextButton")
allBtn.Size = UDim2.new(1, -24, 0, 36)
allBtn.Position = UDim2.new(0, 12, 1, -44)
allBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 70)
allBtn.BorderSizePixel = 0
allBtn.Text = "Run ALL tests"
allBtn.TextColor3 = Color3.fromRGB(220, 220, 255)
allBtn.TextSize = 14
allBtn.Font = Enum.Font.GothamBold
allBtn.AutoButtonColor = true
allBtn.ZIndex = 5
allBtn.Parent = frame
Instance.new("UICorner", allBtn).CornerRadius = UDim.new(0, 8)

allBtn.MouseButton1Click:Connect(function()
	setStatus("Running all tests...", Color3.fromRGB(255, 230, 120))
	local cashBefore = getCash()
	for _, test in ipairs(TESTS) do
		local ok, res = fireRemote(test.name, test.args)
		print("[Audit ALL]", test.name, ok, res)
		task.wait(0.15)
	end
	task.wait(0.5)
	local cashAfter = getCash()
	if cashBefore ~= nil and cashAfter ~= nil and cashAfter ~= cashBefore then
		setStatus("ALL done | CASH CHANGED — HOLE", Color3.fromRGB(255, 80, 80))
	else
		setStatus("ALL done | verify admin/VIP/jump/mutations manually", Color3.fromRGB(160, 255, 180))
	end
end)

print("[AdminRemoteAudit] GUI# ready — buttons are clickable TextButtons")