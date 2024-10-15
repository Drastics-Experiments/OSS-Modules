local runService = game:GetService("RunService")
local httpService = game:GetService("HttpService")
local isServer, isClient = runService:IsServer(), runService:IsClient()

local utility = {}

local instanceManager = require(script.Parent.instanceManager)
local tableManager = require(script.Parent.tableManager)
local tableReplicator; task.defer(function()
	if tableReplicator == nil then
		tableReplicator = require(script.Parent)
		utility.loaded = true
	end
end)

local function json(input)
	if typeof(input) == "table" then
		return httpService:JSONEncode(input)
	else
		return httpService:JSONDecode(input)
	end
end

function utility.yield()
	if not utility.loaded then
		while not utility.loaded do task.wait() end
	end
end

function utility.manageV3orCf(input: Vector3 | CFrame | string)
	local result;

	if typeof(input) == "Vector3" then
		result = "vector3: "
		result = result .. json({input.X, input.Y, input.Z})
	elseif typeof(input) == "CFrame" then
		result = "cframe: "
		result = result .. json({input:GetComponents()})
	elseif typeof(input) == "string" then
		if string.find(input, "vector3: ") then
			local sub = string.gsub(input, "vector3: ", "")
			result = Vector3.new(table.unpack(json(sub)))
		elseif string.find(input, "cframe: ") then
			local sub = string.gsub(input, "cframe: ", "")
			result = CFrame.new(table.unpack(json(sub)))
		end
	end

	return result
end

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

		tableManager.editCacheId(metatable.id, 1)

		if isServer then
			tableManager.registerTable(newSelf, newMetatable.id)
			tableManager.replicateTable(utility.copy(newMetatable.__index), whitelistedPlayers)
		end

		return newSelf
	elseif typeof(value) == "Instance" then
		instanceManager.registerInstance(value)
		instanceManager.editCacheId(instanceManager.getIdFromInstance(value), 1)

		if isServer then instanceManager.replicateInstances(value, whitelistedPlayers) end

		return value
	elseif typeof(value) == "CFrame" or typeof(value) == "Vector3" then
		return utility.manageV3orCf(value)
	elseif typeof(value) == "buffer" then
		value = httpService:JSONDecode(buffer.tostring(value))

		return utility.typeHandler(self, value)
	elseif type(value) == "string" then
		return tableManager.getTableFromId(value) 
			or instanceManager.getInstanceFromId(value)
			or utility.manageV3orCf(value)
			or (value ~= "__EMPTY" and value)
			or nil
	elseif typeof(value) == "nil" then
		return "__EMPTY" -- needed so the property updates table doesnt get garbage collected
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