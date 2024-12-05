-- interesting idea i had

local runService = game:GetService("RunService")

local signal = require(script.Signal)

local isClient, isServer = runService:IsClient(), runService:isServer()

local remote = {}
local wrappedRemotes = {}

remote.OnClientEvent = signal.new()
remote.OnServerEvent = signal.new()

local function checkOrCreate(parent, name)
    local remote = parent:FindFirstChild(name)
    if not remote and isServer then
        remote = Instance.new("RemoteEvent")
        remote.Name = name
        remote.Parent = parent
    end
    return remote
end

function remote.new(remoteName)
    local fenv = getfenv(2)
    local script = fenv.script

    local currentRemote = checkOrCreate(script, remoteName)
    local clone = table.clone(remote)
    local self = setmetatable(clone, {
        __index = currentRemote
    })

    if isClient then
        currentRemote.OnClientEvent:Connect(function(serializedData)
            local convertedData = serializedData
            self.OnClientEvent:Fire(convertedData)
        end)
    end

    return self
end

function remote:FireClient()
end

function remote:FireServer()
end

function remote:GetRawRemote()
    return getmetatable(self.__index)
end

export type wrappedRemoteEvent = {
    FireClients: (self, clients: {}, data: ...any),

}

return remote