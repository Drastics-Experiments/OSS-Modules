local Http = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Spawn = require(script.Spawn)
local Util = require(script.Util)

local activeRemotes = {}
local Client = {
	_activeRemotes = activeRemotes,
	_initialized = false,
}

local Server = {
	_activeRemotes = activeRemotes,
	_initialized = false,
}

local dataQueue = {}
local dataQueueUnreliable = {}
local reliableHasContents = false
local unreliableHasContents = false
local IsServer, IsClient = RunService:IsServer(), RunService:IsClient()
local UnreliableEvent: UnreliableRemoteEvent, Event: RemoteEvent
local checkIfConvertable = Util.checkIfConvertable
local convertToBuffer = Util.convertToBuffer
local checkIfRemoteExists

local INSERT = table.insert
local CLEAR = table.clear
local UNPACK = table.unpack
local PACK = table.pack

-- // SHARED

local function updateValues(self)
	if self._reliable then
		reliableHasContents = true
	else
		unreliableHasContents = true
	end
end

local function disconnect(self)
	self._listeners[self._fn] = nil
	CLEAR(self)
end

local function Listen<T>(self, fn: T)
	self._listeners[tostring(fn)] = fn

	return {
		_listeners = self._listeners,
		_fn = tostring(fn),
		Disconnect = disconnect
	}
end

local function Once<fn>(self: serverRemote & clientRemote, fn: fn)
	if typeof(fn) ~= "function" then error("Retard") end
	
	local connection
	connection = self:Listen(function(...)
		Spawn(fn, ...)
		connection:Disconnect()
	end)
end

local function waitFor(self: serverRemote & clientRemote)
	local running = coroutine.running()
	local connection
	
	connection = self:Listen(function(...)
		connection:Disconnect()
		task.defer(running, ...)
	end)

	return coroutine.yield() 
end

local FRAME_RATE = 1/60
local Network = {}

local function onEventRecieved(self: serverRemote, Player: Player)
	local limitPerSecond = self._rateLimit
	local currentTally = self._currentTally
	local lastReset = self._lastReset

	if limitPerSecond > 0 then
		if os.clock() - lastReset >= 1 then
			CLEAR(currentTally)
			self._lastReset = os.clock()
			lastReset = self._lastReset
		end

		if not currentTally[Player] then
			currentTally[Player] = 0
		end

		if currentTally[Player] > limitPerSecond then
			if self._onRateLimitReached then
				self._onRateLimitReached(Player)
			end

			return false
		end

		currentTally[Player] += 1
	end

	return true
end



-- // SERVER

local function setRateLimit(self: serverRemote, rateLimit: number, fn: (Player: Player) -> ())
	if typeof(fn) ~= "function" then error("Did not recieve a function") return end 
	-- if fn isnt provided it will still exit the function

	if rateLimit and rateLimit >= 0 then
		self._rateLimit = rateLimit
		self._onRateLimitReached = fn
	end
end

local function serverFire<T...>(self: serverRemote, Players: { Player } | Player, ...: T...)
	local data = {
		[1] = self._name,
		[2] = PACK(...)
	}

	local canConvert = checkIfConvertable(data)
	if canConvert then data = convertToBuffer(data) end
	local correctQueue = (self._reliable and dataQueue) or dataQueueUnreliable
	
	if IsServer then
		if typeof(Players) ~= "table" then Players = { Players } end
		for i,v in Players do
			if not correctQueue[v] then
				correctQueue[v] = {}
			end

			INSERT(correctQueue[v], data)
		end
	elseif IsClient then
		INSERT(correctQueue, data)	
	end

	updateValues(self)
end

local function serverFireAll<T...>(self: serverRemote, ...: T...)
	local args = PACK(...)
	self:Fire(Players:GetPlayers(), UNPACK(args))
end

local function onServerInvoke<fn>(self: serverFunction, fn: fn)
	if typeof(fn) ~= "function" then error("retard") end
	self._callback = fn
end 


local function onServerEvent(plr: Player, data)
	for i,v in data do
		if typeof(v) == "buffer" then
			local decoded = Http:JSONDecode(buffer.tostring(v))
			v = decoded
			data[i] = decoded
		end
		
		local name = v[1]
		local remote = activeRemotes[name]
		local __type = remote.__type
		
		if __type == "Remote" then
			for i2, v2 in remote._listeners do
				if not remote:_onEvent(plr) then continue end
				Spawn(v2, plr, UNPACK(v[2]))
			end
		elseif __type == "Function" then
			if remote._callback == nil then continue end
			
			serverFire(remote, {plr}, 
				v[3],
				{remote._callback(plr, UNPACK(v[2]))}
			)
		end
	end
end

function Network.Server()
	if not Server._initialized then
		Event = Instance.new("RemoteEvent")
		UnreliableEvent = Instance.new("UnreliableRemoteEvent")
		
		Event.Parent = script
		UnreliableEvent.Parent = script
		
		checkIfRemoteExists = Server.Function("_CheckRemoteExists")
		checkIfRemoteExists:OnServerInvoke(function(plr, remoteName)
			if activeRemotes[remoteName] then return true end
			while not activeRemotes[remoteName] do task.wait(0.1) end
			return true
		end)
		
		Event.OnServerEvent:Connect(onServerEvent)
		UnreliableEvent.OnServerEvent:Connect(onServerEvent)
		
		local lastSent = 0
		RunService.PreSimulation:Connect(function(dt)
			lastSent += dt
			if lastSent < FRAME_RATE then return end
			lastSent = 0
			if reliableHasContents then
				for player, remoteCall in dataQueue do
					Event:FireClient(player, remoteCall)
				end

				CLEAR(dataQueue)
				reliableHasContents = false
			end

			if unreliableHasContents then
				for player, remoteCall in dataQueue do
					UnreliableEvent:FireClient(player, remoteCall)
				end
				
				CLEAR(dataQueueUnreliable)
				unreliableHasContents = false
			end
		end)
		
		Server._initialized = true
	end

	return Server
end

function Server.Remote(Name: string, Reliable: boolean?) : serverRemote
	local self = {
		_listeners = {},
		_reliable = if Reliable ~= nil then Reliable else true,
		_rateLimit = 0,
		_lastReset = 0,
		_currentTally = {},
		_name = Name,
		_onEvent = onEventRecieved,
		_onRateLimitReached = function() print("Rate Limit") end,
		
		__type = "Remote",
		
		Fire = serverFire,
		FireAll = serverFireAll,
		Once = Once,
		Wait = waitFor,
		Listen = Listen,
		RateLimit = setRateLimit
	}

	activeRemotes[Name] = self
	return self
end

function Server.Function(Name: string, Reliable: boolean?)
	local self = {
		OnServerInvoke = onServerInvoke,

		_reliable = if Reliable ~= nil then Reliable else true,
		_invokeResultsStorage = {},
		_currentYields = {},
		_callback = nil,
		_name = Name,

		__type = "Function",
	}

	activeRemotes[Name] = self
	return self
end


-- // CLIENT

local function invokeServer<T...>(self: clientFunction, ...: T...)
	local id = Http:GenerateGUID(false)
	local data = {
		[1] = self._name,
		[2] = PACK(...),
		[3] = id
	}

	local canConvert = checkIfConvertable(data)
	if canConvert then data = convertToBuffer(data) end

	INSERT((self._reliable and dataQueue) or dataQueueUnreliable, data)
	updateValues(self)
	self._currentYields[id] = coroutine.running()
	
	return coroutine.yield()
end

local function clientFire<T...>(self: clientRemote, ...: T...)
	serverFire(self, nil, ...)
end

local function onClientEvent(data)
	local unsuccessful = {}
	for i,v in data do
		if typeof(v) == "buffer" then
			local decoded = Http:JSONDecode(buffer.tostring(v))
			v = decoded
			data[i] = decoded
		end
		
		local name = v[1]
		local remote = activeRemotes[name]
		if activeRemotes[name] == nil then table.insert(unsuccessful, v) continue end
		
		local __type = remote.__type
		
		if __type == "Remote" then
			local ran = false
			for i2, v2 in remote._listeners do
				Spawn(v2, UNPACK(v[2]))
				ran = true
			end
			
			if ran == false then table.insert(unsuccessful, v) continue end
		elseif __type == "Function" then
			local contents = v[2]
			local data = contents[2]
			local id = contents[1]
			
			task.spawn(remote._currentYields[id], UNPACK(data))
			remote._currentYields[id] = nil
		end
	end
	
	if #unsuccessful > 0 then task.delay(0.2, onClientEvent, unsuccessful) end
end

function Network.Client()
	local r1, r2 = script:FindFirstChild("RemoteEvent"), script:FindFirstChild("UnreliableRemoteEvent")
	
	if not r1 or not r2 then
		warn("Server is not Initialized. Currently Yielding")
		r1, r2 = script:WaitForChild("RemoteEvent"), script:WaitForChild("UnreliableRemoteEvent")
	end
	
	if not Client._initialized then
		checkIfRemoteExists = Client.Function("_CheckRemoteExists")
		UnreliableEvent = r2
		Event = r1
		Client._initialized = true
		
		Event.OnClientEvent:Connect(onClientEvent)
		UnreliableEvent.OnClientEvent:Connect(onClientEvent)
		
		local lastSent = 0
		RunService.PreSimulation:Connect(function(dt)
			lastSent += dt
			if lastSent < FRAME_RATE then return end
			lastSent = 0
			
			if #dataQueue > 0 then
				Event:FireServer(dataQueue)
				CLEAR(dataQueue)
			end
			
			if #dataQueueUnreliable > 0 then
				UnreliableEvent:FireServer(dataQueueUnreliable)
				CLEAR(dataQueueUnreliable)
			end
		end)
	end

	return Client
end

function Client.Remote(Name: string, Reliable: boolean?) : clientRemote
	checkIfRemoteExists:Invoke(Name)
	local self = {
		Fire = clientFire,
		Listen = Listen,
		Once = Once,
		Wait = waitFor,
		
		_listeners = {},
		_reliable = if Reliable ~= nil then Reliable else true,
		_name = Name,

		__type = "Remote",
	}

	activeRemotes[Name] = self
	return self
end

function Client.Function(Name: string, Reliable: boolean?)
	if Name ~= "_CheckRemoteExists" then
		checkIfRemoteExists:Invoke(Name)
	end
	
	local self = {
		Invoke = invokeServer,

		_reliable = if Reliable ~= nil then Reliable else true,
		_currentYields = {},
		_name = Name,

		__type = "Function",
	}

	activeRemotes[Name] = self
	return self
end

export type serverRemote = typeof(Server.Remote(UNPACK(...)))
export type serverFunction = typeof(Server.Function(UNPACK(...)))
export type clientRemote = typeof(Client.Remote(UNPACK(...)))
export type clientFunction = typeof(Client.Function(UNPACK(...)))

return table.freeze(Network)
