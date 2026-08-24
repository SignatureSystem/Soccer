local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FlyButtonGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local button = Instance.new("TextButton")
button.Name = "FlyButton"
button.Size = UDim2.new(0, 140, 0, 50)
button.Position = UDim2.new(1, -20, 0.85, 0)  -- Right side
button.AnchorPoint = Vector2.new(1, 0)
button.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
button.TextColor3 = Color3.fromRGB(255, 255, 255)
button.Text = "Hold to Fly Up"
button.Font = Enum.Font.GothamBold
button.TextSize = 18
button.AutoButtonColor = true
button.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = button

local flying = false
local flySpeed = 60

button.MouseButton1Down:Connect(function()
	flying = true
end)

button.MouseButton1Up:Connect(function()
	flying = false
end)

button.MouseLeave:Connect(function()
	flying = false
end)

button.TouchLongPress:Connect(function()
	flying = true
end)

button.TouchEnded:Connect(function()
	flying = false
end)

RunService.RenderStepped:Connect(function()
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	if flying then
		local velocity = rootPart.AssemblyLinearVelocity
		rootPart.AssemblyLinearVelocity = Vector3.new(velocity.X, flySpeed, velocity.Z)
	end
end)