
local runService = game:GetService("RunService")
local isClient, isServer = runService:IsClient(), runService:IsServer()

local signal = require(script.Parent.signal)
local bufferLib = require(script.Parent.buffer)

local tableManager = {}
local tableCache = {}
local clientCache = {}
local replicator: RemoteEvent

function tableManager.registerTable(tbl, id)
	if signal.Is(tbl) then return end
	tableCache[id or tostring(tbl)] = tbl
end

function tableManager.clearCache(cachedata: {[string]: boolean})
	for i,v in tableCache do
		if not cachedata[i] then
			tableCache[i] = nil
		end
	end

	for i,v in clientCache do
		for i2, v2 in v do
			if not cachedata[i2] then
				v[i2] = nil
			end
		end
	end
end

function tableManager.getIdFromTable(tbl)
	if not tableCache[tostring(tbl)] then
		tableManager.registerTable(tbl)
	end

	return tostring(tbl)
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
