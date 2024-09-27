local runService = game:GetService("RunService")

local replicator: RemoteEvent
local isServer, isClient = runService:IsServer(), runService:IsClient()
local instanceManager = {}
local instanceCache = {}
local clientInstanceCache = {}

function instanceManager.registerInstance(instance)
	instanceCache["instance: "..instance:GetDebugId(0)] = instance
end

function instanceManager.replicateInstances(instances, clients)
	if typeof(clients) ~= "table" then clients = {clients} end
	if typeof(instances) ~= "table" then instances = {instances} end

	for i,v in clients do
		if not clientInstanceCache[v] then clientInstanceCache[v] = {} end
		for i2, v2 in instances do
			if not instanceManager.getInstanceFromId("instance: "..v2:GetDebugId(0)) then instanceManager.registerInstance(v2) end
			clientInstanceCache[v]["instance: "..v2:GetDebugId(0)] = v2
			replicator:FireClient(v, "instance: "..v2:GetDebugId(0), v2)
			print(v2)
		end
	end
end

function instanceManager.getInstanceFromId(id)
	return instanceCache[id]
end

function instanceManager.getIdFromInstance(instance)
	local a
	for i,v in instanceCache do
		if v == instance then 
			a = i
			break
		end
	end
	return a
end

if isServer then
	replicator = Instance.new("RemoteEvent")
	replicator.Parent = script
elseif isClient then
	replicator = script:WaitForChild("RemoteEvent")

	replicator.OnClientEvent:Connect(function(id, instance)
		print(id,instance)
		instanceCache[id] = instance
		print(instanceCache)
	end)
end

return instanceManager
