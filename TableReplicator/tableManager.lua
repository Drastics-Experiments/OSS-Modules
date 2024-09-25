local runService = game:GetService("RunService")
local isClient, isServer = runService:IsClient(), runService:IsServer()

local tableManager = {}
local replicator: RemoteEvent

if isServer then
    replicator = Instance.new("RemoteEvent")
    replicator.Name = "tableReplication"
    replicator.Parent = script
elseif isClient then
    replicator = script:WaitForChild("tableReplication")
end

return tableManager