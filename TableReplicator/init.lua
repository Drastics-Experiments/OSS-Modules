--!strict

local runService = game:GetService("RunService")
local httpService = game:GetService("HttpService")

local isServer, isClient = runService:IsServer(), runService:IsClient()

local instanceManager = require(script.instanceManager)
local tableManager = require(script.tableManager)
local signal = require(script.signal)
local bufferLib = require(script.buffer)
local utility = require(script.utility)

local tableInitQueue, propertyUpdatesQueue = {} :: { [Player]: { any } }, {}:: { [string]: { [any]: any } }
local activeTables = {}:: { [string]: replicatedTable }
local tableReplicator = {}
local methods = {}

local function check(self: replicatedTable, value: string)
	if type(value) ~= "string" then return end
	local metatable: metatable = getmetatable(getmetatable(self).base)
	if string.find(value, "table: ") then
		tableManager.replicateTable(tableManager.getTableFromId(value), metatable.whitelistedPlayers)
	elseif string.find(value, "instance: ") then
		instanceManager.replicateInstances(instanceManager.getInstanceFromId(value), metatable.whitelistedPlayers)
	end
end

local function makeCacheChanges(value, change)
	if typeof(value) == "table" then
		tableManager.editCacheId(tableManager.getIdFromTable(value), change)
	elseif typeof(value) == "Instance" then
		instanceManager.editCacheId("instance: " .. value:GetDebugId(0), change)
	end
end

local function detectCacheChanges(index, value, oldValue)
	if typeof(value) ~= typeof(oldValue) then
		makeCacheChanges(oldValue, -1)
	elseif getmetatable(value) ~= getmetatable(oldValue) then
		makeCacheChanges(oldValue, -1)
	elseif value == nil then
		makeCacheChanges(index, -1)
	end
end


local function __newindex(self: replicatedTable, index: any, value: any)
	local metatable: metatable = getmetatable(self)
	local data = metatable.__index
	local oldValue: any = data[index]

	detectCacheChanges(index, value, oldValue)

	data[utility.typeHandler(self, index)] = utility.typeHandler(self, value)
	if value ~= oldValue then
		if isServer then	
			if not propertyUpdatesQueue[metatable.id] then	
				propertyUpdatesQueue[metatable.id] = {}
			end

			local currentQueue = propertyUpdatesQueue[metatable.id]
			
			local i,v = utility.copy(index, true), utility.copy(value, true)
			
			check(self, i)
			check(self, v)
			
			currentQueue[i] = v
		end

		self:FireChanged(index, value, oldValue)
	end

	return value
end

type mainTable = {
	Changed: signal.Signal<any>,
	GetPropertyChangedSignal: (self: replicatedTable, property: string) -> (signal.Signal<any>),
	FireChanged: (self: replicatedTable, index: unknown, value: unknown, oldValue: unknown) -> (),
	GetRawTable: (self: replicatedTable, networkify: boolean) -> ({}),
	ReplicateTable: (self: replicatedTable, player: Player) -> (),
}

type privateTable = {
	__index: { 
		[any]: replicatedTable & any
	},
	__type: "replicatedTable",
	__newindex: (self: replicatedTable, index: any, value: any) -> (),

	id: string,
	base: replicatedTable,
	whitelistedPlayers: { Player },
	name: string?,
	propertysignals: {[string]: signal.Signal<...any>}
}

function tableReplicator.createMetatable()
	local self: replicatedTable
	self = setmetatable({
		Changed = signal.new(),
		GetPropertyChangedSignal = methods.GetPropertyChangedSignal,
		FireChanged = methods.FireChanged,
		GetRawTable = methods.GetRawTable,
		ReplicateTable = methods.ReplicateTable,
	}:: mainTable, {
		__index = {},
		__type = "replicatedTable",
		__newindex = __newindex,
		propertysignals = {},
		id = "",
	} :: privateTable)

	local metatable = getmetatable(self)
	metatable.id = tostring(self)

	return self
end


function tableReplicator.new(tableProps: {
	Name: string,
	InitialData: { [any]: any }?,
	PlayersToReplicate: { Player }?
	}): replicatedTable
	
	utility.yield()
	
	if isClient then 
		while not activeTables[tableProps.Name] do task.wait() end
		return activeTables[tableProps.Name]
	end
	
	local self: replicatedTable = tableReplicator.createMetatable()
	local metatable: metatable = getmetatable(self)
	
	metatable.name = tableProps.Name
	metatable.base = self

	if tableProps.PlayersToReplicate then
		metatable.whitelistedPlayers = tableProps.PlayersToReplicate
	end
	
	if tableProps.InitialData then
		for i: any, v: any in tableProps.InitialData do
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
	
	tableManager.registerTable(self, metatable.id)
	activeTables[tableProps.Name] = self
	
	return self
end

function methods.ReplicateTable(self: replicatedTable, player: Player)
	local networkable = self:GetRawTable(true)

	if not tableInitQueue[player] then
		tableInitQueue[player] = {}
	end

	table.insert(tableInitQueue[player], {
		Name = getmetatable(self).name,
		Id = getmetatable(self).id,
		Data = networkable
	})
end


function methods.GetRawTable(self: replicatedTable, networkify)
	local metatable: metatable = getmetatable(self)
	local rawData = {}

	for i,v in metatable.__index do
		rawData[utility.copy(i, networkify)] = utility.copy(v, networkify)
	end

	return rawData
end

function methods.FireChanged(self: replicatedTable, index: unknown, value: unknown, oldValue: unknown)
	local metatable = getmetatable(self)
	local propertysignals = metatable.propertysignals

	self.Changed:Fire(index,value,oldValue)
	if propertysignals[index] then
		propertysignals[index]:Fire(value, oldValue)
	end
end

function methods.GetPropertyChangedSignal(self: replicatedTable, property: string)
	local metatable: metatable = getmetatable(self)
	local propertysignals = metatable.propertysignals

	if not propertysignals[property] then
		propertysignals[property] = signal.new()
	end

	return propertysignals[property]
end

local lastCacheClear = 0
local function clearCache(dt: number)
	lastCacheClear += dt
	if lastCacheClear < 7 then return end
	lastCacheClear = 0

	tableManager.clearCache()
	instanceManager.clearCache()
end


local tableInit: RemoteEvent = script.tableInit
local propertyUpdates: RemoteEvent = script.propertyUpdate

if isServer then
	runService.Heartbeat:Connect(function(dt: number)
		for player: Player, sendData in tableInitQueue do
			tableInit:FireClient(player, bufferLib.CompressTable(sendData))
		end
		
		for tbl: string, sendData in propertyUpdatesQueue do
			local newTbl: replicatedTable = tableManager.getTableFromId(tbl)
			local meta = getmetatable(newTbl)
			local metatable: metatable = getmetatable(meta.base)
			if metatable.whitelistedPlayers then
				for i,v in metatable.whitelistedPlayers do
					propertyUpdates:FireClient(v, tbl, sendData)
				end
			end
		end

		table.clear(tableInitQueue)
		table.clear(propertyUpdatesQueue)
		clearCache(dt)
	end)
elseif isClient then
	runService.Heartbeat:Connect(function(dt)
		clearCache(dt)
	end)
	
	tableInit.OnClientEvent:Connect(function(sendData)
		utility.yield()
		local decompressed: {
			[number]: {
				Name: string,
				Id: string,
				Data: {any}
			}
		} = bufferLib.DecompressTable(sendData)
		
		for _, data in decompressed do
			local self = tableReplicator.createMetatable()
			local metatable = getmetatable(self)
			metatable.base = self
			metatable.name = data.Name
			
			local result = utility.typeHandler(self, data.Data)
			tableManager.registerTable(self, data.Id)
			activeTables[data.Name] = self
			
			for i,v in result do
				self[i] = v
			end
		end

	end)
	
	propertyUpdates.OnClientEvent:Connect(function(id, changes)
		while not tableManager.getTableFromId(id) do warn("No Table Found " .. id) task.wait(1) end
		local tbl: replicatedTable = tableManager.getTableFromId(id)
		local metatable: metatable = getmetatable(tbl)
		
		for i,v in changes do
			local i2, v2 = tableManager.getTableFromId(i) 
				or instanceManager.getInstanceFromId(i) 
				or i, tableManager.getTableFromId(v) 
				or instanceManager.getInstanceFromId(v) 
				or v
			
			tbl[i2] = v2
		end
	end)
end

export type replicatedTable = typeof(tableReplicator.createMetatable(table.unpack(...)))
export type metatable = typeof(getmetatable(tableReplicator.new(table.unpack(...))))
export type module = {
	new: (props: {
		Name: string,
		InitialData: { [any]: any }?,
		PlayersToReplicate: { Player }?
	}) -> (replicatedTable),
	createMetatable: () -> (replicatedTable),
}

return tableReplicator
