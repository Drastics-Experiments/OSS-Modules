--!strict

local runService = game:GetService("RunService")

local replicator: RemoteEvent
local isServer, isClient = runService:IsServer(), runService:IsClient()
local instanceManager = {}
local instanceCache = {}::{[string]: Instance?}
local clientInstanceCache = {}
local cacheUsage = {}

function instanceManager.registerInstance(instance: Instance)
	instanceCache["instance: "..instance:GetDebugId(0)] = instance
end

function instanceManager.replicateInstances(instances: {Instance} | Instance, clients: { Player } | Player)
	if typeof(clients) ~= "table" then clients = {clients} end
	if typeof(instances) ~= "table" then instances = {instances} end

	for i,v in clients do
		if not clientInstanceCache[v] then clientInstanceCache[v] = {} end
		for i2, v2 in instances do
			if not instanceManager.getInstanceFromId("instance: "..v2:GetDebugId(0)) then instanceManager.registerInstance(v2) end
			clientInstanceCache[v]["instance: "..v2:GetDebugId(0)] = v2
			replicator:FireClient(v, "instance: "..v2:GetDebugId(0), v2)
		end
	end
end

function instanceManager.clearCache()
	for i,v in instanceCache do
		if not cacheUsage[i] then
			instanceCache[i] = nil
		end
	end

	for i,v in clientInstanceCache do
		for i2, v2 in v do
			if not cacheUsage[i2] then
				v[i2] = nil
			end
		end
	end
end

function instanceManager.editCacheId(id: string, amount: number)
	if not cacheUsage[id] then cacheUsage[id] = 0 end

	cacheUsage[id] += amount
	if cacheusage[id] <= 0 then
		cacheUsage[id] = nil
	end
end

function instanceManager.getInstanceFromId(id: string): Instance?
	return instanceCache[id]
end

function instanceManager.getIdFromInstance(instance: Instance): string?
	return "instance: " .. instance:GetDebugId(0)
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
