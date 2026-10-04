local Rayfield = loadstring(game:HttpGet("https://cdn.jsdelivr.net/gh/72msreal-pixel/MySoure@main/Rayfield-Plus.luau"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local flight = {
	enabled = false,
	mode = "CFrame",
	speed = 60,
	smoothness = 0.2,
	activeVelocity = Vector3.zero,
	hoverHeight = 12,

	attachment = nil :: Attachment?,
	linearVelocity = nil :: LinearVelocity?,
	alignOrientation = nil :: AlignOrientation?,

	bodyVelocity = nil :: BodyVelocity?,
	bodyGyro = nil :: BodyGyro?,
}

local movementKeys = {
	[Enum.KeyCode.W] = Vector3.new(0, 0, -1),
	[Enum.KeyCode.S] = Vector3.new(0, 0, 1),
	[Enum.KeyCode.A] = Vector3.new(-1, 0, 0),
	[Enum.KeyCode.D] = Vector3.new(1, 0, 0),
	[Enum.KeyCode.Space] = Vector3.new(0, 1, 0),
	[Enum.KeyCode.LeftShift] = Vector3.new(0, -1, 0),
}

local function getCharacterParts()
	local char = player.Character
	if not char then return nil end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then return nil end
	return char, root, hum
end

local function cleanupAllInstances()
	if flight.linearVelocity then flight.linearVelocity:Destroy(); flight.linearVelocity = nil end
	if flight.alignOrientation then flight.alignOrientation:Destroy(); flight.alignOrientation = nil end
	if flight.attachment then flight.attachment:Destroy(); flight.attachment = nil end
	if flight.bodyVelocity then flight.bodyVelocity:Destroy(); flight.bodyVelocity = nil end
	if flight.bodyGyro then flight.bodyGyro:Destroy(); flight.bodyGyro = nil end
end

local function setupLinearVelocity(root: BasePart)
	cleanupAllInstances()

	flight.attachment = Instance.new("Attachment")
	flight.attachment.Name = "FlyAttachment"
	flight.attachment.Parent = root

	flight.linearVelocity = Instance.new("LinearVelocity")
	flight.linearVelocity.Name = "FlyLinearVelocity"
	flight.linearVelocity.Attachment0 = flight.attachment
	flight.linearVelocity.MaxForce = math.huge
	flight.linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	flight.linearVelocity.VectorVelocity = Vector3.zero
	flight.linearVelocity.Parent = root

	flight.alignOrientation = Instance.new("AlignOrientation")
	flight.alignOrientation.Name = "FlyAlignOrientation"
	flight.alignOrientation.Attachment0 = flight.attachment
	flight.alignOrientation.Mode = Enum.AlignType.OneAttachment
	flight.alignOrientation.MaxTorque = math.huge
	flight.alignOrientation.Responsiveness = 200
	flight.alignOrientation.CFrame = root.CFrame
	flight.alignOrientation.Parent = root
end

local function setupBodyMovers(root: BasePart)
	cleanupAllInstances()

	flight.bodyVelocity = Instance.new("BodyVelocity")
	flight.bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	flight.bodyVelocity.Velocity = Vector3.zero
	flight.bodyVelocity.Parent = root

	flight.bodyGyro = Instance.new("BodyGyro")
	flight.bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	flight.bodyGyro.P = 10000
	flight.bodyGyro.D = 500
	flight.bodyGyro.CFrame = root.CFrame
	flight.bodyGyro.Parent = root
end

local function updateModeInstances()
	cleanupAllInstances()
	if not flight.enabled then return end

	local _, root = getCharacterParts()
	if not root then return end

	if flight.mode == "LinearVelocity" then
		setupLinearVelocity(root)
	elseif flight.mode == "BodyVelocity" then
		setupBodyMovers(root)
	end
end

local function setFlying(state: boolean)
	flight.enabled = state
	local _, root, hum = getCharacterParts()
	if not root or not hum then return end

	if flight.enabled then
		hum:ChangeState(Enum.HumanoidStateType.Physics)
		hum.PlatformStand = true
		flight.activeVelocity = Vector3.zero
		updateModeInstances()
	else
		hum.PlatformStand = false
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		cleanupAllInstances()
	end
end

local function getMoveDirection(): Vector3
	local dir = Vector3.zero
	for key, vec in pairs(movementKeys) do
		if UserInputService:IsKeyDown(key) then
			dir += vec
		end
	end
	return dir.Magnitude > 0 and dir.Unit or Vector3.zero
end

RunService.RenderStepped:Connect(function(deltaTime)
	if not flight.enabled then return end

	local char, root, hum = getCharacterParts()
	if not root or not hum then
		if flight.enabled then setFlying(false) end
		return
	end

	local moveDir = getMoveDirection()
	local camCF = camera.CFrame
	local targetVelocity = (camCF.RightVector * moveDir.X)
		+ (Vector3.new(0, 1, 0) * moveDir.Y)
		+ (camCF.LookVector * -moveDir.Z)

	if targetVelocity.Magnitude > 0 then
		targetVelocity = targetVelocity.Unit * flight.speed
	end

	flight.activeVelocity = flight.activeVelocity:Lerp(targetVelocity, 1 - (flight.smoothness ^ deltaTime))

	if flight.mode == "CFrame" then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.CFrame = CFrame.lookAlong(root.Position + (flight.activeVelocity * deltaTime), camCF.LookVector)

	elseif flight.mode == "LinearVelocity" then
		if flight.linearVelocity and flight.alignOrientation then
			flight.linearVelocity.VectorVelocity = flight.activeVelocity
			flight.alignOrientation.CFrame = CFrame.lookAlong(root.Position, camCF.LookVector)
		end

	elseif flight.mode == "BodyVelocity" then
		if flight.bodyVelocity and flight.bodyGyro then
			flight.bodyVelocity.Velocity = flight.activeVelocity
			flight.bodyGyro.CFrame = CFrame.lookAlong(root.Position, camCF.LookVector)
		end

	elseif flight.mode == "RaycastHover" then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero

		local rayParams = RaycastParams.new()
		rayParams.FilterDescendantsInstances = {char}
		rayParams.FilterType = RaycastParamsType.Exclude

		local rayResult = Workspace:Raycast(root.Position, Vector3.new(0, -100, 0), rayParams)
		local groundY = rayResult and rayResult.Position.Y or (root.Position.Y - flight.hoverHeight)

		local planarDir = (camCF.RightVector * moveDir.X) + (camCF.LookVector * -moveDir.Z)
		if planarDir.Magnitude > 0 then
			planarDir = Vector3.new(planarDir.X, 0, planarDir.Z).Unit * flight.speed
		else
			planarDir = Vector3.zero
		end

		flight.hoverHeight = math.clamp(flight.hoverHeight + (moveDir.Y * flight.speed * deltaTime * 0.5), 3, 80)

		local targetY = groundY + flight.hoverHeight
		local newPos = Vector3.new(
			root.Position.X + (planarDir.X * deltaTime),
			root.Position.Y + (targetY - root.Position.Y) * math.clamp(deltaTime * 8, 0, 1),
			root.Position.Z + (planarDir.Z * deltaTime)
		)

		root.CFrame = CFrame.lookAlong(newPos, Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z).Unit)

	elseif flight.mode == "CameraPivot" then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero

		local newCFrame = root.CFrame + (flight.activeVelocity * deltaTime)
		root.CFrame = CFrame.new(newCFrame.Position) * (camCF - camCF.Position)
	end
end)

player.CharacterAdded:Connect(function()
	flight.enabled = false
	cleanupAllInstances()
end)

local Window = Rayfield:CreateWindow({
	name = "Movement Controller",
	subtitle = "Multi-Engine Flight",
	icon = 0,
	size = UDim2.fromOffset(560, 420),
})

local Tab = Window:CreateTab({
	name = "Flight Modes",
	icon = 0,
})

Tab:CreateToggle({
	name = "Enable Flight",
	flag = "fly_toggle",
	value = false,
	callback = function(val)
		setFlying(val)
		Window:Toast({
			title = "Flight Engine",
			subtitle = val and ("Active: " .. flight.mode) or "Disabled",
			position = "Top",
			duration = 2,
		})
	end,
})

Tab:CreateDropdown({
	name = "Movement Engine",
	flag = "fly_engine",
	options = {
		"CFrame",
		"LinearVelocity",
		"BodyVelocity",
		"RaycastHover",
		"CameraPivot",
	},
	value = "CFrame",
	callback = function(option)
		flight.mode = option
		updateModeInstances()
		Window:Toast({
			title = "Mode Switched",
			subtitle = option,
			position = "Top",
			duration = 1.5,
		})
	end,
})

Tab:CreateSlider({
	name = "Speed",
	flag = "fly_speed",
	range = {10, 350},
	increment = 5,
	value = 60,
	suffix = " studs/s",
	callback = function(val)
		flight.speed = val
	end,
})

Tab:CreateSlider({
	name = "Hover Target Height",
	flag = "fly_hover_height",
	range = {5, 60},
	increment = 1,
	value = 12,
	suffix = " studs",
	callback = function(val)
		flight.hoverHeight = val
	end,
})

Tab:CreateKeybind({
	name = "Toggle Keybind",
	flag = "fly_bind",
	default = Enum.KeyCode.F,
	callback = function()
		setFlying(not flight.enabled)
	end,
})
