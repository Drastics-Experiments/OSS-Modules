-- NOTE: will not work without RBXM file

local RunService = game:GetService("RunService")
local Http = game:GetService("HttpService")
local InputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local IsServer, IsClient = RunService:IsServer(), RunService:IsClient()

local Signal = require(script.Signal)

local addDetector = script.AddDetector
local mouseClick = script.MouseClick
local removeDetector = script.RemoveDetector
local checkDetector = script.SeeIfDetectorExists
local propertyChanged = script.PropertyChanged

local ClickDetector = {}
local ActiveDetectors = {}

local currentHover, lastDetector
local Params = RaycastParams.new()
ClickDetector.Params = Params

Params.FilterType = Enum.RaycastFilterType.Exclude
Params.FilterDescendantsInstances = {}


type properties = {
	MaxActivationDistance: number?,
	CursorIcon: string?,
	ClientOnly: boolean?,
	Adornee: Instance?
}
function ClickDetector.new(customProps: properties?)
	local self = newproxy(true)
	local metatable = getmetatable(self)
	metatable.data = {
		MaxActivationDistance = 30,
		CursorIcon = "",
		ClientOnly = false,
		Adornee = nil,

		_currentlyHovering = false,
		_identifier = Http:GenerateGUID(false),

		MouseClick = Signal.new(),
		RightMouseClick = Signal.new(),
		MouseHoverEnter = Signal.new(),
		MouseHoverLeave = Signal.new(),
		_get = function() return metatable.data end,
		Destroy = function(self)
			ActiveDetectors[self._identifier] = nil
			self.MouseClick:Destroy()
			self.RightMouseClick:Destroy()
			self.MouseHoverEnter:Destroy()
			self.MouseHoverLeave:Destroy()
			
			for i,v in self:_get() do
				self[i] = nil
			end
		end,
	}

	metatable.__index = metatable.data
	metatable.__newindex = function(self, index, value)
		if self[index] ~= value then
			rawset(self:_get(), index, value)
			if IsServer then
				propertyChanged:FireAllClients(self._identifier, index, value)
			end
		end
	end

	if customProps then
		for i,v in customProps do
			self[i] = v
		end
	end
	
	ActiveDetectors[tostring(self._identifier)] = self
	if IsServer then
		self.ClientOnly = false
		addDetector:FireAllClients({
			MaxActivationDistance = self.MaxActivationDistance,
			CursorIcon = self.CursorIcon,
			Adornee = self.Adornee,
			_identifier = self._identifier,
			ClientOnly = self.ClientOnly
		})
	else
		if not checkDetector:InvokeServer(self._identifier) then
			self.ClientOnly = true
		end
	end
	
	return self
end

local function getNonModel(model: Model | Part)
	if model:IsA("Model") then
		return model.PrimaryPart
	end

	return model
end

local function checkIfValid(adornee, part)
	return adornee == part or adornee:IsAncestorOf(part)
end

local function onMouseClick(player: Player, identifier: string, clickType: "MouseClick" | "RightMouseClick")
	if not IsServer then return end
	
	local char: Model? = player.Character
	if not char then return end

	local foundClickDetector = ActiveDetectors[identifier]
	local detectionDistance = foundClickDetector.MaxActivationDistance
	local root = char:FindFirstChild("HumanoidRootPart")
	
	if not root then return end
	if (root.Position - getNonModel(foundClickDetector.Adornee).Position).Magnitude <= detectionDistance then
		foundClickDetector[clickType]:Fire(player)
	end
end

local function onHover(self, mouse: Mouse)
	if self._currentlyHovering == false then
		self._currentlyHovering = true
		mouse.Icon = self.CursorIcon
		self.MouseHoverEnter:Fire()
	end

	currentHover = self
end

local function onLeave(self, mouse: Mouse)
	if self._currentlyHovering then
		self._currentlyHovering = false
		mouse.Icon = ""
		self.MouseHoverLeave:Fire()
	end

	currentHover = nil
	ActiveDetectors[self._identifier] = self
end

local function onHeartbeat(player: Player, mouse: Mouse, cam: Camera)
	local mousePosition = InputService:GetMouseLocation()
	local viewportPoint = cam:ViewportPointToRay(mousePosition.X, mousePosition.Y)
	local cast = workspace:Raycast(viewportPoint.Origin, viewportPoint.Direction * 1000, Params)

	if not cast then 
		if currentHover then
			onLeave(lastDetector, mouse)
			lastDetector = nil
		end
		return 
	end

	local part = cast.Instance
	if currentHover then
		if not checkIfValid(currentHover.Adornee, part) then
			onLeave(currentHover, mouse)
			lastDetector = nil
			return
		end
	end

	for i, v in ActiveDetectors do
		if not v.Adornee then continue end
		if not checkIfValid(v.Adornee, part) then continue end
		
		onHover(v, mouse)
		lastDetector = v
		ActiveDetectors[i] = nil
	end
end

local button1PressedOn, button2PressedOn
local button1, button2 = Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2
local function onMousePress()
	if not lastDetector then return end

	if InputService:IsMouseButtonPressed(button1) then
		button1PressedOn = lastDetector
	elseif InputService:IsMouseButtonPressed(button2) then
		button2PressedOn = lastDetector
	end
end

local function onMouseRelease(input: InputObject)
	if InputService:GetFocusedTextBox() then return end
	if not lastDetector then return end
	
	local wasButton1, wasButton2 = lastDetector == button1PressedOn, lastDetector == button2PressedOn
	if input.UserInputType == button1 and wasButton1 then
		lastDetector.MouseClick:Fire()
		if lastDetector.ClientOnly then return end
		mouseClick:FireServer(lastDetector._identifier, "MouseClick")
	elseif input.UserInputType == button2 and wasButton2 then
		lastDetector.RightMouseClick:Fire()
		if lastDetector.ClientOnly then return end
		mouseClick:FireServer(lastDetector._identifier, "RightMouseClick")
	end
end

local function onPropertyChanged(identifier, index, value)
	ActiveDetectors[identifier][index] = value
end

if IsClient then
	local player = Players.LocalPlayer
	local mouse = player:GetMouse()
	local cam = workspace.CurrentCamera
	
	RunService.Heartbeat:Connect(function(dt)
		onHeartbeat(player, mouse, cam)
	end)
	
	addDetector.OnClientEvent:Connect(ClickDetector.new)
	mouse.Button1Down:Connect(onMousePress)
	mouse.Button2Down:Connect(onMousePress)
	InputService.InputEnded:Connect(onMouseRelease)
	propertyChanged.OnClientEvent:Connect(onPropertyChanged)
end

if IsServer then
	local a = ClickDetector.new({ClientOnly = false, CursorIcon = "rbxassetid://13923614662", Adornee = workspace.Entities.daz_fe})
	local s = ClickDetector.new({ClientOnly = false, Adornee = workspace.Baseplate})

	mouseClick.OnServerEvent:Connect(onMouseClick)
	checkDetector.OnServerInvoke = function(identifier)
		return (ActiveDetectors[identifier] and true) or false
	end
end

return ClickDetector