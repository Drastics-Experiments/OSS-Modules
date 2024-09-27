local runService = game:GetService("RunService")
local isClient, isServer = runService:IsClient(), runService:IsServer()

local bufferLib = require(script.Parent.buffer)

local tableManager = {}
local tableCache = {}
local clientCache = {}
local replicator: RemoteEvent

function tableManager.registerTable(tbl)
	tableCache[tostring(tbl)] = tbl
	print(tableCache)
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
end

return tableManager
