local runService = game:GetService("RunService")
local isClient, isServer = runService:IsClient(), runService:IsServer()

local signal = require(script.Signal)

local humanoid = {}
local activeHumanoids = {}

local function setLinearVelocity(self, newVelocityX: number?, newVelocityY: number?, newVelocityZ: number?)
	local self2 = getmetatable(self).data
	local currentVelocity = self2.RootPart.AssemblyLinearVelocity
	local x,y,z = currentVelocity.X, currentVelocity.Y, currentVelocity.Z

	local newX = newVelocityX or x
	local newY = newVelocityY or y
	local newZ = newVelocityZ or z

	self2.RootPart.AssemblyLinearVelocity = Vector3.new(newX * self.WalkSpeed, newY, newZ * self.WalkSpeed)
end

function humanoid:Heal(amount: number)
	self.Health = math.clamp(self.Health + amount, 0, self.MaxHealth)
end

function humanoid:TakeDamage(amount: number)
	self.Health = math.clamp(self.Health - amount, 0, self.MaxHealth)
	if self.Health == 0 then
		self.Died:Fire()
	end
end

function humanoid:GetPropertyChangedSignal(property: string)
	local metatable = getmetatable(self)
	local private = metatable.__private
	local propChangedSignals = private.propertyChangedSignals

	if not propChangedSignals[property] then
		local newSignal = signal.new()
		propChangedSignals[property] = newSignal
		return newSignal
	else
		return propChangedSignals[property]
	end
end

function humanoid:Move(MoveDirection: Vector3)
	self.MoveDirection = MoveDirection
end



function humanoid:MoveTo(destination: Vector3)
	if typeof(destination) ~= "Vector3" then return end
	local metatable = getmetatable(self)
	local private = metatable.__private

	private.currentMoveTo = destination
	local lookvector = CFrame.new(self.RootPart.Position, destination).LookVector
	self:Move(Vector3.new(lookvector.X, 0, lookvector.Z))
end

function humanoid:AssignBackPack(backPack: Instance)
	if backPack == nil then error("the genius") end
	self.BackPack = backPack
end

function humanoid:EquipTool(toolName: string)
	if self.BackPack == nil then return end
	if self.RootPart == nil then return end
	if toolName == nil then return end

	local tool = self.BackPack:FindFirstChild(toolName)
	tool.Parent = self.RootPart.Parent
end

function humanoid:UnequipTools()
	for i,v in self.RootPart.Parent:GetChildren() do
		if v:IsA("Tool") then
			v.Parent = self.BackPack
		end
	end
end

function humanoid:GetLimb(limb: string)
	local char = self.RootPart.Parent
	return char:FindFirstChild(limb)
end

function humanoid:GetState()
	return self.HumanoidState
end

function humanoid:ChangeState(state: Enum.HumanoidStateType)
	local metatable = getmetatable(self)
	local disabledStates = metatable.__private.disabledStates
	if not disabledStates[state] then
		local oldState = self.HumanoidState
		rawset(metatable.data, "HumanoidState", state) -- so .Changed doesnt fire
		self.StateChanged:Fire(state, oldState)
	end
end

function humanoid:SetStateEnabled(state: Enum.HumanoidStateType, enabled: boolean)
	local metatable = getmetatable(self)
	local private = metatable.__private
	local disabledStates = private.disabledStates

	if enabled then
		disabledStates[state] = nil
	else
		disabledStates[state] = true
	end
end


type state = "Running" | "FallingDown" | "Landed" | "Jumping" | "Clumbing" | "Seated"
function humanoid:GetStateSignal(state: state)
	if not self.StateSignals[state] then
		local newsignal = signal.new()
		self.StateSignals[state] = newsignal
		return newsignal
	else
		return self.StateSignals[state]
	end
end

function humanoid:FireStateSignal(state: state, ...)
	local foundSignal = self.StateSignals[state]
	if foundSignal then
		foundSignal:Fire(...)
	end
end

local function ifRunning(self, metatable, ray: RaycastResult?)
	local private = metatable.__private
	local rootPart = self.RootPart
	local linearVelocity = rootPart.AssemblyLinearVelocity
	local moveDirection = self.MoveDirection
	
	if not ray then self:ChangeState(Enum.HumanoidStateType.FallingDown) return end
	local distance = ray.Distance
	local neededAmount =  self.HipHeight - distance
	setLinearVelocity(self, moveDirection.X, neededAmount, moveDirection.Z)
	
	if self.Jump then
		self:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end

local function ifJumping(self, metatable, ray: RaycastResult?)
	local private = metatable.__private
	local rootPart = self.RootPart
	local linearVelocity = rootPart.AssemblyLinearVelocity
	if ray and self.Jump then
		self:ChangeState(Enum.HumanoidStateType.Jumping)
		setLinearVelocity(self, self.MoveDirection.X, self.JumpPower, self.MoveDirection.Z)
		self:FireStateSignal("Jumping", true)
	elseif linearVelocity.Y < 0 then
		self:ChangeState(Enum.HumanoidStateType.FallingDown)
		self:FireStateSignal("Jumping", false)
	end
end

local function ifFalling(self, metatable, ray)
	if not ray then return end
	local private = metatable.__private
	setLinearVelocity(self, nil, 0, nil)
	self:ChangeState(Enum.HumanoidStateType.Running)
	self:FireStateSignal("FallingDown")
end

local stateFunctions = {
	[Enum.HumanoidStateType.Running] = ifRunning,
	[Enum.HumanoidStateType.Jumping] = ifJumping,
	[Enum.HumanoidStateType.FallingDown] = ifFalling,
}

runService.PreSimulation:Connect(function(dt)
	for _, Humanoid in activeHumanoids do
		local metatable = getmetatable(Humanoid)
		local private = metatable.__private
		
		if not Humanoid.RootPart then continue end
		private.rayParams.FilterDescendantsInstances = {Humanoid.RootPart.Parent}
		local rootPart = Humanoid.RootPart
		local ray = workspace:Raycast(rootPart.Position, Vector3.new(0, -Humanoid.HipHeight - 0.2, 0), private.rayParams)
		local moveDirection = Humanoid.MoveDirection
		
		stateFunctions[Humanoid.HumanoidState](Humanoid, metatable, ray)
		rootPart.AssemblyAngularVelocity = Vector3.zero
		if private.currentMoveTo then
			if (Humanoid.RootPart.Position - private.currentMoveTo).Magnitude <= 1 then
				private.currentMoveTo = nil
				Humanoid:Move(Vector3.zero)
			end
		end
	end
end)

export type customHumanoid = {
	MoveDirection: Vector3,
	Health: number,
	MaxHealth: number,
	RootPart: BasePart?,
	HipHeight: number,
	Jump: boolean,
	JumpPower: number,
	WalkSpeed: number,
	FloorMaterial: Enum.Material,
	HumanoiState: Enum.HumanoidStateType,

}
return function(): customHumanoid
	local self = newproxy(true)
	local metatable = getmetatable(self)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	metatable.data = {
		MoveDirection = Vector3.zero,
		Health = 100,
		MaxHealth = 100,
		RootPart = nil,
		HipHeight = 4,
		Jump = false,
		JumpPower = 100,
		WalkSpeed = 16,
		FloorMaterial = Enum.Material.Air,
		HumanoidState = Enum.HumanoidStateType.Running,
		Changed = signal.new(),
		StateChanged = signal.new(),
		Died = signal.new(),
		StateSignals = {},
	}
	
	for i,v in humanoid do
		metatable.data[i] = v
	end
	
	metatable.__private = {
		propertyChangedSignals = {},
		disabledStates = {},
		currentMoveTo = nil,
		rayParams = rayParams,
		equippedTool = nil
	}

	metatable.__index = metatable.data
	metatable.__newindex = function(self, index, value)
		local old = metatable.data[index]
		rawset(metatable.data, index, value)

		if value ~= old then
			self.Changed:Fire(index, value, old)
			local pchanges = metatable.__private.propertyChangedSignals
			if pchanges[index] then
				pchanges[index]:Fire(value, old)
			end
		end
	end

	table.insert(activeHumanoids, self)
	print(activeHumanoids)
	print(metatable)
	return self:: customHumanoid
end
