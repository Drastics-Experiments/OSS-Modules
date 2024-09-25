local runService = game:GetService("RunService")

local replicator: RemoteEvent
local isServer, isClient = runService:IsServer(), runService:IsClient()
local instanceManager = {}
local instanceCache = {}
local clientInstanceCache = {}

function instanceManager.registerInstance(instance, id)
    if isServer then
        instanceCache[instance.UniqueId] = instance
    elseif isClient then
        instanceCache[id] = instance
    end
end

function instanceManager.replicateInstances(instances, clients)
    if typeof(clients) ~= "table" then clients = {clients} end
    if typeof(instances) ~= "table" then instances = {instances} end

    for i,v in clients do
        if not clientInstanceCache[v] then clientInstanceCache[v] = {} end
        for i2, v2 in instances do
            if not instanceManager.getInstanceFromId(v2.UniqueId) then instanceManager.registerInstance(v2) end
            clientInstanceCache[v][v2.UniqueId] = v2
            replicator:FireClient(v, v2.UniqueId, v2)
        end
    end
end

function instanceManager.getInstanceFromId(id)
    return instanceCache[id]
end

function getIdFromInstance(instance)
    local a
    for i,v in instanceCache do
        if v == instance then 
            a = v 
            break
        end
    end
    return a
end

if IsServer then
    replicator = Instance.new("RemoteEvent")
    replicator.Parent = script
elseif isClient then
    replicator = script:WaitForChild("RemoteEvent")

    replicator.OnClientEvent:Connect(function(instance, id)
        instanceManager.registerInstance(instance, id)
    end)
end

return instanceManager