local runService = game:GetService("RunService")
local httpService = game:GetService("HttpService")
local isServer, isClient = runService:IsServer(), runService:IsClient()

local utility = {}

local instanceManager = require(script.Parent.instanceManager)
local tableManager = require(script.Parent.tableManager)
local tableReplicator; task.defer(function()
	print("ran")
	if tableReplicator == nil then
		tableReplicator = require(script.Parent)
		script:SetAttribute((isClient and "client_".."Loaded") or "server_".."Loaded", true)
		print(tableReplicator)
	end
end)


function utility.typeHandler(self, value, id: string?)
	local metatable = getmetatable(self)
	local whitelistedPlayers = (isServer and getmetatable(metatable.base).whitelistedPlayers) or nil
	local cache = metatable.cacheusage

	if type(value) == "table" then

		local newSelf = tableReplicator.createMetatable()
		local newMetatable = getmetatable(newSelf)

		newMetatable.id = if isServer then tostring(value) else id
		newMetatable.base = metatable.base


		for i,v in value do
			newSelf[utility.typeHandler(self, i)] = utility.typeHandler(self, v)
		end
		
		table.insert(cache, metatable.id)

		if isServer then
			tableManager.registerTable(newSelf, newMetatable.id)
			tableManager.replicateTable(utility.copy(newMetatable.__index), whitelistedPlayers)
		end

		return newSelf
	elseif typeof(value) == "Instance" then
		instanceManager.registerInstance(value)
		table.insert(cache, "instance: " .. value:GetDebugId(0))
		
		if isServer then
			instanceManager.replicateInstances(value, whitelistedPlayers)
		end
		
		return value
	elseif typeof(value) == "buffer" then
		value = httpService:JSONDecode(buffer.tostring(value))

		return utility.typeHandler(self, value)
	elseif type(value) == "string" then
		return tableManager.getTableFromId(value) 
			or instanceManager.getInstanceFromId(value) 
			or value
	end

	return value
end

local function checkForReplicatedTable(tbl)
	local metatable = getmetatable(tbl)
	return metatable and metatable.__type == "replicatedTable"
end

function utility.copy(value, networkify)
	if type(value) == "table" then
		local NewTable = {}

		for i,v in (checkForReplicatedTable(value) and getmetatable(value).__index) or value do
			NewTable[utility.copy(i, networkify)] = utility.copy(v, networkify)
		end

		return (networkify and tableManager.getIdFromTable(NewTable)) or NewTable
	elseif typeof(value) == "Instance" then
		return (networkify and instanceManager.getIdFromInstance(value)) or value
	elseif typeof(value) == "buffer" then
		value = httpService:JSONDecode(buffer.tostring(value))

		return utility.copy(value, networkify)
	elseif type(value) == "string" then
		value = (networkify == false and tableManager.getTableFromId(value)) or (networkify == false and instanceManager.getInstanceFromId(value)) or value
	end

	return value
end

return utility