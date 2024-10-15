--!strict

local runService = game:GetService("RunService")

local generateID = require(script.idGenerator)

local replicator: RemoteEvent
local isServer, isClient = runService:IsServer(), runService:IsClient()
local instanceManager = {}
local instanceCache = {}::{[string]: Instance?}
local clientInstanceCache = {}
local cacheUsage = {}

function instanceManager.registerInstance(instance: Instance)
	if isServer then
		instanceCache["instance: "..generateID()] = instance
	end
end

function instanceManager.debug()
	print(instanceCache)
	print(cacheUsage)
end

function instanceManager.replicateInstances(instances: {Instance}, clients: { Player })
	if typeof(clients) ~= "table" then clients = {clients} end
	if typeof(instances) ~= "table" then instances = {instances} end

	for i,v in clients do
		if not clientInstanceCache[v] then clientInstanceCache[v] = {} end
		for i2, v2 in instances do
			local id = instanceManager.getIdFromInstance(v2)
			if not id then instanceManager.registerInstance(v2) id = instanceManager.getIdFromInstance(v2) end
			clientInstanceCache[v][id] = v2
			replicator:FireClient(v, id, v2)
		end
	end
end

function instanceManager.clearCache()
	for i,v in instanceCache do
		if cacheUsage[i] then continue end
		instanceCache[i] = nil
	end

	for plr, tbl in clientInstanceCache do
		for id, _ in tbl do
			if not cacheUsage[id] then tbl[id] = nil end
		end
	end
end

function instanceManager.editCacheId(id: string, amount: number)
	if not cacheUsage[id] then cacheUsage[id] = 0 end

	cacheUsage[id] += amount
	if cacheUsage[id] <= 0 then
		cacheUsage[id] = nil
	end
end

function instanceManager.getInstanceFromId(id: string): Instance?
	return instanceCache[id]
end

function instanceManager.getIdFromInstance(instance: Instance): string?
	for i,v in instanceCache do
		if v == instance then
			return i
		end
	end
end

if isServer then
	replicator = Instance.new("RemoteEvent")
	replicator.Parent = script
elseif isClient then
	replicator = script:WaitForChild("RemoteEvent")

	replicator.OnClientEvent:Connect(function(id, instance)
		if instance == nil then warn("No instance provided, make sure the client has access to the instance before adding it to a replicated table.") end
		instanceCache[id] = instance
	end)
end

return instanceManager
