local Http = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Spawn = require(script.Spawn)

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
local UnreliableEvent: UnreliableRemoteEvent, Event: RemoteEvent

local function checkIfConvertable(data: {})
	local CanConvert = true
	for i,v in data do
		if typeof(v) == "table" then
			if checkIfConvertable(v) == false then
				CanConvert = false
			end
		else
			local t = type(v)
			if t == "userdata" then
				return false
			end

			if t == "function" then
				error("Retard")
			end
		end
	end

	return CanConvert
end

local function convertToBuffer(data: {})
	local json = Http:JSONEncode(data)
	local newData = buffer.fromstring(json)

	return newData
end

local function disconnect(self)
	self._listeners[self._fn] = nil
	table.clear(self)
end

local function onEventRecieved<Data...>(self: serverRemote, Player: Player)
	local limitPerSecond = self._rateLimit
	local currentTally = self._currentTally
	local lastReset = self._lastReset
	
	if limitPerSecond > 0 then
		if os.clock() - lastReset >= 1 then
			table.clear(currentTally)
			self._lastReset = os.clock()
			lastReset = self._lastReset
		end
		
		if not currentTally[Player] then
			currentTally[Player] = 0
		end
		
		if currentTally[Player] > limitPerSecond then
			return false
		end
		
		currentTally[Player] += 1
	end
	
	return true
end

local function setRateLimit(self: clientRemote | serverRemote, rateLimit: number)
	if rateLimit and rateLimit >= 0 then
		self._rateLimit = rateLimit
	end
end

local function clientFire<T...>(self: clientRemote, ...: T...)
	local data = {
		[1] = self._name,
		[2] = {...}
	}

	local canConvert = checkIfConvertable(data)
	if canConvert then data = convertToBuffer(data) end
	table.insert((self._reliable and dataQueue) or dataQueueUnreliable, data)
	if self._reliable then
		reliableHasContents = true
	else
		unreliableHasContents = true
	end
end

local function clientListen<T>(self: clientRemote, fn: T)
	self._listeners[tostring(fn)] = fn

	return {
		_listeners = self._listeners,
		_fn = tostring(fn),
		Disconnect = disconnect
	}
end

function Client.Remote(Name: string, Reliable: boolean?)
	local self = {
		_listeners = {},
		_reliable = if Reliable ~= nil then Reliable else true,
		_name = Name,
		
		Fire = clientFire,
		Listen = clientListen,
	}

	activeRemotes[Name] = self
	return self
end




local function serverFire<T...>(self: serverRemote, Players: Player | { Player }, ...: T...)
	if typeof(Players) ~= "table" then Players = { Players } end
	local data = {
		[1] = self._name,
		[2] = {...}
	}

	local canConvert = checkIfConvertable(data)
	if canConvert then data = convertToBuffer(data) end
	local correctQueue = (self._reliable and dataQueue) or dataQueueUnreliable
	
	for i,v in Players do
		if not correctQueue[v] then
			correctQueue[v] = {}
		end
		
		table.insert(correctQueue[v], data)
	end
	
	if self._reliable then
		reliableHasContents = true
	else
		unreliableHasContents = true
	end
end

local function serverFireAll<T...>(self: serverRemote, ...: T...)
	self:Fire(Players:GetPlayers(), ...)
end

local function serverListen<T>(self: serverRemote, fn: T)
	self._listeners[tostring(fn)] = fn

	return {
		_listeners = self._listeners,
		_fn = tostring(fn),
		Disconnect = disconnect
	}
end

function Server.Remote(Name: string, Reliable: boolean?)
	local self = {
		_listeners = {},
		_reliable = if Reliable ~= nil then Reliable else true,
		_rateLimit = 0,
		_lastReset = 0,
		_currentTally = {},
		_name = Name,
		_onEvent = onEventRecieved,
		
		Fire = serverFire,
		FireAll = serverFireAll,
		Listen = serverListen,
		RateLimit = setRateLimit
	}
	
	activeRemotes[Name] = self
	return self
end


local FRAME_RATE = 1/60
local Network = {}

local function onServerEvent(plr: Player, data)
	for i,v in data do
		if typeof(v) == "buffer" then
			print(data)
			local decoded = Http:JSONDecode(buffer.tostring(v))
			v = decoded
			data[i] = decoded
		end
		
		local name = v[1]
		local remote = activeRemotes[name]

		for i2, v2 in remote._listeners do
			if not remote:_onEvent(plr) then print("Rate Limited") continue end
			Spawn(v2, plr, v[2])
		end
	end
end

function Network.Server()
	if not Server._initialized then
		Event = Instance.new("RemoteEvent")
		UnreliableEvent = Instance.new("UnreliableRemoteEvent")
		
		Event.Parent = script
		UnreliableEvent.Parent = script
		
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

				table.clear(dataQueue)
				reliableHasContents = false
			end

			if unreliableHasContents then
				for _, remoteCall in dataQueue do
					for i,v in remoteCall.Players do
						UnreliableEvent:FireClient(v, remoteCall.Data)
					end
				end
				
				table.clear(dataQueueUnreliable)
				unreliableHasContents = false
			end
		end)
		
		Server._initialized = true
	end

	return Server
end

local function onClientEvent(data)
	for i,v in data do
		if typeof(v) == "buffer" then
			local decoded = Http:JSONDecode(buffer.tostring(v))
			v = decoded
			data[i] = decoded
		end

		for i2, v2 in activeRemotes[v[1]]._listeners do
			Spawn(v2, v[2])
		end
	end
end

function Network.Client()
	local r1, r2 = script:FindFirstChild("RemoteEvent"), script:FindFirstChild("UnreliableRemoteEvent")
	
	if not r1 or not r2 then
		warn("Server is not Initialized. Currently Yielding")
		r1, r2 = script:WaitForChild("RemoteEvent"), script:WaitForChild("UnreliableRemoteEvent")
	end
	
	if not Client._initialized then
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
				table.clear(dataQueue)
			end
			
			if #dataQueueUnreliable > 0 then
				UnreliableEvent:FireServer(dataQueueUnreliable)
				table.clear(dataQueueUnreliable)
			end
		end)
	end

	return Client
end

export type serverRemote = typeof(Server.Remote(table.unpack(...)))
export type clientRemote = typeof(Client.Remote(table.unpack(...)))

return table.freeze(Network)