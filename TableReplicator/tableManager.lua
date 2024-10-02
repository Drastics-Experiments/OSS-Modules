

local runService = game:GetService("RunService")
local isClient, isServer = runService:IsClient(), runService:IsServer()

local signal = require(script.Parent.signal)
local bufferLib = require(script.Parent.buffer)

local tableManager = {}
local tableCache = {}
local clientCache = {}
local cacheUsage = {}
local replicator: RemoteEvent

function tableManager.registerTable(tbl, id)
	if signal.Is(tbl) then return end
	tableCache[id or tostring(tbl)] = tbl
end

function tableManager.clearCache()
	for i,v in tableCache do
		if not cacheUsage[i] then
			tableCache[i] = nil
		end
	end

	for i,v in clientCache do
		for i2, v2 in v do
			if not cacheUsage[i2] then
				v[i2] = nil
			end
		end
	end
end

function tableManager.debug()
	print(cacheUsage)
	print(tableCache)
end

function tableManager.editCacheId(id: string, amount: number)
	if not cacheUsage[id] then cacheUsage[id] = 0 end
	cacheUsage[id] += amount
	if cacheUsage[id] <= 0 then
		cacheUsage[id] = nil
	end
end


function tableManager.getIdFromTable(tbl)
	local meta = getmetatable(tbl)
	local id

	if meta and meta.__type == "replicatedTable" then
		id = meta.id
	elseif isServer then
		id = tostring(tbl)
	elseif isClient then
		for i,v in tableCache do
			if v == tbl then id = i end
		end
	end

	return id
end

function tableManager.checkTableReplicated(id, clients)
	for i,v in clients do
		v = clientCache[v]
	end
end

function tableManager.getTableFromId(id)
	return tableCache[id]
end

function tableManager.replicateTable(tbl, players: {Player})
	local dataToSend = tbl
	local buffered = bufferLib.CompressTable(tbl)
	if buffered ~= "failed" then dataToSend = buffered end

	for i,v in players do
		replicator:FireClient(v, tostring(tbl), dataToSend)
	end
end

if isServer then
	replicator = Instance.new("RemoteEvent")
	replicator.Name = "tableReplication"
	replicator.Parent = script
elseif isClient then
	replicator = script:WaitForChild("tableReplication")

	replicator.OnClientEvent:Connect(function(id, tbl)
		local decompressed = bufferLib.DecompressTable(tbl)
		tableCache[id] = if decompressed ~= "failed" then decompressed else tbl
	end)
end

return tableManager
