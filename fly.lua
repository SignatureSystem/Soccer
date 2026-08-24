local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create the GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FlyButtonGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local button = Instance.new("TextButton")
button.Name = "FlyButton"
button.Size = UDim2.new(0, 140, 0, 50)
button.Position = UDim2.new(0.5, -70, 0.85, 0)
button.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
button.TextColor3 = Color3.fromRGB(255, 255, 255)
button.Text = "Hold to Fly Up"
button.Font = Enum.Font.GothamBold
button.TextSize = 18
button.Parent = screenGui

-- Rounded corners (optional)
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = button

local flying = false
local flySpeed = 60 -- Change this number to make it faster/slower

-- Detect holding the button
button.MouseButton1Down:Connect(function()
	flying = true
end)

button.MouseButton1Up:Connect(function()
	flying = false
end)

-- Also stop flying if the mouse leaves the button while held
button.MouseLeave:Connect(function()
	flying = false
end)

-- Make the character fly upward while holding
RunService.RenderStepped:Connect(function()
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	if flying then
		-- Keep current horizontal speed, force vertical speed upward
		local velocity = rootPart.AssemblyLinearVelocity
		rootPart.AssemblyLinearVelocity = Vector3.new(velocity.X, flySpeed, velocity.Z)
	end
end)