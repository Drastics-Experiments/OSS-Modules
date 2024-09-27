local runService = game:GetService("RunService")
local httpService = game:GetService("HttpService")

local isServer, isClient = runService:IsServer(), runService:IsClient()

local instanceManager = require(script.instanceManager)
local tableManager = require(script.tableManager)
local signal = require(script.signal)
local bufferLib = require(script.buffer)

local tableInitQueue, propertyUpdatesQueue = {}, {}
local activeTables = {}
local tableReplicator = {}
local methods = {}

local function typeHandler(self, value)
    local metatable = getmetatable(self)
    local whitelistedPlayers = metatable.whitelistedPlayers
    local cache = metatable.cacheusage

    if type(value) == "table" then
        if isServer then
            tableManager.registerTable(value)
            tableManager.replicateTable(value, whitelistedPlayers)
        end
        
        table.insert(cache, tostring(value))
        
        local newSelf = tableReplicator.createMetatable()
        local newMetatable = getmetatable(newSelf)

        newMetatable.id = tostring(value)
        newMetatable.base = metatable.base

        for i,v in value do
            newSelf[i] = v
        end

        return newSelf
    elseif typeof(value) == "Instance" then
        if isServer then
            instanceManager.registerInstance(value)
            instanceManager.replicateInstances(value, whitelistedPlayers)
        end

        table.insert(cache, "instance: " .. value:GetDebugId(0))
        return value
    elseif type(value) == "string" then
        return tableManager.getTableFromId(value) 
        or instanceManager.getInstanceFromId(value) 
        or value
    end
end

local function __newindex(self, index, value)
	local metatable = getmetatable(self)
	local data = metatable.__index
	local oldValue = data[index]

    local oldMetatable = getmetatable(oldValue)
    if oldMetatable and oldMetatable.__type == "replicatedTable" then
        local base = oldMetatable.base
        local mainMeta = getmetatable(base)
        local cache = mainMeta.cacheusage
        table.remove(cache, table.find(oldMetatable.id))
    end

	data[typeHandler(self, index)] = typeHandler(self, value)
	if value ~= oldValue then
		if isServer then	
			if not propertyUpdatesQueue[metatable.id] then	
				propertyUpdatesQueue[metatable.id] = {}
			end
		
			local currentQueue = propertyUpdatesQueue[metatable.id]
			currentQueue[copy(index, true)] = copy(value, true)
		end

		self:FireChanged(index, value, oldValue)
	end
	
	return value
end

function tableReplicator.createMetatable()
	local self = setmetatable({
		Changed = signal.new(),
		GetPropertyChangedSignal = methods.GetPropertyChangedSignal,
		FireChanged = methods.FireChanged,
		GetRawTable = methods.GetRawTable,
		ReplicateTable = methods.ReplicateTable,
	}, {
		__index = {},
		cacheusage = {},
		__type = "replicatedTable",
		__newindex = __newindex,
		propertysignals = {},
	})
		
	local metatable = getmetatable(self)
	metatable.id = tostring(self)
	
	return self
end

function tableReplicator.new(tableProps: {
		Name: string,
		InitialData: {}?,
		PlayersToReplicate: { Player }?
	})

	local self = tableReplicator.createMetatable()

	local metatable = getmetatable(self)
	metatable.whitelistedPlayers = tableProps.PlayersToReplicate
	metatable.base = self
	if tableProps.InitialData then
		for i,v in tableProps.InitialData do
			self[i] = v
		end
	end

	if isServer then
		if tableProps.PlayersToReplicate then
			for i,v in tableProps.PlayersToReplicate do
				self:ReplicateTable(v)
			end
		end
	end

    activeTables[Name] = self

	return self
end

function methods:ReplicateTable(player: Player)
	local networkable = self:GetRawTable(true)
	local buffered = bufferLib.CompressTable(networkable)
	
	if not tableInitQueue[player] then
		tableInitQueue[player] = {}
	end
	
	table.insert(tableInitQueue[player], buffered)
end

local function checkForReplicatedTable(tbl)
	local metatable = getmetatable(tbl)
	return metatable and metatable.__type == "replicatedTable"
end

local function copy(value, networkify)
	if type(value) == "table" then
		local NewTable = {}

		for i,v in (checkForReplicatedTable(value) and getmetatable(value).__index) or value do
			NewTable[copy(i, networkify)] = copy(v, networkify)
		end

		return (networkify and tableManager.getIdFromTable(NewTable)) or NewTable
	elseif typeof(value) == "Instance" then
		return (networkify and instanceManager.getIdFromInstance(value)) or value
	elseif typeof(value) == "buffer" then
		value = httpService:JSONDecode(buffer.tostring(value))
		
		return copy(newTable, networkify)
	elseif type(value) == "string" then
		value = (networkify and tableManager.getTableFromId(value) or instanceManager.getInstanceFromId(value)) or value
	end
	
	return value
end

function methods:GetRawTable(networkify)
	local metatable = getmetatable(self)
	local rawData = {}

	for i,v in metatable.__index do
		rawData[copy(i, networkify)] = copy(v, networkify)
	end

	return rawData
end

function methods:FireChanged(index, value, oldValue)
	local metatable = getmetatable(self)
	local propertysignals = metatable.propertysignals

	self.Changed:Fire(index,value,oldValue)
	if propertysignals[index] then
		propertysignals[index]:Fire(value, oldValue)
	end
end

function methods:GetPropertyChangedSignal(property: string)
	local metatable = getmetatable(self)
	local propertysignals = metatable.propertysignals

	if not propertysignals[property] then
		propertysignals[property] = signal.new()
	end

	return propertysignals[property]
end

local lastCacheClear = 0
if isServer then
	local tableInit = Instance.new("RemoteEvent")
	local propertyUpdates = Instance.new("RemoteEvent")
	
	tableInit.Name, propertyUpdates.Name = "tableInit", "propertyUpdates"
	tableInit.Parent, propertyUpdates.Parent = script,script
	
	runService.Heartbeat:Connect(function(dt)
		for i,v in tableInitQueue do
			tableInit:FireClient(i, v)
		end

		for i,v in propertyUpdatesQueue do
			propertyUpdates:FireClient(i, v)
		end
		
		table.clear(tableInitQueue)
		table.clear(propertyUpdatesQueue)

        lastCacheClear += dt
        if lastCacheClear < 7 then return end

        local usedCacheData = {}
        for i,v in activeTables do
            local metatable = getmetatable(v)
            for i2, v2 in metatable.cacheusage do
                usedCacheData[v2] = true
            end
        end

		tableManager.clearCache(usedCacheData)
	end)
elseif isClient then
	local tableInit: RemoteEvent = script:WaitForChild("tableInit")
	local propertyUpdates: RemoteEvent = script:WaitForChild("propertyUpdates")
	
	
	
	tableInit.OnClientEvent:Connect(function(buffered, id)
		for i,v in buffered do
			print(httpService:JSONDecode(buffer.tostring(v)))
		end
		print(copy(buffered, false))
	end)
	
	propertyUpdates.OnClientEvent:Connect(function()
		
	end)
end

return tableReplicator