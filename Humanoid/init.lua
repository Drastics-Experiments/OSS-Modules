local runService = game:GetService("RunService")
local isClient, isServer = runService:IsClient(), runService:IsServer()

local signal = require(script.Signal)

local humanoid = {}
local methods = {}
local activeHumanoids = {}

debug.setmemorycategory("Humanoid")

local function setLinearVelocity(self, newVelocityX: number?, newVelocityY: number?, newVelocityZ: number?)
	local currentVelocity = self.RootPart.AssemblyLinearVelocity
	local x,y,z = currentVelocity.X, currentVelocity.Y, currentVelocity.Z

	local newX = newVelocityX or x
	local newY = newVelocityY or y
	local newZ = newVelocityZ or z

	self.RootPart.AssemblyLinearVelocity = Vector3.new(newX * self.WalkSpeed, newY, newZ * self.WalkSpeed)
end

function methods:Heal(amount: number)
	self.Health = math.clamp(self.Health + amount, 0, self.MaxHealth)
end

function methods:TakeDamage(amount: number)
	self.Health = math.clamp(self.Health - amount, 0, self.MaxHealth)
	if self.Health == 0 then
		self:FireStateSignal("Dead")
		self:ChangeState()
	end
end

function methods:GetPropertyChangedSignal(property: string)
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

function methods:Move(MoveDirection: Vector3)
	self.MoveDirection = MoveDirection
end



function methods:MoveTo(destination: Vector3)
	if typeof(destination) ~= "Vector3" then return end
	local metatable = getmetatable(self)
	local private = metatable.__private

	private.currentMoveTo = destination
	local lookvector = CFrame.new(self.RootPart.Position, destination).LookVector
	self:Move(Vector3.new(lookvector.X, 0, lookvector.Z))
end

function methods:AssignBackPack(backPack: Instance)
	if backPack == nil then error("the genius") end
	self.BackPack = backPack
end

function methods:EquipTool(toolName: string)
	if self.BackPack == nil then return end
	if self.RootPart == nil then return end
	if toolName == nil then return end

	local tool = self.BackPack:FindFirstChild(toolName)
	tool.Parent = self.RootPart.Parent
end

function methods:UnequipTools()
	local private = self._get().__private
	for i,v in self.RootPart.Parent:GetChildren() do
		if v:IsA("Tool") then
			v.Parent = self.BackPack
			table.insert(private.equippedTools, v)
		end
	end
end

function methods:GetLimb(limb: string)
	if not self.RootPart then return "No RootPart" end
	local char = self.RootPart.Parent
	return char:FindFirstChild(limb)
end

function methods:GetState()
	return self.HumanoidState
end

function methods:ChangeState(state: Enum.HumanoidStateType)
	local metatable = getmetatable(self)
	local disabledStates = metatable.__private.disabledStates
	if not disabledStates[state] then
		local oldState = self.HumanoidState
		rawset(metatable.__public, "HumanoidState", state) -- so .Changed doesnt fire
		self.StateChanged:Fire(state, oldState)
	end
end

function methods:SetStateEnabled(state: Enum.HumanoidStateType, enabled: boolean)
	local metatable = getmetatable(self)
	local private = metatable.__private
	local disabledStates = private.disabledStates

	if enabled then
		disabledStates[state] = nil
	else
		disabledStates[state] = true
	end
end


type state = "Running" | "FallingDown" | "Landed" | "Jumping" | "Climbing" | "Seated"
function methods:GetStateSignal(state: state)
	local private = self._get().__private
	local stateSignals = private.stateSignals
	if not stateSignals[state] then
		local newsignal = signal.new()
		stateSignals[state] = newsignal
		return newsignal
	else
		return stateSignals[state]
	end
end

function methods:FireStateSignal(state: state, ...)
	local private = self._get().__private
	local stateSignals = private.stateSignals
	local foundSignal = stateSignals[state]
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
	if ray.Distance > self.HipHeight then return end
	local private = metatable.__private
	setLinearVelocity(self, self.MoveDirection.X, 0, self.MoveDirection.Z)
	self:ChangeState(Enum.HumanoidStateType.Running)
	self:FireStateSignal("FallingDown")
end

local stateFunctions = {
	[Enum.HumanoidStateType.Running] = ifRunning,
	[Enum.HumanoidStateType.Jumping] = ifJumping,
	[Enum.HumanoidStateType.FallingDown] = ifFalling,
}

runService.Stepped:Connect(function(dt)
	for _, Humanoid in activeHumanoids do
		local metatable = Humanoid._get()
		local private = metatable.__private
		
		if not Humanoid.RootPart then continue end
		private.rayParams.FilterDescendantsInstances = {Humanoid.RootPart.Parent}

		local rootPart = Humanoid.RootPart
		local rootPos = rootPart.Position
		local ray = workspace:Raycast(rootPos - Vector3.new(0, rootPart.Size / 2, 0), Vector3.new(0, -Humanoid.HipHeight - 0.2, 0), private.rayParams)
		local moveDirection = Humanoid.MoveDirection

		stateFunctions[Humanoid.HumanoidState](Humanoid, metatable, ray)
		rootPart.AssemblyAngularVelocity = Vector3.zero

		if private.currentMoveTo then
			local destination = private.currentMoveTo
			if (Vector3.new(rootPos.X, 0, rootPos.Z) - Vector3.new(destination.X, 0, destination.Z)).Magnitude <= 1 then
				private.currentMoveTo = nil
				Humanoid:Move(Vector3.zero)
			end
		end
	end
end)


function humanoid.new()
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local self = setmetatable(table.clone(methods), {
		__public = {
			WalkSpeed = 16,
			JumpPower = 50,
			HipHeight = 2,
			Health = 100,
			MaxHealth = 100,
			Jump = false,
			MoveDirection = Vector3.zero,
			HumanoidState = Enum.HumanoidStateType.Running,
			FloorMaterial = Enum.Material.Air,
			Died = signal.new(),
			StateChanged = signal.new(),
			Changed = signal.new()
		},
		__private = {
			propertyChangedSignals = {},
			currentMoveTo = nil,
			disabledStates = {},
			stateSignals = {},
			equippedTools = {},
			rayParams = rayParams
		},
		__type = "Humanoid"
	})

	local metatable = getmetatable(self)
	metatable.__index = metatable.__public
	metatable.__newindex = function(self, index, value)
		local old = metatable.__public[index]
		rawset(metatable.__public, index, value)
		if value ~= old then
			self.Changed:Fire(index, value, old)
			local pc = metatable.__private.propertyChangedSignals
			if pc[index] then
				pc[index]:Fire(value, old)
			end
		end
	end
	
	metatable.__public._get = function()
		return getmetatable(self)
	end
	
	table.insert(activeHumanoids, self)
	return self
end

export type customHumanoid = typeof(humanoid.new(table.unpack(...)))
return humanoid