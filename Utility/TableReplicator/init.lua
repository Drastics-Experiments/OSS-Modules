-- Old version of module, current version is no longer public.

--!strict

local runService = game:GetService("RunService")
local httpService = game:GetService("HttpService")

local isServer, isClient = runService:IsServer(), runService:IsClient()

local instanceManager = require(script.instanceManager)
local tableManager = require(script.tableManager)
local signal = require(script.signal)
local bufferLib = require(script.buffer)
local utility = require(script.utility)

local activeTables = {}:: { [string]: replicatedTable }
local tableReplicator = {}
local methods = {}

local tableInit: RemoteEvent = script.tableInit
local propertyUpdates: RemoteEvent = script.propertyUpdate

type mainTable = {
	Changed: signal.Signal<any>,
	GetPropertyChangedSignal: (self: replicatedTable, property: string) -> (signal.Signal<any>),
	FireChanged: (self: replicatedTable, index: unknown, value: unknown, oldValue: unknown) -> (),
	GetRawTable: (self: replicatedTable, networkify: boolean) -> ({}),
	ReplicateTable: (self: replicatedTable, player: Player) -> (),
	ApplyMetatable: (self: replicatedTable, meta: {[string]: any}) -> (),
}

type privateTable = {
	__index: { 
		[any]: replicatedTable & any
	},
	__type: "replicatedTable",
	__newindex: (self: replicatedTable, index: any, value: any) -> (),
	__len: (self: replicatedTable) -> (number),

	meta: { [string]: any },
	id: string,
	base: replicatedTable,
	whitelistedPlayers: { Player },
	name: string?,
	propertysignals: { [string]: signal.Signal<any> }
}

type propertyUpdate = {
	id: string,
	i: any,
	v: any
}

export type module = {
	new: (props: {
		Name: string,
		InitialData: { [any]: any }?,
		PlayersToReplicate: { Player }?
	}) -> (replicatedTable),
	createMetatable: () -> (replicatedTable),
}

local function makeCacheChanges(value, change)
	if typeof(value) == "table" then
		tableManager.editCacheId(tableManager.getIdFromTable(value), change)
	elseif typeof(value) == "Instance" then
		local result = instanceManager.getIdFromInstance(value)
		
		if result then
			instanceManager.editCacheId(result, change)
		end
	end
end

local function check(self: replicatedTable, value: string)
	if type(value) ~= "string" then return end
	local metatable: metatable = getmetatable(getmetatable(self).base)
	if string.find(value, "table: ") then
		tableManager.replicateTable(tableManager.getTableFromId(value), metatable.whitelistedPlayers)
	elseif string.find(value, "instance: ") then
		local result = instanceManager.getInstanceFromId(value)
		
		if result then
			instanceManager.replicateInstances(result, metatable.whitelistedPlayers)
		end
	end
end

local function __newindex(self: replicatedTable, index: any, value: any)
	local metatable: metatable = getmetatable(self)
	local data = metatable.__index
	local oldValue: any = data[index] 

	if typeof(value) ~= typeof(oldValue) or getmetatable(value) ~= getmetatable(oldValue) then makeCacheChanges(oldValue, -1) end
	if value == nil then makeCacheChanges(index, -1) end
	if not data[index] then index = utility.typeHandler(self, index) end

	value = utility.typeHandler(self, value)
	data[index] = if value ~= "__EMPTY" then value else nil
	
	if value ~= oldValue then
		if isServer then
			local meta = getmetatable(metatable.base)
			local whitelistedPlayers = meta.whitelistedPlayers
			local i,v = utility.copy(index, true), utility.copy(value, true)

			check(self, i)
			check(self, v)
			
			if whitelistedPlayers then
				for _, plr in whitelistedPlayers do
					propertyUpdates:FireClient(plr, bufferLib.CompressTable({
						id = metatable.id,
						i = i,
						v = v
					}))
				end
			end
		end

		self:FireChanged(index, data[index], oldValue)
	end

	local meta = metatable.meta
	if meta and meta.__newindex then
		local success, err = pcall(meta.__newindex, self, index, value)
		if not success then
			warn(err)
		end
	end

	return value
end

local function __len(self)
	-- supports dictionaries and not only arrays
	
	local meta = getmetatable(self)
	local num = 0
	
	for i,v in meta.__index do
		num += 1
	end
	
	return num
end

function tableReplicator.createMetatable()
	local self: replicatedTable
	self = setmetatable({
		Changed = signal.new(),
		GetPropertyChangedSignal = methods.GetPropertyChangedSignal,
		FireChanged = methods.FireChanged,
		GetRawTable = methods.GetRawTable,
		ReplicateTable = methods.ReplicateTable,
		ApplyMetatable = methods.ApplyMetatable
	}:: mainTable, {
		__index = {},
		__type = "replicatedTable",
		__newindex = __newindex,
		__len = __len,
		propertysignals = {},
		id = "",
		meta = {},
	} :: privateTable)

	local metatable = getmetatable(self)
	metatable.id = tostring(self)

	return self
end


function tableReplicator.new(Name: string, tableProps: {
		InitialData: { [any]: any },
		PlayersToReplicate: { Player }
	}): replicatedTable

	utility.yield()

	if isClient then 
		while not activeTables[Name] do task.wait() end
		return activeTables[Name]
	end

	local self: replicatedTable = tableReplicator.createMetatable()
	local metatable: metatable = getmetatable(self)

	metatable.name = Name
	metatable.base = self

	if tableProps.InitialData then
		for i: any, v: any in tableProps.InitialData do
			self[i] = v
		end
	end

	if isServer then
		if tableProps.PlayersToReplicate then
			metatable.whitelistedPlayers = tableProps.PlayersToReplicate
			for i,v in tableProps.PlayersToReplicate do
				self:ReplicateTable(v)
			end
		end
	end

	tableManager.registerTable(self, metatable.id)
	tableManager.editCacheId(metatable.id, 1)
	activeTables[Name] = self

	return self
end

function methods.ApplyMetatable(self: replicatedTable, meta: { [string]: any })
	if meta.__index then
		warn("__index is not supported")
		meta.__index = nil
	end

	if meta.__metatable then
		warn("__metatable is not supported")
		meta.__metatable = nil
	end

	local metatable: metatable = getmetatable(self)
	local typeErrorBypass = {} :: { [string]: any }
	metatable.meta = typeErrorBypass
	
	for i: string, v: any in meta do
		if not metatable[i] then
			metatable[i] = v
		else
			metatable.meta[i] = v
		end
	end
end

function methods.ReplicateTable(self: replicatedTable, player: Player)
	local networkable = self:GetRawTable(true)
	local meta = getmetatable(self)
		
	tableInit:FireClient(player, bufferLib.CompressTable({
		Name = meta.name,
		Id = meta.id,
		Data = networkable
	}))
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
	local metatable: metatable = getmetatable(self)
	local propertysignals = metatable.propertysignals

	self.Changed:Fire(index,value,oldValue)
	if propertysignals[index] then propertysignals[index]:Fire(value, oldValue) end
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
	
	if lastCacheClear > 7 then
		lastCacheClear = 0

		tableManager.clearCache()
		instanceManager.clearCache()
	end
end

runService.Heartbeat:Connect(clearCache)

if isClient then
	tableInit.OnClientEvent:Connect(function(sendData)
		utility.yield()
		local decompressed: {
			Name: string,
			Id: string,
			Data: {any}
		} = bufferLib.DecompressTable(sendData)

		local self = tableReplicator.createMetatable()
		local metatable = getmetatable(self)
		metatable.base = self
		metatable.name = decompressed.Name

		local result = utility.typeHandler(self, decompressed.Data)
		tableManager.registerTable(self, decompressed.Id)
		tableManager.editCacheId(decompressed.Id, 1)
		activeTables[decompressed.Name] = self

		for i,v in result do
			self[i] = v
		end
	end)

	propertyUpdates.OnClientEvent:Connect(function(data)
		local data: propertyUpdate = bufferLib.DecompressTable(data)
		local id = data.id
		local i,v = data.i, data.v
		
		while not tableManager.getTableFromId(id) do warn("No Table Found " .. id) task.wait(1) end
		local tbl: replicatedTable = tableManager.getTableFromId(id)
		local metatable: metatable = getmetatable(tbl)
				
		local i2, v2 = tableManager.getTableFromId(i) 
			or instanceManager.getInstanceFromId(i) 
			or i, tableManager.getTableFromId(v)
			or instanceManager.getInstanceFromId(v) 
			or (v ~= "__EMPTY" and v)
			or nil
		
		tbl[i2] = v2
	end)
end

export type replicatedTable = typeof(tableReplicator.createMetatable(table.unpack(...)))
export type metatable = typeof(getmetatable(tableReplicator.new(table.unpack(...))))

return tableReplicator
